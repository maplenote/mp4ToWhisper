# Whisper 影片字幕辨識標準作業程序 (SOP)

這是一份專為解決「Whisper 處理長靜音導致異常循環」所設計的標準作業程序 (SOP)。
此流程利用 PowerShell 7.5 與 FFmpeg 自動化處理「偵測靜音 → 切割 → 辨識 → 合併 → 轉純文字」的所有步驟。

**核心目標**：避免 Whisper 因長靜音 (\>=8 秒) 產生幻覺或重複，確保時間軸精準。
**適用環境**：Windows 11 / PowerShell 7.5
**必備工具**：FFmpeg, OpenAI Whisper (Python 版)
**檔案結構**：

- `file/ori_mp4/`: 原始影片檔
- `file/ori_mp3/`: 轉換後的 MP3 (或手動放入的 MP3)
- `file/tmp_mp3/`: 切割後的 MP3 片段
- `file/tmp_csv/`: 切割片段的 Offset 資訊
- `file/tmp_srt/`: Whisper 辨識出的片段字幕
- `file/fin_srt/`: 最終合併的字幕檔

## 步驟 0：環境建置

檢查是否已安裝 uv
`uv --version`

檢查 uv 目前以安裝 python 版本
`uv python find`

windows 安裝 uv
`powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"`

建議安裝 python 3.11 (Whisper 在 3.14.0 版本安裝會出錯)
`uv python install 3.11`

uv 版本更新
`uv self update`

更新 uv 所有已安裝的依賴包
`uv tool upgrade --all`

想在全域使用 OpenAI Whisper 的指令 (全域工具)
`uv tool install openai-whisper --python 3.11`

安裝完成後，你不需要手動下載模型 (它不吃 ggml)，直接跑指令，它會自動偵測 GPU (CUDA) 並下載對應的 .pt 模型

範例：使用 medium 模型轉錄 mp4
`whisper "你的錄影檔名.mp4" --model medium --device cuda`

## 步驟 1：準備資料夾與轉換 MP4 (Phase 1)

此步驟會自動建立所需資料夾，並將 `file/ori_mp4/` 內的影片轉換為 MP3 放入 `file/ori_mp3/`。
若您有錄影失敗的檔案，請手動轉成 MP3 後直接放入 `file/ori_mp3/`。

請將以下腳本存為 `0_Prepare_And_Convert.ps1` 並執行。

```powershell
# 設定區
$Folders = @("file/ori_mp4", "file/ori_mp3", "file/tmp_mp3", "file/tmp_csv", "file/tmp_srt", "file/fin_srt")
foreach ($f in $Folders) { if (!(Test-Path $f)) { New-Item -ItemType Directory -Path $f -Force | Out-Null } }

$OriMp4Dir = "file/ori_mp4"
$OriMp3Dir = "file/ori_mp3"

# 轉換 MP4 -> MP3
Get-ChildItem "$OriMp4Dir/*.mp4" | ForEach-Object {
    $BaseName = $_.BaseName
    $Output = Join-Path $OriMp3Dir "$BaseName.mp3"
    if (!(Test-Path $Output)) {
        Write-Host "正在轉換 $($_.Name) 為 MP3..." -ForegroundColor Cyan
        ffmpeg -v error -i $_.FullName -vn -acodec libmp3lame -q:a 2 $Output
    }
}
Write-Host "準備完成！請確認 file/ori_mp3/ 內有檔案。" -ForegroundColor Green
```

## 步驟 2：自動偵測靜音並切割音訊 (Phase 2)

此步驟會掃描 `file/ori_mp3/`，計算檔案雜湊值 (MD5) 以產生唯一 ID，並依據靜音區段切割檔案。
切割後的檔案會存入 `file/tmp_mp3/`，命名格式為 `{ID}_chunk_{編號}.mp3`。
Offset 資訊會存入 `file/tmp_csv/{ID}.csv`。

請將以下腳本存為 `1_Split_Audio.ps1` 並執行。

```powershell
# 設定區
$OriMp3Dir = "file/ori_mp3"
$TmpMp3Dir = "file/tmp_mp3"
$TmpCsvDir = "file/tmp_csv"
$SilenceDuration = 8             # 設定靜音閾值 (秒)
$SilenceDb = -50                 # 設定靜音分貝 (dB)

# --- 腳本邏輯開始 ---
Get-ChildItem "$OriMp3Dir/*.mp3" | ForEach-Object {
    $InputFile = $_
    Write-Host "正在處理 $($InputFile.Name)..." -ForegroundColor Yellow

    # 1. 取得標準 32 字元的十六進位 MD5
    $Hash = (Get-FileHash $InputFile.FullName -Algorithm MD5).Hash

    # 2. (關鍵) 將 32 字元的 Hex 轉換回 16-byte 的「原始二進位」陣列
    $Bytes = [System.Convert]::FromHexString($Hash)

    # 3. 將 16-byte 陣列轉換為標準 Base64 字串
    $Base64 = [System.Convert]::ToBase64String($Bytes)

    # 4. 轉換為「檔名安全」格式 (替換 +/ 並移除 =)
    $FileID = $Base64.Replace('+', '-').Replace('/', '_').TrimEnd('=')
    
    Write-Host "  檔案 ID: $FileID" -ForegroundColor Gray

    # 偵測靜音
    $FfmpegOutput = ffmpeg -i $InputFile.FullName -af "silencedetect=noise=${SilenceDb}dB:d=${SilenceDuration}" -f null - 2>&1
    $Matches = [regex]::Matches($FfmpegOutput, 'silence_start: (\d+(\.\d+)?)|silence_end: (\d+(\.\d+)?)')

    $Segments = @()
    $LastEnd = 0

    foreach ($Match in $Matches) {
        if ($Match.Value -match "silence_start") {
            $CurrentStart = $Match.Groups[1].Value -as [double]
            if ($CurrentStart -gt $LastEnd) {
                $Segments += [PSCustomObject]@{ Start = $LastEnd; End = $CurrentStart }
            }
        } elseif ($Match.Value -match "silence_end") {
            $LastEnd = $Match.Groups[3].Value -as [double]
        }
    }
    $Segments += [PSCustomObject]@{ Start = $LastEnd; End = "EOF" } 

    # 執行切割
    $OffsetData = @()
    $Counter = 1

    foreach ($Seg in $Segments) {
        $ChunkName = "${FileID}_chunk_${Counter}.mp3"
        $ChunkPath = Join-Path $TmpMp3Dir $ChunkName
        $Start = $Seg.Start
        $End = $Seg.End
        
        # 記錄 Offset 與原始檔名
        $OffsetData += [PSCustomObject]@{ 
            ID = $FileID
            OriginalFileName = $InputFile.Name
            ChunkName = $ChunkName
            Offset = $Start 
        }

        if ($End -eq "EOF") {
            ffmpeg -v error -i $InputFile.FullName -ss $Start -ar 16000 -ac 1 -b:a 128k -y $ChunkPath
        } else {
            ffmpeg -v error -i $InputFile.FullName -ss $Start -to $End -ar 16000 -ac 1 -b:a 128k -y $ChunkPath
        }
        $Counter++
    }

    # 儲存 CSV
    $CsvPath = Join-Path $TmpCsvDir "${FileID}.csv"
    $OffsetData | Export-Csv -Path $CsvPath -NoTypeInformation
}
Write-Host "`n切割完成！" -ForegroundColor Green
```

## 步驟 3：執行 Whisper 辨識 (Phase 3)

批次辨識 `file/tmp_mp3/` 內的片段，並將 SRT 輸出至 `file/tmp_srt/`。

請在 PowerShell 終端機直接輸入：

```powershell
$TmpMp3Dir = "file/tmp_mp3"
$TmpSrtDir = "file/tmp_srt"

Get-ChildItem "$TmpMp3Dir/*.mp3" | ForEach-Object {
    $SrtName = $_.Name -replace ".mp3", ".srt"
    $SrtPath = Join-Path $TmpSrtDir $SrtName
    
    if (!(Test-Path $SrtPath)) {
        Write-Host "正在辨識 $($_.Name) ..." -ForegroundColor Yellow
        # 注意: --output_dir 指定輸出目錄
        whisper $_.FullName --model medium --language Chinese --device cuda --output_format srt --output_dir $TmpSrtDir --verbose False
    }
}
```

## 步驟 4：合併字幕並校正時間軸 (Phase 4)

此步驟改為掃描 `file/ori_mp3/`，檢查是否已有最終字幕。若無，則計算 MD5 ID 尋找對應的 CSV 與片段字幕進行合併。

請將以下腳本存為 `2_Merge_SRT.ps1` 並執行。

```powershell
# 設定區
$OriMp3Dir = "file/ori_mp3"
$TmpCsvDir = "file/tmp_csv"
$TmpSrtDir = "file/tmp_srt"
$FinSrtDir = "file/fin_srt"

# --- 腳本邏輯開始 ---
Get-ChildItem "$OriMp3Dir/*.mp3" | ForEach-Object {
    $InputFile = $_
    $BaseName = $InputFile.BaseName
    $FinalSrtName = "$BaseName.srt"
    $OutputFile = Join-Path $FinSrtDir $FinalSrtName

    # 1. 檢查是否已存在最終字幕
    if (Test-Path $OutputFile) {
        Write-Host "跳過: $FinalSrtName (檔案已存在)" -ForegroundColor DarkGray
        return # 繼續處理下一個檔案
    }

    Write-Host "正在處理: $($InputFile.Name)..." -ForegroundColor Cyan

    # 2. 計算 ID (需與切割步驟演算法一致)
    $Hash = (Get-FileHash $InputFile.FullName -Algorithm MD5).Hash
    $Bytes = [System.Convert]::FromHexString($Hash)
    $Base64 = [System.Convert]::ToBase64String($Bytes)
    $FileID = $Base64.Replace('+', '-').Replace('/', '_').TrimEnd('=')

    # 3. 尋找對應的 CSV
    $CsvPath = Join-Path $TmpCsvDir "${FileID}.csv"
    if (-not (Test-Path $CsvPath)) {
        Write-Warning "  找不到對應的 CSV: $CsvPath (可能尚未切割或 ID 不符)"
        return
    }

    # 4. 執行合併
    $Offsets = Import-Csv $CsvPath
    $GlobalCounter = 1
    
    foreach ($Row in $Offsets) {
        $ChunkSrtName = $Row.ChunkName -replace ".mp3", ".srt"
        $ChunkSrtPath = Join-Path $TmpSrtDir $ChunkSrtName
        $TimeOffset = [double]$Row.Offset
        
        if (-not (Test-Path $ChunkSrtPath)) { 
            Write-Warning "  找不到片段字幕: $ChunkSrtPath"
            continue 
        }

        $Content = Get-Content $ChunkSrtPath
        $TimeSpanOffset = [TimeSpan]::FromSeconds($TimeOffset)

        foreach ($Line in $Content) {
            if ($Line -match '(\d{2}:\d{2}:\d{2},\d{3})\s+-->\s+(\d{2}:\d{2}:\d{2},\d{3})') {
                $StartT = [TimeSpan]::Parse($Matches[1].Replace(',', '.'))
                $EndT   = [TimeSpan]::Parse($Matches[2].Replace(',', '.'))

                $NewStart = $StartT.Add($TimeSpanOffset).ToString('hh\:mm\:ss\,fff')
                $NewEnd   = $EndT.Add($TimeSpanOffset).ToString('hh\:mm\:ss\,fff')

                "$NewStart --> $NewEnd" | Add-Content $OutputFile
            }
            elseif ($Line -match '^\d+$') {
                "$GlobalCounter" | Add-Content $OutputFile
                $GlobalCounter++
            }
            else {
                $Line | Add-Content $OutputFile
            }
        }
    }
    Write-Host "  合併完成 -> $FinalSrtName" -ForegroundColor Green
}
Write-Host "所有作業結束！"
```

## 步驟 5：產生純文字檔 (Phase 5)

若您需要沒有時間碼的逐字稿，請執行此步驟。會將 `file/fin_srt/` 內的字幕轉為同名的 `.txt`。

請將以下腳本存為 `3_Extract_Text.ps1` 並執行。

```powershell
# 設定區
$FinSrtDir = "file/fin_srt"

# --- 腳本邏輯開始 ---
Get-ChildItem "$FinSrtDir/*.srt" | ForEach-Object {
    $InputSrt = $_.FullName
    $OutputTxt = $_.FullName -replace ".srt", ".txt"
    
    Write-Host "正在提取文字: $($_.Name)"
    
    $Content = Get-Content $InputSrt -Raw
    $TextOnly = $Content -replace '(?m)^\d+\r?\n', '' `
                         -replace '(?m)^\d{2}:\d{2}:\d{2},\d{3} --> \d{2}:\d{2}:\d{2},\d{3}\r?\n', '' `
                         -replace '(?m)^\s*[\r\n]+', "`r`n" 

    $TextOnly | Set-Content $OutputTxt -Encoding UTF8
}
Write-Host "純文字提取完成！" -ForegroundColor Green
```

### SOP 總結

1. **準備**：執行 `0_Prepare_And_Convert.ps1` (建立資料夾、MP4轉MP3)。
2. **切割**：執行 `1_Split_Audio.ps1` (產出 chunk mp3 和 csv)。
3. **辨識**：在終端機執行 `whisper` 批次指令 (產出 chunk srt)。
4. **合併**：執行 `2_Merge_SRT.ps1` (產出 完整 srt)。
5. **轉文**：執行 `3_Extract_Text.ps1` (產出 完整 txt)。

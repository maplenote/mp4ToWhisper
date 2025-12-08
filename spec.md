# Whisper 影片字幕辨識標準作業程序 (SOP)

這是一份專為解決「Whisper 處理長靜音導致異常循環」所設計的標準作業程序 (SOP)。
此流程利用 PowerShell 7.5 與 FFmpeg 自動化處理「偵測靜音 → 切割 → 辨識 → 合併 → 轉純文字」的所有步驟。

**核心目標**：避免 Whisper 因長靜音 (\>=8 秒) 產生幻覺或重複，確保時間軸精準。
**適用環境**：Windows 11 / PowerShell 7.5 (請務必使用 `pwsh` 指令執行)
**必備工具**：FFmpeg, OpenAI Whisper (Python 版)
**檔案結構**：

- `powershell/`: 各步驟執行的 ps1 檔
- `file/ori_mp4/`: 原始影片檔
- `file/ori_mp3/`: 轉換後的 MP3 (或手動放入的 MP3)
- `file/tmp_mp3/`: 切割後的 MP3 片段
- `file/tmp_csv/`: 切割片段的 Offset 資訊
- `file/tmp_srt/`: Whisper 辨識出的片段字幕
- `file/merge_srt/`: 合併後的字幕 (`_merge.srt`)、AI 對照表 (`.json`)、AI 優化字幕 (`_ai.srt`)
- `file/fin_srt/`: 最終字幕檔

## 步驟 0：環境建置

### 安裝 FFmpeg

FFmpeg 用於音訊格式轉換與靜音偵測，建議使用 7.0 以上版本。

**Windows 手動安裝步驟**：

1. 前往 [FFmpeg Builds by Gyan](https://www.gyan.dev/ffmpeg/builds/) 下載 **release full** 版本
2. 解壓縮到任意目錄，例如 `C:\Program Files\ffmpeg`
3. 將 `C:\Program Files\ffmpeg\bin` 加入 windows 系統 PATH 環境變數：
   - 開啟「系統內容」→「進階系統設定」→「環境變數」
   - 在「系統變數」中找到 `Path`，點擊「編輯」
   - 新增 `C:\Program Files\ffmpeg\bin`
4. 開啟新的 PowerShell 視窗，執行以下指令確認安裝成功：

```powershell
ffmpeg -version
```

### 安裝 uv 套件管理器

檢查是否已安裝 uv
`uv --version`

Windows 安裝 uv
`powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"`

uv 版本更新
`uv self update`

### 安裝專案相依套件

在專案目錄下執行以下指令，會自動建立 `.venv` 虛擬環境並安裝所有相依套件 (含 PyTorch CUDA 版本)：

```powershell
uv sync
```

**注意**：首次執行會下載約 2.5GB 的 PyTorch 相依套件，請確保網路暢通。

### 下載 Whisper 模型

首次執行辨識時會自動下載模型，或可手動預先下載：

```powershell
uv run whisper --model medium --model_dir "file/models" --help
```

模型存放在 `file/models/` 目錄中 (約 1.5GB)，不會被系統暫存清理刪除。

### 測試 Whisper 是否正常運作

```powershell
uv run whisper "file/tmp/test.mp3" --model medium --device cuda --model_dir "file/models" --language Chinese --output_format srt --output_dir "file/tmp"
```

執行後會在終端機直接顯示辨識後的內容 (輸出檔案會在 `file/tmp/test.srt`)：

```text
[00:00.000 --> 00:02.000] 這是測試用的語音
```

若顯示 "UserWarning: FP16 is not supported on CPU; using FP32 instead"，表示正在使用 CPU 執行。
請確認已安裝 NVIDIA GPU 驅動程式，並檢查 `pyproject.toml` 中的 `extra-index-url` 設定。

清除 uv 暫存檔案 (不會影響專案內的 .venv 和 models)
`uv cache clean`

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

**參數說明**：

- `-TargetFileName "檔案名.mp3"`：指定只處理單一檔案
- `-Force`：強制重新處理 (忽略已存在的輸出檔案)

**範例**：

```powershell
# 處理全部檔案
.\powershell\1_Split_Audio.ps1

# 處理指定檔案
.\powershell\1_Split_Audio.ps1 -TargetFileName "my_video.mp3"

# 強制重新處理指定檔案
.\powershell\1_Split_Audio.ps1 -TargetFileName "my_video.mp3" -Force
```

腳本存放於 `powershell/1_Split_Audio.ps1`。

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

**參數說明**：

- `-TargetFileName "檔案名.mp3"`：指定只處理單一檔案 (需為 `file/ori_mp3` 中的原始檔名)
- `-Force`：強制重新處理 (忽略已存在的輸出檔案)
- `-Model "medium"`：指定 Whisper 模型 (預設 medium)

**範例**：

```powershell
# 處理全部檔案
.\powershell\1.5_Run_whisper.ps1

# 處理指定檔案
.\powershell\1.5_Run_whisper.ps1 -TargetFileName "my_video.mp3"

# 強制重新處理指定檔案
.\powershell\1.5_Run_whisper.ps1 -TargetFileName "my_video.mp3" -Force
```

腳本存放於 `powershell/1.5_Run_whisper.ps1`。

```powershell
# (腳本內容略，請直接執行檔案)
```

## 步驟 4：合併字幕並校正時間軸 (Phase 4)

此步驟會掃描 `file/ori_mp3/`，計算 MD5 ID 尋找對應的 CSV 與片段字幕進行合併。
合併後的字幕會存入 `file/merge_srt/`，命名格式為 `{原檔名}_merge.srt`。

**參數說明**：

- `-TargetFileName "檔案名.mp3"`：指定只處理單一檔案
- `-Force`：強制重新處理 (忽略已存在的輸出檔案)

**範例**：

```powershell
# 處理全部檔案
.\powershell\2_Merge_SRT.ps1

# 處理指定檔案
.\powershell\2_Merge_SRT.ps1 -TargetFileName "my_video.mp3"

# 強制重新處理指定檔案
.\powershell\2_Merge_SRT.ps1 -TargetFileName "my_video.mp3" -Force
```

腳本存放於 `powershell/2_Merge_SRT.ps1`。

```powershell
# 設定區
$OriMp3Dir = "file/ori_mp3"
$TmpCsvDir = "file/tmp_csv"
$TmpSrtDir = "file/tmp_srt"
$MergeSrtDir = "file/merge_srt"  # 合併輸出目錄

# --- 腳本邏輯開始 ---
Get-ChildItem "$OriMp3Dir/*.mp3" | ForEach-Object {
    $InputFile = $_
    $BaseName = $InputFile.BaseName
    $MergeSrtName = "${BaseName}_merge.srt"
    $OutputFile = Join-Path $MergeSrtDir $MergeSrtName

    # 1. 檢查是否已存在合併字幕
    if (Test-Path $OutputFile) {
        Write-Host "跳過: $MergeSrtName (檔案已存在)" -ForegroundColor DarkGray
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
    Write-Host "  合併完成 -> $MergeSrtName" -ForegroundColor Green
}
Write-Host "所有作業結束！"
```

## 步驟 4.2：簡轉繁 (Phase 4.2)

此步驟使用 OpenCC 將 `file/merge_srt/` 內的簡體字幕轉換為繁體中文 (台灣正體)。

**參數說明**：

- `-TargetFileName "檔案名.mp3"`：指定只處理單一檔案

**範例**：

```powershell
.\powershell\2.2_Convert_S2T.ps1
```

## 步驟 4.5：AI 優化辨識錯誤文字 (Phase 4.5)

此步驟由 AI Agent 根據當次辨識的主題，分析 `file/merge_srt/` 內的 `_merge.srt` 字幕檔，產生專用的錯誤對照表並套用修正。

> **注意**：本專案所有 SRT 檔案與程式碼皆採用 **UTF-8** 編碼。AI 在讀取檔案內容或檔名時，請確保使用 UTF-8 格式，避免中文出現亂碼。

### 檔案命名規則

```text
file/merge_srt/
├── {檔名}_merge.srt   # 步驟 4 合併的原始字幕
├── {檔名}.json        # AI 產生的專用對照表
└── {檔名}_ai.srt      # AI 優化後的字幕

file/fin_srt/
└── {檔名}.srt         # 最終字幕 (複製自 _ai.srt)
```

### 範本對照表

範本位於 `.github/prompts/errorWords.json`，包含程式術語、框架名稱等常見辨識錯誤供 AI 參考。

### AI Agent 使用方式

使用 `.github/prompts/fixErrorWords.prompt.md` 提示詞，AI 會：

1. 讀取 `_merge.srt` 字幕內容
2. 根據主題識別可能的辨識錯誤
3. 產生 `{檔名}.json` 專用對照表
4. 套用修正並輸出 `{檔名}_ai.srt`
5. 複製至 `file/fin_srt/{檔名}.srt`

### PowerShell 輔助腳本

完成 JSON 對照表後，可執行腳本自動套用：

```powershell
# 處理全部檔案
.\powershell\2.5_Fix_Error_Words.ps1

# 處理指定檔案
.\powershell\2.5_Fix_Error_Words.ps1 -TargetFileName "my_video.mp3"

# 強制重新處理
.\powershell\2.5_Fix_Error_Words.ps1 -Force
```

### 對照表 JSON 結構

```json
{
  "version": "1.0",
  "description": "針對 {主題} 的錯誤對照表",
  "topic": "{辨識主題}",
  "mappings": [
    {
      "wrong": ["錯誤寫法1", "錯誤寫法2"],
      "correct": "正確文字",
      "category": "database",
      "note": "說明"
    }
  ]
}
```

這種設計的優點：

- 每次辨識都有專屬的對照表，方便追蹤
- `_merge.srt` 與 `_ai.srt` 並存，可用 diff 比對修改內容
- JSON 檔案可累積為知識庫，改善未來辨識品質

## 步驟 5：產生純文字檔 (Phase 5)

若您需要沒有時間碼的逐字稿，請執行此步驟。會將 `file/fin_srt/` 內的字幕轉為同名的 `.txt`。

**參數說明**：

- `-TargetFileName "檔案名.mp3"`：指定只處理單一檔案 (可輸入 .mp3 或 .srt 檔名)
- `-Force`：強制重新處理 (忽略已存在的輸出檔案)

**範例**：

```powershell
# 處理全部檔案
.\powershell\3_Extract_Text.ps1

# 處理指定檔案
.\powershell\3_Extract_Text.ps1 -TargetFileName "my_video.mp3"

# 強制重新處理指定檔案
.\powershell\3_Extract_Text.ps1 -TargetFileName "my_video.srt" -Force
```

腳本存放於 `powershell/3_Extract_Text.ps1`。

```powershell
# (腳本內容略，請直接執行檔案)
```

## 步驟 6：清空暫存資料夾 (Cleanup)

當專案執行完畢或需要重置環境時，可使用此腳本清空 `file/` 下除了 `models` 以外的所有資料夾內容。
此腳本會保留所有 `.gitkeep` 檔案以維持目錄結構。

**參數說明**：

- `-Force`：強制刪除 (不詢問確認)
- `-DryRun`：模擬執行 (僅列出會被刪除的檔案，不實際刪除)

**範例**：

```powershell
# 互動式確認後刪除
.\powershell\Clear_File_Dir.ps1

# 強制刪除
.\powershell\Clear_File_Dir.ps1 -Force

# 模擬刪除
.\powershell\Clear_File_Dir.ps1 -DryRun
```

### SOP 總結

1. **環境**：執行 `uv sync` (建立虛擬環境並安裝相依套件)。
2. **準備**：執行 `.\powershell\0_Prepare_And_Convert.ps1` (建立資料夾、MP4 轉 MP3)。
3. **切割**：執行 `.\powershell\1_Split_Audio.ps1` (產出 chunk mp3 和 csv)。
4. **辨識**：執行 `.\powershell\1.5_Run_whisper.ps1` (產出 chunk srt)。
5. **合併**：執行 `.\powershell\2_Merge_SRT.ps1` (產出 完整 srt)。
6. **修正**：執行 `.\powershell\2.5_Fix_Error_Words.ps1` (自動修正常見辨識錯誤)。
7. **轉文**：執行 `.\powershell\3_Extract_Text.ps1` (產出 完整 txt)。
8. **清理**：執行 `.\powershell\Clear_File_Dir.ps1` (清空暫存檔，保留 models/ 與 .gitkeep)。

param (
    [string]$TargetFileName = $null,
    [switch]$Force = $false
)

# 設定區
$BaseDir = Join-Path $PSScriptRoot ".."
$OriMp3Dir = Join-Path $BaseDir "file/ori_mp3"
$TmpMp3Dir = Join-Path $BaseDir "file/tmp_mp3"
$TmpCsvDir = Join-Path $BaseDir "file/tmp_csv"
$SilenceDuration = 8             # 設定靜音閾值 (秒)
$SilenceDb = -50                 # 設定靜音分貝 (dB)

# 決定要處理的檔案列表
if ($TargetFileName) {
    $FullPath = Join-Path $OriMp3Dir $TargetFileName
    if (-not (Test-Path $FullPath)) { 
        Write-Error "找不到指定檔案: $FullPath"
        exit 1 
    }
    $FilesToProcess = @(Get-Item $FullPath)
} else {
    $FilesToProcess = Get-ChildItem "$OriMp3Dir/*.mp3"
}

# --- 腳本邏輯開始 ---
$FilesToProcess | ForEach-Object {
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

    # 檢查是否已處理過
    $CsvPath = Join-Path $TmpCsvDir "${FileID}.csv"
    if ((Test-Path $CsvPath) -and (-not $Force)) {
        Write-Host "  跳過: 已存在切割資訊 (使用 -Force 強制重跑)" -ForegroundColor DarkGray
        return
    }

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
    $OffsetData | Export-Csv -Path $CsvPath -NoTypeInformation
}
Write-Host "`n切割完成！" -ForegroundColor Green

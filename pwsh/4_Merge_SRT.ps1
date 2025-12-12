param (
    [string]$TargetFileName = $null,
    [switch]$Force = $false
)

# 設定區
$BaseDir = Join-Path $PSScriptRoot ".."
$OriMp3Dir = Join-Path $BaseDir "file/ori_mp3"
$TmpCsvDir = Join-Path $BaseDir "file/tmp_csv"
$TmpSrtDir = Join-Path $BaseDir "file/tmp_srt"
$MergeSrtDir = Join-Path $BaseDir "file/merge_srt"  # 第一次合併輸出目錄

# 確保 merge_srt 目錄存在
if (-not (Test-Path $MergeSrtDir)) {
    New-Item -ItemType Directory -Path $MergeSrtDir -Force | Out-Null
}

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
    $BaseName = $InputFile.BaseName
    $MergeSrtName = "${BaseName}_merge.srt"  # 合併後的檔名格式
    $OutputFile = Join-Path $MergeSrtDir $MergeSrtName

    # 1. 檢查是否已存在合併字幕
    if ((Test-Path $OutputFile) -and (-not $Force)) {
        Write-Host "跳過: $MergeSrtName (檔案已存在，使用 -Force 強制重跑)" -ForegroundColor DarkGray
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
    $Offsets = Import-Csv $CsvPath -Encoding UTF8
    $GlobalCounter = 1
    
    # 清除舊檔 (如果是 Force 模式)
    if (Test-Path $OutputFile) { Remove-Item $OutputFile }

    foreach ($Row in $Offsets) {
        $ChunkSrtName = $Row.ChunkName -replace ".mp3", ".srt"
        $ChunkSrtPath = Join-Path $TmpSrtDir $ChunkSrtName
        $TimeOffset = [double]$Row.Offset
        
        if (-not (Test-Path $ChunkSrtPath)) { 
            Write-Warning "  找不到片段字幕: $ChunkSrtPath"
            continue 
        }

        $Content = Get-Content $ChunkSrtPath -Encoding UTF8
        $TimeSpanOffset = [TimeSpan]::FromSeconds($TimeOffset)

        foreach ($Line in $Content) {
            if ($Line -match '(\d{2}:\d{2}:\d{2},\d{3})\s+-->\s+(\d{2}:\d{2}:\d{2},\d{3})') {
                $StartT = [TimeSpan]::Parse($Matches[1].Replace(',', '.'))
                $EndT   = [TimeSpan]::Parse($Matches[2].Replace(',', '.'))

                $NewStart = $StartT.Add($TimeSpanOffset).ToString('hh\:mm\:ss\,fff')
                $NewEnd   = $EndT.Add($TimeSpanOffset).ToString('hh\:mm\:ss\,fff')

                "$NewStart --> $NewEnd" | Add-Content $OutputFile -Encoding UTF8
            }
            elseif ($Line -match '^\d+$') {
                "$GlobalCounter" | Add-Content $OutputFile -Encoding UTF8
                $GlobalCounter++
            }
            else {
                $Line | Add-Content $OutputFile -Encoding UTF8
            }
        }
    }
    Write-Host "  合併完成 -> $MergeSrtName" -ForegroundColor Green
}
Write-Host "所有作業結束！"

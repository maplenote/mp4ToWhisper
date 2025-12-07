param (
    [string]$TargetFileName = $null,
    [switch]$Force = $false
)

# 設定區
$BaseDir = Join-Path $PSScriptRoot ".."
$FinSrtDir = Join-Path $BaseDir "file/fin_srt"

# 決定要處理的檔案列表
if ($TargetFileName) {
    # 允許使用者輸入 mp3 或 srt 檔名
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($TargetFileName)
    $SrtName = "$BaseName.srt"
    $FullPath = Join-Path $FinSrtDir $SrtName
    
    if (-not (Test-Path $FullPath)) { 
        Write-Error "找不到指定字幕檔: $FullPath"
        exit 1 
    }
    $FilesToProcess = @(Get-Item $FullPath)
} else {
    $FilesToProcess = Get-ChildItem "$FinSrtDir/*.srt"
}

# --- 腳本邏輯開始 ---
$FilesToProcess | ForEach-Object {
    $InputSrt = $_.FullName
    $OutputTxt = [System.IO.Path]::ChangeExtension($_.FullName, ".txt")
    
    if ((Test-Path $OutputTxt) -and (-not $Force)) {
        Write-Host "跳過: $($_.Name) (檔案已存在，使用 -Force 強制重跑)" -ForegroundColor DarkGray
        return
    }

    Write-Host "正在提取文字: $($_.Name)"
    
    $Content = Get-Content $InputSrt -Raw
    $TextOnly = $Content -replace '(?m)^\d+\r?\n', '' `
                         -replace '(?m)^\d{2}:\d{2}:\d{2},\d{3} --> \d{2}:\d{2}:\d{2},\d{3}\r?\n', '' `
                         -replace '(?m)^\s*[\r\n]+', "`r`n" 

    $TextOnly | Set-Content $OutputTxt -Encoding UTF8
}
Write-Host "純文字提取完成！" -ForegroundColor Green

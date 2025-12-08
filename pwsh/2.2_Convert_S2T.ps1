# 2.2_Convert_S2T.ps1
# 使用 OpenCC 將合併後的簡體字幕轉換為繁體中文 (台灣正體)
# 
# 工作流程：
# 1. 讀取 file/merge_srt/{檔名}_merge.srt
# 2. 呼叫 python_scripts/convert_s2t.py 進行轉換
# 3. 覆蓋原始檔案 (或另存，目前設定為覆蓋以利後續流程)

param(
    [Parameter(Mandatory = $false)]
    [string]$TargetFileName,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# 設定區
$BaseDir = Join-Path $PSScriptRoot ".."
$MergeSrtDir = Join-Path $BaseDir "file/merge_srt"
$PythonScript = Join-Path $BaseDir "python_scripts/convert_s2t.py"

# 嘗試尋找 .venv 的 python
$VenvPython = Join-Path $BaseDir ".venv/Scripts/python.exe"
if (-not (Test-Path $VenvPython)) {
    # 如果找不到 venv，嘗試直接用 python 指令
    $VenvPython = "python"
}

# 檢查 Python 腳本是否存在
if (-not (Test-Path $PythonScript)) {
    Write-Host "錯誤：找不到 Python 轉換腳本 $PythonScript" -ForegroundColor Red
    exit 1
}

# --- 腳本邏輯開始 ---

# 1. 決定要處理的檔案
if ($TargetFileName) {
    # 處理單一指定檔案 (支援 .mp3 或 _merge.srt 格式)
    $BaseName = $TargetFileName -replace "\.mp3$", "" -replace "_merge\.srt$", "" -replace "\.srt$", ""
    $MergeSrtPath = Join-Path $MergeSrtDir "${BaseName}_merge.srt"
    
    if (-not (Test-Path $MergeSrtPath)) {
        Write-Host "錯誤：找不到合併字幕檔案 $MergeSrtPath" -ForegroundColor Red
        exit 1
    }
    $MergeFiles = @(Get-Item $MergeSrtPath)
} else {
    # 處理所有 _merge.srt 檔案
    $MergeFiles = Get-ChildItem "$MergeSrtDir/*_merge.srt" -ErrorAction SilentlyContinue
}

if ($MergeFiles.Count -eq 0) {
    Write-Host "在 $MergeSrtDir 目錄下找不到任何 _merge.srt 檔案" -ForegroundColor Yellow
    exit 0
}

Write-Host "準備進行簡繁轉換 (OpenCC)..." -ForegroundColor Cyan
Write-Host "找到 $($MergeFiles.Count) 個待處理檔案`n" -ForegroundColor Cyan

# 2. 處理每個檔案
foreach ($MergeFile in $MergeFiles) {
    Write-Host "處理中: $($MergeFile.Name)" -ForegroundColor Yellow
    
    # 執行 Python 腳本進行轉換
    # 直接覆蓋原檔案，這樣後續的 2.5_Fix_Error_Words.ps1 就能直接讀到繁體內容
    $ProcessInfo = Start-Process -FilePath $VenvPython -ArgumentList "`"$PythonScript`"", "`"$($MergeFile.FullName)`"" -NoNewWindow -Wait -PassThru
    
    if ($ProcessInfo.ExitCode -eq 0) {
        Write-Host "  轉換成功 (簡 -> 繁)" -ForegroundColor Green
    } else {
        Write-Host "  轉換失敗 (Exit Code: $($ProcessInfo.ExitCode))" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "簡繁轉換作業完成！" -ForegroundColor Cyan

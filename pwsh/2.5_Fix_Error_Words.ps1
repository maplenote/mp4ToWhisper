# 2.5_Fix_Error_Words.ps1
# AI 優化 SRT 字幕中的辨識錯誤文字
# 此腳本為輔助工具，主要由 AI Agent 執行實際修正
# 
# 工作流程：
# 1. 讀取 file/merge_srt/{檔名}_merge.srt (合併後的原始字幕)
# 2. AI 根據主題與內容產生 file/merge_srt/{檔名}.json (當次專用的取代規則)
# 3. 套用取代規則，輸出至 file/merge_srt/{檔名}_ai.srt
# 4. 複製 _ai.srt 至 file/fin_srt/{檔名}.srt

param(
    [Parameter(Mandatory = $false)]
    [string]$TargetFileName,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# 設定區
$BaseDir = Join-Path $PSScriptRoot ".."
$MergeSrtDir = Join-Path $BaseDir "file/merge_srt"
$FinSrtDir = Join-Path $BaseDir "file/fin_srt"
$TemplateJson = Join-Path $BaseDir ".github/prompts/errorWords.json"

# 確保目錄存在
if (-not (Test-Path $FinSrtDir)) {
    New-Item -ItemType Directory -Path $FinSrtDir -Force | Out-Null
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

Write-Host "範本對照表位置: $TemplateJson" -ForegroundColor Cyan
Write-Host "找到 $($MergeFiles.Count) 個待處理檔案`n" -ForegroundColor Cyan

# 2. 處理每個 _merge.srt 檔案
foreach ($MergeFile in $MergeFiles) {
    # 解析檔名
    $BaseName = $MergeFile.BaseName -replace "_merge$", ""
    $JsonPath = Join-Path $MergeSrtDir "${BaseName}.json"
    $AiSrtPath = Join-Path $MergeSrtDir "${BaseName}_ai.srt"
    $FinalSrtPath = Join-Path $FinSrtDir "${BaseName}.srt"
    
    # 檢查是否已處理過
    if ((Test-Path $FinalSrtPath) -and -not $Force) {
        Write-Host "跳過: $BaseName (已存在最終字幕，使用 -Force 強制重新處理)" -ForegroundColor DarkGray
        continue
    }
    
    Write-Host "處理中: $BaseName" -ForegroundColor Yellow
    Write-Host "  來源: ${BaseName}_merge.srt" -ForegroundColor Gray
    
    # 檢查 JSON 對照表是否存在
    if (-not (Test-Path $JsonPath)) {
        Write-Host "  ⚠ 找不到專用對照表: ${BaseName}.json" -ForegroundColor Yellow
        Write-Host "  請使用 AI Agent 根據主題產生對照表，或手動建立" -ForegroundColor Yellow
        Write-Host "  範本參考: $TemplateJson" -ForegroundColor Gray
        continue
    }
    
    Write-Host "  對照表: ${BaseName}.json" -ForegroundColor Gray
    
    # 讀取 JSON 對照表
    try {
        $ErrorWordsData = Get-Content $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $Mappings = $ErrorWordsData.mappings
        Write-Host "  已載入 $($Mappings.Count) 組對照規則" -ForegroundColor Cyan
    } catch {
        Write-Host "  ✗ JSON 解析失敗: $_" -ForegroundColor Red
        continue
    }
    
    # 讀取 _merge.srt 內容
    $Content = Get-Content $MergeFile.FullName -Raw -Encoding UTF8
    $TotalReplacements = 0
    
    # 逐一套用對照規則
    foreach ($Mapping in $Mappings) {
        $CorrectWord = $Mapping.correct
        
        foreach ($WrongWord in $Mapping.wrong) {
            $Pattern = [regex]::Escape($WrongWord)
            $MatchCount = ([regex]::Matches($Content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
            
            if ($MatchCount -gt 0) {
                Write-Host "    取代: '$WrongWord' -> '$CorrectWord' ($MatchCount 處)" -ForegroundColor Green
                $Content = $Content -replace $Pattern, $CorrectWord
                $TotalReplacements += $MatchCount
            }
        }
    }
    
    # 儲存 _ai.srt
    $Content | Set-Content $AiSrtPath -Encoding UTF8 -NoNewline
    Write-Host "  輸出: ${BaseName}_ai.srt (共修正 $TotalReplacements 處)" -ForegroundColor Green
    
    # 複製到 fin_srt
    Copy-Item $AiSrtPath $FinalSrtPath -Force
    Write-Host "  複製: ${BaseName}.srt -> file/fin_srt/" -ForegroundColor Green
    
    Write-Host ""
}

Write-Host "錯誤文字修正作業完成！" -ForegroundColor Cyan

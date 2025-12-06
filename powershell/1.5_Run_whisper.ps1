param (
    [string]$TargetFileName = $null,
    [string]$Model = "medium",
    [switch]$Force = $false
)

# 設定區
$BaseDir = Join-Path $PSScriptRoot ".."
$OriMp3Dir = Join-Path $BaseDir "file/ori_mp3"
$TmpMp3Dir = Join-Path $BaseDir "file/tmp_mp3"
$TmpSrtDir = Join-Path $BaseDir "file/tmp_srt"
$ModelsDir = Join-Path $BaseDir "file/models"

# 確保輸出目錄存在
if (-not (Test-Path $TmpSrtDir)) {
    New-Item -ItemType Directory -Path $TmpSrtDir -Force | Out-Null
}

# 確保模型目錄存在
if (-not (Test-Path $ModelsDir)) {
    New-Item -ItemType Directory -Path $ModelsDir -Force | Out-Null
}

# 決定要處理的檔案列表
$Mp3Files = @()

if ($TargetFileName) {
    # 如果指定了原始檔名，先計算 ID，再找出對應的 chunks
    $FullPath = Join-Path $OriMp3Dir $TargetFileName
    if (-not (Test-Path $FullPath)) { 
        Write-Error "找不到指定檔案: $FullPath"
        exit 1 
    }
    
    Write-Host "正在計算檔案 ID: $TargetFileName" -ForegroundColor Cyan
    
    # 計算 ID (需與切割步驟演算法一致)
    $Hash = (Get-FileHash $FullPath -Algorithm MD5).Hash
    $Bytes = [System.Convert]::FromHexString($Hash)
    $Base64 = [System.Convert]::ToBase64String($Bytes)
    $FileID = $Base64.Replace('+', '-').Replace('/', '_').TrimEnd('=')
    
    Write-Host "  檔案 ID: $FileID" -ForegroundColor Gray
    
    # 找出所有以此 ID 開頭的 chunk
    $Mp3Files = Get-ChildItem "$TmpMp3Dir/${FileID}_chunk_*.mp3"
    
    if ($Mp3Files.Count -eq 0) {
        Write-Warning "找不到對應的切割檔案 (ID: $FileID)。請確認是否已執行 1_Split_Audio.ps1"
        exit
    }
} else {
    # 否則處理所有 tmp_mp3 下的檔案
    $Mp3Files = Get-ChildItem "$TmpMp3Dir/*.mp3"
}

if ($Mp3Files.Count -eq 0) {
    Write-Warning "沒有找到 MP3 檔案: $TmpMp3Dir"
    exit
}

Write-Host "找到 $($Mp3Files.Count) 個 MP3 檔案，準備開始轉錄..." -ForegroundColor Cyan

foreach ($File in $Mp3Files) {
    $BaseName = $File.BaseName
    $SrtPath = Join-Path $TmpSrtDir "$BaseName.srt"

    if ((Test-Path $SrtPath) -and (-not $Force)) {
        Write-Host "跳過: $BaseName (SRT 已存在)" -ForegroundColor DarkGray
        continue
    }

    Write-Host "正在轉錄: $($File.Name)..." -ForegroundColor Yellow
    
    # 使用 uv run 執行 whisper
    # 注意: 需確保專案環境已安裝 openai-whisper
    # --model_dir 指定模型下載/讀取位置
    
    $Command = "uv"
    $ArgsList = @(
        "run", 
        "whisper", 
        $File.FullName, 
        "--model", $Model, 
        "--language", "Chinese",
        "--output_dir", $TmpSrtDir, 
        "--output_format", "srt",
        "--model_dir", $ModelsDir,
        "--verbose", "False"
    )

    # 執行指令
    & $Command $ArgsList
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  完成: $BaseName.srt" -ForegroundColor Green
    } else {
        Write-Host "  失敗: $($File.Name)" -ForegroundColor Red
    }
}

Write-Host "轉錄作業完成！" -ForegroundColor Green

param (
    [string]$TargetFileName = $null,
    [string]$Model = "medium",
    [string]$Engine = $null,
    [string]$InitialPrompt = $null,
    [switch]$UseVAD = $false,
    [switch]$Force = $false
)

# 設定區
$BaseDir = Join-Path $PSScriptRoot ".."
$OriMp3Dir = Join-Path $BaseDir "file/ori_mp3"
$TmpMp3Dir = Join-Path $BaseDir "file/tmp_mp3"
$TmpSrtDir = Join-Path $BaseDir "file/tmp_srt"
$ModelsDir = Join-Path $BaseDir "file/models"
$EnvFile = Join-Path $BaseDir ".env"

# 讀取 .env 設定
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match "^\s*([^#=]+)\s*=\s*(.*)\s*$") {
            $Name = $matches[1]
            $Value = $matches[2]
            Set-Variable -Name "ENV_$Name" -Value $Value -Scope Local
        }
    }
}

# 決定使用的 Engine
# 優先順序: 參數 > 環境變數 > 預設值(openai)
$Source = "Default"
if ($Engine) {
    $Source = "Parameter"
} elseif ($ENV_WHISPER_ENGINE) {
    $Engine = $ENV_WHISPER_ENGINE
    $Source = "Environment (.env)"
} else {
    $Engine = "openai"
}

# 驗證 Engine
if ($Engine -notin @("openai", "ctranslate2")) {
    Write-Warning "偵測到無效的 Engine 設定: '$Engine' (來源: $Source)。將自動切換為預設值 'openai'。"
    $Engine = "openai"
}

Write-Host "使用 Whisper Engine: $Engine" -ForegroundColor Cyan
if ($InitialPrompt) {
    Write-Host "使用 Initial Prompt: $InitialPrompt" -ForegroundColor Cyan
}
if ($UseVAD) {
    if ($Engine -eq "ctranslate2") {
        Write-Host "啟用 VAD (Voice Activity Detection)" -ForegroundColor Cyan
    } else {
        Write-Warning "VAD 參數僅支援 ctranslate2 引擎，目前使用 openai 引擎，將忽略此參數。"
    }
}

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
        Write-Warning "找不到對應的切割檔案 (ID: $FileID)。請確認是否已執行 2_Split_Audio.ps1"
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
    # 注意: 需確保專案環境已安裝 openai-whisper 或 whisper-ctranslate2
    # --model_dir 指定模型下載/讀取位置
    
    $Command = "uv"
    $ArgsList = @()

    if ($Engine -eq "ctranslate2") {
        $ArgsList = @(
            "run", 
            "whisper-ctranslate2", 
            $File.FullName, 
            "--model", $Model, 
            "--language", "Chinese",
            "--device", "cuda",
            "--output_dir", $TmpSrtDir, 
            "--output_format", "srt",
            "--model_dir", $ModelsDir
            # whisper-ctranslate2 可能不支援 --verbose False，故省略
        )
        
        if ($UseVAD) {
            $ArgsList += "--vad_filter"
            $ArgsList += "True"
        }
    } else {
        # openai
        $ArgsList = @(
            "run", 
            "whisper", 
            $File.FullName, 
            "--model", $Model, 
            "--language", "Chinese",
            "--device", "cuda",
            "--output_dir", $TmpSrtDir, 
            "--output_format", "srt",
            "--model_dir", $ModelsDir,
            "--verbose", "False"
        )
    }

    if ($InitialPrompt) {
        $ArgsList += "--initial_prompt"
        $ArgsList += $InitialPrompt
    }

    # 執行指令
    & $Command $ArgsList
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  完成: $BaseName.srt" -ForegroundColor Green
    } else {
        Write-Host "  失敗: $($File.Name)" -ForegroundColor Red
    }
}

Write-Host "轉錄作業完成！" -ForegroundColor Green

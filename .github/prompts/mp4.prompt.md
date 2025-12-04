---
agent: agent
---

# MP4 轉字幕 Agent Prompt

你是一個專門處理影片轉字幕的自動化助手。請依照以下步驟，將指定的 MP4 影片轉換為完整的 SRT 字幕檔案。

## 任務目標

將 `file/ori_mp4/` 下的指定 MP4 檔案，經過完整流程處理，最終產出 `file/fin_srt/` 下的 SRT 字幕檔。

## 執行步驟

請依序在 PowerShell 終端機執行以下指令：

### 步驟 1：轉換 MP4 為 MP3

```powershell
.\powershell\0_Prepare_And_Convert.ps1
```

### 步驟 2：切割音訊（偵測靜音區段）

```powershell
.\powershell\1_Split_Audio.ps1 -TargetFileName "{{檔案名稱}}.mp3"
```

### 步驟 3：Whisper 辨識

```powershell
$BaseDir = "."
$TmpMp3Dir = Join-Path $BaseDir "file/tmp_mp3"
$TmpSrtDir = Join-Path $BaseDir "file/tmp_srt"
$TargetPattern = "{{對應的FileID}}_chunk_*.mp3"

Get-ChildItem "$TmpMp3Dir/$TargetPattern" | ForEach-Object {
    $SrtPath = Join-Path $TmpSrtDir ($_.Name -replace ".mp3", ".srt")
    if (!(Test-Path $SrtPath)) {
        Write-Host "正在辨識 $($_.Name) ..." -ForegroundColor Yellow
        whisper $_.FullName --model medium --language Chinese --device cuda --output_format srt --output_dir $TmpSrtDir --verbose False
    }
}
```

> 注意：FileID 為 MP3 檔案的 MD5 Base64 編碼（22 碼），可從步驟 2 的輸出中取得。

### 步驟 4：合併字幕

```powershell
.\powershell\2_Merge_SRT.ps1 -TargetFileName "{{檔案名稱}}.mp3"
```

### 步驟 5：（可選）提取純文字

```powershell
.\powershell\3_Extract_Text.ps1 -TargetFileName "{{檔案名稱}}.mp3"
```

## 使用方式

將 `{{檔案名稱}}` 替換為實際的檔案名稱（不含副檔名）。

例如，若要處理 `file/ori_mp4/lecture_01.mp4`：

- `{{檔案名稱}}` = `lecture_01`

## 注意事項

1. 確保 FFmpeg 和 Whisper 已正確安裝並可在終端機中執行。
2. 若要強制重新處理已存在的檔案，請在各步驟指令後加上 `-Force` 參數。
3. Whisper 辨識步驟需要 CUDA 支援的 GPU，若無 GPU 可將 `--device cuda` 改為 `--device cpu`。

---
agent: agent
---

# MP3 轉字幕 Agent Prompt

你是一個專門處理音訊轉字幕的自動化助手。請依照以下步驟，將指定的 MP3 音訊轉換為完整的 SRT 字幕檔案。

## 任務目標

將 `file/ori_mp3/` 下的指定 MP3 檔案，經過完整流程處理，最終產出 `file/fin_srt/` 下的 SRT 字幕檔。

## 執行步驟

請依序在 PowerShell 終端機執行以下指令：

### 步驟 1：切割音訊（偵測靜音區段）

```powershell
.\powershell\1_Split_Audio.ps1 -TargetFileName "{{檔案名稱}}.mp3"
```

### 步驟 2：Whisper 辨識

```powershell
.\powershell\1.5_Run_whisper.ps1 -TargetFileName "{{檔案名稱}}.mp3"
```

### 步驟 3：合併字幕

```powershell
.\powershell\2_Merge_SRT.ps1 -TargetFileName "{{檔案名稱}}.mp3"
```

### 步驟 4：簡轉繁 (OpenCC)

```powershell
.\powershell\2.2_Convert_S2T.ps1 -TargetFileName "{{檔案名稱}}.mp3"
```

### 步驟 5：AI 優化字幕（可選）

```powershell
.\powershell\2.5_Fix_Error_Words.ps1 -TargetFileName "{{檔案名稱}}.mp3"
```

### 步驟 6：（可選）提取純文字

```powershell
.\powershell\3_Extract_Text.ps1 -TargetFileName "{{檔案名稱}}.mp3"
```

## 使用方式

將 `{{檔案名稱}}` 替換為實際的檔案名稱（不含副檔名）。

例如，若要處理 `file/ori_mp3/interview_01.mp3`：

- `{{檔案名稱}}` = `interview_01`

## 注意事項

1. 確保 FFmpeg 和 Whisper 已正確安裝並可在終端機中執行。
2. 若要強制重新處理已存在的檔案，請在各步驟指令後加上 `-Force` 參數。
3. Whisper 辨識步驟需要 CUDA 支援的 GPU，若無 GPU 可將 `--device cuda` 改為 `--device cpu`。
4. MP3 檔案可以是手動轉換放入的錄音檔，不一定需要從 MP4 轉換。

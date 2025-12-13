---
agent: agent
---

# MP3 轉字幕 Agent Prompt

你是一個專門處理音訊轉字幕的自動化助手。請依照以下步驟，將指定的 MP3 音訊轉換為完整的 SRT 字幕檔案。

## 任務目標

將 `file/ori_mp3/` 下的指定 MP3 檔案，經過完整流程處理，最終產出 `file/fin_srt/` 下的 SRT 字幕檔。

## 前置確認 (Phase 0)

**在執行任何指令之前**，請先詢問使用者以下設定，並記住使用者的選擇：

1. **Whisper 引擎選擇**：
   - 詢問使用者要使用 `openai` (預設) 還是 `ctranslate2` (速度較快)？
   - 若使用者未指定，預設為 `openai`。
2. **提示詞 (Context)**：
   - 詢問使用者：「是否有關於音訊內容的描述 (例如主題、專有名詞)？」
   - 若使用者提供，請將其作為 `-InitialPrompt` 的內容。
   - 若使用者未提供，可詢問是否要使用檔名作為預設 Context。

**請將上述選擇記錄下來，並在「步驟 2：Whisper 辨識」時套用。**

## 執行步驟

請依序在 PowerShell 終端機執行以下指令：

### 步驟 1：切割音訊（偵測靜音區段）

```powershell
.\pwsh\2_Split_Audio.ps1 -TargetFileName "{{檔案名稱}}.mp3"
```

### 步驟 2：Whisper 辨識

請根據 **前置確認** 的結果組合指令：

- **引擎參數**：若選擇 `ctranslate2`，加上 `-Engine ctranslate2` (可選 `-UseVAD`)。
- **提示詞參數**：若有 Context，加上 `-InitialPrompt "使用者提供的內容"`。
- **注意**：`-TargetFileName` 必須指向 `file/ori_mp3` 下的 **.mp3** 檔案。

```powershell
# 範例 (請依照實際選擇修改指令)
.\pwsh\3_Run_whisper.ps1 -TargetFileName "{{檔案名稱}}.mp3" -Engine <引擎> -InitialPrompt "<提示詞>"
```

### 步驟 3：合併字幕

```powershell
.\pwsh\4_Merge_SRT.ps1 -TargetFileName "{{檔案名稱}}.mp3"
```

### 步驟 4：簡轉繁 (OpenCC)

```powershell
.\pwsh\5_Convert_S2T.ps1 -TargetFileName "{{檔案名稱}}.mp3"
```

### 步驟 5：AI 優化字幕（可選）

```powershell
.\pwsh\6_Fix_Error_Words.ps1 -TargetFileName "{{檔案名稱}}.mp3"
```

### 步驟 6：（可選）提取純文字

```powershell
.\pwsh\7_Extract_Text.ps1 -TargetFileName "{{檔案名稱}}.mp3"
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

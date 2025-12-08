# MP4 to Whisper SRT

[![PowerShell](https://img.shields.io/badge/PowerShell-7.5+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![FFmpeg](https://img.shields.io/badge/FFmpeg-required-green.svg)](https://ffmpeg.org/)
[![Whisper](https://img.shields.io/badge/OpenAI_Whisper-required-orange.svg)](https://github.com/openai/whisper)
[![uv](https://img.shields.io/badge/uv-package_manager-purple.svg)](https://docs.astral.sh/uv/)

專為解決「Whisper 處理長靜音導致異常循環」所設計的自動化字幕產生工具。

## How to Start?

1. 確認環境有 uv 與 FFmpeg 與 PowerShell 7.5+ (請務必使用 `pwsh` 指令執行)
2. uv sync 安裝相依套件 (預計約 2.5GB，第一次執行轉檔還會下載 Whisper 模型，預計約 1.5GB)
3. 將 MP4 放入 `file/ori_mp4/` ，若只有 MP3 可放入 `file/ori_mp3/`
4. 開啟 vscode 或 gemini cli 
   - vscode 選擇使用 /mp4 或 /mp3 指示轉檔
   - gemini cli 使用 @YOLO_PROMPT.md 或 @SAFE_MODE_PROMPT.md 指示轉檔
5. 等待轉檔完成，最終字幕會放在 `file/fin_srt/`

## 🎯 核心功能

- **靜音偵測切割**：自動偵測音訊中超過 8 秒的靜音區段，將音訊切割成多個片段
- **避免 Whisper 幻覺**：透過切割避免 Whisper 因長靜音產生重複或錯誤的辨識結果
- **時間軸校正**：自動將切割片段的時間軸還原至原始影片的正確位置
- **批次處理**：支援一次處理多個影片 / 音訊檔案
- **單檔處理**：支援指定處理單一檔案，並可強制重新處理

## 📁 專案結構

```text
mp4ToWhisper/
├── powershell/                 # PowerShell 腳本
│   ├── 0_Prepare_And_Convert.ps1  # 建立資料夾、MP4 轉 MP3
│   ├── 1_Split_Audio.ps1          # 偵測靜音並切割音訊
│   ├── 1.5_Run_whisper.ps1        # 執行 Whisper 辨識
│   ├── 2_Merge_SRT.ps1            # 合併字幕並校正時間軸
│   ├── 2.5_Fix_Error_Words.ps1    # 套用 AI 對照表修正字幕
│   ├── 3_Extract_Text.ps1         # 提取純文字逐字稿
│   └── Clear_File_Dir.ps1         # 清空暫存資料夾 (保留 models 與 .gitkeep)
├── file/
│   ├── ori_mp4/               # 原始影片檔
│   ├── ori_mp3/               # 轉換後的 MP3(或手動放入)
│   ├── tmp_mp3/               # 切割後的 MP3 片段
│   ├── tmp_csv/               # 切割資訊 (Offset)
│   ├── tmp_srt/               # Whisper 辨識的片段字幕
│   ├── merge_srt/             # 合併字幕 (*_merge.srt)、AI 對照表 (*.json)、AI 優化字幕 (*_ai.srt)
│   ├── fin_srt/               # 最終字幕檔
│   └── models/                # Whisper 模型存放目錄
├── .github/prompts/           # Agent Prompt 範本
│   ├── mp4.prompt.md          # MP4 轉字幕流程
│   ├── mp3.prompt.md          # MP3 轉字幕流程
│   ├── fixErrorWords.prompt.md # AI 優化字幕流程
│   └── errorWords.json        # 錯誤對照表範本
├── pyproject.toml             # Python 專案設定
├── spec.md                    # 詳細 SOP 文件
└── README.md
```

## 🚀 快速開始

### 環境需求

- **Windows 11** / PowerShell 7.5+
- **FFmpeg**：用於音訊處理
- **uv**：Python 套件管理器
- **NVIDIA GPU + CUDA** (建議)：加速語音辨識

### 安裝步驟

#### 1️⃣ 安裝 FFmpeg

1. 前往 [FFmpeg Builds by Gyan](https://www.gyan.dev/ffmpeg/builds/) 下載最新的 **release full** 版本 (建議 7.0+)
2. 解壓縮到任意目錄，建議放在 `C:\Program Files\ffmpeg`
3. 將 `C:\Program Files\ffmpeg\bin` 資料夾加入 windows 系統 PATH 環境變數
4. 開啟新的 PowerShell 視窗，執行 `ffmpeg -version` 確認安裝成功

#### 2️⃣ 安裝 uv 套件管理器

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

#### 3️⃣ 複製專案並安裝相依套件

```powershell
git clone https://github.com/your-repo/mp4ToWhisper.git
cd mp4ToWhisper

# 安裝所有相依套件(含 PyTorch CUDA 版本)
uv sync
```

**注意**：首次執行會下載約 2.5GB 的 PyTorch 相依套件，請確保網路暢通。

#### 4️⃣ 下載 Whisper 模型

首次執行辨識時會自動下載，或可手動預先下載：

```powershell
uv run whisper --model medium --model_dir "file/models" --help
```

模型約 1.5GB，存放在 `file/models/` 目錄中，不會被系統暫存清理刪除。

#### 5️⃣ 測試 Whisper 是否正常運作

```powershell
uv run whisper "file/tmp/test.mp3" --model medium --device cuda --model_dir "file/models" --language Chinese --output_format srt --output_dir "file/tmp"
```

執行後會在終端機直接顯示辨識後的內容 (輸出檔案會在 `file/tmp/test.srt`)：

```text
[00:00.000 --> 00:02.000] 這是測試用的語音
```

### 使用流程

#### 1️⃣ 準備資料夾與轉換 MP4

將 MP4 影片放入 `file/ori_mp4/`，然後執行：

```powershell
.\powershell\0_Prepare_And_Convert.ps1
```

#### 2️⃣ 切割音訊

```powershell
# 處理全部
.\powershell\1_Split_Audio.ps1

# 處理指定檔案
.\powershell\1_Split_Audio.ps1 -TargetFileName "my_video.mp3"
```

#### 3️⃣ Whisper 辨識

```powershell
# 處理全部
.\powershell\1.5_Run_whisper.ps1

# 處理指定檔案
.\powershell\1.5_Run_whisper.ps1 -TargetFileName "my_video.mp3"
```

#### 4️⃣ 合併字幕

```powershell
# 處理全部
.\powershell\2_Merge_SRT.ps1

# 處理指定檔案
.\powershell\2_Merge_SRT.ps1 -TargetFileName "my_video.mp3"
```

合併後的字幕會存入 `file/merge_srt/{filename}_merge.srt`。

#### 4.2️⃣ 簡轉繁 (OpenCC)

將合併後的簡體字幕轉換為繁體中文 (台灣正體)：

```powershell
# 處理全部
.\powershell\2.2_Convert_S2T.ps1

# 處理指定檔案
.\powershell\2.2_Convert_S2T.ps1 -TargetFileName "my_video.mp3"
```

#### 4.5️⃣ AI 優化字幕 (可選)

使用 AI Agent 根據主題產生專用的錯誤對照表，並套用修正：

> **注意**：本專案所有 SRT 檔案與程式碼皆採用 **UTF-8** 編碼。AI 在讀取檔案內容或檔名時，請確保使用 UTF-8 格式，避免中文出現亂碼。

1. 使用 `.github/prompts/fixErrorWords.prompt.md` 提示 AI
2. AI 產生 `file/merge_srt/{filename}.json` 對照表
3. 執行腳本套用修正：

```powershell
.\powershell\2.5_Fix_Error_Words.ps1 -TargetFileName "my_video.mp3"
```

輸出結果：

- `file/merge_srt/{filename}_ai.srt` - AI 優化後的字幕
- `file/fin_srt/{filename}.srt` - 最終字幕 (複製自 \_ai.srt)

#### 5️⃣ (可選) 提取純文字

```powershell
.\powershell\3_Extract_Text.ps1
```

#### 6️⃣ (可選) 清空暫存資料夾

當專案執行完畢，可使用此腳本清空 `file/` 下除了 `models` 以外的所有資料夾內容 (會保留 `.gitkeep`)。

```powershell
# 互動式確認後刪除
.\powershell\Clear_File_Dir.ps1

# 強制刪除 (不詢問)
.\powershell\Clear_File_Dir.ps1 -Force

# 模擬刪除 (僅列出會被刪除的檔案)
.\powershell\Clear_File_Dir.ps1 -DryRun
```

## 📌 參數說明

所有腳本 (1\~3) 都支援以下參數：

| 參數                          | 說明                 |
| --------------------------- | ------------------ |
| `-TargetFileName "檔案名.mp3"` | 指定只處理單一檔案 (需為原始檔名) |
| `-Force`                    | 強制重新處理 (忽略已存在的輸出)  |

**範例**：

```powershell
# 強制重新處理指定檔案
.\powershell\1_Split_Audio.ps1 -TargetFileName "lecture.mp3" -Force
```

## 🤖 Agent Prompt

本專案提供 Agent Prompt 範本，可搭配 AI 助手使用：

- `.github/prompts/mp4.prompt.md`：從 MP4 開始的完整流程
- `.github/prompts/mp3.prompt.md`：從 MP3 開始的流程 (適用於手動轉換的音訊)

## 📖 詳細文件

完整的標準作業程序請參閱 [spec.md](spec.md)。

## ⚙️ 技術細節

### 檔案 ID 產生邏輯

為避免檔名重複，切割後的檔案使用 MD5 雜湊產生唯一 ID：

```text
原始檔案 → MD5 (16 bytes) → Base64 → 檔名安全格式 (22 碼)
```

### 靜音偵測參數

- **閾值時間**：8 秒 (超過此時間的靜音會被視為切割點)
- **分貝閾值**：-50 dB (低於此音量視為靜音)

這些參數可在 `1_Split_Audio.ps1` 中調整。

## 📝 License

MIT License

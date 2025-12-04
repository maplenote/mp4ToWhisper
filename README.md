# MP4 to Whisper SRT

[![PowerShell](https://img.shields.io/badge/PowerShell-7.5+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![FFmpeg](https://img.shields.io/badge/FFmpeg-required-green.svg)](https://ffmpeg.org/)
[![Whisper](https://img.shields.io/badge/OpenAI_Whisper-required-orange.svg)](https://github.com/openai/whisper)

專為解決「Whisper 處理長靜音導致異常循環」所設計的自動化字幕產生工具。

## 🎯 核心功能

- **靜音偵測切割**：自動偵測音訊中超過 8 秒的靜音區段，將音訊切割成多個片段
- **避免 Whisper 幻覺**：透過切割避免 Whisper 因長靜音產生重複或錯誤的辨識結果
- **時間軸校正**：自動將切割片段的時間軸還原至原始影片的正確位置
- **批次處理**：支援一次處理多個影片/音訊檔案
- **單檔處理**：支援指定處理單一檔案，並可強制重新處理

## 📁 專案結構

```
mp4ToWhisper/
├── powershell/                 # PowerShell 腳本
│   ├── 0_Prepare_And_Convert.ps1  # 建立資料夾、MP4 轉 MP3
│   ├── 1_Split_Audio.ps1          # 偵測靜音並切割音訊
│   ├── 2_Merge_SRT.ps1            # 合併字幕並校正時間軸
│   └── 3_Extract_Text.ps1         # 提取純文字逐字稿
├── file/
│   ├── ori_mp4/               # 原始影片檔
│   ├── ori_mp3/               # 轉換後的 MP3（或手動放入）
│   ├── tmp_mp3/               # 切割後的 MP3 片段
│   ├── tmp_csv/               # 切割資訊 (Offset)
│   ├── tmp_srt/               # Whisper 辨識的片段字幕
│   └── fin_srt/               # 最終合併的字幕檔
├── .github/prompts/           # Agent Prompt 範本
│   ├── mp4.prompt.md          # MP4 轉字幕流程
│   └── mp3.prompt.md          # MP3 轉字幕流程
├── spec.md                    # 詳細 SOP 文件
└── README.md
```

## 🚀 快速開始

### 環境需求

- **Windows 11** / PowerShell 7.5+
- **FFmpeg**：用於音訊處理
- **OpenAI Whisper**：用於語音辨識

### 安裝 Whisper（使用 uv）

```powershell
# 安裝 uv
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# 安裝 Python 3.11
uv python install 3.11

# 安裝 Whisper 為全域工具，並強制指定 CUDA 12.1 (才能使用 GPU)
uv tool install openai-whisper --python 3.11 --reinstall --extra-index-url https://download.pytorch.org/whl/cu121
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
$TmpMp3Dir = "file/tmp_mp3"
$TmpSrtDir = "file/tmp_srt"

Get-ChildItem "$TmpMp3Dir/*.mp3" | ForEach-Object {
    $SrtPath = Join-Path $TmpSrtDir ($_.Name -replace ".mp3", ".srt")
    if (!(Test-Path $SrtPath)) {
        whisper $_.FullName --model medium --language Chinese --device cuda --output_format srt --output_dir $TmpSrtDir --verbose False
    }
}
```

#### 4️⃣ 合併字幕

```powershell
# 處理全部
.\powershell\2_Merge_SRT.ps1

# 處理指定檔案
.\powershell\2_Merge_SRT.ps1 -TargetFileName "my_video.mp3"
```

#### 5️⃣ （可選）提取純文字

```powershell
.\powershell\3_Extract_Text.ps1
```

## 📌 參數說明

所有腳本（1~3）都支援以下參數：

| 參數 | 說明 |
|------|------|
| `-TargetFileName "檔案名.mp3"` | 指定只處理單一檔案 |
| `-Force` | 強制重新處理（忽略已存在的輸出） |

**範例**：

```powershell
# 強制重新處理指定檔案
.\powershell\1_Split_Audio.ps1 -TargetFileName "lecture.mp3" -Force
```

## 🤖 Agent Prompt

本專案提供 Agent Prompt 範本，可搭配 AI 助手使用：

- `.github/prompts/mp4.prompt.md`：從 MP4 開始的完整流程
- `.github/prompts/mp3.prompt.md`：從 MP3 開始的流程（適用於手動轉換的音訊）

## 📖 詳細文件

完整的標準作業程序請參閱 [spec.md](spec.md)。

## ⚙️ 技術細節

### 檔案 ID 產生邏輯

為避免檔名重複，切割後的檔案使用 MD5 雜湊產生唯一 ID：

```
原始檔案 → MD5 (16 bytes) → Base64 → 檔名安全格式 (22 碼)
```

### 靜音偵測參數

- **閾值時間**：8 秒（超過此時間的靜音會被視為切割點）
- **分貝閾值**：-50 dB（低於此音量視為靜音）

這些參數可在 `1_Split_Audio.ps1` 中調整。

## 📝 License

MIT License

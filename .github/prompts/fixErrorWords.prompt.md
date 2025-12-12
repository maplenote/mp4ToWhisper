---
agent: agent
---

# AI 優化 SRT 字幕辨識錯誤文字

## 任務說明

根據使用者提供的主題與背景資訊，分析 `file/merge_srt/` 目錄下的 `_merge.srt` 字幕檔，產生專用的錯誤對照表並套用修正。

## 檔案結構

```text
file/merge_srt/
├── {檔名}_merge.srt   # 合併後的原始字幕 (輸入)
├── {檔名}.json        # AI 產生的專用對照表
└── {檔名}_ai.srt      # AI 優化後的字幕 (輸出)

file/fin_srt/
└── {檔名}.srt         # 最終字幕 (複製自 _ai.srt)
```

## 範本對照表

常見錯誤的參考範本位於 `.github/prompts/errorWords.json`，包含程式術語、框架名稱等常見辨識錯誤。

### JSON 結構說明

```json
{
  "version": "1.0",
  "description": "針對 {主題} 的錯誤對照表",
  "topic": "{辨識主題}",
  "mappings": [
    {
      "wrong": ["錯誤寫法 1", "錯誤寫法 2"],
      "correct": "正確文字",
      "category": "database",
      "note": "說明"
    }
  ]
}
```

## 使用方式

1. 使用者會提供：

   - 待修正的字幕檔案路徑（位於 `file/merge_srt/{檔名}_merge.srt`）
   - 相關的技術文件或領域背景資訊
   - 可能的專有名詞、資料庫表格名稱、程式碼術語等

2. Agent 應：
   - 讀取 `.github/prompts/errorWords.json` 作為參考範本
   - 讀取 `file/merge_srt/{檔名}_merge.srt` 字幕內容
   - 根據主題與內容，識別可能的辨識錯誤
   - 產生 `file/merge_srt/{檔名}.json` 專用對照表
   - 套用對照表修正字幕
   - 輸出 `file/merge_srt/{檔名}_ai.srt`
   - 複製至 `file/fin_srt/{檔名}.srt`

## MCP 工具支援 (可選，限內部專用)

請確定有安裝 fepmdbdoc 這個 MCP 工具 (內部專案)，使用 #tableSchema 可取得 `資料庫. 資料表` 結構 (markdown 格式)：

```
#mcp_fepmdbdoc_tableSchema 資料庫.資料表
```

## 執行流程

1. ** 讀取範本 **：讀取 `.github/prompts/errorWords.json` 了解常見錯誤
2. ** 讀取 SRT 檔案 **：讀取 `file/merge_srt/{檔名}_merge.srt`
3. ** 分析內容 **：根據主題識別可能的辨識錯誤
4. ** 查詢資料表結構 **（可選）：使用 `#mcp_fepmdbdoc_tableSchema` 確認專有名詞
5. ** 產生對照表 **：建立 `file/merge_srt/{檔名}.json`
6. ** 套用修正 **：使用編輯工具修正字幕內容
7. ** 輸出結果 **：儲存 `{檔名}_ai.srt` 並複製至 `fin_srt/`

## 注意事項

- **編碼提醒**：本專案所有 SRT 檔案與程式碼皆採用 **UTF-8** 編碼。讀取檔案內容或檔名時，請確保使用 UTF-8 格式，避免中文出現亂碼。
- SRT 檔案格式為：序號、時間軸、字幕文字，修正時僅修改字幕文字行
- 修正前應確保有足夠的上下文以判斷正確用詞
- 技術術語應保持一致性（如 Laravel、jQuery 等大小寫）
- 每個主題應產生獨立的 JSON 對照表，方便日後 diff 比對
- 若發現新的常見錯誤，可更新 `.github/prompts/errorWords.json` 範本

## PowerShell 輔助腳本

完成 JSON 對照表後，可執行以下腳本自動套用：

```powershell
# 處理全部檔案
.\pwsh\6_Fix_Error_Words.ps1

# 處理指定檔案
.\pwsh\6_Fix_Error_Words.ps1 -TargetFileName "我的影片.mp3"
```

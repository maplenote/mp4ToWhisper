---
agent: agent
---

# 修正 SRT 字幕辨識錯誤文字

## 任務說明

依照使用者提供的資訊，修正指定的 `.srt` 字幕檔中辨識有誤的文字。

## 使用方式

1. 使用者會提供：

   - 待修正的 SRT 檔案路徑（通常位於 `file/tmp/` 目錄下）
   - 相關的技術文件或領域背景資訊
   - 可能的專有名詞、資料庫表格名稱、程式碼術語等

2. Agent 應：
   - 讀取指定的 SRT 檔案內容
   - 根據提供的背景資訊，識別並修正常見的語音辨識錯誤
   - 使用 `multi_replace_string_in_file` 批次套用修正

## 常見辨識錯誤對照表

| 錯誤文字          | 正確文字 | 說明              |
| ----------------- | -------- | ----------------- |
| Larrable / layer  | Laravel  | PHP 框架名稱      |
| Zachary / Jackery | jQuery   | JavaScript 函式庫 |
| Keyleth           | keyid    | 程式碼變數名稱    |
| 藍位              | 欄位     | 資料表欄位        |
| 起床              | 銑床     | CNC 加工機台      |
| 明系              | 明細     | 明細頁            |
| 名系              | 明細     | 明細頁            |
| 註意              | 注音     | 注音              |
| 第一 B            | DB       | 資料庫的簡稱      |
| 會總頁            | 彙總頁   | 查詢作業的首頁    |
| 方程              | function | 程式碼術語        |
| 方選              | function | 程式碼術語        |
| PN-01-4 / PN01    | PLN014   | 程式代號格式      |
| mutation          | markdown | Markdown          |
| 卡密              | commit   | Git 提交          |
| 佈置              | 複製     | 複製              |
| 落 back           | rollback | 回復              |
| 落背口            | rollback | 回復              |
| 全線              | 權限     | 權限              |
| gettings          | GET 參數 | HTTP 請求參數     |
| bestnet           | basename | PHP 函式名稱      |
| autolow           | autoload | autoload.php      |

## MCP 工具支援

若需要查詢資料庫的資料表結構以確認正確的欄位名稱或專有名詞，可使用：

```
#mcp_fepmdbdoc_tableSchema
```

### 使用範例

查詢 `fepmbusiness.fpstationdriverdef` 資料表：

```json
{
  "db.table": "fepmbusiness.fpstationdriverdef"
}
```

回傳的 schema 將包含欄位名稱（如 `DRIVERNO`、`DRIVERNAME`、`SHOWTYPE` 等），可用於比對字幕中的專有名詞是否正確。

## 執行流程

1. **讀取 SRT 檔案**：使用 `read_file` 讀取完整內容
2. **搜尋常見錯誤**：使用 `grep_search` 找出可能的錯誤文字
3. **查詢資料表結構**（可選）：使用 `#mcp_fepmdbdoc_tableSchema` 確認專有名詞
4. **批次修正**：使用編輯工具套用所有修正
5. **驗證結果**：再次搜尋確認無遺漏

## 注意事項

- SRT 檔案格式為：序號、時間軸、字幕文字，修正時僅修改字幕文字行
- 修正前應確保有足夠的上下文以判斷正確用詞
- 技術術語應保持一致性（如 Laravel、jQuery 等大小寫）

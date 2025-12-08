# 解決 Windows 終端機中文亂碼問題

若 Gemini CLI 在終端機出現中文亂碼，請先嘗試執行 `Shell echo "測試中文"` 確定輸出是否為亂碼。

若為亂碼，可請 AI 直接執行 `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8` (只會在單次終端機內生效) 指令，看是否能修正。

若依舊無法修正，請嘗試以下兩個方法 (最推薦方法 A)：

#### **方法 A：開啟 Windows 的「UTF-8 全球語言支援」 (最有效)**

這很可能是您另一台電腦正常的關鍵原因。

1. 按 `Win` 鍵，輸入 **「地區」** 或 **「Region」**，開啟設定。
2. 切換到 **「系統管理 (Administrative)」** 分頁。
3. 點擊 **「變更系統地區設定 (Change system locale...)」**。
4. **勾選** `Beta: 使用 Unicode UTF-8 提供全球語言支援 (Use Unicode UTF-8 for worldwide language support)`。
5. **重開機**。

> **注意**：這會讓您的 CMD/PowerShell 預設變成 UTF-8 (Code Page 65001)，這能解決 99% 的開發工具亂碼問題。唯一的副作用是極少數非常老舊的台灣本土軟體可能會顯示異常 (但在 2025 年已很少見)。

#### **方法 B：設定 PowerShell 設定檔 (如果不做方法 A)**

如果您不想更改系統設定，可以強迫 PowerShell 每次啟動都使用 UTF-8。

1. 開啟 PowerShell。

2. 輸入 `code $PROFILE` (如果您有裝 VS Code) 或 `notepad $PROFILE`。
   - 如果出現錯誤說找不到檔案，請先輸入 `New-Item -Path $PROFILE -Type File -Force` 再開。

3. 在打開的文件中，貼上以下內容：

   ```powershell
   [Console]::InputEncoding = [System.Text.Encoding]::UTF8
   [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
   $OutputEncoding = [System.Text.Encoding]::UTF8
   ```

4. 存檔並重啟終端機 / Gemini CLI。

### Gemini CLI 以後更新有機會修復嗎？ (本文件是 2025.12.8 建立)

**有機會，而且這屬於 Bug。**
這嚴格來說是開發者的責任。成熟的 CLI 工具在 Windows 上運行時，應該要主動偵測環境編碼，或者在生成子程序 (Subprocess) 時明確指定 `encoding='utf-8'`。

如果是開源專案，通常會在 GitHub Issue 上看到類似 "Fix Windows encoding issues" 的討論。您可以等待更新，但**方法 A 是目前作為 Windows 開發者的最佳實踐**，建議直接設定以一勞永逸。

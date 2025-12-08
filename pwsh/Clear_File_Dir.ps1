param(
    [switch]$Force = $false,
    [switch]$DryRun = $false
)

# 載入 VisualBasic 組件以支援資源回收筒功能
Add-Type -AssemblyName Microsoft.VisualBasic

# 清理暫存檔案腳本
$BaseDir = Join-Path $PSScriptRoot ".."
$FileDir = Join-Path $BaseDir "file"
# 取得 file/ 底下所有資料夾，排除 models（models 不會被清除）
$Targets = Get-ChildItem -Path $FileDir -Directory | Where-Object { $_.Name -ne 'models' } | ForEach-Object { Join-Path 'file' $_.Name }

if ($Targets.Count -eq 0) {
    Write-Host "在 $FileDir 底下沒有可處理的子資料夾。" -ForegroundColor Yellow
    exit 0
}

Write-Host "將要清理以下目錄的內容：" -ForegroundColor Yellow
foreach ($t in $Targets) { Write-Host " - $t" -ForegroundColor Gray }

if (-not $Force) {
    $ans = Read-Host "是否真的要清空所有資料?(檔案會移到windows垃圾桶) [y/N]"
    if ($ans -ne 'y' -and $ans -ne 'Y') {
        Write-Host "已取消。未進行任何刪除操作。" -ForegroundColor Cyan
        exit 0
    }
}

foreach ($rel in $Targets) {
    $path = Join-Path $BaseDir $rel
    if (-not (Test-Path $path)) {
        Write-Host "找不到目錄： $rel，跳過。" -ForegroundColor DarkGray
        continue
    }

    function Clear-PathPreserveGitkeep([string]$TargetPath) {
        # 遞迴刪除所有檔案/資料夾，但保留任何名稱為 .gitkeep 的檔案
        Get-ChildItem -Path $TargetPath -Force | ForEach-Object {
            if ($_.PSIsContainer) {
                # 對子資料夾遞迴處理
                Clear-PathPreserveGitkeep $_.FullName
                # 不刪除資料夾本身，以保留 .gitkeep 或目錄結構
                return
            } else {
                if ($_.Name -ieq '.gitkeep') {
                    # 保留 .gitkeep
                    return
                }
                try { 
                    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($_.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin') 
                } catch { Write-Host "    無法刪除檔案: $($_.FullName) - $_" -ForegroundColor Red }
            }
        }
    }

    if ($DryRun) {
        Write-Host "[DryRun] 下列項目會被刪除（保留 .gitkeep）： $path" -ForegroundColor Yellow
        Get-ChildItem -Path $path -Recurse -Force | Where-Object { -not ($_.PSIsContainer) -and ($_.Name -ine '.gitkeep') } | ForEach-Object { Write-Host "  -> $($_.FullName)" -ForegroundColor Gray }
        continue
    }

    try {
        Write-Host "清除目錄內容（保留 .gitkeep）： $path" -ForegroundColor Yellow
        Clear-PathPreserveGitkeep $path
        Write-Host "  已清空（保留 .gitkeep）： $rel" -ForegroundColor Green
    } catch {
        Write-Host "  無法清除 ${rel}: $($_)" -ForegroundColor Red
    }
}

Write-Host "清理作業完成。" -ForegroundColor Cyan

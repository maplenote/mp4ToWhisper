# 設定區
$BaseDir = Join-Path $PSScriptRoot ".."
$Folders = @("file/ori_mp4", "file/ori_mp3", "file/tmp_mp3", "file/tmp_csv", "file/tmp_srt", "file/fin_srt")
foreach ($f in $Folders) { 
    $Path = Join-Path $BaseDir $f
    if (!(Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null } 
}

$OriMp4Dir = Join-Path $BaseDir "file/ori_mp4"
$OriMp3Dir = Join-Path $BaseDir "file/ori_mp3"

# 轉換 MP4 -> MP3
Get-ChildItem "$OriMp4Dir/*.mp4" | ForEach-Object {
    $BaseName = $_.BaseName
    $Output = Join-Path $OriMp3Dir "$BaseName.mp3"
    if (!(Test-Path $Output)) {
        Write-Host "正在轉換 $($_.Name) 為 MP3..." -ForegroundColor Cyan
        ffmpeg -v error -i $_.FullName -vn -acodec libmp3lame -q:a 2 $Output
    }
}
Write-Host "準備完成！請確認 file/ori_mp3/ 內有檔案。" -ForegroundColor Green

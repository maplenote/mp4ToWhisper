# 設定區
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$BaseDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
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
        # 檢查是否有音訊流
        $hasAudio = ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$($_.FullName)"
        if (-not $hasAudio) {
            Write-Host "警告: $($_.Name) 沒有音訊流，跳過轉換。" -ForegroundColor Yellow
            return # In ForEach-Object, return acts like continue
        }

        Write-Host "正在轉換 $($_.Name) 為 MP3..." -ForegroundColor Cyan
        ffmpeg -v error -i "$($_.FullName)" -vn -acodec libmp3lame -q:a 2 "$Output"
    }
}
Write-Host "準備完成！請確認 file/ori_mp3/ 內有檔案。" -ForegroundColor Green

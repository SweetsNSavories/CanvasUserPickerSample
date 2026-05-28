Add-Type -Assembly System.IO.Compression.FileSystem
function List-Zip($path) {
    $full = (Resolve-Path $path).Path
    $z = [System.IO.Compression.ZipFile]::OpenRead($full)
    $list = $z.Entries | Select-Object FullName, Length, CompressedLength | Sort-Object FullName
    $z.Dispose()
    return $list
}

Write-Host "=== ORIGINAL msapp ===" -ForegroundColor Cyan
$orig = List-Zip "out\unpacked_unmanaged\CanvasApps\sns_canvasuserpickersample_c0ead_DocumentUri.msapp"
$orig | Format-Table -AutoSize

Write-Host "=== REBUILT msapp ===" -ForegroundColor Cyan
$new = List-Zip "out\v101_build\app.msapp"
$new | Format-Table -AutoSize

Write-Host "=== DIFF (files only in original) ===" -ForegroundColor Yellow
$orig | Where-Object { $_.FullName -notin $new.FullName } | ForEach-Object { $_.FullName }
Write-Host "=== DIFF (files only in rebuilt) ===" -ForegroundColor Yellow
$new | Where-Object { $_.FullName -notin $orig.FullName } | ForEach-Object { $_.FullName }

# Pack the Src/ folder into an .msapp ready to upload to make.powerapps.com.
#
# Requires: Power Platform CLI (pac) 1.27 or newer.
#   winget install Microsoft.PowerPlatformCLI    # if you don't have it
#   pac install latest                            # to update
#
# Usage:
#   .\pack.ps1                       # produces out\CanvasUserPickerSample.msapp
#   .\pack.ps1 -OutFile foo.msapp    # custom output path
#
[CmdletBinding()]
param(
    [string] $OutFile = (Join-Path $PSScriptRoot 'out\CanvasUserPickerSample.msapp')
)

$ErrorActionPreference = 'Stop'

$pac = Get-Command pac -ErrorAction SilentlyContinue
if (-not $pac) {
    Write-Error "Power Platform CLI (pac) not found on PATH. Install with: winget install Microsoft.PowerPlatformCLI"
}

$srcDir = Join-Path $PSScriptRoot 'Src'
if (-not (Test-Path $srcDir)) {
    Write-Error "Source folder not found: $srcDir"
}

$outDir = Split-Path -Parent $OutFile
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

Write-Host "Packing $srcDir -> $OutFile" -ForegroundColor Cyan
& pac canvas pack --sources $srcDir --msapp $OutFile

if ($LASTEXITCODE -ne 0) {
    Write-Error "pac canvas pack failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Done. Upload the .msapp at:" -ForegroundColor Green
Write-Host "  https://make.powerapps.com  ->  Apps  ->  Import canvas app" -ForegroundColor Green
Write-Host ""
Write-Host "Output: $OutFile"

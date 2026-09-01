#Requires -Version 5.1
<#
.SYNOPSIS
    Regenerates module/ITSupportOps/Scripts from the single source of truth
    in scripts/windows.

.DESCRIPTION
    module/ITSupportOps/Scripts is a bundled COPY, not a reference, because
    a published PowerShell module must be self-contained: once someone runs
    Install-Module ITSupportOps, they get exactly what's inside
    module/ITSupportOps, not the rest of this git repo.

    scripts/windows is the single source of truth. Never hand-edit files in
    module/ITSupportOps/Scripts directly. Instead:

      1. Make your change in scripts/windows/*.ps1
      2. Run this script: ./tools/Build-Module.ps1
      3. Commit both the scripts/windows change and the regenerated
         module/ITSupportOps/Scripts files together

    CI enforces this automatically (see .github/workflows/ci.yml,
    job: verify-module-sync) and will fail the build if the two locations
    ever drift apart.

.EXAMPLE
    ./tools/Build-Module.ps1
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

$source = Join-Path $RepoRoot "scripts/windows"
$dest = Join-Path $RepoRoot "module/ITSupportOps/Scripts"

if (-not (Test-Path $source)) {
    throw "Source folder not found: $source"
}
if (-not (Test-Path $dest)) {
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
}

Get-ChildItem -Path $dest -Filter "*.ps1" -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -Path $source -Filter "*.ps1" | Copy-Item -Destination $dest -Force

$count = (Get-ChildItem -Path $dest -Filter "*.ps1").Count
Write-Host "Rebuilt module/ITSupportOps/Scripts from scripts/windows ($count files)."
Write-Host "Remember to commit the regenerated files."
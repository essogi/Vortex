<#
.SYNOPSIS
Reproduce the fixed Out of the Vortex ROM from the archived Hidden Palace
source plus this repository's patches.

.DESCRIPTION
This repository contains no Cryo code or data. You supply the two tools:

  -SourceZip  Out_of_the_Vortex_(Source_Code_-_Sep_13,_1995).zip
              from hiddenpalace.org (the Sep 13, 1995 prototype page)
  -Axm68k     axm68k.exe from github.com/cvghivebrain/axm68k (releases)
  -Macros     "Macros - More CPUs.asm" (ships alongside axm68k.exe)

The script verifies the archive checksum, extracts the source tree, applies
the patches, assembles with axm68k, and verifies the output ROM checksum.
See docs/01-toolchain-migration.md for what the patches do and why.

Requires:  Windows 8 and later plus git (Git for Windows).
Easiest entry point: build.bat next to this script runs it without any
execution-policy fiddling. On Linux, axm68k is a Win32 console binary;
running this flow under Wine is expected to work but is unverified -
reports welcome.

.EXAMPLE
.\build.ps1 -SourceZip "$HOME\Downloads\Out_of_the_Vortex_(Source_Code_-_Sep_13,_1995).zip" `
                -Axm68k "$HOME\Downloads\axm68k\axm68k.exe" `
                -Macros "$HOME\Downloads\axm68k\Macros - More CPUs.asm"
#>
param(
    [Parameter(Mandatory = $true)][string]$SourceZip,
    [Parameter(Mandatory = $true)][string]$Axm68k,
    [Parameter(Mandatory = $true)][string]$Macros,
    # The sources hardcode this path; building elsewhere auto-rewrites the includes.
    [string]$WorkDir = 'c:\travaux\megadrv\vortex2',
    # 'all' applies patches 01..NN in order; 'latest' applies the single
    # rolled-up source-patches/latest.patch. The output is identical.
    [ValidateSet('all', 'latest')][string]$PatchSet = 'all',
    [switch]$SkipChecksums
)

. "$PSScriptRoot\_common.ps1"
$patchRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'source-patches'

Assert-Git
foreach ($f in @($SourceZip, $Axm68k, $Macros)) {
    if (-not (Test-Path -LiteralPath $f)) { throw "input not found: $f" }
}
if (-not $SkipChecksums) {
    Assert-Sha256 $SourceZip $OOTV.SourceZipSha 'Hidden Palace source archive'
    Assert-Sha256 $Axm68k $OOTV.Axm68kSha 'axm68k.exe'
}

if ((Test-Path -LiteralPath $WorkDir) -and (Get-ChildItem -LiteralPath $WorkDir)) {
    throw "work directory exists and is not empty: $WorkDir`nPick another -WorkDir or remove it first."
}

Write-Host "extracting source archive..."
$extract = Join-Path $env:TEMP ("ootv-extract-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $extract
# .NET ZipFile rather than Expand-Archive, which needs PowerShell 5+.
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory(
    (Resolve-Path -LiteralPath $SourceZip).ProviderPath, $extract)
try {
    $gameTree = Find-GameTree $extract
    $null = New-Item -ItemType Directory -Force -Path $WorkDir
    Copy-Item -Path (Join-Path $gameTree '*') -Destination $WorkDir -Recurse
} finally {
    Remove-Item -LiteralPath $extract -Recurse -Force
}
if (-not $SkipChecksums) {
    Assert-Sha256 (Join-Path $WorkDir 'TOTAL2.68K') $OOTV.ArchiveTotal2 'archive TOTAL2.68K'
}

Write-Host "applying patches ($PatchSet)..."
if ($PatchSet -eq 'latest') {
    Invoke-ApplyPatch $WorkDir (Join-Path $patchRoot 'latest.patch')
} else {
    foreach ($p in Get-PatchFiles $patchRoot) { Invoke-ApplyPatch $WorkDir $p.FullName }
}

Copy-Item -LiteralPath $Macros -Destination (Join-Path $WorkDir $OOTV.MacrosName)

$canonical = [System.IO.Path]::GetFullPath($OOTV.CanonicalPath).TrimEnd('\')
$actual = [System.IO.Path]::GetFullPath($WorkDir).TrimEnd('\')
if ($actual -ne $canonical) {
    Write-Host "work directory is not $($OOTV.CanonicalPath); rewriting hardcoded include paths..."
    Invoke-RedirectPaths $WorkDir $actual
}

Write-Host 'assembling (axm68k)...'
$rom = Invoke-Assemble $WorkDir $Axm68k

$hash = Get-Sha256 $rom
$size = (Get-Item -LiteralPath $rom).Length
Write-Host ''
Write-Host ("built: {0} ({1:N0} bytes)" -f $rom, $size)
Write-Host ("SHA-256: {0}" -f $hash)
$expected = Get-ExpectedRom $patchRoot
if ($hash -eq $expected.Sha256) {
    Write-Host ("MATCH: byte-identical to the v{0} release build." -f $expected.Version) -ForegroundColor Green
} else {
    Write-Warning ("output does not match the v{0} release ROM. If you modified patches or sources this may be expected; otherwise something went wrong." -f $expected.Version)
}

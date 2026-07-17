<#
.SYNOPSIS
Maintainer tool: rebuild everything from archive + patches, verify the chain,
regenerate source-patches/latest.patch, and produce release assets (BPS patch
+ checksums).

.DESCRIPTION
Run this before every release. It fails loudly if the per-fix patches do not
reproduce the expected ROM byte-for-byte, so a release can never drift from
its patches. Steps:

  1. stage a copy of the archive source tree
  2. apply patches 01..NN in order
  3. regenerate source-patches/latest.patch from the staged result and
     round-trip verify it (apply to archive, compare byte-for-byte)
  4. assemble the staged tree and assert the ROM SHA-256 equals -ExpectedRom
  5. optionally (-ProtoRom + -Flips) create the gamer-path BPS patch against
     the Hidden Palace prototype ROM, verify it round-trips, and write
     checksums.txt release notes material into -OutDir

.EXAMPLE
.\make-release.ps1 -ArchiveTree C:\path\to\archive\vortex2 `
                   -Axm68k C:\tools\axm68k.exe -Macros 'C:\tools\Macros - More CPUs.asm' `
                   -ExpectedRom C:\dev\vortex2\TOTAL2.bin `
                   -ProtoRom 'C:\roms\Out of the Vortex (Sep 13, 1995 prototype).md' `
                   -Flips C:\tools\flips.exe -Version 0.03 -OutDir C:\release-staging
#>
param(
    [Parameter(Mandatory = $true)][string]$ArchiveTree,
    [Parameter(Mandatory = $true)][string]$Axm68k,
    [Parameter(Mandatory = $true)][string]$Macros,
    [Parameter(Mandatory = $true)][string]$ExpectedRom,
    [string]$ProtoRom,
    [string]$Flips,
    [string]$Version = 'dev',
    [string]$OutDir,
    [string]$StageRoot = 'C:\travaux\megadrv\.ootv-stage',
    [switch]$KeepStage
)

. "$PSScriptRoot\_common.ps1"
$repoRoot = Split-Path $PSScriptRoot -Parent
$patchRoot = Join-Path $repoRoot 'source-patches'

Assert-Git
Assert-Sha256 (Join-Path $ArchiveTree 'TOTAL2.68K') $OOTV.ArchiveTotal2 'archive TOTAL2.68K'
Assert-Sha256 $Axm68k $OOTV.Axm68kSha 'axm68k.exe'

if (Test-Path -LiteralPath $StageRoot) { Remove-Item -LiteralPath $StageRoot -Recurse -Force }
$stage = Join-Path $StageRoot 'tree'
$null = New-Item -ItemType Directory -Force -Path $stage

try {
    Write-Host 'staging archive tree...'
    Copy-Item -Path (Join-Path $ArchiveTree '*') -Destination $stage -Recurse

    Write-Host 'applying per-fix patches...'
    $patches = @(Get-PatchFiles $patchRoot)
    if ($patches.Count -eq 0) { throw "no numbered patches found under $patchRoot" }
    foreach ($p in $patches) { Invoke-ApplyPatch $stage $p.FullName }

    # ---- regenerate source-patches/latest.patch ----------------------------
    Write-Host 'regenerating latest.patch...'
    $diffRoot = Join-Path $StageRoot 'diff'
    $null = New-Item -ItemType Directory -Force -Path (Join-Path $diffRoot 'a')
    $null = New-Item -ItemType Directory -Force -Path (Join-Path $diffRoot 'b')
    $changed = @()
    foreach ($f in Get-ChildItem -LiteralPath $stage -File) {
        $orig = Join-Path $ArchiveTree $f.Name
        if ((Test-Path -LiteralPath $orig) -and ((Get-Sha256 $orig) -ne (Get-Sha256 $f.FullName))) {
            $changed += $f.Name
            Copy-Item -LiteralPath $orig -Destination (Join-Path $diffRoot "a\$($f.Name)")
            Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $diffRoot "b\$($f.Name)")
        }
    }
    Write-Host ("  changed files: {0}" -f ($changed -join ', '))
    $latestPatch = Join-Path $patchRoot 'latest.patch'
    Push-Location -LiteralPath $diffRoot
    try {
        # --output keeps git in charge of the file: bytes (CRLF) land intact.
        & git -c core.autocrlf=false diff --no-index --no-prefix --output="$latestPatch" a b
        if ($LASTEXITCODE -gt 1) { throw "git diff failed ($LASTEXITCODE)" }
    } finally { Pop-Location }

    Write-Host 'round-trip verifying latest.patch...'
    $rt = Join-Path $StageRoot 'roundtrip'
    $null = New-Item -ItemType Directory -Force -Path $rt
    foreach ($n in $changed) { Copy-Item -LiteralPath (Join-Path $ArchiveTree $n) -Destination (Join-Path $rt $n) }
    Invoke-ApplyPatch $rt $latestPatch
    foreach ($n in $changed) {
        if ((Get-Sha256 (Join-Path $rt $n)) -ne (Get-Sha256 (Join-Path $stage $n))) {
            throw "latest.patch round-trip mismatch on $n"
        }
    }
    Write-Host '  OK  latest.patch == patches 01..NN, byte-for-byte' -ForegroundColor Green

    # ---- assemble + assert ------------------------------------------------
    Copy-Item -LiteralPath $Macros -Destination (Join-Path $stage $OOTV.MacrosName)
    Invoke-RedirectPaths $stage ([System.IO.Path]::GetFullPath($stage).TrimEnd('\'))
    Write-Host 'assembling staged tree...'
    $rom = Invoke-Assemble $stage $Axm68k
    $romHash = Get-Sha256 $rom
    $expHash = Get-Sha256 $ExpectedRom
    if ($romHash -ne $expHash) {
        throw "built ROM does not match -ExpectedRom:`n  built    $romHash`n  expected $expHash`nA fix in the dev tree is probably not captured by the patches yet (tools/new-patch.ps1)."
    }
    Write-Host "  OK  built ROM matches expected ROM ($romHash)" -ForegroundColor Green

    if ($Version -ne 'dev') {
        $expFile = Join-Path $patchRoot 'expected-rom.txt'
        $romSize = (Get-Item -LiteralPath $rom).Length
        Set-Content -LiteralPath $expFile -Encoding Ascii -Value @(
            "version $Version"
            "sha256 $romHash"
            "bytes $romSize"
        )
        Write-Host "  OK  $expFile updated (build.ps1 verifies against this)" -ForegroundColor Green
    } else {
        Write-Host '  note: -Version is "dev"; expected-rom.txt NOT updated'
    }

    # ---- release assets ----------------------------------------------------
    if ($ProtoRom -and $Flips) {
        if (-not $OutDir) { throw '-OutDir is required when creating release assets' }
        $null = New-Item -ItemType Directory -Force -Path $OutDir
        $bps = Join-Path $OutDir ("ootv-fixes-v{0}.bps" -f $Version)
        Write-Host 'creating BPS (gamer path)...'
        & $Flips --create --bps-delta $ProtoRom $rom $bps | Out-Host
        if (-not (Test-Path -LiteralPath $bps)) { throw 'flips did not produce the BPS patch' }
        $applied = Join-Path $StageRoot 'bps-roundtrip.bin'
        & $Flips --apply $bps $ProtoRom $applied | Out-Host
        if ((Get-Sha256 $applied) -ne $romHash) { throw 'BPS round-trip does not reproduce the built ROM' }
        Write-Host ("  OK  {0} ({1:N0} bytes), round-trip verified" -f (Split-Path $bps -Leaf), (Get-Item -LiteralPath $bps).Length) -ForegroundColor Green

        $checks = @(
            "Out of the Vortex - fixed build v$Version - checksums (SHA-256)"
            ""
            ("HP source zip (input) : {0}" -f $OOTV.SourceZipSha)
            ("HP proto ROM (input)  : {0}" -f (Get-Sha256 $ProtoRom))
            ("fixed ROM (output)    : {0}" -f $romHash)
            ("BPS patch             : {0}" -f (Get-Sha256 $bps))
        )
        Set-Content -LiteralPath (Join-Path $OutDir 'checksums.txt') -Value $checks -Encoding utf8
    } else {
        Write-Host 'skipping BPS/release assets (-ProtoRom and -Flips not both given)'
    }

    Write-Host ''
    Write-Host "release verification complete for v$Version" -ForegroundColor Green
} finally {
    if (-not $KeepStage -and (Test-Path -LiteralPath $StageRoot)) {
        Remove-Item -LiteralPath $StageRoot -Recurse -Force
    }
}

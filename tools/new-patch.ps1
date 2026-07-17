<#
.SYNOPSIS
Maintainer tool: cut a CANDIDATE patch for a new fix by diffing the dev tree
against archive + all existing patches.

.DESCRIPTION
Produces a unified diff of every .68K file that differs between (archive
source + patches 01..NN) and your development tree. The output is a CANDIDATE:
review it by hand before promoting it to source-patches/NN-name.patch —
remove hunks that are not part of the fix (translated comments, experiments),
and keep only what the fix needs. Then run make-release.ps1, which fails
unless the patch set reproduces your dev ROM byte-for-byte — that failure is
the safety net for over-trimming.

.EXAMPLE
.\new-patch.ps1 -ArchiveTree C:\path\to\archive\vortex2 -DevTree C:\travaux\megadrv\vortex2 `
                -Out .\candidate.patch
#>
param(
    [Parameter(Mandatory = $true)][string]$ArchiveTree,
    [Parameter(Mandatory = $true)][string]$DevTree,
    [string]$Out = (Join-Path (Get-Location) 'candidate.patch'),
    [string]$StageRoot = 'C:\travaux\megadrv\.ootv-newpatch'
)

. "$PSScriptRoot\_common.ps1"
$patchRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'source-patches'

Assert-Git
Assert-Sha256 (Join-Path $ArchiveTree 'TOTAL2.68K') $OOTV.ArchiveTotal2 'archive TOTAL2.68K'

if (Test-Path -LiteralPath $StageRoot) { Remove-Item -LiteralPath $StageRoot -Recurse -Force }
$baseDir = Join-Path $StageRoot 'a'
$devDir = Join-Path $StageRoot 'b'
$null = New-Item -ItemType Directory -Force -Path $baseDir
$null = New-Item -ItemType Directory -Force -Path $devDir

try {
    Write-Host 'staging baseline (archive + existing patches)...'
    Copy-Item -Path (Join-Path $ArchiveTree '*.68K') -Destination $baseDir
    foreach ($p in Get-PatchFiles $patchRoot) { Invoke-ApplyPatch $baseDir $p.FullName }

    $changed = @()
    foreach ($f in Get-ChildItem -LiteralPath $baseDir -Filter *.68K) {
        $dev = Join-Path $DevTree $f.Name
        if ((Test-Path -LiteralPath $dev) -and ((Get-Sha256 $dev) -ne (Get-Sha256 $f.FullName))) {
            $changed += $f.Name
            Copy-Item -LiteralPath $dev -Destination (Join-Path $devDir $f.Name)
        } else {
            Remove-Item -LiteralPath $f.FullName
        }
    }
    if ($changed.Count -eq 0) {
        Write-Host 'dev tree and baseline are identical - nothing to cut.' -ForegroundColor Green
        return
    }
    Write-Host ("  files with new changes: {0}" -f ($changed -join ', '))

    Push-Location -LiteralPath $StageRoot
    try {
        & git -c core.autocrlf=false diff --no-index --no-prefix --output="$Out" a b
        if ($LASTEXITCODE -gt 1) { throw "git diff failed ($LASTEXITCODE)" }
    } finally { Pop-Location }

    Write-Host ''
    Write-Host "candidate written: $Out" -ForegroundColor Green
    Write-Host 'Review it hunk by hunk; keep only the fix. Then name it source-patches/NN-name.patch'
    Write-Host 'and run make-release.ps1 to verify the chain.'
} finally {
    if (Test-Path -LiteralPath $StageRoot) { Remove-Item -LiteralPath $StageRoot -Recurse -Force }
}

# Building the ROM from source

If you just want to play, see [`PLAYING.md`](../PLAYING.md); this page is
for rebuilding the game from the Hidden Palace source archive, if you are interested in modifying it. Background on every step: [`01-toolchain-migration.md`](01-toolchain-migration.md).

This repository contains none of Cryo's code or data. You supply the tools,
all freely available:

- `Out_of_the_Vortex_(Source_Code_-_Sep_13,_1995).zip` from
  [hiddenpalace.org](https://hiddenpalace.org/Out_of_the_Vortex_(Sep_13,_1995_prototype))
- `axm68k.exe` + `Macros - More CPUs.asm` from
  [github.com/cvghivebrain/axm68k](https://github.com/cvghivebrain/axm68k)

Requirements: Windows 8 or later plus [git](https://git-scm.com/download/win). Every input
and output is checksum-verified; the scripts refuse to continue on a
mismatch (expected hashes live in `tools/_common.ps1`).

Run the `.bat`; it launches the PowerShell script for you, no
execution-policy fiddling:

```bat
tools\build.bat -SourceZip "%USERPROFILE%\Downloads\Out_of_the_Vortex_(Source_Code_-_Sep_13,_1995).zip" ^
                -Axm68k "%USERPROFILE%\Downloads\axm68k\axm68k.exe" ^
                -Macros "%USERPROFILE%\Downloads\axm68k\Macros - More CPUs.asm"
```

Success looks like: `MATCH: byte-identical to the vX.XX release build.`, where
`X.XX` is whichever release your patch set reproduces.

Notes:

- The 1995 sources hardcode `c:\travaux\megadrv\vortex2` in 620 include
  paths. The default `-WorkDir` is that path; pass any other `-WorkDir` and
  the script rewrites the paths for you.
- `source-patches/latest.patch` is the generated single-file equivalent of applying
  every numbered patch in order; `-PatchSet latest` uses it, and the output
  ROM is identical either way. It is regenerated and round-trip verified on
  every release; never edit it by hand. To apply it without the script:
  `git -c core.autocrlf=false apply latest.patch` from the game directory.
- Linux/macOS: axm68k is a Win32 console binary. The same flow under Wine is
  expected to work but is unverified; reports welcome.

## Maintainer notes for myself (or someone who wants to make their own patch):

1. Make and test the fix in the dev tree.
2. `tools/new-patch.ps1` → produces `candidate.patch` (dev tree vs.
   base + existing patches). Curate it by hand: keep only the fix's
   hunks, name it `source-patches/NN-name.patch`.
3. `tools/make-release.ps1`: refuses to pass unless base + patches
   reproduces the dev ROM byte-for-byte; regenerates `source-patches/latest.patch`
   and `source-patches/expected-rom.txt` (the version + hash `build.ps1`
   verifies user builds against; generated, never hand-edited), plus the
   release BPS + checksums (needs `flips.exe` from
   [github.com/Alcaro/Flips](https://github.com/Alcaro/Flips)).
4. Publish the GitHub release with the BPS + checksums.

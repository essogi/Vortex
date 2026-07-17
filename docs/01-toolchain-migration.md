# 01 - Toolchain migration: building the 1995 source in 2024

*How I found a build system for modern Windows machines, and why the
corresponding changes in patch `01-toolchain-migration.patch` were made.
This patch changes no gameplay.*

The Hidden Palace release (July 2024, source provided by original programmer
David "Pipozor" Saulnier) contains the complete game source for
Sega's 1990s PSY-Q/SNASM development kit: 68000 assembly across
eight `.68K` files (built as one translation unit from
`TOTAL2.68K`), all game assets, and Cryo's build script `ASS.CMD`. It
includes `SNASM68K.EXE` (a DOS-era binary incompatible with 64-bit
Windows) but no working build instructions. Shortly after Hidden Palace's release,
I began researching how I could get the source to assemble on my machine.

## Finding an assembler

1. **SNASM68K.EXE under DOSBox**: the assembler complained about not finding
   the development kit's SCSI PC card, and I didn't find a simple way to
   bypass it.
2. **vasm** (under Linux): syntax and directive gaps with the SNASM sources.
3. **[axm68k](https://github.com/cvghivebrain/axm68k)**: found via the
   Sonic Retro community forums. It is SN Systems asm68k 2.53 patched to
   run as a modern Win32 console binary. With sufficient code changes, this
   one worked.

I owe the Mega Drive homebrew community thanks for patching versions of
asm68k to run on 64-bit Windows.

## What the patch changes

The minimal source changes that make the clean archive assemble with
axm68k. Three files change: `TOTAL2.68K`, `HEADER.68K`,
`ROUTANIM.68K`. Eight categories:

1. **Macro shim + CPU select** (top of `TOTAL2.68K`): `include "…\Macros -
   More CPUs.asm"` + `cpu 68000`. axm68k supports both the 68000 and the
   Z80; the mnemonics the two CPUs share are stripped and reinstated per-CPU
   as macros in a shim file that ships with axm68k. Without it, every
   `add`/`sub`/`and`/`or` in the project is an unknown token. **Obtain the
   shim from the axm68k distribution; it is not part of this repository.**
2. **SNASM `REGS` directives commented out**: `REGS` is a SNASM
   debugger-state directive.
3. **Labels un-glued from shimmed mnemonics**: `label:addq` parses fine
   when `addq` is a real opcode but not when it is a macro.
4. **`i set …` → `i = …`**: the shim removes
   `SET`, which collides with the Z80 instruction of the same name.
5. **`SPR.W` renamed `SPR.Y`**: asm68k insists on parsing `.W` as a size
   suffix. `SPR.Y` was unused and the rename preserves every structure
   offset.
6. **8.3 filename fixes** (`DeadLight.Cmg` → `DeadLigh.Cmg`): the source
   references long names, but the asset files carry DOS-truncated 8.3
   names. Under DOS this worked anyway, since filenames were silently
   clipped when opened. Modern Windows takes long names literally, so the
   references miss.
7. **`ORG $ffff0000` → `OBJ $ffff0000`**: the hardest issue to find. The
   source ends by switching to the Work-RAM address space to lay out
   variables. In binary output mode asm68k treats `ORG` as a *file seek*,
   and seeking to `$ffff0000` is a fatal error that is reported ~400 lines
   away from the real site. Testing yielded:

   | Line | Result |
   |---|---|
   | `ORG $ffff0000` | fatal "seek before start of file", misreported location |
   | omitted | assembles, but every RAM variable lands at ROM addresses |
   | `OBJ $ffff0000` | correct: logical address changes, and file position does not |

   I found my solution by deleting the `ORG` line and watching the RAM
   layout displace into ROM. Building a ROM that booted only to black was
   encouraging. I then found `OBJ` in the SN Systems manual, and had the
   fix.
8. **Backslash line-continuations collapsed** in 11 `TO_VRAM_Copy` macro
   invocations: axm68k rejects `\`-continued macro arguments.

Additionally, six `opt` optimization lines in `HEADER.68K` are commented
out. The source assembles either way; opts **off** is what the released
builds used. Deterministic addresses matter when you are debugging, so the
patch keeps them off to stay byte-comparable with the releases.

This patch leaves everything else byte-identical to the archive:
`VARS_EQU.68K`, `COUPS.68K`, `PUZZLE.68K`, `TAB_INTE.68K`, `REPLAY.68K`.

## Build command and flags

```
axm68k.exe /p /c /zd /k /ov+ /ol+ TOTAL2.68K,TOTAL2.bin,TOTAL2.symb,TOTAL2.list
```

- `/p`: output a pure binary file, i.e. the ROM image itself.
- `/k`: allow `ifeq`/`ifne` conditionals, which the source uses
  throughout (`Debug`, `Select_Depart_Menu`, ...).
- `/zd`: emit source-level debug info: `TOTAL2.symb` and `TOTAL2.list`,
  the address→source mapping every bug hunt in patches 03-07 ran on.
- `/c`: keep conditioned-out lines in the listing, so the disabled
  branches (the `Debug` blocks) stay visible when reading it.
- `/ov+`: write local labels to the symbol file; crashes tend to land on
  locals like `.boucle`, so they need to be resolvable.
- `/ol+`: select `.` as the local-label lead character, the convention
  this source uses.

`/p` and `/k` are the two the build cannot live without; the other four
exist to make the listing and symbol file as useful as possible while
debugging.

## Reproducing the build

The 1995 sources hardcode `c:\travaux\megadrv\vortex2` in include/incbin
paths. There are no relative includes, so a tree extracted anywhere else
fails with hundreds of missing-file errors. Either extract the archive so
the game tree sits at exactly that path, or build with
`tools\build.bat -WorkDir <your folder>`, which rewrites all path strings
inside the sources to point at the folder you actually chose before
assembling.

Inputs are identified by SHA-256 (the build script refuses a mismatch):

| Artifact | SHA-256 |
|---|---|
| HP source zip `Out_of_the_Vortex_(Source_Code_-_Sep_13,_1995).zip` | `D2A1F27174B3A1B27CF347A85AB4C731D200A92A9BB363526F49910C461CBD5A` |
| axm68k.exe ("SN 68k version 2.53") | `29AB2945555FAE2903A44FF516BAFA486B61C3AA1A14B6D20139FE295D777DE5` |

`tools\build.bat` runs the whole chain (verify, extract, patch, assemble)
and checks the output against `source-patches/expected-rom.txt`, the
version + hash record regenerated with each release. By hand: extract to
the canonical path, copy the Macros shim in, apply the patches in numeric
order (they are CRLF byte-exact against the archive as shipped), and
assemble with the command above. The toolchain is deterministic: the same
tree always produces the same hash.

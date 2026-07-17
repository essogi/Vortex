# 02 - Off-dev-kit configuration, exception traps, region-free builds

**Type:** platform/debug infrastructure · **First shipped:** v0.00
**Files:** `VARS_EQU.68K`, `HEADER.68K`, `TOTAL2.68K`

This patch sets up my debug infrastructure and ensures the builds are
region-free.

## The problem

The archived source is configured for Sega's SCSI dev-kit hardware
(`Debug: EQU 1`): exception vectors 02-09 point at `SCSIExcept` (exception
reporting that talks to the dev-kit hardware), and the entry point takes
the dev branch. A straight retail-style flip to `Debug: EQU 0` boots on
emulators and stock consoles, but it throws away all crash visibility and would have *activated* Sega's territory lockout.

## The changes

1. **`Debug: EQU 1 → 0`** (`VARS_EQU.68K:6`): retail-style boot path.
2. **`Pizza_Debug: EQU 1`** (new): gates my replacement debug
   infrastructure.
3. **Vector table rewrite** (`HEADER.68K`): the `IFNE Debug` SCSI block is
   retired; under `IFNE Pizza_Debug` vectors 02-09 point at eight new
   handlers: `Bus_Trap`, `Address_Trap`, `Instruction_Trap`, `Zero_Trap`,
   `CHK_Trap`, `TrapV`, `Privilege_Trap`, `Trace_Trap`, with the plain
   `rte` fallback otherwise.
4. **The trap handlers** (`TOTAL2.68K`): eight labeled `jmp self`
   spin-loops. A crash now freezes the game at a *named* address instead
   of executing garbage; the emulator's address log (Blast 'Em `-l`) then
   shows exactly which exception fired and from where. Combined with the
   assembler's `/zd` listing/symbol output, this is the workflow that
   located the bugs in patches 03-07.
5. **Region lock kept out: `ifeq DEBUG → ifne DEBUG`** (`HEADER.68K:895`,
   guarding `include …lock.a`). `LOCK.A` is Sega of America's official
   1995 "Genesis territory lockout" file, present in the HP archive: it
   reads the hardware territory ID at `$A10001` and hangs on a region
   mismatch. asm68k symbols are case-insensitive, so `DEBUG` is `Debug`:
   the pristine dev builds (`Debug=1`) skipped the lock, and flipping to
   `Debug=0` alone would have pulled it **in**. Inverting the guard keeps
   the lockout out of the build. This is why the released builds run on
   any region's hardware.

6. **Level select enabled: `Select_Depart_Menu: EQU 0 → 1`**
   (`VARS_EQU.68K`). A second Cryo build-time switch flipped in the same
   file; the stage-select menu it gates is already complete in the archived
   source, so the released builds turn it on to let testers reach later
   levels directly. Hidden Palace's own prototype release ships a separate
   "vortex level select" ROM with the same feature enabled.

## Why the traps

Before the vector table rewrite, an exception would go through the old
dev-kit vector table, which sent execution off into data the CPU could
execute as instructions: a confusing situation to untangle, since code and
data look alike from the emulator's perspective. My table lets me trap the
exceptions usefully; working backwards from crashes required crashes to
land somewhere observable.

Keeping the released builds region-free should let people play on any Mega
Drive or Genesis, on a flash cart or an emulator, with any regional
setting.

## Debugging methodology (used for patches 03-07)

1. Run in Blast 'Em (or MAME); on a crash, dump the last executed
   addresses / address log.
2. Map addresses back to source lines through the `/zd` output
   (`TOTAL2.symb`/`TOTAL2.list`).
3. Emulator watchpoints/breakpoints to catch the write that planted bad
   state.
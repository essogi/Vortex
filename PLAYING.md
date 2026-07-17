# Quick Play Patching

Grab the `.bps` patch from the
[latest release](https://github.com/essogi/Vortex/releases) and turn the
Hidden Palace prototype ROM into the bug-fixed build:

1. Download the **Out of the Vortex (Sep 13, 1995 prototype)** ROM from
   [hiddenpalace.org](https://hiddenpalace.org/Out_of_the_Vortex_(Sep_13,_1995_prototype)).
2. Open [Rom Patcher JS](https://www.marcrobledo.com/RomPatcher.js/) in your
   browser; patching runs locally and nothing is uploaded anywhere.
3. Select the prototype ROM, select the `.bps` file, press **Apply patch**,
   and save the result. Play it in any Mega Drive emulator or on real
   hardware via a flashcart.

The patch has the correct base ROM's checksum built in: if you picked the
wrong file it will say so instead of producing a broken game. Flashcart
users: apply the patch first, then copy the output file to the cart
(on-cart auto-patching is IPS-only).

There are still bugs, but the game is more completable than the first ROM
released. See the [issues tab](https://github.com/essogi/Vortex/issues) for
the documented bugs, and open an issue if you find another one.

## Suggested Emulator

[BlastEm](https://www.retrodev.com/blastem/nightlies/): grab the latest
nightly build.

## Guide for how you can help with testing

Run BlastEm from the command line with a ROM and the `-l` option, which
produces a file called `address.log` in the BlastEm folder:

```
blastem.exe [rom name] -l
```

If the game hangs, take a screenshot of the frozen game state. Send me the
screenshot, the `address.log`, and a description of the game state if you
can, and I will try to sort out the bug. Thanks!

No original ROM or source code is distributed here; the patch contains only
the fixes. The [README](README.md) indexes each fix. The toolchain restoration and debug
infrastructure are written up in [`docs/`](docs/).

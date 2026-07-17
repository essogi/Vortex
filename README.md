# Out of the Vortex: bug fixes and toolchain restoration

*Out of the Vortex* is an unreleased 1995 Sega Mega Drive brawler by Cryo
Interactive, based on the Dark Horse comic, cancelled at roughly 95%
complete. This repository holds my work on it: a restored build toolchain
and a set of source patches that fix crashes and gameplay bugs, all against
the Hidden Palace source release.

It contains none of Cryo's code or ROMs. To build or to play you supply
your own copy of the public Hidden Palace archive; this repository
ships only my patches and documentation.

## History

Hidden Palace released the final prototype together with the complete game
source in July 2024, donated by original lead programmer David "Pipozor"
Saulnier. The source targets Sega's proprietary 1990s PSY-Q development kit
and came with no working build instructions. Hidden Palace's own restoration successfully
stripped PSY-Q debug code from the released `.CPE` executable and produced the first publicly playable ROM.

Shortly after that release, I restored a working build toolchain on modern
Windows and began fixing bugs. As far as I know, this is the first working
build of the game since its cancellation. If you have information about its original development, I would love to learn more.

## How To

- **Play ROM with Bug fixes:** See [PLAYING.md](PLAYING.md). Apply the release BPS
  patch to your Hidden Palace prototype ROM in the browser, nothing to
  install.
- **Build from source:** See [docs/building.md](docs/building.md).

## Patches

Each patch in [`source-patches/`](source-patches/) applies to the clean
archive. Applying patches 01 through the highest-numbered patch in order
reproduces my current build byte for byte. More per-bug writeups to come.

| # | Fix | Shipped | Reference |
|---|-----|---------|-----------|
| 01 | Toolchain migration: build the 1995 source with axm68k | v0.00 | [writeup](docs/01-toolchain-migration.md) |
| 02 | Off-dev-kit config, exception traps, region-free, level select | v0.00 | [writeup](docs/02-offkit-traps-regionfree.md) |
| 03 | Animation-cancel out-of-bounds jump (sewer and Ghost crash) | v0.00 | [issue #10](https://github.com/essogi/Vortex/issues/10) |
| 04 | Monorail screen-shake follows you out of the level | v0.01 | [issue #3](https://github.com/essogi/Vortex/issues/3) |
| 05 | Red Guy double-hit death (first boss crash) | v0.02 | [issue #4](https://github.com/essogi/Vortex/issues/4) |
| 06 | Continue screen never appears | v0.02 | fixed without filing |
| 07 | Nano3 null stun-table crash (final boss, second form) | v0.03 | [issue #2](https://github.com/essogi/Vortex/issues/2) |

## Credits

- **Hidden Palace** for preserving and releasing the prototype and the
  source: [the release announcement](https://hiddenpalace.org/News/Vanished_without_a_Trace_-_Out_of_the_Vortex_for_the_Sega_Mega_Drive).
- **David "Pipozor" Saulnier**, original lead programmer, for saving the work
  and donating it.
- The Mega Drive homebrew community for the modern asm68k builds the
  toolchain depends on.
- [Goati_](https://www.youtube.com/watch?v=XeKYVwdjfnk) for the good video
  digging into the history of the game and current preservation efforts.
- Zenkerdus for the early play-testing that verified the first bug fix.

## License and scope

The patches and documentation here are my work, licensed [MIT](LICENSE). The
MIT license covers only my contributions. It does not cover any Cryo
Interactive source code or game data. Rights to the original game are held
by Microïds (successor to Cryo through DreamCatcher); the Dark Horse comic
is owned by Dark Horse.

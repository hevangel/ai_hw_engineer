# External reference repositories

Third-party emulators, tools and documentation used as **independent
references** when checking chip and system designs. They are not part of any
design and nothing here is built by the repository's scripts.

Each folder is a git submodule pinned to one commit. The repository records
only that pointer, not the files.

## Fetching

These submodules are opt-in. `.gitmodules` marks each one `update = none` and
`shallow = true`, so `git clone --recurse-submodules` and
`git submodule update --init` skip them. Together they are roughly 500 MB.
Fetch only the ones you need:

```sh
git submodule update --init --checkout --depth 1 external/martypc
```

That shallow fetch takes the upstream branch tip. Once upstream has moved
past the pinned commit it can fail with "did not contain <commit>". The clone
exists by then, so fetch the pinned commit directly:

```sh
git -C external/86box/86Box fetch --depth 1 origin "$(git rev-parse HEAD:external/86box/86Box)"
git -C external/86box/86Box checkout FETCH_HEAD
```

To move one to a newer upstream commit, fetch and check it out inside the
submodule, then commit the new pointer here with the reason:

```sh
git -C external/86box/86Box fetch --depth 1 origin master
git -C external/86box/86Box checkout FETCH_HEAD
git add external/86box/86Box
```

## Contents

| Path | Upstream | Use | Licence |
|---|---|---|---|
| `martypc/` | [dbalsom/martypc](https://github.com/dbalsom/martypc) | Cycle-accurate IBM PC/XT emulator; 8086/8088 reference | MIT |
| `pce-286/` | [tsupplis/pce-286](https://github.com/tsupplis/pce-286) | PCE with protected-mode 80286 support; 80286 reference | GPL-2.0 |
| `86box/86Box/` | [86Box/86Box](https://github.com/86Box/86Box) | x86 machine emulator; 286/386/486 reference | GPL-2.0 |
| `86box/86BoxManager/` | [86Box/86BoxManager](https://github.com/86Box/86BoxManager) | Configuration manager (archived upstream) | MIT |
| `86box/86box.github.io/` | [86Box/86box.github.io](https://github.com/86Box/86box.github.io) | Project website | No licence file |
| `86box/assets/` | [86Box/assets](https://github.com/86Box/assets) | Other emulator assets | Preservation notice, see below |
| `86box/bios-tools/` | [86Box/bios-tools](https://github.com/86Box/bios-tools) | x86 BIOS analysis tools | GPL-2.0 |
| `86box/docs/` | [86Box/docs](https://github.com/86Box/docs) | Emulator documentation | No licence file |
| `86box/kbc-probes/` | [86Box/kbc-probes](https://github.com/86Box/kbc-probes) | Keyboard-controller firmware probes | No licence file; contains vendor images |
| `86box/mdsx/` | [86Box/mdsx](https://github.com/86Box/mdsx) | MDS v2 / MDX decryption library | MIT |
| `86box/probing-tools/` | [86Box/probing-tools](https://github.com/86Box/probing-tools) | x86 hardware probing tools | GPL-2.0 |
| `86box/roms/` | [86Box/roms](https://github.com/86Box/roms) | Machine and device ROM images | Preservation notice, see below |

## Rules for using a reference

- An emulator is a **third-party oracle**, not ground truth. Where it
  disagrees with the manufacturer's documents or physical captures, record
  the disagreement and its sources rather than copying the emulator's
  behavior. Cite the submodule commit with any result derived from it.
- Do not copy GPL-licensed code into designs, testbenches or scripts. Read it,
  run it as a separate program, or compare against its output.
- `86box/roms`, `86box/assets` and `86box/kbc-probes` hold firmware images
  owned by their original copyright holders, published upstream "in the
  interest of preservation". Never copy those files into tracked paths. A
  design that needs firmware keeps it in an ignored `work/` directory and
  documents how to obtain it, as `AGENTS.md` requires.

# Intel 80386DX

**First introduced: 1985. Status: work in progress (milestone M1, real-address mode). The shared execution core replays 1,758,671 of 1,758,691 physical-chip real-mode captures; protected mode, paging, virtual-8086 mode and the native 32-bit bus unit are not built yet.**

Intel launched the 80386 in October 1985 as its first 32-bit x86 processor, with about 275,000 transistors. It first shipped as pre-production samples, with volume production from 1986. Secondary sources give 16 or 17 October; Intel's own October 1985 employee newsletter is cited for the 16th. No Intel press release was located to settle the day, so only October 1985 is claimed. Sources: [Centre for Computing History](https://www.computinghistory.org.uk/det/6192/Intel-introduces-the-80386-microprocessor/), [Tom's Hardware on the 386's 40th anniversary](https://www.tomshardware.com/tech-industry/semiconductors/intel-386-at-40), [WikiChip](https://en.wikichip.org/wiki/i386).

**Why it matters.** The 386 brought 32-bit registers and addressing, a flat 4 GB linear address space, demand paging and virtual-8086 mode to the PC architecture. Those are the facilities that 32-bit DOS extenders, Windows/386 and 386 enhanced mode, OS/2 2.x and early PC Unix systems were built on. The original i386 instruction set is also the baseline target of later x86 toolchains. In this program it gates the Compaq Deskpro 386, IBM PS/2 Model 70/80 and the i386 toolchain issue.

**Technical authority:** Intel *80386 Programmer's Reference Manual* (order 230985) and the *Intel386 DX Microprocessor* datasheet. The independent behavioural oracle is [SingleStepTests/80386](https://github.com/SingleStepTests/80386) at revision `459d49fb`: real-mode single-instruction tests captured from a physical Intel 80386EX (KU80C386EX33) on the ArduinoX86 board. The oracle is a different 386 variant from the target; see the limits in the report.

## Contents

- [Specification, interfaces and assumption ledger](spec/spec.md)
- [Implementation plan and milestones](plans/implementation_plan.md)
- [Test plan](plans/testplan.md) and [formal plan](plans/formal_plan.md)
- [Verification report, measured behaviour and open discrepancies](report/final_report.md)
- RTL: [core](src/intel_80386_core.sv), [decoder](src/intel_80386_decode.sv), [divider](src/intel_80386_divider.sv), [ALU/shifter package](src/intel_80386_pkg.sv)
- Replay bench: [tb/tb_replay.cpp](tb/tb_replay.cpp). Capture tooling: [scripts/sst386.py](scripts/sst386.py), [waivers](scripts/sst386_waivers.json), [open discrepancies](scripts/sst386_open.json)
- SX profile, which shares this core: [../intel_80386sx](../intel_80386sx/README.md)

## Running

Run from the repository root:

```sh
sh design/intel_80386/intel_80386dx/scripts/run_all.sh
```

`run_vectors.sh` downloads the pinned capture files once into the ignored `work/` folder. Set `SST386_DIR` to a local clone of the pinned revision to use that instead. Pass file stems (for example `00 6601 0FA4`) to replay a subset. The gate passes only if the failing records are exactly the [listed open discrepancies](scripts/sst386_open.json).

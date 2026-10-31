# IBM AT page-register BIOS checkpoint — 2026-10-29

## Result

Added a digital 16-slot, 8-bit CPU-visible page-register fixture for canonical
ports `80h`–`8Fh`, replacing generic host-port storage in the combined 80286,
8254 and 8237 fixture. Its storage resets to zero as an explicit fixture
assumption; the original BIOS writes the tested registers before reading them.
The DMA-side page mapping, aliases and full 74LS612 pin behavior are not yet
implemented. The [fixture contract](../spec/ibm_at_dma_fixture.md) records the
IBM channel-to-page map and the assumption.

The standalone `scripts/run_at_page_fixture.sh` test passed with Verilator
5.052 `--timing -Wall`, checking all 16 isolated slots, a stalled write, a
stalled read, the map output, and the excluded `90h` alias. The unchanged IBM
AT REV1 BIOS then reached `F000:038A`, after its own timer, DMA register and
page-register tests. Each scenario includes 3,573 page-register reads; the
BIOS tests `81h`–`8Eh` across patterns and `8Fh` separately, branching to HLT
on a mismatch.

| READY policy | Virtual timer half-period | CPU states | Page reads | Result |
| --- | ---: | ---: | ---: | --- |
| Always ready | 3 fixture ticks | 247,196 | 3,573 | BIOS checkpoint and Unicorn CPU comparison pass |
| Periodic stalls | 5 fixture ticks | 1,295,769 | 3,573 | BIOS checkpoint and Unicorn CPU comparison pass |

Unicorn 2.1.4 compares the CPU's CS:IP, defined flags, registers, segments and
data transactions using recorded I/O inputs. It is an independent CPU oracle,
not an independent model of the timer, DMA or page-register device. The two
clock/READY combinations are fixture assumptions, not physical timing evidence.

## Sources and evidence

IBM's 1984 5170 reference, [PDF page 31](https://bitsavers.org/pdf/ibm/pc/at/1502494_PC_AT_Technical_Reference_Mar84.pdf#page=31),
lists the channel/page register mapping and the different 8-bit and 16-bit DMA
address composition. The [TI 1984 data book](https://pestingers.net/pdfs/Electronic-references/texas-instruments/ttl-data-book-vol-1-1984.pdf)
describes the 74LS612's 16-word, 12-bit mapper. The IBM page was visually
reviewed with Playwright CLI; the retained screenshot has SHA-256
`513515CCE2EF53B749753853488B3759E0D5F867DCEE2040D8EF4A7B62E521B6`.

The complete `scripts/run_software.sh` exited 0 in retained container
`codex-intel286-at-page-software-20261029-01`, with build inputs hashed before
and checked after the run. Verilator 5.052, g++ 15.2.0, Python 3.14.4 and
Unicorn 2.1.4 were used. Evidence is under ignored
`work/at_page_software_20261029_03/`:

- `run_software.log`: `120A2F86BFF0C4764E01645A085ABAEC86ADDA543F2549C58180121B8C27FDC7`.
- `at_timer_bios/inputs.sha256`: `AC161D9436179939B59D5E29DEBB6971EC0EBFCB9BF84478695B7F5608223163`.
- `at_timer_bios/build.log`: `F321AD6A30E8F294054C4EC325696AE9BAE4A42E01E117A449CC4CE0742125E8`.
- `at_timer_bios/obj/Vintel_80286_at_fixture`: `0314C047F5CD252940E2C9BAC131773BB713F0A57718553ED57B6C4072FB23DD`.
- `at_timer_bios/trace_wait0_half3.txt`: `CDE99AFC5A0FDEB9249F1C559499868345F746B89C4257080011A783CC91000B`.
- `at_timer_bios/trace_wait1_half5.txt`: `DF74757F65BF4A9444548B850A7DB0655A44A0899E7D42B9ADFB131511C3CAB5`.
- `at_timer_bios/oracle_wait0_half3.log`: `71D8A5E4DBD3BC2AA193B0981199A04F67A1A9309C45D02484818713C25C3A6B`.
- `at_timer_bios/oracle_wait1_half5.log`: `73F71E198D6DE4E25B84E94611C19519709B1EDDA43FE838D7923D34019A0881`.

Standalone evidence is in `work/at_page_fixture_20261029_01/at_page_fixture/`:
`build.log` SHA-256 `3EE403391BB6F3DE6CEB082B378CCFDB2E978ADB79202232872B4DE44C8AA86F`,
`sim.log` SHA-256 `CA97A56B2318004772D961E0B4E12F9CE0B77350FA292EBDF442AE645F8065A4`,
and binary SHA-256 `E8F4B8139D4BD9FC18A11FFAA503BE7CA1B2915883411D44B42F2F25CA0C54F5`.

Run from the repository root in the tool image with a fresh work directory:

```sh
INTEL_80286_WORK_DIR=/work/design/intel_80286/work/new_at_page_run \
  sh design/intel_80286/scripts/run_software.sh
INTEL_80286_WORK_DIR=/work/design/intel_80286/work/new_at_page_unit \
  sh design/intel_80286/scripts/run_at_page_fixture.sh
```

## Remaining work

The page register's DMA-side address output, controller arbitration/cascade,
refresh, interrupts, other POST devices and full POST/boot remain open. The
current-source whole-core PDR is running without a terminal result; no formal
or whole-CPU acceptance is implied by this software checkpoint.
The checkpoint was posted and read back in
[issue comment 6491652810](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6491652810).

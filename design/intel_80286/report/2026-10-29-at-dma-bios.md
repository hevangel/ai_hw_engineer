# IBM AT DMA-register fixture — 2026-10-29

## Complete software entry point

`scripts/run_software.sh` exited 0 in retained container
`codex-intel286-dma-software-20261029-01`. It includes the original checksum,
hex-helper, IRQ8 and system-register regressions, followed by the connected
CPU/8254/two-8237 fixture. The BIOS reaches `F000:0302` after both channel-1
timer bit tests and both DMA-controller address/count register tests. Each
controller performs 64 register reads covering all eight address/count ports.

The always-ready / virtual half-period 3 run matches Unicorn for 197,920
instruction states and data transactions; the periodically stalled / half-period
5 run matches 1,246,493. The timer and DMA input bytes are recorded from the
fixture and supplied to Unicorn, so this is independent CPU execution with
the same inputs, not an independent proof of either peripheral. The original
BIOS itself checks the DMA register patterns and branches to an error HLT on
mismatch. No DMA transfer, arbitration, refresh, full POST or physical timing
claim follows from this bounded run.

The pinned ROM and the exact build inputs were hashed before and verified
after the run. Evidence is in ignored `work/at_dma_software_20261029_02/`:

- `run_software.log`: `5C05F41D202061ED8462A8D5C272904090AE8B9792F6D120230C8E57D5300221`.
- `at_timer_bios/inputs.sha256`: `746C44B76D0FACC752928D8D8E8FAD82F6245096E7AF5327AEEF0F6100734CF9`.
- `at_timer_bios/build.log`: `3BE96DB61F43F7191391FDCCEAA3FF266144FC7478D49D646F80F897E55A7123`.
- `at_timer_bios/obj/Vintel_80286_at_fixture`: `7FEF015233FA71AC4D17864A10D8A9CAE79BA579A518591820D0800A2EBD49F6`.
- `at_timer_bios/trace_wait0_half3.txt`: `E531C1AF48003E03B6CDBE52FD7064A8759CB447A836E4FE91571EF9D83A8E25`.
- `at_timer_bios/trace_wait1_half5.txt`: `5FAE7DD81C0B9F37B9E87DFA7A7F286A58C01BE8D6357C02DA6FE09C055F1009`.
- `at_timer_bios/oracle_wait0_half3.log`: `5A9D8D66FC800D77AE28EBE6A275859E8BBB5CA028DD9E426A399C9C574A286A`.
- `at_timer_bios/oracle_wait1_half5.log`: `375FF6E9AE42E28E605B9EF3A93AAA98EED669413743BD4735BF4EADEC5D53EB`.

Reproduce in the tool image with a fresh work directory:

```sh
INTEL_80286_WORK_DIR=/work/design/intel_80286/work/at_dma_software_20261029_02 \
  sh design/intel_80286/scripts/run_software.sh
```

The 8237/8254 RTL and all fixture, runner and oracle inputs are bound by the
manifest. The CPU core RTL was not changed by this fixture work.
The checkpoint was posted and read back in
[issue comment 6491502332](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6491502332).

## Recovered independent comparison

Docker's original `dcd30140a9c0` container was absent after the engine
returned. The stalled trace and its build input manifest were retained; a new
container checked the manifest before and after replay and checked the trace
hash. The saved 1,246,493-instruction trace now passes the Unicorn CPU-state
and data-transaction comparison with 131,086 recorded timer reads. The
always-ready 197,920-instruction comparison had already passed. The complete
software entry point was then rerun in retained container
`codex-intel286-dma-software-20261029-01` and exited 0 as recorded above.

Evidence in `work/at_dma_bios_20261029_01/at_timer_bios/`:

- `inputs.sha256`: `59C2C3F28AA723316787B89154A3700E810090D17B29A6A187702336692E9CC8`.
- `trace_wait0_half3.txt`: `E531C1AF48003E03B6CDBE52FD7064A8759CB447A836E4FE91571EF9D83A8E25`.
- `trace_wait1_half5.txt`: `5FAE7DD81C0B9F37B9E87DFA7A7F286A58C01BE8D6357C02DA6FE09C055F1009`.
- `oracle_wait0_half3.log`: `5A9D8D66FC800D77AE28EBE6A275859E8BBB5CA028DD9E426A399C9C574A286A`.
- `oracle_wait1_half5_recovered.log`: `375FF6E9AE42E28E605B9EF3A93AAA98EED669413743BD4735BF4EADEC5D53EB`.

The two Playwright CLI screenshots are retained in ignored
`work/at_dma_source_20261029_01/`: page 30 SHA-256
`F1FD05250E7C4DA2FAE16347EF5574D0FB411BF058582E5660771B52EE9DD9D5`,
page 32 `0FE4FA36B172CC928D96B0D1F7580B27940071ED62C35789A7C26322FFA9AAF3`.

The 1984 IBM 5170 technical reference, PDF pages 30 and 32, identifies two
8237A-5 controllers and maps controller 2 registers to the even ports
`C0h`–`DEh`. The source was visually reviewed with Playwright CLI:
[IBM technical reference](https://bitsavers.org/pdf/ibm/pc/at/1502494_PC_AT_Technical_Reference_Mar84.pdf#page=30).

`intel_80286_at_dma.sv` connects the repository's 8237 RTL to canonical
controller-1 ports `00h`–`0Fh` and controller-2 even ports `C0h`–`DEh`. It
qualifies register strobes with accepted READY transactions. DMA requests and
HLDA are tied inactive: this is a register fixture, not DMA bus mastering,
cascade, refresh or a complete IBM AT platform.

The unchanged BIOS reached `F000:0302` after the two timer tests and both DMA
register pattern tests in two virtual-clock/READY scenarios. The always-ready
scenario retired 197,920 instructions and independently matched Unicorn on
every captured instruction state and data transaction. The periodically
stalled scenario reached the same checkpoint after 1,246,493 instructions;
its initial independent comparison did not produce an observed terminal result
when the Docker engine became unavailable. The saved trace was subsequently
verified as described above.

Evidence directory: `work/at_dma_bios_20261029_01/at_timer_bios/`. On resume,
the retained software container has exit code 0. The earlier PDR container is
absent, without a terminal proof result; a fresh current-source PDR is running
as recorded in the formal plan. Full POST/boot,
independent timer/DMA fidelity, physical timing and whole-CPU acceptance remain
open.

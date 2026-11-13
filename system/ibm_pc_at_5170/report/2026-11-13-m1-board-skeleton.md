# M1 board skeleton — 2026-11-13

## Result

The unchanged IBM AT REV1 BIOS runs on the new system board for 30
instructions and stops at `F000:00DE`, its first read of the 8042 keyboard
controller's status register (port `64h`). Every one of the 30 instructions
matches Unicorn. Both clock scenarios stop at the same point.

```text
STOP kind=io-read port=0064 at=F000:00DE post=00 retired=30 cycles=361 rom_writes=0 wait=0 half=8
PASS: 30 instruction states and data transfers match Unicorn up to F000:00DE; 0 data transfers in the unfinished instruction
STOP kind=io-read port=0064 at=F000:00DE post=00 retired=30 cycles=474 rom_writes=0 wait=1 half=11
PASS: 30 instruction states and data transfers match Unicorn up to F000:00DE; 0 data transfers in the unfinished instruction
```

This is short of the 286 design's AT fixture, which reaches `F000:03A2`
(about 247,000 instructions). The difference is deliberate; see below.

## What was built

- `src/ibm_pc_at_5170.sv`: the board top. It composes the native 286 with
  the 286 design's schematic-cited AT models, reused in place from
  `design/intel_80286/tb/`: the 8254 timer, port 61h, the refresh request
  path, two 8237 register interfaces, the 74LS612 page registers with the
  refresh page map, and the RAS trigger. Memory is external. The top
  reports any I/O cycle no device claims (`io_unclaimed_o`) and any selected
  device that fails to drive a read (`io_read_undriven_o`). It records the
  port 80h checkpoint byte (`post_code_o`).
- `tb/post_runner.cpp`: supplies 640K RAM and the 64K ROM at `F0000h` and
  `FF0000h`, and stops at the first unmodeled I/O port, the first memory
  access outside RAM and ROM, or a halt, shutdown or bus error.
- `scripts/run_post.sh`: lint, build, two clock scenarios, the stop check
  against `scripts/expected_stop.txt`, and Unicorn replay.
- `scripts/run_synth.sh`: Yosys synthesis of the board top.
- `design/intel_80286/scripts/bios_replay.py`: the Unicorn comparison loop,
  moved out of `check_at_timer_bios.py` so the system and the 286 fixtures
  share one copy. The 286 checker now only adds its checkpoints.

## Finding: the 8042 is the first board dependency

At `F000:00DE` the BIOS reads port `64h` and tests bit 2, the 8042 system
flag, to choose between a cold boot and a restart from protected mode (the
restart path then reads the CMOS shutdown byte at port `71h`). The 286
fixture answers every unmodeled port from a zero-initialised array, so it
takes the cold-boot path without any 8042. Zero is the right cold-boot
answer, but no device produced it. The fixture's spec now records this as an
assumption.

The BIOS meets the 8042 again right after the refresh test: at
`F000:03A2`–`0422` it sends the self-test command (`AAh`, expects `55h`),
reads the input port (`C0h`) and writes the command byte (`60h`, `5Dh`).
So the plan's old order (interrupt controllers before the 8042) was wrong.
The 8042 is now milestone M2, and decision D3 (MCS-48 core with IBM's
firmware, or a behavioral model) blocks it.

## Regression of the 286 fixtures after the replay refactor

| Run | Result |
|---|---|
| `design/intel_80286/scripts/run_at_bios_native.sh` | PASS, 247,306 and 247,355 instructions match Unicorn through `F000:03A2` |
| `design/intel_80286/scripts/run_at_timer_bios.sh` | PASS, 247,196 and 1,295,769 instructions match Unicorn through `F000:038A` |

## Synthesis

`scripts/run_synth.sh` passes: Yosys `synth` plus `check -assert` with 0
problems, 76,442 generic cells for the whole board, 691 s. The one warning
worth noting is the latch in `intel_80286_at_refresh_arbiter`; it is
intentional and models the schematic's U69/U121 gate-feedback hold.
Strict Verilator lint (`-Wall`) of the board top is clean.

## Commands

Tool image `ai-hw-engineer:latest`, Verilator 5.052, Unicorn 2.1.4.

```sh
ROM=$(sh system/ibm_pc_at_5170/scripts/get_bios.sh)
sh system/ibm_pc_at_5170/scripts/run_all.sh "$ROM"
```

The BIOS SHA-256 is
`74e7b36b4ec0adc5ac3277a887579996c1d2aa755b9892ef3afe7485c10ce04f`.

## Limits

- Virtual clocks (AT1). No DMA requests (AT4). RAM starts at zero (AT6).
- No 8042, 8259, CMOS, video or disk. The 8259 designs exist but are not
  wired, because no BIOS code reached so far uses them and wiring them now
  would be untested.
- Unicorn checks the CPU, not the devices: device inputs come from the
  trace.

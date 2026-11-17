# M4a: I/O channel and EGA — 2026-11-16

## Result

With an I/O channel and an IBM Enhanced Graphics Adapter in a slot, the
unchanged IBM AT REV1 BIOS (01/10/84) and the card's own BIOS (IBM ROM
6277356 at C0000h) run 18,201,512 instructions of power-on self-test and
stop at `F000:1454`, after the BIOS's first read of port 1F7h (fixed-disk
status) at POST checkpoint 3Ch. That is the same instruction at which the
board without a card stops, so the boundary has not moved. What changed is
that the machine now has a display: the last video frame is 640 x 350 and
reads `00640 KB OK`, ` 301-Keyboard Error`, ` 601-Diskette Error`. Both
errors are correct for this configuration, because no keyboard is plugged
in and no diskette adapter is modeled. Nothing boots.

| Check | Command | Result |
|---|---|---|
| Lint | `scripts/run_post_ega.sh` (first step) | Clean, `verilator --lint-only -Wall` on `ibm_pc_at_5170_ega` |
| Stop point | `scripts/run_post_ega.sh` | `kind=stop-at after=F1453 at=F000:1454 post=3C`; 18,201,512 instructions, 279,013,645 processor clocks, 3 CPU resets, 14 interrupt-acknowledge cycles (7 timer interrupts) |
| Channel activity | `scripts/run_post_ega.sh` | 1,321 channel I/O writes, 4 channel I/O reads nobody answered, 1,270,314 channel memory writes, 648 video frames |
| Screen | `scripts/check_frame.py` via `scripts/run_post_ega.sh` | Pass: the last frame decodes, with the 8 x 14 font found in the EGA ROM, to the three rows in `tb/expected_screen_ega.txt` |
| 8042 against the UPI-42 reference model | `scripts/run_post_ega.sh` | 9,987,012 instructions, 19 host writes, 6 data reads and 1,648,622 CPU read values identical |
| MC146818 against its reference model | `scripts/run_post_ega.sh` | 64,931 address strobes, 23 writes and 64,906 CPU read values identical over 46.5 s of clock time |
| 80286 against Unicorn | `scripts/run_post_ega.sh` | 18,201,512 instruction states and data transfers match, in the system BIOS and in the EGA BIOS; 13 of 13 BIOS checkpoints |
| Bare board, unchanged | `scripts/run_post.sh` | Stops at `kind=io-read port=01F7 at=F000:1453 post=3C`; 16,688,169 and 16,586,155 instructions match Unicorn; 8042 and MC146818 match their models |
| Synthesis, board | `scripts/run_synth.sh` | 86,864 generic cells (87,161 in M3; the unanswered-I/O read path no longer forces 0) |
| Synthesis, EGA machine | `scripts/run_synth.sh` | `ibm_pc_at_5170_ega`: 94,169 generic cells with the card's plane RAMs and ROM as black boxes; `check -assert` clean; the only latch is the refresh arbiter's schematic latch |

The clean run of 2026-11-16 in the `ai-hw-engineer` image took about 15
minutes of simulation and screen and device checks, plus about 20 minutes
for the Unicorn replay.

## What was added

- **Board output `mem_cycle_o`** (`src/ibm_pc_at_5170.sv`). An I/O read
  that no board device answers now takes its data from the host or the
  channel instead of reading 0. The bare-board regression is unchanged in
  behavior and result.
- **`src/at_io_channel.sv`.** 8-bit I/O channel cycles for expansion
  cards (ASSUMPTION AT18). The channel owns memory A0000h-DFFFFh and
  unanswered I/O at 100h and above. A word memory access is two byte
  cycles, low byte first; each byte cycle is one clock of address setup,
  four clocks of command and one clock of hold. A byte no card drives
  reads FFh (AT14).
- **`src/ibm_pc_at_5170_ega.sv`.** The machine top: the unchanged board,
  the channel, and the IBM EGA card from [`design/ibm_ega`](../../../design/ibm_ega/)
  (256 KB, IBM ROM 6277356 at C0000h). The card's IRQ2 goes to the board's
  IRQ 9, which is the channel's IRQ 2 pin on the AT. The clock arrangement
  is ASSUMPTION AT19 (below).
- **Card configuration in the bench** (`tb/ibm_pc_at_5170_ega_tb.sv`):
  switches SW1 off, SW2 on, SW3 on, SW4 off, which is the Enhanced Color
  Display as primary display in 350-line mode. The CMOS image
  `tb/cmos_ega.hex` has equipment byte 01h (display with its own BIOS) and
  checksum 00A3h.
- **Runner** (`tb/post_runner.cpp`). Built with `-DAT_EGA` it drives the
  EGA machine, rebuilds the picture from the card's monitor connector
  (active area only; one pixel per pixel enable while display enable is
  active, a new line at each horizontal sync, a new frame at each vertical
  sync) and writes the last complete frame. New options: `--stop-at`,
  `--stop-post`, `--max-cycles`, `--frame` and `--empty-slots`.
- **`scripts/run_post_ega.sh`**, `scripts/expected_stop_ega.txt`,
  `tb/expected_screen_ega.txt`, `scripts/check_frame.py`, and the
  EGA machine's synthesis in `scripts/run_synth.sh`.

## How the new parts are checked

- **Screen.** `scripts/check_frame.py` reads the text on the captured
  frame. Every 8 x 14 character cell must be one glyph of the font in IBM's
  EGA ROM, in two colors (one cell may carry the cursor), and the decoded
  rows must equal `tb/expected_screen_ega.txt`. This checks the display
  path (BIOS character writes, video memory, font, attribute and timing
  logic) against the ROM's own font, not against the card model. It is a
  check of one frame.
- **80286.** The Unicorn replay covers both BIOSes. The EGA ROM is mapped
  into the oracle. Reads of video memory are device inputs taken from the
  trace in the CPU's order; writes to it are not applied in the oracle.
  Followed in the run: 7 hardware interrupts, 146 software interrupts, 3
  resets and 4 exceptions. Taken from the trace: 787,512 device-memory or
  open-bus read bytes; 1,270,123 writes to unpopulated or device memory;
  209 writes to ROM addresses. Not judged, because Unicorn models a later
  CPU: 1,187 accessed-bit writes, the undefined AF bit in 2 pushed flag
  images, MSW bits (3 times) and the SGDT/SIDT sixth byte (6 times).
- **8042 and MC146818.** As in M3, replayed into the UPI-42 model and the
  MC146818 model; see the table.
- **8259s.** Still checked only by the BIOS's own tests and by the vectors
  and in-service values seen.

## The EGA BIOS's own self-test

The EGA BIOS runs a power-on self-test of its own, and it passes on this
machine: switch sense reads 9; the sync timing test sees 350
display-enable pulses per frame and a vertical period within its timer
bounds; the colour-dot test through Input Status 1 passes; the memory test
finds 256 KB (BIOS INFO byte 60h); then it sets mode 3. Two things went
wrong on the way, and both were found only because the real ROM was run.

- **An escaped defect in the card.** Attribute-controller writes at port
  3C1 were not decoded, and the EGA BIOS's dot test failed with error code
  10h. The BIOS writes the attribute index to 3C0 and the data to 3C1; the
  card took the 3C1 writes as dropped, so its index/data flip-flop went out
  of step and the screen was forced to the overscan colour. The card was
  fixed (reads of 3C1 stay undecoded) and a post-mortem written:
  [failure note](../../../failure_notes/2026-11-16-ibm-ega-attribute-3c1.md).
  The card's own suite missed it because its model and RTL shared the
  assumption and its BIOS replay skipped the POST self-tests.
- **Clock ratio.** Before the AT19 clock arrangement, the EGA BIOS's sync
  test failed, counting 224 of 350 display-enable pulses per frame. The
  80286 model is not cycle accurate: this BIOS needs about 17 clocks per
  instruction, and a real 80286 needs about a quarter of that. The test
  counts the pulses by polling Input Status 1, so at the real ratio of
  video to processor clock the model polled too slowly and miscounted.
  Under AT19 the card's clock runs at the processor clock's rate and
  stands for 24 MHz; the channel's 14.31818 MHz OSC, the card's 16.257 MHz
  crystal and the 8254 clock (OSC / 12) are derived from it, so video and
  the timer keep their real ratio to each other. The processor is
  therefore four times faster relative to them than the real 6 MHz. The
  8042 and the MC146818 keep the board's processor-clock ratios (AT1), so
  they run four times fast relative to video. This is a modeling choice,
  not IBM AT timing.

## Exploratory runs, not part of the regression

- A longer run of the EGA machine (3,000,000,000 processor clocks,
  212,970,955 instructions) reaches POST checkpoint 3Fh. The screen then
  also shows `(RESUME = "F1" KEY)` and the BIOS waits for the F1 key. No
  keyboard device exists to press it.
- With no card at all and empty slots readable (`--empty-slots`), the bare
  board also reaches checkpoint 3Fh.

Neither run is checked against the oracles and neither is in
`run_post_ega.sh` or `run_all.sh`.

## Limits

- Channel timing is not the real board's (AT18); no card stretches a cycle
  and I/O CH RDY is not used.
- The time base is virtual (AT19). The 8042 and the MC146818 run four
  times fast relative to video.
- One scenario for the EGA machine: no added wait states. The bare board
  still has its two scenarios.
- No keyboard device, no diskette adapter and no fixed-disk adapter, so
  POST ends in errors and the run stops at the fixed-disk probe. Nothing
  boots.
- The 8259s have no independent model.
- Unicorn does not check segment limits or rights on accesses that do not
  fault.
- The display is checked as the text of one frame, not continuously.
- 200-line modes on the direct-drive connector are not converted; the
  frame colors assume the 350-line 64-colour interpretation.
- No whole-machine comparison with an independent emulator.
- The 80287 is not fitted, NMI is not connected, and the other M3 limits
  stand.

## Reproduce

```sh
ROM=$(sh system/ibm_pc_at_5170/scripts/get_bios.sh)
sh system/ibm_pc_at_5170/scripts/run_post_ega.sh "$ROM"
sh system/ibm_pc_at_5170/scripts/run_synth.sh
```

`run_post_ega.sh` fetches and hash-checks the EGA ROM with
`design/ibm_ega/scripts/get_rom.py` into the ignored `work/` folder and
writes the frame to `work/post_ega/frame.ppm` and `frame.png`. The bare
board regression is `scripts/run_post.sh`; `scripts/run_all.sh` runs that
and the synthesis but does not run `run_post_ega.sh`.

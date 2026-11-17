# Web front end, batch host and AT keyboard — 2026-11-17

## Result

The VGA machine (`src/ibm_pc_at_5170_vga.sv`, unchanged) now has a web and
batch host and a keyboard on its keyboard connector. With the keyboard
model attached, the unchanged BIOS completes its keyboard tests against
the real 8042 running IBM's firmware 1503033: the screen no longer shows
` 301-Keyboard Error`, only the diskette error, and the BIOS reaches its
`(RESUME = "F1" KEY)` prompt after about 210 million processor clocks.
F1 typed through the keyboard model reaches the BIOS (the processor reads
3Bh and BBh at port 60h, the 8042's set 1 translation of the keyboard's
05h, F0h 05h) and POST goes on to checkpoint 40h. There it stops: the
BIOS's 80287 probe (`FNINIT`) makes the 80286 write coprocessor port
0F8h, which no board device decodes, so the machine stops as the POST
runner would (see "Board finding" below). Nothing boots.

No board or card RTL, `tb/post_runner.cpp`, `tb/*_tb.sv`,
`scripts/run_post*.sh` or `scripts/sources.sh` was changed, so the
existing regressions' inputs are unchanged; they were not rerun.

| Check | Command | Result |
|---|---|---|
| Keyboard against the real 8042 and BIOS | `scripts/run_keyboard_test.sh "$ROM"` | Pass (579 s wall): reset handshake, screen without 301, F1 delivered and POST resumed; run ends at the expected 80287-probe stop |
| Screen at the F1 prompt | same (`check_frame.py` with the VGA ROM's font) | `00640 KB OK` / ` 601-Diskette Error` / ` (RESUME = "F1" KEY)`, equal to `scripts/expected_screen_keyboard.txt`; no 301 |
| Waveform capture leaves the machine unchanged | `python3 scripts/test_capture.py SIM BIOS VGA_ROM DIR` | Pass: CAPTURE of 1,024, 4,096 and 65,536 clocks gives the same state as RUN (CPU, counters, keyboard, BIOS data area) |
| Speed | batch runs below | 425,000-440,000 processor clocks per second alone (1.8 % of real time on the AT19 time base); about 370,000 with two simulations running |
| Web page in a real browser | headless Chrome on the host, see README | SCREENSHOT_RESULT |

All runs were made on 2026-11-16/17 (host clock) in container
`claude-at-web` from image `ai-hw-engineer:latest` (Verilator 5.052).

## What was added

- `host/ibm_pc_at_5170_vga_host.sv`: the simulator top. It instantiates
  the VGA machine unchanged and adds read-only taps (retirement, CS, IP,
  flags, the CPU's read data, 8042 port 2). Built with `--trace-depth 1`,
  its ports and taps are exactly the signals a waveform capture records.
- `host/simulator.cpp`: persistent simulator. The clocking is the body of
  `post_runner.cpp`'s loop for the VGA build, with the same evaluation
  order, memory map, open-bus rules and readable empty slots, without the
  trace and logs. Commands: `STATE`, `RUN n`, `RESET` (power-on: a fresh
  model and context, RAM cleared, keyboard power-on), `KEY code make`,
  `TYPE keys`, `FRAME` (PNG, base64), `TEXT` (screen read with the VGA
  ROM's font), `PPM path`, `PEEK addr len`, `CAPTURE n` (FST), `QUIT`.
  Batch mode (`--batch=N --out=DIR`) writes status, the latest frame,
  changed frames and screen text every `--save-every` clocks; key scripts
  (`--script`, rules `at`, `wait`, `when "TEXT"`); `--ext-kb=N` adds
  expansion RAM from 100000h (1408 for 2 MB). A marked `AT_DISKETTE`
  integration point includes `tb/at_diskette_media.hpp`, calls its
  per-clock DMA service and passes `--fda`/`--fdb` for the diskette branch.
- `host/at_keyboard.hpp`: the 84-key AT keyboard (header-only). Protocol,
  commands and timing in the specification's "Keyboard" section;
  assumptions AT20-AT24.
- `host/server.py`, `host/web/`: the page (monitor, power/reset/run/pause,
  status and speed, keyboard capture and buttons, Surfer waveform, batch
  progress and replay). No external resources; Surfer is served from the
  image's `/opt/surfer/webapp`.
- Scripts: `build_host.sh`, `run_web.sh`, `run_batch.sh`,
  `run_keyboard_test.sh`, `test_capture.py`,
  `expected_screen_keyboard.txt`.

## Speed

| Run | Clocks | Wall time | Clocks per second |
|---|---|---|---|
| Batch to 240,000,000 clocks (alone, keyboard attached, F1 prompt reached) | 240,000,000 | 556 s | 431,600 |
| Interactive `RUN`, first 20,000,000 clocks | 20,000,000 | 45 s | 446,000 |
| Same, generated C++ at `-O2` instead of Verilator's `-Os` | 20,000,000 | 44 s | 456,000 |
| `--threads 4` | under 10,000,000 in 210 s | — | well under 50,000; rejected |

POST averages 14.3 processor clocks per instruction (16,806,927
instructions in 240,000,000 clocks), so about 30,000 instructions per
second (16.8 million in 556 s). The three combinational `eval()` calls per clock
cost about 1.5 % (measured by dropping one and comparing state); the
four clock-edge evaluations of the board and the card dominate.
Real-time fraction on the AT19 time base (processor clock = 24 MHz):
1.8 %. Without a keyboard, the exploratory EGA run needed about 3 billion
clocks to reach the F1 prompt (the BIOS waits out its keyboard timeouts);
with the keyboard the prompt comes at 210 million clocks, about
8 minutes.

## Keyboard test evidence

`sh system/ibm_pc_at_5170/scripts/run_keyboard_test.sh system/ibm_pc_at_5170/work/software/atbios.bin`
in the container, output (after the build lines):

```
== run: press F1 at the BIOS prompt (at most 1,000,000,000 clocks)
wall time 579 s; batch: 216627973 clocks, 15054033 instructions, post 40, 374117 clocks/s, stopped: io-write port=00F8 at=F000:15EF
machine stopped as expected after F1: io-write port=00F8 at=F000:15EF
script: ['clock 210000000: line 1 keys F1']
keyboard received: FF
keyboard sent:     AA FA AA 05 F0 05
port 60h, last values read: 55 FF AA AA 02 FA AA 3B BB
== check 1: keyboard reset handshake
PASS: received FF; sent AA (power-on BAT), FA, AA
== check 2: screen at the F1 prompt
PASS: 720 x 400 frame reads as 80 x 25 text of the 8 x 16 font in the adapter ROM and equals the expected screen (4 rows): 00640 KB OK / 601-Diskette Error / (RESUME = "F1" KEY)
== check 3: F1 typed through the keyboard and the 8042
screen after F1:
POST checkpoint after F1: 40
PASS: keyboard reset handshake, no 301-Keyboard Error, F1 resumes the BIOS
```

Reading the evidence: the keyboard's power-on BAT code AAh waited
while the 8042 held the clock low and was read by the BIOS (port 60h
AAh); the BIOS then sent Reset (FFh) through the 8042, the keyboard
acknowledged (FAh) and completed its BAT (AAh), which the BIOS read at
port 60h. The stuck-key check found nothing, so no 301 line. At the F1
prompt the script pressed and released F1; the keyboard sent 05h, F0h
05h; the 8042 translated them (command byte XLAT) and the processor read
3Bh and BBh, the set 1 make and break of F1. The BIOS cleared the screen
(blank after F1) and moved from checkpoint 3Fh to 40h. The screen after
F1 is blank in the saved frame.

The earlier run of the same test (before the context fix below) gave the
same keyboard and port 60h values (wall 582 s).

## Board finding: coprocessor port 0F8h

After F1 the BIOS reaches checkpoint 40h and probes for an 80287 with
`FNINIT` / `FNSTSW` (Technical Reference listing near "IS THE 287
INSTALLED?"). The 80286 model runs the coprocessor transfer as an I/O
write to 00F8h. The board decodes only F0h and F1h of the coprocessor
range (AT17), so the write is an unclaimed I/O cycle below 100h, which
the strict decoding rule turns into a stop (`io-write port=00F8 at=
F000:15EF`). On a real AT with no 80287 the cycle reaches no device, and
the BIOS's status-word read sees an undriven bus and decides there is no
coprocessor. Deciding how the board treats 0F8h-0FFh without an 80287 (an
assumption like AT14, or a board decode change) belongs to the board's
owner; this branch does not change board RTL or the strict rule. Until
then, neither the web front end nor a batch run gets past checkpoint 40h.

## Limits

- Time base is virtual (AT19, AT20): the keyboard and the 8042 run four
  times fast relative to video and the timer.
- Slow: about 1.8 % of real time; long boots need batch runs; no
  save/restore checkpoints.
- Stops at the 80287 probe (above). No diskette adapter, fixed-disk
  adapter or 80287; nothing boots.
- Keyboard: no scan time, debounce or sense-amplifier diagnostics (AT23);
  typematic and LED commands are implemented from the 8048 listing and
  the Technical Reference but were not exercised by the BIOS run before
  the stop, and have no independent oracle. The POST runner does not yet
  attach the keyboard, so its expected screen still has the 301 line.
- Expansion RAM is host memory standing for a memory card; the CMOS image
  still says 640 KB.
- Waveform time axis: 41.67 ns per processor clock (AT19), not physical.

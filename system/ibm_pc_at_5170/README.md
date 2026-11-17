# IBM PC AT 5170

Milestone M4b part 1: the board has the 80286, timer, DMA and page registers,
refresh logic, the 8042 keyboard controller running IBM's own firmware, the
MC146818 clock, two 8259A interrupt controllers, the math-coprocessor ports
and the shutdown-to-reset path. A second machine top adds an I/O channel and
an IBM Enhanced Graphics Adapter (EGA) in an expansion slot. The unchanged
IBM BIOS and the card's own BIOS run about 18.2 million instructions of the
power-on self-test: both interrupt controllers are set up, memory is tested
in protected mode, the processor is reset through the 8042 three times, and
seven timer interrupts are taken. The EGA BIOS's own self-test passes and
its display shows `00640 KB OK`, ` 301-Keyboard Error` and
` 601-Diskette Error`; both errors are correct, because no keyboard is
plugged in and no diskette adapter is modeled. The run stops at POST
checkpoint 3Ch on the BIOS's first read of port 1F7h, the fixed-disk status
register; no fixed-disk adapter is fitted. The board alone, without a
card, stops at the same read. Nothing boots.

A third machine top puts the IBM PS/2 Display Adapter (VGA) in the slot
instead of the EGA. The same BIOS and the card's BIOS run 16,294,929
instructions to the same stop, and the 720 x 400 display shows the same
three lines. The VGA BIOS sets its 80-column text mode (inferred from the
screen); graphics modes and the DAC are not exercised by this run.

The IBM Personal Computer AT (model 5170) was IBM's first 80286 machine. It
added a 16-bit expansion bus, 24-bit addressing (16 MB), a second interrupt
controller and DMA controller, an 8042 keyboard controller and a
battery-backed MC146818 clock with CMOS setup memory. These became the
"AT-compatible" base that later PCs followed. IBM's
[personal computer history](https://www.ibm.com/history/personal-computer)
dates it to August 1984; the exact day is not yet confirmed from an IBM
source. IBM's announcement letter for the EGA is dated 10 September 1984; see the
[EGA design](../../design/ibm_ega/) for sources.

This system runs the unchanged IBM AT REV1 BIOS (1984-01-10) on the
repository's [`intel_80286`](../../design/intel_80286/) RTL. The goal is to
boot PC DOS and then Microsoft OS/2 1.0.

Important chips: Intel 80286, 8254 timer, two 8259A interrupt controllers,
two 8237A DMA controllers (register interface), 74LS612 page registers,
8042 keyboard controller with IBM firmware 1503033, Motorola MC146818 clock
and the IBM EGA (five custom LSI devices, 256 KB display memory, IBM ROM
6277356) in the EGA machine, or the IBM PS/2 Display Adapter (VGA; 256 KB,
DAC, 24 KB adapter BIOS) in the VGA machine.

## Web interface and waveform

WEB_SCREENSHOT_PLACEHOLDER

The page (`host/web/`, served by `host/server.py`) drives the VGA machine
through a persistent Verilator simulator (`host/simulator.cpp`):

- **Monitor.** The picture is rebuilt from the card's analog monitor
  connector (DAC codes scaled to 8 bits per gun, active area only) and
  shown at a 4:3 aspect ratio; it refreshes whenever a new frame has been
  completed.
- **Controls and status.** Power (a fresh model: power-on reset, RAM
  cleared, keyboard power-on), Reset (the same), Run and Pause. Status
  shows the POST checkpoint (port 80h), CS:IP, processor clocks,
  instructions, frames, the measured speed in processor clocks per second
  and as a fraction of real time on the AT19 time base (the processor
  clock stands for 24 MHz), and the machine time. A stop of the kind
  that ends the regression (for example an unclaimed I/O read below 100h)
  is shown and stops the machine.
- **Keyboard.** Click the display and type: browser key events are mapped
  to the 84-key AT keyboard's scan code set 2 (the table and its choices
  are at the top of `host/web/app.js`; cursor and editing keys use the
  numeric-keypad keys that carry them on the AT keyboard, F11/F12 have no
  AT key) and enter the keyboard model as key down and key up; browser
  auto-repeat is ignored because the model repeats on its own. Losing
  focus releases the held keys. Buttons send F1, Esc, Enter and
  Ctrl-Alt-Del. The Num, Caps and Scroll Lock lamps show what the BIOS set
  with command EDh.
- **Waveform.** Capture records the next 1,024 to 262,144 processor clocks
  to FST and opens it in the self-hosted Surfer (`/surfer/`, from the
  image). Presets: processor bus (clock, reset, CS, IP, retirement,
  address, cycle type, data both ways, I/O port, channel select, INTR and
  INTA, refresh, POST code), keyboard lines (both drivers and line levels,
  8042 port 2, OBF, port 60h reads) and video (video clock, pixel enable,
  syncs, display enable, DAC codes). Every signal of
  `host/ibm_pc_at_5170_vga_host.sv` is in the file. The time axis uses
  41.67 ns per processor clock (AT19). Capturing pauses the machine.
- **Batch run.** With `--batch-dir`, the page shows a batch run's live
  status and latest frame and steps or plays through its saved frames.

The POST regressions also save single frames, which are not the panel. The
image below is the last video frame of the EGA machine at the stop point (POST checkpoint 3Ch), captured in simulation
from the card's monitor connector (active area only, 640 x 350) and
written by `scripts/run_post_ega.sh` as `work/post_ega/frame.png`:

![Last video frame of the IBM PC AT 5170 with an EGA at POST checkpoint 3Ch](assets/post-ega-frame.png)

Reproduce it with `sh system/ibm_pc_at_5170/scripts/run_post_ega.sh "$ROM"`
(see Run). The three rows of text are checked by the script against the
ROM's own font; the frame is one picture, not a recording.

The next image is the same kind of frame from the VGA machine at the same
stop, captured from the card's analog monitor connector (the DAC's 6-bit
codes scaled to 8 bits per gun; 720 x 400) and written by
`scripts/run_post_vga.sh` as `work/post_vga/frame.png`:

![Last video frame of the IBM PC AT 5170 with a VGA card at POST checkpoint 3Ch](assets/post-vga-frame.png)

Reproduce it with `sh system/ibm_pc_at_5170/scripts/run_post_vga.sh "$ROM"`
(see Run). The three rows of text are checked by the script against the
VGA ROM's own font; again one picture, not a recording.

## Run

### Web front end

From the repository root on the Docker host (the Docker image
`ai-hw-engineer:latest`; publish the port):

```sh
docker run --rm -it -p 8286:8286 -v "$PWD":/work -w /work ai-hw-engineer:latest \
    sh system/ibm_pc_at_5170/scripts/run_web.sh system/ibm_pc_at_5170/work/software/atbios.bin 8286
```

then open http://localhost:8286/. `run_web.sh BIOS [PORT] [--ext-kb N]
[--batch-dir DIR] [--script FILE]` checks the BIOS's SHA-256, rebuilds and
hash-checks the 8042 firmware, fetches and hash-checks the VGA ROM (as
`run_post_card.sh` does), builds the simulator with `scripts/build_host.sh`
(about 1.5 minutes) and starts the server. The page starts with the
machine off; **Power on** starts it running. The BIOS image is obtained with
`scripts/get_bios.sh` (see below) and never committed.

The simulation is slow: about 450,000 processor clocks per second, 1.9 %
of real time on the AT19 time base. The memory count appears after about
1 minute, the POST error lines after about 9 minutes, and the BIOS's F1
prompt after about 2 hours (about 3 billion processor clocks).

### Batch runs and scripted keys

```sh
sh system/ibm_pc_at_5170/scripts/run_batch.sh BIOS CLOCKS OUT_DIR \
    [--ext-kb=N] [--script=FILE] [--save-every=N] [--until-script]
```

runs CLOCKS processor clocks with no browser. Every `--save-every` clocks
(default 50,000,000) it writes `OUT_DIR/status.json`, `latest.png` and
`screen.txt` (the screen read with the VGA ROM's font), adds the frame to
`OUT_DIR/frames/` when it changed (listed in `frames.json`), and at the end
writes `frame.ppm` for `scripts/check_frame.py`. Watch it, or replay it
later, with `run_web.sh BIOS 8286 --batch-dir OUT_DIR`.

A key script has one rule per line; the rules fire in order, each armed
when the previous one has fired, and the batch saves a frame when a rule
fires:

```
# comment
at 3000000000 F1                # at processor clock N
when "RESUME" F1                # when the screen text contains TEXT
wait 50000000 "dir\n"           # N clocks after the previous rule
when "A>" Ctrl+Alt+Del
```

Keys: names (`F1`-`F10`, `Esc`, `Enter`, `Tab`, `Space`, `Backspace`,
`Ctrl`, `Alt`, `Shift`, `RShift`, `CapsLock`, `NumLock`, `ScrollLock`,
`SysRq`, `KP0`-`KP9`, `KP.`, `KP+`, `KP-`, `KP*`, `Home`, `End`, `Up`,
`Down`, `Left`, `Right`, `PgUp`, `PgDn`, `Ins`, `Del`), a two-digit hex
set 2 code, `A+B+C` held together, or `"text"` typed with Shift as needed
(`\n` is Enter). Key events are applied 30 ms apart (AT23).

`--ext-kb=1408` gives a 2 MB machine (640 KB plus 1,408 KB from 1 MB).

### POST regressions

From the repository root, inside the `ai-hw-engineer` tool image:

```sh
ROM=$(sh system/ibm_pc_at_5170/scripts/get_bios.sh)
sh system/ibm_pc_at_5170/scripts/run_all.sh "$ROM"
sh system/ibm_pc_at_5170/scripts/run_post_ega.sh "$ROM"
sh system/ibm_pc_at_5170/scripts/run_post_vga.sh "$ROM"
```

`get_bios.sh` downloads the BIOS from the pinned PCjs archive into the
ignored `work/` folder and checks its SHA-256. The 8042 firmware (IBM part
1503033) is rebuilt and hash-checked by the 8042 design's script, also into
`work/`. `run_all.sh` lints the board, runs the BIOS in two clock
scenarios, checks the stop point in `scripts/expected_stop.txt`, compares
every 80286 instruction with Unicorn, checks the 8042 and the MC146818
against their reference models, and synthesizes the board, the EGA
machine and the VGA machine with Yosys. The two scenarios take about 20 minutes of simulation
and their Unicorn replays about 20 minutes each; `run_post.sh` takes about
54 minutes and synthesis about 12 more.

`run_post_ega.sh` needs only the path of the AT BIOS. It fetches the EGA
ROM (IBM 6277356) with `design/ibm_ega/scripts/get_rom.py`, which checks its
hashes and writes it to the ignored `work/` folder. It runs the EGA machine
in one scenario, checks the stop point in `scripts/expected_stop_ega.txt`,
checks the screen text in `tb/expected_screen_ega.txt`, replays the 8042
and the MC146818 into their models and compares every 80286 instruction
with Unicorn. It takes about 15 minutes of simulation and checks plus about
20 minutes for the Unicorn replay, and writes `work/post_ega/frame.png`.
`run_all.sh` does not run it.

`scripts/run_post_card.sh ega|vga /path/to/atbios.bin` is the one regression
for either card; `run_post_ega.sh` and `run_post_vga.sh` are wrappers.
`run_post_vga.sh` fetches the VGA ROM with `design/ibm_vga/scripts/get_rom.py`
(hash-checked, into the ignored `work/` folder), runs the VGA machine in one
scenario, makes the same five checks (stop point in
`scripts/expected_stop_vga.txt`, screen text in `tb/expected_screen_vga.txt`,
8042, MC146818, Unicorn) and writes `work/post_vga/frame.png`. `run_all.sh`
does not run it either. `run_synth.sh` also synthesizes the VGA machine.

## Verification and boundaries

The board answers an I/O read only from modeled devices. On the bare board
the run stops at the first unmodeled I/O read, and at an instruction fetch
from memory that is not fitted. Two cases have no effect on a real bus and
are accepted: a write to an empty expansion-slot address, and a write to
memory that is not fitted; a data read from unfitted memory returns FFh
(assumption AT14). Current stop on the bare board: `F000:1453`, a read of
port 1F7h (fixed-disk status) at POST checkpoint 3Ch. In the EGA machine
the channel and the card answer video memory and the card's ports, and the
run ends after the same read, at `F000:1454`.

Every 80286 instruction of all four runs (two bare-board scenarios, the EGA
machine and the VGA machine) matches Unicorn, in the system BIOS and, for
the card machines, in the card's BIOS. The 8042 and the MC146818 match their
reference models in all four. The display is checked as the text of one
frame against the ROM's own font. The board synthesizes to 86,864 generic
cells, the EGA machine to 94,169 and the VGA machine to 129,054 (the cards'
plane RAMs and ROMs are black boxes; the VGA DAC's palette is in logic). The
bare-board regression was last run for M4a, not on the VGA branch; its
inputs are unchanged since M4a except `tb/post_runner.cpp`.

Limits:

- The keyboard device exists only in the web/batch host
  (`host/at_keyboard.hpp`, AT20-AT24); the POST runner has none, so the
  regressions still expect ` 301-Keyboard Error`. With the keyboard the
  BIOS reaches its F1 prompt at about 210 million clocks and, after F1,
  stops at its 80287 probe: `FNINIT` writes port 0F8h, which no board
  device decodes (AT17); see the
  [web and keyboard report](report/2026-11-17-web-front-end-and-keyboard.md).
- No diskette adapter, fixed-disk adapter or 80287; NMI is
  not connected; only the timer interrupt (IRQ 0) has been taken, and the
  8259s are checked only by the BIOS's own tests and by the vectors and
  in-service values seen.
- Channel timing is not the real board's (AT18). The video and processor
  clocks have a virtual ratio: the 8042 and the MC146818 run four times
  fast relative to video (AT19).
- The EGA and VGA machines are each checked in one scenario, with no added
  wait states.
- The VGA ROM image could not be cross-checked against an IBM listing, and
  the POST run does not exercise VGA graphics modes or the DAC; only the
  card's own suite covers them. The VGA machine's card clock stands for
  48 MHz on the virtual time base (an extension of AT19).
- 200-line modes on the card's direct-drive connector are not converted;
  frame colors assume the 350-line 64-colour interpretation.
- Unicorn does not check segment limits on accesses that do not fault.
- No whole-machine comparison with an independent emulator.
- Exploratory, not part of the regression: a longer EGA run
  (3,000,000,000 processor clocks) reaches POST checkpoint 3Fh, where the
  screen also shows `(RESUME = "F1" KEY)` and the BIOS waits for the F1
  key; the bare board with readable empty slots also reaches 3Fh.

The VGA card is done (M4b part 1), and the web front end, batch host and
keyboard model exist (2026-11-17). The rest of M4b is the diskette, the
80287-port decision and a complete POST; see the [implementation plan](plans/implementation_plan.md).
Tracking issue: https://github.com/hevangel/ai_hw_engineer/issues/254.

- [Specification](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [M1 report](report/2026-11-13-m1-board-skeleton.md)
- [M2 report](report/2026-11-14-m2-8042-and-rtc.md)
- [M3 report](report/2026-11-15-m3-interrupts-and-protected-mode.md)
- [M4a report](report/2026-11-16-m4a-io-channel-and-ega.md)
- [M4b part 1 report](report/2026-11-16-m4b-vga.md)
- [Web front end and keyboard report](report/2026-11-17-web-front-end-and-keyboard.md)
- [Verification report](report/final_report.md)

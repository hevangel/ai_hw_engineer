# IBM PC AT 5170 verification report

Status: M4b diskette adapter and DMA. The unchanged REV1 BIOS runs 16,688,169
instructions of its power-on self-test (16,586,155 with bus wait states) on the
bare board and stops at `F000:1453`, a read of port 1F7h (fixed-disk status) at
POST checkpoint 3Ch. With an I/O channel, the diskette adapter and an IBM EGA
in a slot, it and the card's BIOS run 18,029,214 instructions to the same point
and the display shows `00640 KB OK` and ` 301-Keyboard Error` (no `601-Diskette
Error`). With an IBM VGA (PS/2 Display Adapter) in the slot instead, it and the
card's BIOS run 16,610,979 instructions to the same point and the 720 x 400
display shows the same two lines. With a bench F1 stimulus at checkpoint 3Fh and
the empty 80287 socket decoded at F8h-FFh, the VGA machine boots a script-built
1.2 MB test diskette through the 8272 controller and board DMA (`27,368,206`
instructions at 640 KB, `39,749,282` instructions with `--ext-kb=1024`). No
operating system has been booted yet.

| Check | Command | Result |
|---|---|---|
| Lint | `scripts/run_post.sh` (first step) | Clean, `verilator --lint-only -Wall` |
| BIOS stop point, two clock scenarios | `scripts/run_post.sh` | Both stop at `F000:1453`, port 1F7h read, POST 3Ch; 3 CPU resets and 8 interrupt-acknowledge cycles (4 interrupts, vector 08h) in each |
| Unicorn replay | `scripts/run_post.sh` | Every instruction state and data transfer matches: 16,688,169 and 16,586,155 instructions, through protected mode, 4 hardware interrupts, 4 exceptions, 69 software interrupts and 3 resets; 13 of 13 BIOS checkpoints |
| 8042 against its reference model | `scripts/run_post.sh` | 7,777,553 and 10,543,228 8042 instructions; 1,648,422 and 1,637,225 CPU reads identical |
| MC146818 against its reference model | `scripts/run_post.sh` | 22,855 and 14,538 address strobes, 23 writes each; 22,830 and 14,513 CPU reads identical |
| Synthesis, board | `scripts/run_synth.sh` | Pass, 86,879 generic cells, `check -assert` clean; the only latch is the refresh arbiter's schematic latch |
| Synthesis, diskette adapter | `scripts/run_synth.sh` | Pass, `at_diskette_adapter` 6,920 generic cells, `check -assert` clean |
| EGA machine: lint | `scripts/run_post_ega.sh` (first step) | Clean, `verilator --lint-only -Wall` on `ibm_pc_at_5170_ega` |
| EGA machine: stop point | `scripts/run_post_ega.sh` | `kind=stop-at after=F1453 at=F000:1454 post=3C`; 18,029,214 instructions, 273,013,658 processor clocks, 3 CPU resets, 16 interrupt-acknowledge cycles (4 timer, 4 diskette IRQ 6), 1,253 slot writes, 3 slot reads, 1,270,295 channel memory writes, 633 video frames |
| EGA machine: screen | `scripts/run_post_ega.sh` (`scripts/check_frame.py`) | The last frame, 640 x 350, decodes with the ROM's own 8 x 14 font to `00640 KB OK`, ` 301-Keyboard Error` |
| EGA machine: 8042 | `scripts/run_post_ega.sh` | 9,787,012 instructions, 19 host writes, 6 data reads, 1,648,622 CPU read values identical |
| EGA machine: MC146818 | `scripts/run_post_ega.sh` | 31,922 address strobes, 23 writes, 31,897 CPU read values identical; 45.5 s of clock time |
| EGA machine: Unicorn replay | `scripts/run_post_ega.sh` | 18,029,214 instruction states and data transfers match, in the system BIOS and in the EGA BIOS; 8 hardware interrupts, 89 software interrupts, 3 resets, 4 exceptions; 13 of 13 BIOS checkpoints |
| Synthesis, EGA machine | `scripts/run_synth.sh` | Pass, `ibm_pc_at_5170_ega` 100,510 generic cells with the card's plane RAMs and ROM as black boxes; `check -assert` clean; the only latch is the refresh arbiter's schematic latch |
| VGA machine: stop point | `scripts/run_post_vga.sh` (2026-11-17) | `kind=stop-at after=F1453 at=F000:1454 post=3C`; 16,610,979 instructions, 225,013,662 processor clocks, 3 CPU resets, 20 interrupt-acknowledge cycles (6 timer, 4 diskette IRQ 6), 3,161 slot writes, 6 slot reads, 271,575 channel memory writes, 583 video frames |
| VGA machine: screen | `scripts/run_post_vga.sh` (`scripts/check_frame.py`) | The last frame, 720 x 400, decodes with the VGA ROM's 8 x 16 font (9 x 16 cells, replacement glyphs, ninth-column rule) to `00640 KB OK`, ` 301-Keyboard Error` |
| VGA machine: 8042 | `scripts/run_post_vga.sh` | 8,002,515 instructions, 19 host writes, 6 data reads, 1,648,623 CPU read values identical |
| VGA machine: MC146818 | `scripts/run_post_vga.sh` | 53,511 address strobes, 23 writes, 53,486 CPU read values identical; 37.5 s of clock time |
| VGA machine: Unicorn replay | `scripts/run_post_vga.sh` | 16,610,979 instruction states and data transfers match, in the system BIOS and in the VGA BIOS; 10 hardware interrupts, 64 software interrupts, 3 resets, 4 exceptions; 13 of 13 BIOS checkpoints |
| Synthesis, VGA machine | `scripts/run_synth.sh` | Pass, `ibm_pc_at_5170_vga` 136,117 generic cells with the card's plane RAMs and ROM as black boxes (the DAC's palette is in logic); `check -assert` clean; the only latch is the refresh arbiter's schematic latch |
| VGA diskette boot (640 KB) | `scripts/run_boot_diskette.sh` | Pass: halts at `0000:7EEC` (`27,368,206` instructions, `417,466,520` clocks); screen `AT DISKETTE BOOT TEST / READ OK / WRITE OK / PASS`; `1,209,344` DMA writes, `512` DMA reads; `check_fdc_log.py`, `check_kbc_log.py` (`14,417,787`), `check_rtc_log.py` (`36,916`) and Unicorn (`13/13` checkpoints) pass |
| VGA diskette boot (2 MB) | `scripts/run_boot_diskette.sh --ext-kb=1024` | Pass: halts at `0000:7EEC` (`39,749,282` instructions, `591,466,611` clocks); screen, DMA, `check_fdc_log.py`, `check_kbc_log.py` (`20,872,359`), `check_rtc_log.py` (`5,083`) and Unicorn (`13/13` checkpoints) pass |
| D/G record self-tests | `scripts/test_board_records.py` | Pass: 8 of 8 on 640 KB trace and 10 of 10 on 2 MB trace |
| Host wrapper & capture | `scripts/build_host.sh` + `scripts/test_capture.py` | Clean lint on `ibm_pc_at_5170_vga_host`; waveform captures of `1,024`, `4,096` and `65,536` clocks match ordinary runs |
| Keyboard against 8042 | `scripts/run_keyboard_test.sh` | Pass (`--fda-type=none`, `187,000,000` clocks): reset `FF` -> `AA FA AA`, no `301`, F1 (`3B`/`BB`) resumes POST past `3Fh` and the `0F8h` probe to `43` |
| Web/batch host diskette boot (AT keyboard) | `scripts/run_host_boot.sh` | Pass (`962 s` wall, `423,466,672` clocks, `27,788,811` instructions): cold power-on without `301` or `601` halts at `0000:7EEC`, screen matches `tb/expected_screen_boot.txt`, DMA `1,209,344`/`512`, `LBA 2399` written back |

Each card machine is checked in one scenario (no added wait states).
`run_post_card.sh ega|vga` is the one regression for either card;
`run_post_ega.sh` and `run_post_vga.sh` are wrappers. See also the
[web front end and keyboard report](2026-11-17-web-front-end-and-keyboard.md).

Details, findings and limits:
[Diskette adapter and DMA report](2026-11-17-diskette-adapter-and-dma.md),
[M4b part 1 report](2026-11-16-m4b-vga.md) and the
[M4a report](2026-11-16-m4a-io-channel-and-ega.md). Earlier:
[M3 report](2026-11-15-m3-interrupts-and-protected-mode.md),
[M2 report](2026-11-14-m2-8042-and-rtc.md) and
[M1 report](2026-11-13-m1-board-skeleton.md).

Exploratory, not part of the regression: a longer run of the EGA machine
(3,000,000,000 processor clocks, 212,970,955 instructions) reaches POST
checkpoint 3Fh and waits at `(RESUME = "F1" KEY)`; the bare board with
readable empty slots (`--empty-slots`) also reaches checkpoint 3Fh.

Not yet modeled: fixed disk and the 80287 (empty 80287 socket AT36 and idle fixed-disk task file AT37 are present on the display machines; the AT keyboard model `host/at_keyboard.hpp` runs in `host/simulator.cpp`, while `tb/post_runner.cpp` still uses its F1 bench stimulus). VGA graphics modes and the DAC are not exercised by the POST run, and
the VGA ROM image could not be cross-checked against an IBM listing. NMI is not connected. Channel timing is not the real
board's (AT18), DMA/diskette timing is not the real board's (AT25, AT27), and the video and processor clocks keep a virtual ratio
(AT19). The 8259s are checked only by the BIOS's own tests and by the
vectors and in-service values seen. The display is checked as text of one
frame. 200-line modes are not converted. There is no whole-machine
comparison with an independent emulator yet.

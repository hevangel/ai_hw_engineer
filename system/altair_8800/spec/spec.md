# Altair 8800 virtual-platform specification

## Machine and sources

Reconstruct the January 1975 MITS Altair 8800 as a functional system: the
repository's verified Intel 8080 core, static RAM, a MITS 88-SIO serial card
for the console, the front-panel display/control logic and the S-100 status
lamps. The machine boots with no ROM: programs are entered from the front
panel and loaded from "paper tape" over the serial card, exactly as the
original system operated.

First introduced: **1975**. The Altair 8800 was announced on the cover of
[Popular Electronics, January 1975](https://www.americanradiohistory.com/hdgrpx/Popular-Electronics/70s/Popular-Electronics-1975-01.pdf)
and shipments began the same year. The year-level claim is uncontroversial;
month-level ship dates varied and are not asserted.

Primary sources:

- [MITS Altair 8800 Operator's Manual](https://altairclone.com/downloads/manuals/Altair%208800%20Operator's%20Manual.pdf)
  (98 pages), consulted through the [CC BY-SA HTML transcription](https://ubuntourist.codeberg.page/Altair-8800/part-3.html).
  Source of every front-panel switch operation, the status-LED meanings and
  the sample add program used by the board testbench.
- [MITS 88-SIO Rev 0 & 1 manual](https://deramp.com/downloads/altair/hardware/sio_serial_interface/88-SIO%20Rev%200%20%26%201.pdf)
  (scanned copy archived in [shared references](../../../references/88-SIO_Rev0_1.pdf)).
  Primary hardware reference for the serial card. The scan has no text layer,
  so the status-bit contract below is pinned by two independent software
  artifacts instead of OCR.
- [SIO loader for 4K BASIC 3.2](reference/LDR4K32.ASM) and its
  [octal listing](reference/LDR4K32-octal.PRN), Mike Douglas's deramp.com
  reconstruction of the MITS front-panel bootstrap, with the byte values the
  original documentation gives.
- [Annotated disassembly of Altair BASIC 3.2 (4K)](reference/altair_basic_32_4k_disassembly.txt)
  (Copyright 1975 Bill Gates, Paul Allen, Monte Davidoff; disassembly by
  Reuben Harris, <http://altairbasic.org>). Ground truth for the console I/O
  contract that real software depends on.
- Altair 4K BASIC version 3.2 tape image: original MITS media, fetched at
  verification time from
  <https://deramp.com/downloads/altair/software/papertape_cassette/4K%20BASIC%20Ver%203-2.tap>
  into the ignored `work/` folder with SHA-256
  `fd01fd8b5c3dfbf67709809a1da6409ff1e0cb9c108fbe6a5129f8ad8e68d90f`.
  The copyrighted image is never committed to Git.

## Hardware boundary

`altair_8800` (`src/altair_8800.sv`) instantiates the repository's
`intel_8080` and models one fully populated board set:

- **RAM**: `RAM_KIB` KiB of static RAM from address 0000h upward, default
  16 KiB (a typical BASIC-era configuration; the original kit shipped with
  256 bytes, and MITS sold memory in 4 KiB increments). Reads above the RAM
  top return FFh. RAM contents survive RESET; power-up contents are zeroes.
- **MITS 88-SIO** serial card at device codes 0 (status/control) and 1
  (data), the classic console address selection that Altair BASIC 3.2 (4K)
  is hard-wired for.
- **Sense switches**: the front panel's upper eight address switches
  A15..A8 are readable as input port FFh, per the 88-SIO/Altair convention.
  All switches OFF reads 00h, which 4K BASIC 3.2 interprets as "88-SIO
  console", matching the bootstrap's documented "set all sense switches
  OFF" setup.
- **Front-panel display/control logic**: RUN/STOP, SINGLE STEP, EXAMINE,
  EXAMINE NEXT, DEPOSIT, DEPOSIT NEXT, RESET, CLR, PROTECT, UNPROTECT,
  the 16 address switches and 8 data switches.
- **Status lamps**: the 8-bit Intel machine status word (systems manual
  table 2-1) drives the eight Altair status lamps, MEMR, INP, M1, OUT,
  HLTA, STACK, WO, INT, plus INTE, HLDA and PROT lamps. WAIT is never lit
  because the modelled memory and SIO never insert wait states.

Interrupts (INT/INTA), DMA devices and the 88-SIO's interrupt facility are
not modelled: `int_i` is tied low, and an OUT to the SIO control port is
accepted and ignored. The core's sticky `fault_o` (undefined opcodes) is
exposed to the host as a diagnostic, not as a panel lamp.

## Bus and panel mechanics

One rising clock edge is one implementation step; all bus transfers complete
in a single step (`bus_ready_i` is tied high). This is the functional bus
contract documented in the 8080 design's spec; native S-100 electrical
timing is outside the virtual platform.

The board latches the address, data and status lamps at every completed CPU
bus transfer. While running, the lamps show live bus activity; when
stopped, they freeze on the last transfer, as the original latched panel
does.

STOP asserts the core's `hold_i`; the core grants `hlda_o` between machine
cycles (after completing any outstanding transfer), which is the functional
equivalent of the original panel taking control of the bus. While held, all
panel memory operations act directly on RAM, which is how the original
panel's forced bus cycles behave.

- **RUN/STOP switch**: STOP asserts HOLD and waits for HLDA; RUN releases
  it. A halted CPU (HALT instruction) stays halted; RUN has no effect until
  RESET or an interrupt, matching the real processor.
- **SINGLE STEP** (stopped only): releases HOLD, runs until the next
  instruction retires and the following instruction's M1 opcode fetch
  completes, then re-asserts HOLD. This is the original panel's
  stop-at-next-M1 behavior and the only boundary the 8080 core's HOLD
  contract (complete the outstanding transfer, then grant) supports; each
  actuation retires exactly one instruction and the architectural registers
  reflect it. Mid-instruction stops resume the interrupted instruction
  before completing the step.
- **EXAMINE** (stopped only): display address ← address switches; data
  lamps ← RAM[display address].
- **EXAMINE NEXT** (stopped only): display address ← display address + 1
  (wrapping at 16 bits); data lamps follow.
- **DEPOSIT** (stopped only): RAM[display address] ← data switches unless
  protected; data lamps ← data switches.
- **DEPOSIT NEXT** (stopped only): display address ← display address + 1,
  then RAM[display address] ← data switches unless protected; data lamps ←
  data switches. Successive DEPOSIT NEXTs write consecutive addresses,
  matching the Operator's Manual loading procedure.
- **RESET**: resets the 8080 core (PC ← 0, per the Operator's Manual "RESET
  sets the Program Counter to address 0") and sets the display address to 0
  so the first DEPOSIT after RESET writes address 0. The RUN switch is not
  changed: with RUN on, the machine restarts from address 0, as the switch
  semantics of the original panel imply. RAM and the protect latch are
  unchanged.
- **CLR**: pulses the I/O-clear line; the modelled 88-SIO resets its status
  (transmitter ready, receiver buffer discarded). The host's pending tape
  queue is also cleared, like a tape reader stopped and rewound.
- **PROTECT/UNPROTECT**: one protect latch guarding all modelled RAM
  against both CPU and panel writes; PROT lamp reflects it. Real machines
  protected per-board; a one-board system has one latch.

## 88-SIO functional contract

Ports: IN/OUT 0 = status/control, IN/OUT 1 = data, IN FF = sense switches.

Status byte read at port 0 (operationally pinned by the original software;
the manual's labels are confusing, so both the label and the observed
semantics are recorded):

| Bit | Manual label | Observed semantics (contract) |
|---|---|---|
| 7 | Output device ready | 1 = transmitter busy; 0 = ready to accept a character |
| 6..2 | (various) | always 0 (overflow/framing/parity errors never occur) |
| 1 | Transmitter buffer empty | always 0 |
| 0 | Input device ready | 1 = no received byte available; 0 = received byte available |

Evidence for bit 0: the MITS-era SIO loader polls `IN 00h; RRC; RC` with the
comment "new byte available? / no" — carry set (bit 0 = 1) means no byte.
Evidence for bit 7: 4K BASIC 3.2's output routine at 0377h is
`IN 00; ANI 80h; JNZ WaitTermReady; POP PSW; OUT 01` — it waits while bit 7
is 1 and transmits when bit 7 is 0. BASIC's input routine is
`IN 00; ANI 01h; JNZ InputChar; IN 01; ANI 7Fh` — it waits while bit 0 is 1.
The break-key test `IN 00; ANI 01; RNZ` uses the same sense.

- Reading port 1 returns and dequeues the oldest received byte; bit 0 then
  reads 1 again until the host supplies another byte. The received-byte
  buffer is a model-level FIFO, not the real card's one-byte register, so
  the manual's overflow bit never sets.
- Writing port 1 latches the byte to the host console and makes the
  transmitter busy for a configurable number of implementation steps
  (`tty_tx_delay`, default 300), pacing output like the real card's
  transmitter. BASIC's polling loop then governs the character rate.
- Writing port 0 (interrupt enables) is accepted and ignored.
- Input from the host arrives through a FIFO filled by explicit KEY (one
  console byte) and TAPE (one file's bytes) host commands; the tape feed
  drains into the FIFO as the machine runs, one byte per step at most,
  which is far faster than any real reader but is bounded by FIFO space
  (4096 bytes) with host-side backpressure.
- Unmapped I/O reads (any port except 0, 1 and FFh) return FFh.
  Unmapped I/O writes are ignored.

## Bootstrap and tape format

The machine has no ROM. The documented 20-byte front-panel bootstrap from
[reference/LDR4K32-octal.PRN](reference/LDR4K32-octal.PRN) is toggled into
RAM at 0000h with all sense switches OFF:

```
21 AE 0F   LXI  H,0FAEh    ; end address = 0FAEh, L = tape length marker
31 12 00   LXI  SP,0012h   ; RET returns to the poll loop
DB 00      IN   00h        ; SIO status
0F         RRC             ; received byte available?
D8         RC              ; no: restart the poll
DB 01      IN   01h        ; read the byte
BD         CMP  L          ; leader byte (0AEh)?
C8         RZ              ; yes: restart the poll
2D         DCR  L          ; decrement low load address
77         MOV  M,A        ; store (downward from 0FADh)
C0         RNZ             ; until 0AEh bytes are loaded
E9         PCHL            ; run the second-stage loader at 0F00h
03 00      (stack word)    ; points back at the poll loop
```

The tape file is 4352 bytes: a run of 0AEh leader bytes followed by 4014
program bytes. The first 0AEh program bytes land at 0F00h..0FADh and form
MITS's second-stage loader, which reads the remaining 3840 bytes into
0000h..0EFEh and starts BASIC. The bootstrap requires at least 4 KiB of RAM
because it writes through 0FADh. After loading, 4K BASIC 3.2 prints
`MEMORY SIZE?`, `TERMINAL WIDTH?`, then one `WANT <FN>?` prompt for each of
SIN, RND and SQR; each answer must be Y or N (a bare CR re-prompts), then
BASIC prints `BYTES FREE`, `BASIC VERSION 3.2 [4K VERSION]` and the `OK`
prompt. BASIC echoes typed characters itself, so the console does not
local-echo.

## Verification and scope

`scripts/run_all.sh` must pass:

1. `verilator --lint-only -Wall` on the board RTL.
2. Board testbench (`tb/tb_top.sv`): exercises EXAMINE/DEPOSIT/DEPOSIT
   NEXT/EXAMINE NEXT, the Operator's Manual add program (12+34 = 46 at
   address 0202 octal), PROTECT, SINGLE STEP, HOLD/HLDA lamp sequencing and
   the 88-SIO status/data contract with an echoed character loop.
3. Real-software regression (`scripts/test_software.py`): fetch and
   hash-check the 4K BASIC 3.2 tape, toggle the bootstrap in through panel
   DEPOSIT/DEPOSIT NEXT commands, RUN, feed the tape over the SIO, answer
   the startup prompts, run a BASIC program (`PRINT 2+2`, a loop and a
   floating-point expression) and require byte-exact expected console
   output. This is the mandatory real-software gate for processor-like
   systems.
4. Backend test (`scripts/test_backend.py`): the HTTP panel API validates
   inputs, serializes commands and serves the waveform capture.
5. Yosys synthesis check.

Out of scope: S-100 electrical timing, the 88-SIO's interrupt vectors,
real UART framing/baud rates, cassette and floppy subsystems, and the
8800b's different panel electronics. The host may observe memory and
state but never writes RAM or architecturally injects state; the only
firmware path is the front panel plus the serial tape, as on the
original machine.

| Assumption or evidence gap | Independent evidence | Status |
|---|---|---|
| SIO status bit 0: 1 = no received byte | MITS SIO loader `RRC/RC` comment; BASIC `ANI 01/JNZ` poll | Validated by booting 4K BASIC 3.2 |
| SIO status bit 7: 1 = transmitter busy | BASIC output poll `ANI 80/JNZ` at 0377h | Validated by booting 4K BASIC 3.2 |
| Unmapped memory reads return FFh | BASIC's memory probe must terminate above RAM top | Validated by MEMORY SIZE probe |
| Transmitter busy pacing (300 steps default) | Real SIO paces output; exact delay is configuration, not behavior | Model choice, documented |
| DEPOSIT NEXT increments then writes | Operator's Manual loading procedure | Validated by board testbench |
| Panel ops act on RAM directly during HLDA | Real panel drives the S-100 bus when HLDA | Functional equivalence, documented |
| CLR resets the modelled SIO only | Manual: CLR is "a clear command for external input/output equipment" | Model choice, documented |
| BASIC echoes input; console does not | `InputLine` calls `RST 03` (OutChar) per typed character | Validated by boot |
| RAM above top returns FFh; power-up RAM is zero | Real power-up RAM is indeterminate | Model choice, documented |
| RESET zeroes PC and display address, keeps RAM and the RUN switch | Operator's Manual RESET description | Validated by board testbench |

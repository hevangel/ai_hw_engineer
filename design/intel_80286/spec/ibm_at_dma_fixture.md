# IBM AT DMA register fixture contract

This fixture exists to run the unchanged 5170 BIOS register tests on the 80286
model. It is not a complete IBM AT DMA or refresh implementation. The [IBM
5170 March 1984 technical reference, PDF pages 30–32](https://bitsavers.org/pdf/ibm/pc/at/1502494_PC_AT_Technical_Reference_Mar84.pdf#page=30),
identifies two 8237A-5 controllers, with the second controller's channel 0
used to cascade the first, and lists the second controller's even-spaced
register ports `C0h`–`DEh`.

`tb/intel_80286_at_dma.sv` instantiates two repository `intel_8237` RTL
controllers. The first decodes canonical ports `00h`–`0Fh` with the low four
address bits; the second decodes even ports `C0h`–`DEh` with address bits
4:1. Other board aliases are outside this fixture. Register strobes occur only
at an accepted READY edge so stalls cannot advance the 8237 byte flip-flop.
Read data is driven only for the 8237's defined read registers. The test
harness reports a selected but undriven DMA read as a failure rather than
silently substituting host-port data.

Both DREQ inputs are zero, HLDA is low, READY is high and EOP is inactive.
Consequently the fixture covers programming and readback, not DMA requests,
bus ownership, cascade arbitration, page registers or memory transfers. The
8254 channel-1 refresh output is not connected to either DMA controller.
Both device models use the fixture's integration clock; this is not a claim
about the IBM AT's physical clock ratio or bus timing.

The original BIOS exercises all eight address/count registers on both
controllers with its own test patterns and branches to its error HLT on
mismatch. Captured I/O reads are also supplied to Unicorn for independent CPU
instruction-state and data-transaction comparison. Unicorn replay does not
independently validate the DMA device or controller timing. See the
[DMA BIOS report](../report/2026-10-29-at-dma-bios.md).

## Page-register fixture and next POST boundary

The original ROM next tests I/O locations `81h`–`8Eh`, then `8Fh`. The
generic host-port array previously stored arbitrary bytes at those addresses,
so continuing with that array alone would not establish a page register.
IBM's 1984 reference, page 1-13 (PDF page 31), maps page registers
for DMA channels 0–3 to `87h`, `83h`, `81h`, `82h`; channels 5–7 to `88h`,
`89h`, `8Ah`; and refresh to `8Fh`. For channels 0–3 the page supplies
address bits A23:A16; for channels 5–7 it supplies A23:A17 while the DMA
counter supplies A16:A1. Other tested addresses and any aliases need the
original board decode and device behavior sourced before they are treated as
physical hardware. A screenshot of page 31 is retained at
`work/at_dma_source_20261029_01/manual_page31.png`, SHA-256
`513515CCE2EF53B749753853488B3759E0D5F867DCEE2040D8EF4A7B62E521B6`.

`tb/intel_80286_at_page.sv` implements a digital CPU-visible 16-slot,
8-bit register fixture at canonical `80h`–`8Fh`; the separate map index
output is exposed for future DMA wiring. The underlying 74LS612 is a
16-word, 12-bit memory mapper, as shown in the [Texas Instruments 1984 data
book](https://pestingers.net/pdfs/Electronic-references/texas-instruments/ttl-data-book-vol-1-1984.pdf).
This fixture models only the CPU-visible bytes used by the BIOS and makes no
claim of complete chip-pin or upper-bit equivalence. **ASSUMPTION:** fixture
reset clears storage for determinism; the device's physical power-up contents
are not established here. The BIOS test writes each tested slot before
reading it. Aliases outside `80h`–`8Fh` and the DMA-side mapping are not yet
connected or qualified.

## Following POST stage: refresh detection

The unchanged BIOS at `F000:038A`–`03A2` reads port `61h` bit 4 and waits
for both states before continuing; an error HLT is reached if either state is
not observed. IBM's original POST listing describes this as the storage
refresh test. The earlier functional-bus fixture returns a static host-port
value at `61h`. A separate native-bus fixture now supplies the modeled 8254,
refresh signal path and port B read buffer; the unchanged BIOS reaches
`F000:03A2` in two virtual-clock/READY scenarios, with CPU state and data bus
transactions compared against Unicorn. It holds DMA DREQ inputs inactive and
observes row and read-drive signals without connecting them to a page mapper
or DRAM. Thus this establishes the BIOS indication test under the stated
fixture assumptions, not complete refresh or an AT platform. See the
[native BIOS report](../report/2026-10-29-at-bios-native-refresh.md).

## Refresh-detect flip-flop

The [IBM 5170 type 1 schematic](https://www.minuszerodegrees.net/misc/schematic_5170_motherboard_type_1.pdf),
sheet 21 (PDF page 11), identifies U118 as an ALS74 with its inverted output
fed back to D, clock on `+REFRESH`, CLR tied high and active-low preset on
the `PULL UP` net. Sheet 3 (PDF page 2) connects that net through R19,
1 kΩ, to +5 V. Both preset and clear are therefore inactive in normal
operation; the schematic does not establish initial Q. Its Q is `REF DET`,
sent to sheet 17. The independent
`tb/intel_80286_at_refresh_detect.sv` models exactly this flip-flop: a rising
`+REFRESH` edge complements Q, and a low preset asynchronously sets Q high.
The preset is exposed to test the device; the board connection holds it high.
There is no assumed initial state. The standalone test compares the board
connection's changes to its observed starting value, which does not establish
a physical startup value. The 74ALS74's analog
setup, hold, recovery and propagation timing are outside this digital model.

The flip-flop is not yet connected to the AT fixture or port `61h`; no real
refresh event is generated by this module. Completing that connection requires
tracing the U68/U90/U95/U69/U98 refresh request and grant network, the LS590
counter, page register `8Fh` and the port-B read mux; then it
must be integrated with native HOLD/HLDA and actual refresh bus cycles. These
are not established by the standalone flip-flop test.

## Timer refresh request and clear chain

The same schematic sheet connects 8254 `OUT1` to U68 pin 3; U68's first D
is high, and its Q feeds the second D. The second clock is `-DMA CLK` and
its Q is the refresh request. Both U68 clear pins connect to U95 Q4. U95 is
cleared by `-RESET` and clocked by `SYS CLK`. Its D inputs are respectively
`NOR(-REFRESH, Q3)`, `Q1`, `Q2 AND IOCHRDY`, and `NOT Q3` (U99, U92 and
the shown Q/Q-bar connections). The resulting Q4 signal asynchronously clears
the two U68 stages after a refresh cycle progresses through this chain.

`tb/intel_80286_at_refresh_request.sv` models this subcircuit with separate
timer, inverted DMA and system clocks. The request is latched, then sampled
on the next rising edge of `-DMA CLK`; an IOCHRDY stall holds Q3 low and
delays the clear. The fixture supplies `-REFRESH` externally: it must come
from the separately modeled grant logic and a real bus cycle, not a free-running
signal. The model is digital, without metastability, setup/hold or real clock
phase claims; simultaneous clock and asynchronous-clear transitions require
timing qualification before a hardware-equivalence claim. It is connected
to the native test path described below, but not the BIOS fixture. See the
[request/clear report](../report/2026-10-29-at-refresh-request.md).

## Refresh/DMA arbiter and combined signal path

Sheet 21's U69/U121 feedback gate is an AND-OR-invert with inverted feedback.
Its output clears when neither `REF REQ` nor `LHRQ1` is asserted; with HLDA
low it follows the presence of a request; with HLDA high and a request still
present it retains its prior value. U90 samples `REF REQ` and `LHRQ1` on
SYS CLK with each Q asynchronously clearing the other flip-flop. U98/U116
assert `-REFRESH` when HLDA, the U69 output and U90's refresh Q are high;
U70 similarly generates HLDA1 for the DMA selection. U92 additionally gates
CPU HRQ with a U120 latch derived from `-INTA` and `-WE`; this enable is an
explicit `hold_permit_i` input until that latch and its timing are modeled.

`tb/intel_80286_at_refresh_arbiter.sv` models these digital equations. The
cross-coupled U90 clears are intentional physical feedback; Yosys `check`
reports one structural loop, so this standalone model has not passed a
`check -assert` synthesis gate. Simulation does not establish analog
metastability or the result when both requests first arrive simultaneously.
The idle state is established by holding both request inputs low and clocking
the circuit; no physical power-up state is assumed.

`tb/intel_80286_at_refresh_path.sv` joins U68/U95, this arbiter and U118.
Its standalone test drives the timer output, HLDA, permit and IOCHRDY: it
checks that a refresh signal requires HLDA, that a wait holds the request,
and that U118 changes once per accepted refresh signal. This is signal-path
evidence only. Separate native tests now connect the 8254, CPU and LS590 as
described below. U120 inhibition, page mapping and the DRAM cycle remain unimplemented.
No BIOS refresh or real memory-retention behavior is claimed; see the
[integrated signal-path report](../report/2026-10-29-at-refresh-path.md).

## Native 286 HOLD/HLDA integration

`tb/intel_80286_at_refresh_native.sv` connects the partial signal path's CPU
HOLD output to `intel_80286_native_cpu` and feeds its actual HLDA back to the
arbiter. The native test supplies timer OUT1, `-DMA CLK`, IOCHRDY and the
unmodeled hold-permit input, and supplies RAM data on the CPU bus. It triggers
refresh requests during a READY-stalled write and a locked XCHG. The CPU must
finish the stalled write, retain LOCK ownership for the exchange, release bus
pins when HLDA is asserted and resume with the exact memory results and no
duplicate writes. See the [native integration report](../report/2026-10-29-at-refresh-native.md).

The test clocks the CPU wrapper's system clock at twice the processor clock,
using its established digital phase; the timer and DMA edges are test-driven.
This test does not connect an 8254, page mapper, DRAM refresh cycle, port
`61h` or authentic BIOS; the later row counter connection is tested separately.
The U90 cross-coupled asynchronous-clear
structural-loop and physical timing limits remain. This test establishes a
CPU bus-ownership handshake, not complete board refresh or POST.

## CPU-programmed timer and native refresh signals

`tb/intel_80286_at_refresh_timer_native.sv` connects the repository's 8254
and canonical timer-port adapter to the native 286 fixture. It latches the
native I/O status during the status phase, accepts an I/O access only when
the native beat completes, and uses the selected byte lane for the odd timer
ports. Channel-1 OUT1 connects directly to the U68 request latch. A test
program writes channel-1 mode 2 and count 8 through ports `43h` and `41h`,
then performs a counted memory loop while timer output edges produce refresh
signals and CPU HOLD/HLDA handoffs. The test supplies the counter and DMA
clock waveforms, IOCHRDY and the U120/U92 hold permit. It is not a board
clock-frequency or phase qualification. See the
[timer/native report](../report/2026-10-29-at-refresh-timer-native.md).

The directed program exercises timer writes, not the adapter's native timer
read path. The subsequently connected LS590 emits row signals, but the test
does not provide a page mapper, DRAM refresh, full bus arbitration or the IBM BIOS. The U90
asynchronous-clear structural-loop and physical timing limits still apply.

## Refresh row counter and memory-read drive

The [IBM 5170 type 1 schematic](https://www.minuszerodegrees.net/misc/schematic_5170_motherboard_type_1.pdf),
sheet 21, ties U32 LS590's CCK and RCK to `+REFRESH`, grounds CCKEN#,
connects CCLR# to `-RESET`, and drives G# from U95 Q1-bar. QA–QH drive
SA0–SA7 while enabled. [TI's SN74LS590 data sheet](https://www.ti.com/lit/gpn/SN74LS590)
states both clocks are rising-edge triggered, the counter has a direct clear,
and when the clocks are tied the register trails the counter by one count.
The output register has no clear input: resetting the counter does not itself
clear the previously latched row. No initial output-register value is assumed.

The schematic's U79 LS125 has data from U95 Q1-bar and active-low enable
from Q2-bar. The model therefore separately exposes an output-enable and an
active-low `-MEMR` value; it does not resolve that drive with the CPU or any
other system bus drivers. `tb/intel_80286_at_refresh_row.sv` implements the
digital counter/register and output-enable behavior, including wrap at 256.
The path's row output represents only SA0–SA7, not a complete refresh
address. The 74LS612 page output is now observed in the separate BIOS fixture
as described below; the other address lines, DRAM cycle and memory-retention
behavior remain unconnected and unverified.

## Refresh page selection

Sheet 15's U120/U110 gates select map-register index `Fh` when refresh is
active and DMA acknowledgements are inactive. Sheet 13's HLDA/`-MASTER`
logic enables the map output, while a separate U79 enable controls XA16.
The digital gate model connects to the page storage in the native BIOS
fixture. **ASSUMPTION:** that fixture has no active external master or DMA
request and ties `-MASTER` and `-AEN1` inactive; these are not modeled DMA
grant waveforms. BIOS execution and the directed two-value page test
validate this fixture's selected-page behavior, not real DMA transfers or
DRAM. The 1984 manual lists channel 5 at `88h`, while the depicted gate
equations select `8Bh` for that channel; this source disagreement remains
open. See the [page-map report](../report/2026-10-29-at-refresh-page-map.md).

Sheet 7 U96 combines active-low memory-read and memory-write signals into
the `+RAS` delay-line trigger. A standalone digital gate and truth-table test
are documented in the [RAS trigger report](../report/2026-10-30-at-memory-ras-trigger.md).
It is connected to a directed refresh signal-path test using the assumption
that other bus masters release the pulled-up read and write signals during
refresh. A native BIOS test of that fixture connection also passes. Neither fixture
implements U61's delay taps, bank selection or final DRAM RAS/CAS pins.

Sheet 5's U72 is a programmed 28S42 PROM, not a simple combinational decoder.
The standalone model in `tb/intel_80286_at_bank_select.sv` implements its
external address wiring, U63 and U64 latch but requires PROM data as an
input. The available type-3 PROM dump is not established to match type 1;
see the [bank selection report](../report/2026-10-30-at-bank-select.md).

## Port B latch and read buffer

The [IBM 5170 type 1 schematic](https://www.minuszerodegrees.net/misc/schematic_5170_motherboard_type_1.pdf),
sheet 17 (PDF page 9), connects U127's four latch outputs to U128 read-buffer
bits 0–3 and connects `REF DET`, timer OUT2, `IO CH CK` and `PCK` to bits
4–7, respectively. The latch clears with `-RESET`. The fixture models the
canonical port `61h` and uses an accepted native bus transaction to update
the latch; it does not model the individual 82288 write-strobe edges or
incomplete address decode aliases. Latch bit 0 drives the timer's channel-2
gate. `IO CH CK` and `PCK` remain external inputs, not parity or channel-check
implementations. This connection is used by the directed native fixture and
the newer authentic BIOS native fixture; the earlier functional-bus BIOS
fixture remains separate.

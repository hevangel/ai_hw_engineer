# Intel 8273 functional specification

## Sources and scope

Programming behavior follows Intel order 210479-004, October 1992, reproduced
in [intel_8273.pdf](../references/intel_8273.pdf) after a Rochester cover page.
PDF indices below are zero-based, including that cover. Register selection is
on page 6; status/results on 14–16; commands on 18–25; timing on 9–11.
The HDLC wire format is independently pinned by
[RFC 1662 sections 3, 5 and appendix C](https://www.rfc-editor.org/rfc/rfc1662.html).
That reference is used for framing/FCS, not for Intel command semantics or PPP
escaping (this core uses bit stuffing, not octet escaping).

This is synthesizable synchronous RTL, not the manufacturer's internal dual
microprocessor implementation. It operates on real serial bits, with automatic
flags, zero insertion/removal, reflected CRC-16, NRZI and frame results. It
supports general/selective receive, buffered/unbuffered frames, transparent
transmit, modem ports, abort, flag streams and SDLC loop turnaround. A 32x
clock-recovery helper supplies sample strobes.

The common `clk` replaces internal chip timing. `tx_tick` represents the falling
edge of physical TxC and `rx_tick` the rising edge of RxC. All inputs must be
synchronous to `clk`; physical asynchronous pin synchronization belongs in a
board wrapper. `clk32_tick` advances the DPLL and `dpll_tick` may be routed to
`rx_tick` externally. `rst_n` is a synchronous active-low adaptation of RESET;
the reset register sequence 01 then 00 is also supported. There is no claim of
original pin delays, baud ceilings, analog noise tolerance or microcode timing.

This version supports early transmit notifications (0C) but does not queue a
second transmit while one is active, share a closing flag with the next frame,
or automatically repeat supervisory frames. Reissue after final result 0D.
Receive partial-byte endings return a length/status but a partial data byte is
not delivered; ordinary complete-byte frames are the supported DMA contract.
These boundaries are exposed in the README and final report.

## Bus and results

`cs_n`, `rd_n`, `wr_n`, `addr[1:0]`, `data_i`, `data_o`, `data_oe` model the CPU
bus; independent active-low `tx_dack_n`/`rx_dack_n` select the two data registers
regardless of chip select/address. Exactly one transfer is accepted per low
read/write assertion, including stretched strobes. DACK selects the data path;
it does not itself consume data. Data requests drop while DACK is active.

| Address | Write | Read |
|---|---|---|
| 0 | Command | Status |
| 1 | Parameter | Immediate result |
| 2 | Reset register | Tx interrupt result |
| 3 | Reserved | Rx interrupt result sequence |

Status bits 7:0: CBSY, CBF, CPBF, CRBF, RxINT, TxINT, RxIRA, TxIRA.
Commands/parameters are accepted directly on the bus edge: CBF/CPBF therefore
read zero, CBSY remains set until the final parameter. CRBF stays high until
the immediate result is read. Interrupts persist until every associated result
byte has been read. In non-DMA mode, INT also requests data when IRA is zero.

Tx results: 0C early notification, 0D complete, 0E underrun, 0F CTS failure,
10 abort complete. Two Tx result slots permit early and final results to coexist.
Rx results: code then length low/high and, in buffered mode, address/control.
Top three bits are E0 for a complete last byte; low five bits are 00 general/A1
match, 01 A2 match, 03 CRC error, 04 abort, 05 idle, 06 EOP, 07 short frame,
08 data overrun, 09 receive memory limit, 0A carrier loss, 0B result overrun.
Receiver stays active after a frame/CRC/short/abort result; idle, EOP, data or
result overrun, buffer exhaustion and carrier loss disable it.

## Commands

Set commands OR their mask into the register; reset commands AND the mask.

| Opcode | Operation | Parameters |
|---|---|---|
| A4 / 64 | Set/reset one-bit delay | Mask bit 7 |
| 97 / 57 | Set/reset non-DMA data mode | Mask bit 0 |
| 91 / 51 | Set/reset operating mode | Mask |
| A0 / 60 | Set/reset serial mode | Mask |
| A3 / 63 | Set/reset port B | Mask |
| 22 / 23 | Read port A/B | None; immediate result |
| C0 | General receive | Buffer length low/high |
| C1 / C2 | Selective receive / selective loop receive | Length low/high, A1, A2 |
| C5 | Disable receive | None |
| C8 / CA | Transmit frame / loop frame | Length low/high, buffered A, C |
| C9 | Transparent transmit | Length low/high |
| CC / CE / CD | Abort frame / loop / transparent | None |

Operating mask bits: 5 HDLC (seven ones abort; SDLC uses eight), 4 EOP
notification, 3 early Tx interrupt, 2 buffered A/C, 1 preframe sync, 0 flags
instead of idle ones. Serial mask bits: 2 internal loopback, 1 Tx clock to Rx,
0 NRZI. Port A bits 4:2 are external inputs, bit 1 CD pin, bit 0 CTS pin;
upper unused bits read zero. Port B bits 4:1 are external outputs, bit 0 RTS,
bit 5 FLAG DET; upper bits read zero. Modem signals retain physical active-low
polarity, also when read through the ports. Reset sets Port B bits 5:0 high.

In buffered Tx, count is information bytes and A/C come from parameters. In
unbuffered Tx, count includes A/C from the data path; only two parameters.
Transparent Tx sends precisely count bytes without flags, stuffing or FCS.
Receive strips FCS always; buffered receive retains A/C for result reads and
only transfers information bytes. Unbuffered receive transfers A/C as well.
Selective filtering checks only the first address byte against either match.
Rejected frames cause no data transfers or frame result. A valid accepted
frame does not disable receive. Streaming host bytes may precede CRC validation;
software must use the frame result before accepting them.

RTS asserts automatically during Tx unless software already holds it active.
CTS must be active to start; loss during a frame yields 0F and aborts. Carrier
loss on an enabled receiver yields 0A. Port B writes can hold RTS independently.
Loop Tx waits for received EOP unless flags are already active; completion and
abort return to one-bit delay. Selective loop receive clears delay and enables
flags after EOP. Protocol extensions beyond the first A/C bytes are software data.
EOP/GA is 01111111 (seven consecutive ones); the SDLC abort threshold is eight.
CC sends an eight-one abort, CE finishes with a flag before relay resumes,
and CD stops transparent transmission without adding a protocol character.

## Serial format

Bytes are sent least-significant bit first. The frame is 7E, A, C, information,
two complemented FCS bytes low-first, 7E. FCS starts FFFF, uses reflected 8408,
and includes A/C/information, not flags/stuffed zeros. The receive residue is
F0B8. Every run of five ones inside the frame is followed by a stuffed zero,
including across byte/FCS boundaries. Flags and aborts are never stuffed.
NRZI zero toggles the line; one retains it. Preframe sync emits two 00 bytes
in NRZI or two 55 bytes in NRZ. Flags can delimit back-to-back received frames.
Idle is fifteen or more consecutive ones after a frame; an isolated idle before
any frame does not disable reception. Short frames are ignored in buffered mode.

DPLL sample intervals are nominally 32 oversample ticks; transitions in the
four quadrants adjust the next interval by -2, -1, +1, +2. No transition leaves
the previously selected interval until the next transition (assumption A5).

## Assumption ledger

- A1: Single-cycle command/parameter consumption and edge-qualified stretched
  bus strobes are common-clock adaptations, not cycle-accurate microcode timings.
  Invalid/reserved commands and attempts to transmit while active are ignored.
- A2: Core mode settings are held constant during a frame; software must change
  modes with Tx/Rx inactive. Results snapshot buffered mode at publication.
- A3: Zero-length buffered Tx is a legal A/C-only supervisory frame. Zero-length
  unbuffered/transparent Tx completes without data. Length zero Rx accepts zero
  data and reports overflow if information arrives; it is not a 65536-byte code.
- A4: Rx bit delay and two-byte tail storage replace original internal timing;
  the maximum service latency is one data byte. Frame completion is published
  after the last data byte is read, keeping non-DMA INT/IRA unambiguous.
  No elastic frame RAM is added.
- A5: DPLL phase starts at zero after reset; the host must supply preframe sync
  or sufficient transitions before relying on recovered sampling. The helper's
  pulse-level interface requires external clock/pin adaptation.
  The datasheet does not detail transition-free interval retention; the helper
  retains its most recent corrected interval. Validation includes all 32 initial
  phases and bit periods 31–33 oversample ticks; no original-silicon jitter or
  acquisition-time equivalence is asserted.
- A6: A pending unread Rx result is replaced with code 0B upon another accepted
  frame result and Rx is disabled. A full Tx result queue retains older entries.
- A7: Intel's Figure 11 says receive remains active after an abort, while
  General Receive note 8 says abort disables it. This core follows Figure 11
  (active). That source disagreement is unresolved without original hardware.

Validation uses independent RFC/table CRC vectors, hostile serial streams,
two connected cores and the existing 8237A DMA controller. See the test plan.

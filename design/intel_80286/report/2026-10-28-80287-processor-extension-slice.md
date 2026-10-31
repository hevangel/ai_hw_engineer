# 80287 processor-extension exception and WAIT slice

Date: 2026-10-28  
Status at this checkpoint: partial functional implementation; successful ESC was not yet implemented. A later [D8 register command slice](2026-10-30-d8-physical-command.md) uses independent physical-286 traces; the data channel remains open.

## Source contract

### Additional port-role evidence — 2026-10-30

Intel's [iSBC 286/10A Hardware Reference Manual, October 1984](https://bitsavers.trailing-edge.com/pdf/intel/iSBC/147532-001_iSBC_286_10A_Hardware_Reference_Manual_Oct84.pdf),
table G-2, identifies the board's 80287 **word** ports: `00F8h` reads status
or writes opcode, `00FAh` transfers data, and `00FCh` transfers address.
[Intel patent 5,325,490](https://www.freepatentsonline.net/5325490.html),
table 1, independently describes the 80287 command port as `00F8h` and
the operand read/write port as `00FAh` in a 386SX-to-287 conversion.
These sources narrow the individual port roles beyond the earlier port-range
evidence. They do not establish the 286's exact command-word bit pattern,
the number and order of address words for each ESC, or PEREQ/PEACK timing;
they do not justify implementing a guessed successful ESC transaction.

The primary source is Intel's [80287 data sheet, February 1983](https://bitsavers.org/components/intel/_dataSheets/80287_Data_Sheet_Feb83.pdf).
Table 1 (PDF pages 2–3) defines BUSY as the executing indication and ERROR
as the unmasked-error indication. PEREQ is active high and means the 80287 is
ready for a data transfer; the extension withdraws it on PEACK acknowledgement
or on the actual transfer, whichever occurs first. PEACK acknowledges PEREQ
and can withdraw the request if no more transfers are needed.

The hardware-interface page (PDF page 4) specifies I/O addresses `00F8h`,
`00FAh`, and `00FCh`, NPS1 low/NPS2 high selection, CMD0 from latched A1, CMD1
from latched A2, and NPRD/NPWR transfer enables. Ports `00F8h–00FFh` are
reserved for this interface. The page also shows the shared data bus and CPU
status signals monitored by the extension. The data-transfer and data-channel
waveforms (PDF page 19) specify relative timing for PEREQ, PEACK#, NPRD/NPWR,
and shared data; the error-output waveform (PDF page 20) shows active-low
ERROR asserting before active-high BUSY deasserts.

The interrupt table and its discussion (PDF page 8) assign vector 7 to ESC
with MSW.EM or MSW.TS set and vector 16 to an unmasked processor-extension
error. Intel's [80286 and 80287 Programmer's Reference Manual, order
210498-005](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf),
printed page 3-30, says WAIT suspends until BUSY indicates completion and ESC
passes the instruction and location to the extension.

Intel 210760-002, *80286 Hardware Reference Manual*, Chapter 6, printed
pages 6-2–6-6, supplies the system-level protocol. BUSY is active high and
wired directly to the 80286; ESC checks EM/TS context, then waits for BUSY to
become inactive. ERROR is active low and may assert before BUSY falls. The CPU
issues one or more reserved-port I/O operations for ESC, independent of
IOPL/CPL and with no wait states. For operand transfers, the CPU initializes
its processor-extension data channel with memory bounds and direction. PEREQ
requests the transfer; PEACK# acknowledges it and is active during the first
bus operation. An operand transfer uses one I/O bus operation to the 80287
and one or two memory bus operations. Channel word transfers are indivisible;
the source also specifies their priority relative to LOCK, HOLD, execution
data and prefetch.

Figure 6-3 on printed page 6-6 (PDF page 216) narrows the transfer window:
channel requests may occur after ESC while BUSY remains high, and stop once
BUSY falls until another ESC executes. The manual specifies two bus cycles for
an even-address word and three for an odd-address word. This still does not
specify the per-instruction reserved-port byte sequence.

Intel's 1983 *Microprocessor and Peripheral Handbook*, iAPX 286/10 Chapter 4,
Table 1 (printed page 4-3), adds that the 80286 may be interrupted while
waiting for BUSY to become inactive. Its “Processor Extension Transfers”
section (printed page 4-31) identifies ports `00F8h`, `00FAh`, and `00FCh`,
and specifies a word I/O transfer at `00FAh` plus one or two memory operations
for a memory operand. It does not document the exact ESC command bytes or
port order. The handbook describes BUSY as becoming inactive HIGH, conflicting
with the active-high BUSY polarity in 210760-002 Chapter 6 and the 80287 data
sheet; only its interruptibility and transfer-count statements are used here.

## Implemented behavior

- Intel 210760-002, *80286 Hardware Reference Manual*, Chapter 6, printed pages 6-2–6-6, documents that BUSY is an active-high signal wired directly from the extension to the CPU. The core and native-CPU wrapper now use active-high `busy_i`; ERROR remains active low as `error_n_i`.
- WAIT (`9B`) checks TS first and raises restartable vector 7 without an error code. Otherwise it waits while BUSY is high. Once BUSY goes low, low `ERROR#` raises restartable vector 16; otherwise WAIT retires at its own PC.
- Eligible real-mode NMI and IF-enabled INTR are now accepted during WAIT's BUSY stall. The test verifies event entry without WAIT retirement and IRET to the instruction after WAIT while BUSY remains high. ASSUMPTION A25: the handbook does not state the saved IP for this case; this return address is not independently validated. See the [WAIT interruptibility report](2026-10-28-wait-interruptibility.md).
- ESC opcodes D8–DF decode a ModR/M byte. EM or TS raises restartable vector 7 first. Otherwise ESC waits while BUSY is high; after BUSY goes low, an asserted `ERROR#` raises restartable vector 16. The no-read-before-gate rule is checked for a memory ESC.
- A normal ESC still stops with development diagnostic code 3. It does not send the command or location to the 80287.

## Verification evidence

The focused `--processor-extension` Verilator case passes. It covers WAIT
stalling and exact retirement/successor PC, EM without TS on WAIT, #NM priority
over BUSY/ERROR# for ESC and TS for WAIT, and #MF from WAIT and ESC. Delayed
ERROR# is asserted while active-high BUSY remains high; both WAIT and ESC stay
suspended, then report restartable vector 16 at their own instruction PC when
BUSY falls. A memory ESC test confirms there is no operand data transfer
before the extension protocol exists. Focused command:

```sh
docker exec -w /work/design/intel_80286 \
  -e INTEL_80286_WORK_DIR=/work/design/intel_80286/work/processor_extension_busy_high_20261028 \
  dcd30140a9c0 sh -lc 'sh scripts/build_runner.sh && /work/design/intel_80286/work/processor_extension_busy_high_20261028/sim/Vintel_80286 --processor-extension'
```

The delayed-error assertions passed in this focused run.

The corrected complete `scripts/run_sim.sh` run exited 0 with this source.
Command:

```sh
docker exec -w /work/design/intel_80286 \
  -e INTEL_80286_WORK_DIR=/work/design/intel_80286/work/processor_extension_busy_high_full_sim_20261028 \
  dcd30140a9c0 sh scripts/run_sim.sh
```

The protected-mode replay manifest reports `PASS` for all 79 cases at `work/processor_extension_busy_high_full_sim_20261028/protected_mode_sim_20261028T125529Z/build_manifest.json`. The connected native-CPU run also passed. These are simulation results, not whole-chip acceptance.

Current-source Yosys 0.69 synthesis exited 0 across all 12 configured targets:
both core configurations, the event/segment/code/access components, cached
reference, native bus, 82288 and connected native CPU. Every target's three
`check -assert` reports say `Found and reported 0 problems.`; no log contains
`ERROR:` and all 12 JSON netlists were written. The main core, native-beat core
and connected native-CPU targets took 402.16, 429.55 and 416.33 seconds.
Their logfile SHA-256 values are `69aebb0c8b5a8d632cad58c1302249ce4226510e97da267855ab430c54d80288`,
`7d8b0da4d0d6f9bf62e2bfbecec2168725e6404d9f867e62b8d7d9c752b82135` and
`c7de655d623c8d7b609af7f3b7863d401ab20fc49dd87876fbcf1e364dbec753`.
The previous synthesis result used the incorrect active-low BUSY model and
does not verify this corrected source. Command:

```sh
docker exec -w /work/design/intel_80286 \
  -e INTEL_80286_WORK_DIR=/work/design/intel_80286/work/processor_extension_busy_high_full_synth_20261028 \
  dcd30140a9c0 sh scripts/run_synth.sh
```

Current logs and netlists are under
`work/processor_extension_busy_high_full_synth_20261028/synth/`.

The ongoing whole-core PDR is an earlier 21-file source snapshot, not evidence
for this 80287 slice or the native wrapper. At 13:16:02 UTC it reached frame
23 with 316/411 assertion outputs proved and 27 timeout retries in the
current anytime pass. It has no counterexample or terminal result. The
aggregate formal audit remains 36/40; the depth-12 induction result is UNKNOWN
and the full `run_all.sh` release gate remains open.

## Remaining work and limits

The native wrapper does not yet implement PEREQ/PEACK# handshaking, reserved-port decode, extension command/data routing, or ESC transaction timing. Automatic extension LOCK, prefix legality, ESC memory-fault priority, protected/native WAIT event timing and ESC interruption remain open. WAIT's saved-IP assumption A25 also needs an independent 286 source or trace. The whole-core PDR job was launched from an earlier 21-file snapshot and does not cover this 80287 change or the native wrapper; its progress is not proof of this slice. The aggregate formal audit and full release gate remain open.

An additional primary-source check used Intel's *1986 Microsystem Components
Handbook: Microprocessors, Volume I*, printed page 4-31 ([scanned page in
Internet Archive](https://archive.org/details/bitsavers_inteldataBystemComponentsHandbookMicroprocessorsVo_75373729/page/n753/mode/1up),
[PDF page 753](https://bitsavers.org/components/intel/_dataBooks/1986_Intel_Microsystem_Components_Handbook_Microprocessors_Volume_I.pdf#page=753)).
The page was visually reviewed through Playwright CLI. It confirms the three
reserved I/O addresses, the IOPL/CPL bypass, PEREQ use for memory ESC operands,
the `00FAh` word transfer plus one or two memory cycles, and the local-bus
priority of extension transfers. It does not show the byte-level command or
port sequence for individual ESC forms, so the successful transaction remains
source-blocked.
The source checkpoint is recorded in [issue comment 6473621922](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6473621922).

Playwright CLI inspection also found Intel AP-113, *Getting Started With the
Numeric Data Processor* (1981), printed page 9. It covers an 8087 with an
8086/88 host and its S2:S0/QS1:QS0 interface, so it is not authority for the
80286/80287 reserved-port sequence. The inspected 80286 Hardware Reference
Manual, Programmer's Reference Manual and 1986 handbook establish that ESC
sends the instruction and location to the extension, identify the reserved-
port range and channel handshake, and describe operand-transfer timing. They
do not provide a complete byte-by-byte reserved-port command sequence for
each ESC form. Locate a source that documents that sequence or an independent
pin trace before implementing successful ESC transactions; do not infer
command payloads or port order from the address map alone.

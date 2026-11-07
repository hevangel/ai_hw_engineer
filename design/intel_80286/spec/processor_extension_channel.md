# 80286 processor-extension data channel

Intel's [80286 Hardware Reference Manual, 210760-002, chapter 6](https://www.bitsavers.org/components/intel/80286/210760-002_80286_Hardware_Reference_Manual_1987.pdf) specifies the transfer order:
- For a load, memory is read before the extension write.
- For a store, the extension is read before memory is written.
- An aligned word uses one memory and one I/O operation; an odd-addressed word
  uses two memory operations.
- PEACK# is active during the first operation of each word.
- A complete transfer is indivisible. Its priority relative to HOLD, LOCK and
  other operations is specified there.

The [80287 data sheet](https://bitsavers.org/components/intel/_dataSheets/80287_Data_Sheet_Feb83.pdf)
specifies active-high PEREQ and active-low PEACK#.

## Connected core channel

The 1985 iAPX 286 Programmer's Reference Manual, Appendix A ("Processor
Extension Transfers"), states that an ESC with a memory operand enables the
CPU to accept PEREQ. The CPU determines the operand start address and the
read/write status, and moves each operand word through port 00FAh.

The core (`pereq_i`, `peack_n_o`, states `PEDC_*`) implements this:

- **Arming.** An ESC memory form arms the channel when its command phase
  retires. It latches the operand offset and its segment's base, limit and
  expand-down attribute. A register-form ESC disarms the channel.
- **Direction.** It follows the 80287 encoding:
  - Stores are D9 /2,/3,/6,/7; DB /2,/3,/7; DD /2,/3,/6,/7; and
    DF /2,/3,/6,/7.
  - Every other memory form is a load.
- **Transfers.** Each accepted request moves one word and then advances the
  offset by 2:
  - A load reads memory, then writes FAh.
  - A store reads FAh, then writes memory.
  - The memory side uses the existing byte/word beat decomposition, so an
    odd-addressed word takes two memory operations in native mode.
- **PEACK#.** `peack_n_o` is low during the first operation of each word.
- **Interrupt 9 (9.6.3).** A word that does not fit in the latched segment
  raises the processor-extension segment overrun interrupt and disarms the
  channel. This includes a word that runs past FFFFh. The interrupt is
  external, has no error code and is not restartable. 9.6.3 defines it as an
  asynchronous external interrupt, so its saved IP is the current boundary.
  The 5-6 summary instead says it "points at the instruction that caused" the
  overrun; that conflict is recorded under A33.
- **End of channel.** The channel ends when BUSY falls after the extension has
  been seen BUSY, or when the next ESC re-arms or disarms it.
- **Protected mode.** A protected-mode memory ESC whose first operand word is
  not inside a usable segment raises #GP(0), or #SS(0) for an SS operand,
  before its command phase.

ASSUMPTION A32: requests are serviced at instruction boundaries, during HLT,
and while WAIT or ESC is held on BUSY, rather than between arbitrary bus
cycles of an instruction. The PRM's local-bus priority list places operand
transfers above EU data and prefetch but below LOCK and HOLD. The first-word
segment check in protected mode follows the general memory-operand rule.
Writes into read-only segments are not checked. Validate both against a
physical 80287 system.

ASSUMPTION A33: interrupt 9 saves the CS:IP of the boundary at which it is
detected, as an external interrupt (9.6.3), rather than the ESC that armed
the channel.

ASSUMPTION A26: a new PEREQ is accepted only after a sampled low separates it
from the previous accepted request. The first request after arming may
already be high. The data sheet says the extension withdraws PEREQ on PEACK#
or the data transfer, but it does not establish whether the CPU must observe
an intervening low on its sampling clock. Validate A26 against a real 80287
or an independent pin trace before sign-off.

## Standalone engine

`intel_80286_pedc` remains a separately verified standalone transaction engine.
It is not instantiated in the core. The core channel above reuses the core's
own memory engine so that both the byte-compatible and native beat interfaces
are covered.

## Verification

`Vintel_80286 --pedc` runs a small 80287 stand-in that drives BUSY and PEREQ
and serves port FAh. It runs three scenarios in both READY modes:
- FLD qword (four loads, memory before FAh).
- FSTP tbyte at an odd address (five stores, FAh before memory).
- FLD tbyte at FFFBh, whose third word raises interrupt 9 after two
  transfers, with no access to the overrunning word.

It also checks PEACK# on each word's first operation and the exact operand
words.

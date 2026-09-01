# Test Plan: Intel 8251 / 8251A

## Overview

One self-checking testbench, `tb/tb_intel_8251.sv`, run under xezim with
`--error-exit`. There is no UVM layer; the design has a single CPU-side
interface and two serial lines, and a direct testbench keeps the checking
visible. Entry point: `scripts/run_sim.sh`.

## Verification goals

1. Every output is the specified function of the registered state, in every
   cycle, for every programmed configuration.
2. Transmit framing on the wire matches the programmed geometry: start bit,
   character length, parity polarity, and stop-phase length.
3. Receive framing on the wire produces the right character and the right error
   flags, including short character lengths and their zero-filled high bits.
4. The CPU-visible contract holds: programming sequence, status composition,
   handshake outputs, buffer semantics, and one-shot command actions.
5. Same-cycle races resolve as the specification says.

## Testbench architecture

Two independent mechanisms run against the same stimulus.

**Lockstep reference model.** A software model of the whole device is stepped
one cycle ahead of each sampling edge and the entire output interface (`data_o`,
`data_oe`, `txd`, `txrdy`, `txempty`, `rxrdy`, `syndet_o`, `syndet_oe`, `rts_n`,
`dtr_n`) is compared after the edge. Every right-hand side in the model reads a
snapshot of the previous state, so the blocking-assignment model reproduces
non-blocking hardware semantics while still letting later writes override
earlier ones exactly as the RTL does. This catches any deviation in the output
derivation or in the effect ordering, but it is structurally similar to the RTL
and so is not treated as sufficient on its own.

**Wire-level serial driver and monitor.** Both are written from the frame
definition in the specification and know nothing about the DUT's internals. The
driver holds `RxD` at each bit value for the programmed number of baud enables
and can inject a wrong parity bit or a low stop bit on request. The monitor
finds the start bit on `TxD`, then samples at the centre of every bit using the
programmed geometry, decodes the character, and independently recomputes the
expected parity bit. Character-level checks compare against what the CPU wrote
or what the driver sent.

The baud-rate enables are produced by a testbench-side divider so both a
one-enable-per-cycle stream and a sparse stream can be exercised.

## Directed tests

| Phase | What it establishes |
|---|---|
| Reset and un-programmed state | `TxD` idles high, `SYNDET` is not driven, `RTS`/`DTR` inactive, status byte reads its reset composition |
| Asynchronous 16x, 8 bits, even parity, 1 stop | Command word drives `RTS`/`DTR`, `TxRDY` asserts with `TxEN`, five characters decoded at the wire including `00` and `ff` |
| Transmit handshake and CTS gating | `TxRDY` and `TxEMPTY` status timing, no frame starts while `CTS` is inactive, the buffered character survives the backpressure |
| Receive path | Two clean frames decoded, `RxRDY` set on delivery and cleared by the data read, no error flags |
| Parity, framing, and overrun errors | Each flag set by the matching wire-level defect, the character still delivered, overrun keeps the newest character, error reset clears all three |
| Break detection and transmission | One all-zero frame is not a break, two are, break clears when `RxD` returns high, `SBRK` forces `TxD` low and releases it |
| Modem status and short characters | `DSR` visible in status; 5-bit with 2 stop bits, 6-bit with odd parity and 1.5 stop bits, 7-bit at 64x, each checked at the wire in both directions |
| Sparse baud-rate enables | A full transmit and receive round trip with one enable every three core cycles |
| Asynchronous 1x division | Start bit visible in the cycle after the write, frame completes and `TxEMPTY` returns |
| Synchronous single sync character | Underrun flagged, sync pattern detected through a serial loopback, status read clears the sync flag, fill character delivered, buffered character clears underrun, enter hunt re-acquires sync |
| Synchronous double sync character | Sync acquired only on character 1 immediately followed by character 2, fill alternates between both |
| Synchronous external sync detection | `SYNDET` is an input, a pulse on it starts character assembly, an idle line assembles as all ones |
| Synchronous framing with parity | Sync acquired with parity enabled and no parity error on a self-generated stream |

Framing-error and break frames leave `RxD` low past the point where the receiver
samples the stop bit, so the receiver re-triggers on the remainder of that bit
exactly as the historical part does. A resynchronization helper holds the mark
for more than a character time, drains the spurious character, and clears the
flags. This is deliberate: it exercises and documents real behavior instead of
hiding it.

## Deterministic pseudorandom regression

A 16-bit LFSR seeded with `0x8251` drives 2048 operations drawn from: full
reprogramming with a pseudorandom mode word (including synchronous modes that
consume sync characters), transmit data writes, status reads, receive data
reads, command words with the internal-reset bit masked off, `RxD` changes held
for a pseudorandom number of enables, modem and external-sync input changes, and
idle runs with a pseudorandom enable divider. Every cycle of the regression is
checked by the lockstep comparison, so the regression explores configuration and
timing combinations the directed phases do not enumerate.

The sequence is fully deterministic: the same seed, the same operation count, and
the same result on every run.

## Functional coverage accounting

The testbench asserts minimum counts before declaring success, so a silently
truncated run fails rather than passing:

- at least 12 mode programmings;
- at least 10 transmit frames decoded at the wire;
- at least 10 receive frames driven at the wire;
- at least 3 sync detections;
- at least one parity error, one framing error, one overrun, and one break;
- at least 60 CPU reads and 60 CPU writes;
- at least 12000 whole-interface comparisons.

## Pass/fail criteria

Every mismatch prints the cycle, the field, the actual value, and the expected
value, and increments a failure counter. The run passes only when the counter is
zero, in which case the testbench prints `TEST PASSED` and calls `$finish`;
otherwise it calls `$fatal`. `run_sim.sh` additionally greps the log for the
seed line, the result line, `Failures: 0`, and `TEST PASSED`, so a simulation
that dies early cannot be mistaken for a pass.

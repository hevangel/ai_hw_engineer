# Intel 8251 / 8251A Coverage Report

## Simulation coverage

From `work/sim/intel_8251.log`, produced by `scripts/run_sim.sh`:

```text
8251 simulation result: 13530 cycles, 13530 interface checks, 135418 field checks
CPU reads: 564, CPU writes: 1035, mode programmings: 217
TX frames decoded: 10, RX frames driven: 11, sync detections: 3
Error events: parity 1, framing 1, overrun 1, break 1
Failures: 0
TEST PASSED
```

Every one of the 13530 sampled cycles compares the complete output interface
against the reference model, which is where the 135418 field checks come from:
ten output fields per cycle plus the directed character and status checks.

### Directed scenario closure

| Scenario | Closed by |
|---|---|
| Reset and un-programmed state | `TxD` high, `SYNDET` undriven, `RTS`/`DTR` inactive, reset status byte |
| Asynchronous framing, 5 to 8 data bits | Wire-level frames at 5, 6, 7, and 8 bits, each decoded and compared |
| Parity generation and checking, both polarities | Even-parity 8-bit and odd-parity 6-bit frames in both directions |
| Stop-bit lengths 1, 1.5, and 2 | 8-bit 1-stop, 6-bit 1.5-stop, 5-bit 2-stop frames decoded at the wire |
| Baud division 1x, 16x, 64x | 1x start-bit and completion timing, 16x throughout, 64x 7-bit frame |
| Sparse baud enables | Full round trip with one enable every three core cycles |
| Transmit handshake | `TxRDY` and `TxEMPTY` status transitions across a character |
| `CTS` gating | No frame launches while `CTS` is inactive; the buffered character survives |
| Send break | `TxD` forced low and released |
| Parity error | Frame with an inverted parity bit; flag set, character still delivered |
| Framing error | Frame with a low stop bit; flag set |
| Overrun error | Two frames with the first left unread; flag set, newest character kept |
| Error reset | All three flags cleared by the command bit |
| Break detection | One all-zero frame does not signal, two do, clears when `RxD` returns high |
| Receive character width | 5-bit character delivered right-aligned with zero-filled high bits |
| Modem control | `RTS` and `DTR` from the command word, `DSR` in status |
| Internal reset | Returns to the un-programmed state, `SYNDET` stops being driven |
| Synchronous single sync character | Detection through loopback, fill delivery, status-read clearing |
| Synchronous double sync character | Detection requires character 1 followed immediately by character 2 |
| Synchronous external sync detection | `SYNDET` is an input, a pulse starts assembly |
| Synchronous underrun | `TxEMPTY` flags fill, clears while a buffered character shifts out |
| Enter hunt | Sync flag cleared and sync re-acquired |
| Synchronous framing with parity | Sync acquired and no parity error on a self-generated stream |
| Configuration and timing combinations | 217 mode programmings across the 2048-operation pseudorandom regression |

The minimum-count assertions listed in `plans/testplan.md` all hold, so the run
cannot report success after a truncated sequence.

## Formal coverage

From `work/formal/cover/PASS`, produced by `scripts/run_formal.sh cover`. All 15
cover statements are reached; the step column is the witness length found by the
solver.

| Cover | Target | Step |
|---|---|---:|
| C1 | configured for asynchronous framing | 3 |
| C2 | configured for synchronous framing | 4 |
| C3 | transmit character reaches the stop phase | 12 |
| C4 | complete asynchronous frame driven, transmitter returns to idle | 13 |
| C5 | received character available to the CPU | 12 |
| C6 | parity error | 12 |
| C7 | framing error | 12 |
| C8 | overrun error | 16 |
| C9 | break detected and driven on the shared pin | 20 |
| C10 | sync pattern detected, receiver has left hunt | 6 |
| C11 | synchronous underrun drives sync-character fill | 6 |
| C12 | status read drives the CPU bus | 2 |
| C13 | receive-buffer read returns a non-zero character | 11 |
| C14 | transmit buffer loaded while a character is in flight | 6 |
| C15 | internal reset returns the programming pointer to the mode instruction | 4 |

Because every cover is reachable, the safety and equivalence assertions in
`work/formal/prove` are non-vacuous: the states they constrain are states the
design actually enters.

## Coverage limitations

- There is no code-coverage or toggle-coverage database. The simulator in the
  project container does not produce one, so coverage is argued from the directed
  scenario table, the whole-interface comparison count, and the formal cover
  results rather than from an instrumented metric.
- Formal coverage does not include whole serial frames at 16x or 64x division. A
  single character spans roughly 176 or 700 baud enables, well past a useful
  proof depth. Frame-level correctness comes from the wire-level monitor and
  driver in simulation, which observe complete character times at every
  programmed geometry.
- The pseudorandom regression reprograms the device with pseudorandom mode words
  but does not attempt to reach every one of the 256 mode-instruction encodings.
  All four baud-factor encodings, all four character lengths, both parity
  polarities, all stop-bit encodings, and both sync-character counts are covered
  by the directed phases; the regression adds combinations rather than
  enumerating them.
- Cross-coverage between synchronous mode and the sparse-baud-enable divider is
  reached only through the regression, not by a directed phase.

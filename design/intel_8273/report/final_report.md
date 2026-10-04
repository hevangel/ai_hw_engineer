# Intel 8273 verification report

Validated on 2026-10-03 with the repository's `ai-hw-engineer:latest` Linux
container. The complete `scripts/run_all.sh` flow passed for the final RTL.

## Implemented behavior

The controller implements the Intel command/parameter/result interface, separate
transmit and receive data latches, DMA and non-DMA service, result interrupts,
modem ports and actual bit-serial HDLC/SDLC framing. Separate engines implement
NRZ/NRZI, stuffing across byte boundaries, FCS generation/checking, A/C buffering,
selective receive, abort handling, transparent transmit, preframe sync and SDLC
loop relay. A 32x sampling helper supplies recovered receive strobes.

The programming reference is Intel 210479-004, October 1992. Independent wire
vectors use RFC 1662 framing and Python's C `binascii.crc_hqx` implementation,
with input/output reflection; the generator never reads the RTL. Source links,
the 1977 announced-availability qualification and oracle provenance are in the
[design overview](../README.md) and [reference notes](../references/README.md).
The requested 908-page 1981 Peripheral Design Handbook is archived in the shared
repository `references/` folder with source and SHA-256 recorded there.

## Results

| Check | Result |
| --- | --- |
| Verilator RTL lint | `--lint-only -Wall`, no RTL warning suppressions, passed |
| Formal BMC | ABC bmc3, depth 40, passed |
| Unbounded control proofs | ABC PDR, passed |
| Non-vacuity covers | Tx completion step 68, successful Rx step 66, carrier-loss error step 18; all passed after reset |
| Directed serial/bus regression | Verilator and Xezim, seeds 1, 42, 2026; each run 401 frame exercises and 93,759 checks |
| Maximum-length frame | Both simulators: 65,535 information bytes, 532,776 wire bits, 860,465 checks per run |
| Real DMA integration | Both simulators: two 8273 endpoints, external full-duplex NRZI link, actual 8237A using all four channels; 96 transfers and 63 checks per run |
| DPLL receive sweep | Both simulators: all 32 starting phases at bit periods 31, 32 and 33 oversample ticks; 96 frames and 4,512 checks per run |
| UVM | Xezim: 628 scoreboard observations, zero errors/fatals; all six defined command bins hit |
| RTL coverage | 94.20% statements, 85.36% branches, 82.29% toggles; see [coverage report](coverage_report.md) |
| Yosys synthesis | Integrated core and all three helper tops passed `hierarchy -check`, generic synthesis and `check -assert` |

The integrated synthesized hierarchy contains 2,753 generic cells, including
59 DPLL, 782 receiver and 579 transmitter cells; the top has 1,333 cells including
its three submodule instances. These are generic synthesis statistics, not
device area or timing results. Yosys emits one informational warning that the
five-byte receive-result array is replaced with registers. UVM emits 28
`UVM/COMP/NAME` warnings from the library's component-name checks under this
simulator configuration; they are reported rather than suppressed.

Tool versions: Verilator 5.052 (2026-09-05), Xezim 0.11.0 (`6558a1e`),
Yosys 0.69 (`9f75ca1f9`), SymbiYosys 0.69, Z3 5.1.0. UVM is the repository's
1800.2-2017 library. Generated logs, traces, coverage databases and netlists stay
in ignored `work/`; scripts regenerate them.

## Defects caught by this verification suite

- Rx frame results initially hid the last non-DMA byte. Results now publish only
  after the pending host byte is consumed; stretched reads continue to drive the
  captured latch so the 8237's later memory-write phase sees the correct byte.
- The maximum-length regression required a 17-bit decoded-body count to include
  65,535 information bytes plus A/C and FCS without wrapping.
- DPLL phase/rate sweeps exposed lost bits when the helper reset its interval to
  32 during transition-free runs. The tested retention behavior is assumption A5.
- Source review and loop tests distinguish seven-one EOP, normal eight-one
  transmit abort, flag-terminated loop abort and immediate transparent abort.
  Relay selection now waits for a serial edge so it preserves the final flag bit.

## Limits and remaining uncertainty

This is a common-clock functional core with pin-edge strobes, not original
electrical or internal microcode timing. Early transmit notifications work, but
queued single-flag frame chaining and automatic supervisory repetition are
outside this version. Partial-byte receive data is not delivered. The one-byte
host service latency requires prompt DMA/non-DMA service. No physical FPGA,
original-silicon comparison, timing closure or analog clock-recovery validation
was performed.

Formal proves control/handshake invariants, not complete HDLC semantic equivalence.
The DPLL sweep validates the stated 31–33-tick test envelope; it does not establish
original-silicon jitter or acquisition-time equivalence. Intel's Figure 11 and
General Receive note 8 disagree about whether an abort disables receive; this
core follows Figure 11 and keeps it active (assumption A7). The complete
[assumption ledger](../spec/spec.md) records this and other adaptations.

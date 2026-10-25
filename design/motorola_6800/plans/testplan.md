# Test Plan — Motorola MC6800

## Gates (all must pass; run via `scripts/run_all.sh`)

| Gate | Script | Pass criterion |
|------|--------|----------------|
| Lint | `run_lint.sh` | `verilator --lint-only -Wall` clean (RTL and TB) |
| ISA vectors | `run_sim.sh` | 1951/1951 boundary checks (pc,a,b,ix,sp,cc) equal the independent ISS; final 64 KiB memory equals `gold_mem.hex`; 0 errors |
| Third-party software | `run_software.sh` | All 50 vendored hakanrw/mc6800 programs reach their self-loop with result windows byte-identical to the oracle's |
| Formal | `run_formal.sh` | `bmc`, `prove`, `cover` tasks all DONE (PASS) |
| Synthesis | `run_synth.sh` | Yosys generic `synth` clean |

## ISA vector coverage (oracle-audited)

- All 197 documented machine codes executed (the generator fails the build
  if any is missing).
- Every documented opcode × addressing-mode pair, with pseudorandom
  register/flag setups biased to flag corners (00/01/7F/80/FF).
- DAA over the BCD corner-value set with both C states (ADD and ABA paths).
- All 15 branch conditions, deterministically forced taken and not-taken.
- Interrupt scenarios: SWI; WAI woken by NMI; WAI woken by IRQ; IRQ
  preemption of straight-line code; level-IRQ re-entry with handler-side
  deassert; NMI nesting inside an IRQ handler.

## Formal properties (formal/motorola_6800.sby)

- Reset vector addresses; fetch discipline; vector mux (IRQ/SWI/NMI) from
  the latched vector, not re-sampled.
- Interrupt-frame push addressing (write at SP, counter walks 7 bytes).
- JSR/BSR return-address byte order (PCL first).
- RTI pull order; RMW read/write address stability.
- WAI halt state consistency; CC bits 7-6 always 1.
- BMC-only bounded progress: the sequencer always returns to FETCH within
  30 cycles (proves no deadlock on any bus content).
- Cover points for every vector, the wait state, frame boundaries, and
  masked-IRQ pending.

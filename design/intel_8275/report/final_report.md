# Intel 8275 verification report

The 80-column functional controller passed the complete flow on 2026-10-02 (America/Vancouver):

```sh
sh design/intel_8275/scripts/run_all.sh
```

Toolchain: project `ai-hw-engineer:latest`, Verilator 5.052, Xezim 0.11.0, Yosys 0.69, SymbiYosys 0.69 and Z3 5.1.0. See [specification](../spec/spec.md) for behavioral scope and assumptions.

| Check | Result |
|---|---|
| RTL `verilator --lint-only -Wall` | PASS, no waivers |
| Timed testbench lint | PASS; only testbench BLKSEQ/PROCASSINIT/UNUSEDSIGNAL waivers |
| BMC | PASS, depth 32, ABC bmc3 |
| Unbounded proof | PASS, ABC PDR |
| Reachability | PASS, all 10 cover goals, within depth 110 |
| Verilator pin tests | PASS, seeds 1/42/2026 |
| Xezim pin tests | PASS, identical per-seed counts |
| Xezim UVM | PASS, 13 CPU reads, 64 displayed cells, 48 DMA bytes; 0 errors/fatals |
| UVM command / raster coverage | All 8 command bins and all 4 HRTC×VRTC combinations |
| Yosys full-capacity synthesis | PASS, `check -assert`, 6,154 generic cells |
| Measured RTL coverage | 100% statements, 98.63% branches, 89.53% toggles |

Pin-suite exact check counts: seed 1: **2,436,556 checks / 100,932 cells**; seed 42: **2,598,740 / 96,820**; seed 2026: **2,457,464 / 96,535**. Each observes 72 inter-burst spacing boundaries. This includes maximum 80-column/64-row/16-line geometry, seeded DMA stalls, all 64 field combinations in both visibility modes, all eleven graphics using independent vectors, all cursor formats and exact blink divisors, light pen, spaced rows, top/bottom blanking, interrupt control, parameter errors, FIFO wrap, invisible final-cell replacement, delayed stop dummy bytes, EOS after EOR, underrun recovery, held strobes and concurrent bus events.

Formal uses a four-column instance with unrestricted safety-task programming. It proves storage consistency at a symbolic bank/address, safe ordinary DMA writes, buffer/parameter bounds, request gating, blanking and held-strobe behavior. Its cover-only environment drives legal bus programming and DMA; those constraints are absent from BMC/prove. Ten goals include DMA, replacement, buffer display, graphics, cursor, LP, IRQ, underrun, symbolic storage and a later frame. Reduced-capacity formal plus full-capacity simulation/synthesis is the actual verification boundary.

Verification caught a false underrun when the final byte arrived on the exact row boundary. The RTL now treats that same-cycle completion as ready for display; a pin regression checks its first character and DU status. Other corrected test expectations involved cold-start status, preset entering HRTC on a one-column screen, and frame-wide EOS blanking. None is an escaped defect: all were found within this design's own suite before submission.

## Remaining limits

* Electrical delays, synchronization, character ROM and dot serializer are external. This is a synchronous functional recreation, not physical pin timing equivalence.
* Historical terminal firmware and physical-silicon differential testing have not been run. Graphics expectations come from an archived MAME table cross-checked visually against Intel, while the remaining directed behavior follows the Intel datasheet.
* Xezim/UVM emits 25 library component-name validation warnings, including UVM-created ports. They are retained in the log; there are zero UVM errors and fatals.
* Coverage omissions are documented in the [coverage report](coverage_report.md). Generic cell count is not a technology-mapped area or clock-frequency estimate.
* The prior 8237A PR is independent and unmerged. This design uses a DMA BFM; no integrated 8237A/8275 system or floppy system is claimed.

Evidence is under ignored `work/`: `final_flow.log`, `sim/`, `uvm/`, `formal/{bmc,prove,cover}/`, `coverage/rtl.json`, `synth/{synth.log,netlist.json,netlist.v}`. Scripts fail if completion markers are absent or any formal/synthesis step fails.

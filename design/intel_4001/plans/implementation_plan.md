# Implementation Plan: intel_4001

## Overview

The Intel 4001 is the MCS-4 family's 2048-bit (256 x 8) mask-programmable
ROM combined with a 4-bit I/O port on one chip. This plan describes the RTL
reconstruction in `src/intel_4001.sv`: a single synchronous module that
latches multiplexed bus addresses, drives fetched instruction nibbles, and
implements the SRC/WRR/RDR ROM-port I/O protocol, timed to interoperate
directly with the verified `intel_4004` reconstruction on branch
`design/add-intel-4004`. The behavioral contract is `spec/spec.md`.

## Design Decomposition

One module, `intel_4001` (a separate package proved unnecessary: the phase
encoding is a pair of `localparam` lists kept identical across the RTL,
formal properties, cover harness, and testbench, each file carrying its own
copy so no file depends on compilation order).

### State elements (all reset-dominant, one write per clock)

| Register | Width | Reset | Function |
|----------|-------|-------|----------|
| `phase` | 3 | A1 | Instruction-cycle period counter, locked to `sync` |
| `addr_q` | 8 | 0 | Latched ROM word address (A1 low nibble, A2 high nibble) |
| `cm_rom_seen` | 1 | 0 | CM-ROM sampled at the A3 edge; qualifies M1/M2 driving |
| `fetch_sel_q` | 1 | 0 | A3 chip-number nibble == `CHIP_NO` (with CM-ROM) |
| `opr_q`, `opa_q` | 4, 4 | 0 | Snooped fetch (OPR at M1, OPA at M2) |
| `io_sel_q` | 4 | 0 | SRC X2 select nibble (ROM-port chip number) |
| `port_q` | 4 | n/a | I/O output latch; cleared by `clr_n` only, never by `rst_n` |

`rst_n` clears everything except `port_q` (spec 6.2: on the real part RESET
clears static flip-flops and inhibits data out, while the separate CL pin
clears the I/O output flip-flops).

### Combinational logic

- `fetch_selected = fetch_sel_q && cm_rom_seen` — qualifies M1/M2 drive.
- ROM read: `rom_word = ROM_FLAT[addr_q*8 +: 8]` — a 256:1 8-bit mux over
  the packed mask contents. In simulation/synthesis `ROM_FLAT` is the
  `ROM_INIT` parameter; in formal mode it is an `anyconst` free constant so
  proofs hold for every mask pattern (parameterized contents, not sampled).
- `io_selected = io_sel_q == CHIP_NO`.
- `rdr_value = (IO_DIR & port_q) | (~IO_DIR & port_i)` — output pins read
  the latch, input pins read the pin.
- Bus output mux per spec 7.4: M1/M2 word nibbles when fetch-selected;
  `rdr_value` at X2/X3 when RDR is snooped and `io_selected`; otherwise
  released (`data_oe` = 0, `data_o` = 0).
- Snooped decodes: `s_src` (OPR = 0010, OPA[0] = 1), `s_wrr` (OPR = 1110,
  OPA = 0010), `s_rdr` (OPR = 1110, OPA = 1010).

### Phase sequencer

```
next = sync ? A2 : (phase == X3 ? A1 : phase + 1)
```

`sync` marks A1 of every cycle; treating it as a re-lock point keeps the
chip aligned with the CPU even if their resets release at different times.

### Update rules (one write per register per clock)

- A1 edge: `addr_q[3:0] <= data_i` when `cm_rom`.
- A2 edge: `addr_q[7:4] <= data_i` when `cm_rom`.
- A3 edge: `fetch_sel_q <= (data_i == CHIP_NO)`, `cm_rom_seen <= cm_rom`.
- M1 edge: `opr_q <= data_i`. M2 edge: `opa_q <= data_i` (all chips snoop
  every fetch; the selected chip is the driver but the values are identical
  bus-wide).
- X2 edge of SRC: `io_sel_q <= data_i` (X3 data ignored, per the manual).
- X3 edge of WRR with `io_selected`: `port_q <= data_i`.
- Any edge with `clr_n` low: `port_q <= 4'h0` (clear wins; CL and a WRR
  commit on the same edge resolve to clear, documented behavior).

## Parameters

| Parameter | Default | Rationale |
|-----------|---------|-----------|
| `CHIP_NO` | 4'h0 | The metal-option chip number; models ordering option 1 |
| `IO_DIR` | 4'b1111 | Per-pin direction metal option; models ordering option 2 |
| `ROM_INIT` | see RTL | 2048-bit packed mask contents; models ordering option 3 |

## Integration Contract

Timed against `design/add-intel-4004:design/intel_4004` (RTL + testbench
memory model): address nibbles at A1 (low) / A2 (high) / A3 (chip number)
under `cm_rom`; word nibbles at M1 (high) / M2 (low); SRC select at X2;
WRR data stable X2-X3 with latch at the end of X3; RDR driven at X2 and X3
and sampled by the CPU at the end of X3. Two documented deviations from the
1973 manual's command-line qualification are analyzed in spec 10.2 and
chosen for compatibility with both the historical and reconstructed CPU.

## Risks

- **Yosys + SVA**: only immediate assertions inside clocked `ifdef FORMAL`
  blocks are used (concurrent SVA is rejected).
- **Simulator NBA ordering**: every register is written exactly once per
  clock edge from a single commit block; no default-then-override patterns.
- **ROM size in proofs**: formal replaces the constant mask with an
  `anyconst` flat vector; assertions observe one `anyconst` address so the
  solver's burden stays small even though contents are fully free.
- **Lint strictness**: all literals and extensions explicitly sized;
  `function automatic` for any helper; unpacked ranges `[0:N-1]`.

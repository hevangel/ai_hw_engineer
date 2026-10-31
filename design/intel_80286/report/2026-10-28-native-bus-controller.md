# Native local-bus controller component

Status: the standalone CPU-pin cycle controller passes its directed component
regression and a generic Yosys synthesis/check. It is not instantiated by the
`intel_80286` core. The existing core still exposes one-byte requests, so this
component is not evidence of an integrated or complete 80286 native bus.

## Implemented component boundary

`src/intel_80286_native_bus.sv` accepts already scheduled physical beats of
one byte or two bytes. An even-address word uses both lanes in one beat; an
odd-address logical word must be supplied as two one-byte beats at consecutive
addresses. Single-byte write data and read data are lane-aligned on D15:D0.
`READY#` low completes `Tc`; while high, the controller holds the captured
address, lane selection and write data stable. Status is valid in `Ts`.

The directed test checks memory instruction/data and I/O status tuples, both
byte lanes, even-word beats, the two-beat odd-word case, repeated READY waits,
bus release and return around HOLD, LOCK blocking HOLD, two consecutive INTA
cycles with vector capture on the second completion, and distinct HALT and
shutdown status using A1. Odd-address two-byte beats are rejected.

## Reproduction and results

Run inside the repository tool container:

```sh
bash design/intel_80286/scripts/run_native_bus.sh
```

Result: `PASS: native bus status, byte lanes, word beats, waits, HOLD, LOCK,
INTA and halt/shutdown`. Verilator 5.052 built with `-Wall`; the retained
console log is `design/intel_80286/work/native_bus_sim/build.log` and the test
output is `design/intel_80286/work/native_bus_sim/run.log`.

The component was also synthesized with Yosys 0.69 and `check -assert`:

```sh
yosys -Q -l design/intel_80286/work/native_bus_sim/synth/yosys.log -p \
  'read_verilog -sv design/intel_80286/src/intel_80286_native_bus.sv; hierarchy -check -top intel_80286_native_bus; synth -top intel_80286_native_bus; check -assert; stat; write_json design/intel_80286/work/native_bus_sim/synth/intel_80286_native_bus.json'
```

Result: zero Yosys check problems and 238 generic cells. The JSON netlist and
full log are retained under `design/intel_80286/work/native_bus_sim/synth/`.

## Source and evidence identities

| Artifact | SHA-256 |
|---|---|
| `src/intel_80286_native_bus.sv` | `4c77334502ba7afea605e31e6ea8a7bb7a4bdda6f4fc041062fd48179aa93154` |
| `tb/native_bus.cpp` | `6f995ed3ca9a394a0286632ce594894c7879589fc07227765ab69517df5dac10` |
| `scripts/run_native_bus.sh` | `395ae9e1ff418e271605258dbdc2ae7b5bb21f37b981a7e66dedd22b2d5d218e` |
| `scripts/run_all.sh` | `befeded5637db8f9b32b9381c0377442e52be3d59ada8823b4069e4a74fe626b` |
| `scripts/run_synth.sh` | `17010cdee97fe4fdae9d5250e6bc0ba7d390b3c86b94cc8e239dc0ba8225874e` |
| Verilator build log | `68edc86ad19cba2cb8e3f4d44c7efe657c4ec94465efe329691d9ce92ed99c20` |
| Directed test log | `a8eacf24b7cf172ffdcaaaf8a1d90f8f38e0b4b0c1637d26482020faa3b1722c` |
| Yosys log | `a45469abe740b20a7433c98cdfa2a47d79d8fbddaedea2378a1c6654cba457c6` |
| Yosys JSON | `ac3df389876586871618414b1acc86f73b1da0bf9bd79a922d085a32b99c35bd` |

## Remaining integration work

The top-level core does not yet provide the controller's one/two-byte beat
contract or 16-bit lane data. Its byte handshake must be refactored so the
core advances only by the physically completed byte count. Integration also
needs the external/internal clock relationship, reset pulse and first-fetch
timing, core-derived automatic LOCK behavior, the remaining reset/shutdown
cases, and the source-backed 80287 PEREQ/PEACK/BUSY/ERROR protocol. The 82288
ALE and command strobes remain a separate system component. This regression
does not establish electrical timing or physical qualification.

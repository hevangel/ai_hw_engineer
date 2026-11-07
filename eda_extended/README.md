# Extended EDA overlay: NVC and SystemC

This folder holds the overlay that adds two upstream reference tools to the
qualified SystemVerilog tools image, and the shared reference corpus for the
later Rust ports.

| Tracker | Tool | Pin | Docs |
| --- | --- | --- | --- |
| [#82](https://github.com/hevangel/ai_hw_engineer/issues/82) | NVC VHDL compiler/simulator | `r1.23.1`, `fab54a9e96964b431050d837e163c22282a1df6c` | [docs/nvc](../docs/nvc/README.md) |
| [#83](https://github.com/hevangel/ai_hw_engineer/issues/83) | Accellera SystemC | `3.0.2`, `70b0fc8e4a74acc677b0fc73cea08f940c2115d5` | [docs/systemc](../docs/systemc/README.md) |

The overlay is not the whole extended image of
[#84](https://github.com/hevangel/ai_hw_engineer/issues/84): e1647-rs and the
NVC and SystemC Rust ports are separate trackers and are not installed here.

## Layout

```text
eda_extended/
├── Dockerfile                 overlay: nvc-build, systemc-build, final
├── nvc/
│   ├── corpus/<case>/         VHDL sources, case.json, expected.txt (+ reference.py)
│   ├── negative/              inputs that must fail, with their expected diagnostics
│   └── vhpi/hello_vhpi.c      minimal VHPI plugin
└── systemc/
    ├── corpus/<case>/<case>.cpp, expected.txt (+ reference.py)
    └── negative/              programs that must report failure
```

## Build and run

```sh
docker build -t ai-hw-engineer .
docker build -f eda_extended/Dockerfile -t ai-hw-engineer-extended .
docker run --rm -v "$PWD:/work" -w /work ai-hw-engineer-extended \
    python3 scripts/check_extended_eda.py --work-dir scratchpad/eda-extended
```

Pin the base with `--build-arg ENGINEER_IMAGE=ai-hw-engineer@sha256:<digest>`.
Generated files and `results.json` stay in the ignored work directory; the
committed copy is `docs/eda-tool-qualification/extended-results.json`.

## How the corpus is used

A case passes only when the tool exits as expected **and** its standard output
equals `expected.txt` line for line (SystemC `Info:` reports and blank lines are
dropped first). The expected files come from one of two places:

- an independent Python model (`reference.py`) that is not derived from the
  VHDL or C++ (counter, CRC-8, records/generics, FIFO); the counter case shares
  one model between NVC and SystemC, and the CRC-8 model asserts the CRC
  catalogue check value `0xF4` for `123456789`;
- values derived by hand from the language manual and stated in the source
  (SystemC delta cycles and reset, the exhaustive adder, VHDL text I/O).

One expected value is an observation of NVC rather than a manual-derived
value: `boolean'image(true)` prints `true` in lower case in `textio_strings`.
The Rust port is compared against NVC, so it should match NVC there.

A Rust port is qualified against this corpus by running the same sources
through the port and diffing its output against the same `expected.txt`
files, in the same exit-status expectations that `scripts/check_extended_eda.py`
asserts for the upstream tool.

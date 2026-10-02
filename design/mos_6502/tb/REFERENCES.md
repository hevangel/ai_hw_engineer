# Independent CPU verification artifacts

All revisions and SHA-256 values are committed in [external_manifest.json](external_manifest.json).
`fetch_cpu_references.py` checks existing cache bytes and verifies new downloads
before use. It never silently updates pins or hashes. No external CPU source,
ROM, vector file or compiled binary is committed to this repository.

| Artifact | Pinned revision | Ownership / purpose |
|---|---|---|
| [SingleStepTests NMOS 6502](https://github.com/SingleStepTests/65x02/tree/2f6980a2d95757486c7bee24355c360e40e2a224/6502/v1) | `2f6980a2d95757486c7bee24355c360e40e2a224` | MIT; 128 first cases per documented opcode, all 10,000 cases for each of 16 ADC/SBC opcodes. Hardware-validated external expectations. |
| [py65](https://github.com/mnaberez/py65/tree/3138e1b337734a9b2ac1ea90ee7a453514436221) | `3138e1b337734a9b2ac1ea90ee7a453514436221` | MIT; unmodified MPU runs all A/operand/carry/decimal combinations for immediate ADC and SBC. |
| [Klaus functional test](https://github.com/Klaus2m5/6502_65C02_functional_tests/tree/7954e2dbb49c469ea286070bf46cdd71aeb29e4b) | `7954e2dbb49c469ea286070bf46cdd71aeb29e4b` | GPL-3.0; unmodified downloaded binary/listing and original license, executed as independent software. Success address is 3469. |
| [perfect6502 / Visual6502](https://github.com/mist64/perfect6502/tree/09fc542877a84318291aa42dab143a3e2c3db974) | `09fc542877a84318291aa42dab143a3e2c3db974` | Solver MIT, recovered netlist **CC BY-NC-SA 3.0**; independent silicon pin oracle. See [board dependencies](../../../system/apple_ii/board/DEPENDENCIES.md). |

The SingleStepTests hashes describe canonical JSON containing the selected
cases, not the entire upstream 10,000-case file. The fetcher selects the first
specified count and validates the canonical bytes against those fixed hashes.

`full_test.cpp` uses Verilator-only initial-register injection, solely to
start external cases. Every expected register, memory value and transaction
comes from an external artifact. It checks the exact next fetch PC and then
executes a single LDX at that address. Memory is otherwise filled with an
unsupported trap byte. There is no landing padding or production load port.

`pin_oracle.c` contains only netlist clock, pin, external-memory and observer
adaptation. Setup instructions establish state in both CPUs without register
injection. Bus pins are compared at phi2; architectural state is compared
after the following phi1 latch commit, necessary for DEX and similar internal
pipelines. RDY holds instruction sequencing, although the NMOS address-high
latch can still correct during a stalled page-correction cycle.

The 648 scenarios sweep IRQ, NMI, simultaneous requests and RDY over 80
arrival edges in two programs (flag controls, BRK/RTI, stack, branches, indexed
crossings and RMW), plus directed SO/reset cases. Warm reset goes to a new
vector without setup code: A/X/Y/D/C preservation, I setting and three stack
decrements are compared directly. Undefined held-reset bus samples are excluded.

Historical firmware is a separate mandatory acceptance layer: the original
Apple II Monitor runs on the authored CPU through actual motherboard nets.
Its ownership, ROM hashes and font conversion are documented in the board
dependency notes. Its cassette gate validates byte routines; complete tape
acquisition and electrical/color fidelity remain system requirements.

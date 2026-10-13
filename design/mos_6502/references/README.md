# Verification references

Third-party artifacts used only for verification. Nothing here is linked
into the RTL or shipped as part of a design.

## py65 simulation MPU (BSD)

- `py65_mpu6502.py`, `py65_utils_conversions.py`, `py65_utils_devices.py`

Vendored from the py65 project (https://github.com/mnaberez/py65, BSD
license) as the independent instruction-set oracle for the directed vector
regression (`scripts/make_isa_vectors.py`). The import lines are rewritten
to local module names; the one intentional semantic override — decimal SBC
replaced with the canonical NMOS algorithm, because py65 deviates from real
6502 hardware in that corner — lives in the generator script, documented
there and in `spec/spec_full_isa.md` (A13).

## Klaus Dormann 6502 functional test (GPL)

- `6502_functional_test.bin.hex` — the assembled test image (64K flat
  binary rendered as hex for `$readmemh`), the real-software regression
  input for `tb/tb_top.sv +klaus`.
- The assembly source (`6502_functional_test.a65`) and the raw image
  (`6502_functional_test.bin`) are kept in the working tree but not
  committed; they come from Klaus Dormann's `6502_functional_test`
  distribution (https://github.com/Klaus2m5/6502_functional_test,
  GPL). Success is the self-loop trap at $3469; any other `BNE *`/`JMP *`
  trap address identifies the failing check.

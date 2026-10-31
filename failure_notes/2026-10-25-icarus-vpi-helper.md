# 2026-10-25 — Icarus VPI helper escaped the image startup checks

## Observation

An actual VPI C-module compilation with the pinned Ubuntu `iverilog=12.0-3` overlay failed because `iverilog-vpi` passed the standalone token `0-3` to the compiler. Its installed CFLAGS and CXXFLAGS both contain that token. The existing board documentation already recorded a direct-compiler workaround; the packaged helper itself remained broken.

## Root cause and escaped coverage

The malformed distro helper flag lists are the immediate cause. The original overlay build only checked `iverilog -V`, `vvp -V` and the VPI header. Those checks can pass without compiling a VPI module, so they did not qualify the supported helper workflow. No RTL/reference-model change is involved.

## Fix and re-verification

The overlay applies a two-assignment `sed` fix that removes only the standalone `0-3` token. It keeps the other compiler flags, include paths, license and simulator/reference sources unchanged. Fresh image-build and container runs now compile and actually load C and C++ VPI modules. Four-state simulation, the documented direct-compiler workflow, and a required nonzero fatal path also pass.

## Prevention

`system/apple_ii/Dockerfile` runs `scripts/check_eda_tools.py --tools iverilog` at build time, making helper build/load failures fail the image build. Both compiler-language paths are exercised. The tool guide documents the exact package, targeted fix and tests. The [audit report](../docs/eda-tool-qualification.md) records image identities and qualifications.

## Confirmed origin and full cause

The follow-up [source investigation](../docs/iverilog/vpi-prefix-map-root-cause.md) identifies the Debian packaging patch introduced in 12.0-3. The expression `s/-ffile-prefix-map=.*\.//` greedily consumes into a later debug-map argument ending in `12.0-3`, leaving `0-3` and potentially discarding intervening flags. The original upstream generator does not contain that filter. Actual upstream/Debian/fixed helper generation and C/C++ module build/load tests isolate the regression to the packaging transformation. The source-level correction is GNU make `filter-out` on whole flag words. The binary workaround does not recover flags already discarded by the package build.

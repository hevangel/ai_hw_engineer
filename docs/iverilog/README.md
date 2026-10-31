# Icarus Verilog for board simulation

The Apple II physical-package model uses **Icarus 12.0-3** from the pinned
Ubuntu snapshot as an independent four-state simulator and VPI host.
The optional [Apple II image overlay](../../system/apple_ii/Dockerfile)
adds it to the project tools image:

```sh
docker build -f system/apple_ii/Dockerfile -t ai-hw-engineer-apple-ii .
docker run --rm -v "$PWD:/work" -w /work/system/apple_ii ai-hw-engineer-apple-ii sh scripts/run_all.sh
```

## Compilation and simulation

```sh
iverilog -g2012 -s tb_top -o work/test.vvp src/*.sv tb/tb_top.sv
vvp work/test.vvp
```

`-g2012` enables the SystemVerilog constructs supported by this installed
release. `-s` chooses the root; use it so uninstantiated package files do not
become roots. `-o` selects the generated vvp program. Four-state nets retain
X and Z; use case equality for bus checks. Successful process exit alone is
insufficient: require the test's success marker and add an explicit timeout.

Official references: [compiler flags](https://steveicarus.github.io/iverilog/usage/command_line_flags.html),
[VPI](https://steveicarus.github.io/iverilog/usage/vpi.html),
[vvp flags](https://steveicarus.github.io/iverilog/usage/vvp_flags.html).
The live upstream docs may describe newer releases; verify features against
the installed `iverilog -V` output.

## VPI adapter

```sh
cc -std=c11 -shared -fPIC -O2 -I/usr/include/iverilog -Iwork/reference \
    board/cpu_reference.c work/reference/netlist_sim_initialized.c -o work/cpu_reference.vpi
vvp -Mwork -mcpu_reference work/boot.vvp
```

Ubuntu's pinned `iverilog=12.0-3` package embeds a stray standalone `0-3` token in the installed VPI helper's CFLAGS and CXXFLAGS. The Apple II overlay removes only that token from those two assignments. It retains the simulator, reference sources, include paths, compiler hardening flags and original license. The image build runs `scripts/check_eda_tools.py --tools iverilog`, requiring the packaged helper to compile and load a real VPI module, a four-state simulation to pass, and the deliberate fatal test to fail. The documented direct-`cc` board workflow remains supported and is tested separately. Future package upgrades must recheck both helper assignments and these actual build/load probes.

Real-valued analog package models are simulation-only. Icarus emits warnings
about synthesizing real assignments in `always_comb`; do not treat these as
claims that the analog models are synthesizable. Use explicit edge events
for package clock/control models; mixed edge/level `always_ff` sensitivity
caused a compiler assertion in the installed release.

The fetcher derives netlist_sim_initialized.c from the unchanged, hash-checked original solver by zero-initializing its state allocation. See the [dependency ledger](../../system/apple_ii/board/DEPENDENCIES.md#explicit-solver-allocation-fix). Run sh scripts/run_reference_smoke.sh from system/apple_ii before longer VPI firmware tests.

## Confirmed source-level diagnosis

The [root-cause investigation](vpi-prefix-map-root-cause.md) traced the malformed flag to Debian’s `filter-out_iverilog-vpi_flags.patch`, inherited by Ubuntu. Its greedy expression consumes across argument boundaries into a later debug-map path. A hash-pinned source experiment proves that upstream helper generation works, Debian’s patch breaks both C/C++ builds, and a token-based make filter repairs both while preserving other flags. A corrected source patch and reproducible six-case experiment are included; the pinned binary-image cleanup remains the production workaround.

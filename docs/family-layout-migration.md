# Family-layout and Java environment validation

Validation date: 2026-10-25. Baseline: ai_hw_engineer main `4612e2c`.

The migration groups 23 existing design folders under seven canonical family roots, preserves shared RTL implementations, gives identified physical package profiles member folders and native sub-issues, and updates source lists, system references, indexes and generated-output ignores. `scripts/design_families.json` records old and new paths. The two NMOS 6502 implementations share the 6502 member issue; the cycle model is nested under that chip. The parameterized 8253/8254 RTL remains shared, with separate member profile folders. Apple II package RTL remains shared and is referenced from individual member folders. A generic mask-ROM model is not assigned a fabricated part identity.

## Checks recorded

- All 129 committed RTL implementation files compare unchanged to the baseline after normalizing Git checkout line endings. Relocated testbench/file-path literals and launch scripts are updated; no RTL behavior was changed.
- All 907 previously valid local Markdown link targets still exist at their mapped destinations.
- Four `test_design_families.py` checks pass: family/member indexes, old-root removal, static design source paths and Am2911 cross-member formal inputs.
- All project/design/system shell scripts passed `bash -n` in the existing EDA image.
- Nested `new_design.sh` creation passed; traversal and overwrite attempts were rejected in an isolated temporary fixture.
- All 13 existing Docker updater unit tests pass in the EDA container.
- Existing complete AMD `run_all.sh` flows passed for Am2501, Am2505, Am2902, Am2903, Am2904, Am2909, Am2910, Am2911, Am2913, Am2914 and Am2918.
- Am2901 lint and formal BMC/prove/cover passed, but its simulation initially stopped because the previous image lacks `javac`. The Dockerfile now installs a headless JDK and checks both `java` and `javac`; the fresh-image oracle rerun now passes as recorded below.
- Relocated simulation entry points passed for 4001, 4002, 4003, 4004, 3205, 3404, 8008, 74181, 8086 and the architectural MOS 6502. Available lint and synthesis entry points passed except the 8086 synthesis smoke run, which exceeded the imposed 120-second limit; it is not recorded as a synthesis failure or pass. Earlier per-design reports retain their original scope.

The nested cycle-level MOS 6502 lint, formal BMC/prove/cover and simulation entry points also passed. Its firmware/network-dependent sign-off and full historical-system acceptance were not rerun by this relocation. Existing reports are linked inventory, not new human or physical verification. Project issues remain Planned.

## Java image qualification

The requested Java compiler/runtime comes from Ubuntu `default-jdk-headless` in the pinned signed APT snapshot. The final-stage dependency placement preserves the tool build-stage definitions. The full root Dockerfile build passed, including every required EDA command smoke check and both Java checks. The candidate was promoted to the local `ai-hw-engineer:latest` tag after the full Am2901 flow passed.

- Build: `docker build --progress=plain -t ai-hw-engineer:codex-java .`
- Verified local image identity: `sha256:93051caf5a9f2678a1653cf85af576f7a9ee6cc66dded18e53c4ccc91a58cad5`.
- OpenJDK runtime and compiler: `25.0.4.1`; `default-jdk-headless` package `2:1.25-77`; `openjdk-25-jdk-headless` package `25.0.4.1+1-1~26.04.4`.
- Fresh-image command: `sh design/amd_am29xx/amd_am2901/scripts/run_all.sh`. Lint, six formal BMC/prove/cover tasks, independent Java-oracle simulation, original microcode regression and synthesis passed.
- Oracle: 98,304 independent cases and 2,064,394 output/storage/phase checks. The immutable emulator has 38,865 known status disagreements, qualified by manufacturer Figure 8 as documented in the member reference manifest; the original oracle was not replaced or bypassed.
- Historical 1975 microcode: 69,732 signed products, 1,324,908 executed words and 8,925,698 exact microcode/state checks.

All twelve relocated AMD member complete flows have now passed (the first eleven in the previous image, Am2901 in the rebuilt Java image). This is recorded technical evidence, not a new human/physical sign-off or an automatic project-status promotion. No Docker registry image was published.

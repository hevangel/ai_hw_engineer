# Icarus 12.0-3 VPI helper: confirmed packaging root cause

Investigation date: 2026-10-25. This is a **Debian packaging regression inherited by the pinned Ubuntu package**, not an error in this project's SystemVerilog/VPI module code or the original Icarus 12.0 helper generator.

## Evidence chain

1. The installed `/usr/bin/iverilog-vpi` in the original, unpatched overlay matches the package manifest: both MD5 values are `09453ff9926677802a21c086528bfc0b`. Missing optional documentation files reported by `dpkg -V` are not helper modifications; the image prunes distribution documentation.
2. `apt-get source --download-only iverilog=12.0-3` from the pinned Ubuntu snapshot supplied the upstream and Debian source archives. The Debian archive hash matches the signed [12.0-3 source release announcement](https://lists.debian.org/debian-devel-changes/2025/09/msg05422.html), which explicitly records introduction of `filter-out_iverilog-vpi_flags.patch`.
3. The original upstream [`v12_0` Makefile.in](https://github.com/steveicarus/iverilog/blob/v12_0/Makefile.in#L230-L240) inserts CFLAGS/CXXFLAGS directly into `iverilog-vpi.sh`; it has no file-prefix-map filtering expression. The GitHub tag file and source-archive file compare byte-for-byte identical (SHA-256 `6eface022267a1bd5ff0712963903cb3d05f960f715e613850555ccb7048b3cb`).
4. Debian's patch changes both substitutions to a shell command containing `sed -e 's/-ffile-prefix-map=.*\.//'`. The greedy `.*` crosses compiler-argument boundaries and matches through a later dot in another option.
5. With the same valid input flags, the generated unmodified upstream helper compiles and loads C/C++ VPI modules, the Debian-patched helper fails both builds, and the source-fixed helper compiles and loads both again. This is an actual `autoconf`/`configure`/`make iverilog-vpi` experiment, not just a simulated regular-expression comparison. The simulator itself is not rebuilt or replaced in this experiment.

## Minimal trigger

Both mapping options below are accepted by the compiler:

```text
-g -O2 -ffile-prefix-map=/build/iverilog-12.0-3=. -fdebug-prefix-map=/build/iverilog-12.0-3=/usr/src/iverilog-12.0-3
```

Debian's expression turns this into:

```text
-g -O2 0-3
```

The second map's final dot is the one in `12.0-3`. Everything from `-ffile-prefix-map=` through that dot is removed, leaving `0-3`, which the compiler treats as an input filename. Flags between the maps, including hardening options in the controlled regression, are removed too. Appending `-std=c++11` explains the corresponding C++ tail observed in the installed helper.

The controlled flags reproduce the exact malformed suffix. This investigation did not recover the complete original Ubuntu build-server environment, so it does not claim the example paths are that server's literal paths.

## Correct source-level fix

Use GNU make's word-based filter when rendering the two helper assignments:

```make
$(filter-out -ffile-prefix-map=%,$(CFLAGS))
$(filter-out -ffile-prefix-map=%,$(CXXFLAGS))
```

The [source patch](../../scripts/patches/iverilog-prefix-map-filter.patch) applies after Debian's filter patch. It removes only complete `-ffile-prefix-map=...` words and preserves the full `-fdebug-prefix-map` argument, hardening flags and C++ standard. Filtering additional map types for distribution privacy/reproducibility policy is a separate decision; the fix does not silently remove other options.

The existing Docker `0-3` cleanup remains a **binary-package workaround for the pinned 12.0-3 snapshot**, not the source-level repair. It makes that helper usable but cannot reconstruct valid flags already deleted while the package was built. Do not generalize its literal version suffix to another package version without requalification.

## Reproduce

Obtain the two archives with `apt-get source --download-only iverilog=12.0-3` using the pinned Ubuntu snapshot's `deb-src` entries. The tracked reproducer validates these hashes before extraction:

| Archive | SHA-256 |
| --- | --- |
| `iverilog_12.0.orig.tar.gz` | `a68cb1ef7c017ef090ebedb2bc3e39ef90ecc70a3400afb4aa94303bc3beaa7d` |
| `iverilog_12.0-3.debian.tar.xz` | `73472c6695debcddd8f8efe2439aee0493de89916fa8f562c1ddf9faaaeaa8da` |

For example, mount the archives read-only at `/inputs` and the checkout at `/work`, then run inside an Icarus overlay with the normal compiler, VPI headers and libraries:

```sh
python3 /work/scripts/reproduce_icarus_vpi_flags.py \
  --upstream-tar /inputs/iverilog_12.0.orig.tar.gz \
  --debian-tar /inputs/iverilog_12.0-3.debian.tar.xz \
  --work-dir /tmp/icarus-source-repro \
  --report /work/scratchpad/icarus-vpi-source-report.json
```

The work directory must be absent or empty. The script extracts only the hash-pinned sources into that directory, generates three helpers and records actual flags and exits. It does not install anything into the system. All six cases passed their expected outcomes:

| Helper generation | C | C++ |
| --- | --- | --- |
| Original upstream | Compile and actual VPI load pass | Compile and actual VPI load pass |
| Debian patch | Expected `0-3` compile failure | Expected `0-3` compile failure |
| Corrected source filter | Compile/load pass; remaining flags retained | Compile/load pass; remaining flags retained |

## Later source check

The publicly indexed [Debian 13.0-2 patch](https://sources.debian.org/src/iverilog/13.0-2/debian/patches/filter-out_iverilog-vpi_flags.patch/) inspected on this date still contains the same greedy expression. No newer binary-package failure or corrected-release claim is inferred from that source inspection. No upstream bug or patch has been submitted by this investigation.

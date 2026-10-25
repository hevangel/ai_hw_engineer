# Java reference-oracle toolchain

The final EDA image installs Ubuntu's `default-jdk-headless` package from the same pinned APT snapshot as the other distribution packages. It includes both `java` and `javac`; a runtime-only JRE is insufficient. No GUI JDK or moving external Java download is required. `java -version` and `javac -version` are mandatory Docker build smoke checks. Record the actual distribution package version with the image digest in verification reports.

The AMD Am2901 simulation compiles the unchanged, MIT-licensed Am2900ME reference and the project-owned adapter before generating independent vectors:

```sh
sh design/amd_am29xx/amd_am2901/scripts/run_sim.sh
```

The [reference manifest](../../design/amd_am29xx/amd_am2901/references/README.md) and its SHA256SUMS identify the external sources. Preserve their license, UTF-8 filenames and the manufacturer-derived status qualification. Adding Java must not bypass this oracle or change the RTL or expected results. The full member verification flow is `sh design/amd_am29xx/amd_am2901/scripts/run_all.sh`.

# Docker toolchain release pins

Release discovery date: 2026-10-04 (xezim re-checked 2026-10-23). The root Dockerfile builds named EDA tools
from published releases, with explicit upstream snapshot exceptions where noted.
Commit and archive digests prevent a moving tag from silently changing a build.
Ubuntu packages come from the dated, signed Ubuntu snapshot; they are the
distribution's supported packages, not separately compiled upstream releases.

| Component | Selected release / revision | Official source |
|---|---|---|
| Ubuntu | 26.04.1 LTS, snapshot 20261001T000000Z | [Ubuntu image](https://hub.docker.com/_/ubuntu), [snapshot service](https://snapshot.ubuntu.com/) |
| Rust | 1.99.0 (stable channel dated 2026-09-28) | [stable manifest](https://static.rust-lang.org/dist/channel-rust-stable.toml) |
| rustup | 1.29.1 | [releases](https://github.com/rust-lang/rustup/releases) |
| xezim | 0.11.3, `058f2bba58648452e5799d17572356ebcae7d163` | [release](https://github.com/aionhw/xezim/releases/tag/0.11.3) |
| Verilator | v5.052, `ea338be98e1e838d3518809ce8899f85a009963c` | [tag](https://github.com/verilator/verilator/tree/v5.052) |
| Yosys | v0.69, `9f75ca1f9834a39a863915b5dae0c7b1e33533bc` | [release](https://github.com/YosysHQ/yosys/releases/tag/v0.69) |
| SBY | `b1a1e98cba941ec8433f8dc27f416cd7bb7f14be` | [upstream](https://github.com/YosysHQ/sby) |
| EQY | `7a92d8441aa442dd1b5543458d6f1060a8f85dd1` | [upstream](https://github.com/YosysHQ/eqy) |
| Yices | 2.7.0, `85cf17e44eac76b5d14b297c09fc9bfecf47ef65` | [release](https://github.com/SRI-CSL/yices2/releases/tag/yices-2.7.0) |
| Z3 | 5.1.0, official x64 glibc-2.39 archive | [release](https://github.com/Z3Prover/z3/releases/tag/z3-5.1.0) |
| Surfer | v0.7.0, `bd749b1f786c1c62cd67893ca71346cbe6983915` | [release](https://gitlab.com/surfer-project/surfer/-/releases/v0.7.0) |
| Trunk | 0.21.14 (Surfer WebAssembly build) | [release](https://github.com/trunk-rs/trunk/releases/tag/v0.21.14) |
| Verible | v0.0-4296-g0f262651, static x86_64 archive | [release](https://github.com/chipsalliance/verible/releases/tag/v0.0-4296-g0f262651) |
| CMake | 4.4.4, PyPI package in a dedicated virtual environment | [package](https://pypi.org/project/cmake/4.4.4/) |
| Java JDK | Ubuntu `default-jdk-headless`, resolved from the pinned signed snapshot; compiler and runtime checked at image build | [Project usage](java/README.md) |
| UVM bundle | `65a3ded36f7f752356de62669fd84e01f4cb0121` (unchanged upstream HEAD) | [repository](https://github.com/nitronis/UVM) |

Run `./scripts/update_docker.sh --dry-run` to preview release updates, or
`./scripts/update_docker.sh` to update the Dockerfile, README version list and
this table and build the local image. Python 3.11+, Git and Docker are required;
`--no-build` skips Docker. Discovery uses the official
[GitHub releases API](https://docs.github.com/en/rest/releases/releases#get-the-latest-release),
[GitLab releases API](https://docs.gitlab.com/api/releases/), Rust and rustup stable
manifests, and PyPI package metadata. Verilator uses published version tags
reachable from its documented stable branch. Source release tags are resolved to commit IDs;
Verible, Z3 and rustup archives are downloaded to calculate and check SHA-256
digests against upstream digests where supplied. Network, asset or document
layout errors stop discovery before any files are changed.

SBY and EQY retain their existing snapshot if no standalone release is available;
their compatibility tags do not trigger snapshot updates. Ubuntu, its APT
snapshot and the UVM submodule are outside the automated update scope. Release
discovery does not establish compatibility; inspect release notes, update tool
documentation and run the image build before accepting upgraded pins.

Run the updater's offline regression checks with
`python3 -m unittest discover -s scripts -p test_update_docker.py -v`.

## Original 2026-10-04 build changes

- Ubuntu 26.04 provides the C++20 compiler required by Yosys. CMake is installed
  in `/opt/cmake` using a virtual environment, respecting system Python isolation.
- Surfer 0.7.0 requires its `f128` and other Git submodules; initialize recursively.
- The Surfer WebAssembly UI follows the v0.7.0 upstream CI build using Trunk 0.21.14.
- Z3 uses the verified official release archive instead of the older Ubuntu package.
- `BUILD_JOBS` defaults to four per compiler stage. Docker can run stages in parallel.
- Rustup, Z3 and Verible downloads are checked against SHA-256 digests in Dockerfile.

Build with `docker build --progress=plain -t ai-hw-engineer:latest .`.
The final image smoke-checks every installed EDA executable. Functional Busicom
results are recorded separately in the system report; a successful image build
alone does not establish RTL correctness.

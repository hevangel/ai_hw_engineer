# AI Hardware Engineer — open-source EDA toolchain

A ready-to-run, reproducible Linux image with the open-source hardware design
and verification tools used by the
[AI Hardware Engineer](https://github.com/hevangel/ai_hw_engineer) project: an
experiment in AI agents designing, verifying and integrating historical chips
and computer systems in SystemVerilog.

Every tool is built from a pinned upstream release or commit, and archive
downloads are checked against SHA-256 digests, so a tag always contains the same
toolchain. It is useful on its own for any SystemVerilog lint, simulation, UVM,
formal verification, synthesis or waveform-viewing workflow.

## Quick start

```sh
docker pull {{IMAGE}}:latest
docker run -it --rm -v "$PWD":/workspace {{IMAGE}}:latest
```

The working directory is `/workspace`; mount your project there. All tools are
on `PATH`.

```sh
verilator --lint-only -Wall top.sv              # lint
xezim --simulate -s tb_top top.sv tb_top.sv     # event-driven simulation
sby -f top.sby                                  # formal (BMC / prove / cover)
eqy -f top.eqy                                  # equivalence checking
yosys -p "read_verilog -sv top.sv; synth -top top"
verible-verilog-lint top.sv
```

Run a single command without an interactive shell:

```sh
docker run --rm -v "$PWD":/workspace {{IMAGE}}:latest verilator --lint-only -Wall top.sv
```

## Included tools

Versions reported by the tools in `{{IMAGE}}:{{VERSION}}`:

{{RUNTIME_VERSIONS}}

Pinned sources for this build:

{{TOOLCHAIN_TABLE}}

SymbiYosys runs with the Yices 2 and Z3 SMT solvers and the ABC engine built
into Yosys.

## UVM

The UVM reference library is installed at `/opt/uvm`, with these environment
variables set:

| Variable | Path |
|---|---|
| `XEZIM_UVM_DIR` | `/opt/uvm` |
| `UVM_HOME_12` | `/opt/uvm/1.2` |
| `UVM_HOME_2017` | `/opt/uvm/1800.2-2017` |
| `UVM_HOME_2020` | `/opt/uvm/1800.2-2020` |

See the project's
[xezim UVM guide](https://github.com/hevangel/ai_hw_engineer/blob/{{REVISION}}/docs/xezim/uvm-guide.md)
for a complete command line.

## Viewing waveforms in a browser

The image contains a self-hosted Surfer web viewer. Serve one VCD or FST file
on the local machine only:

```sh
docker run --rm --init -p 127.0.0.1:8080:8080 \
  -v "$PWD/work:/waveforms:ro" \
  -e SURFER_WAVEFORM=/waveforms/dump.fst \
  -e SURFER_TOKEN="$(openssl rand -hex 18)" \
  {{IMAGE}}:latest /opt/surfer/serve_web.sh
```

Open the URL that the container prints. Keep the port bound to `127.0.0.1`;
the token is the only access control.

## Tags

| Tag | Meaning |
|---|---|
| `latest` | Most recently published build |
| `YYYY.MM.DD-<commit>` | Immutable build from that date and [ai_hw_engineer](https://github.com/hevangel/ai_hw_engineer) commit; pin this in CI |

This build: `{{VERSION}}`, from commit
[`{{REVISION}}`]({{REVISION_URL}}), published {{BUILD_DATE}}.

Image labels follow the OCI conventions; inspect them with
`docker inspect {{IMAGE}}:{{VERSION}}`.

## Platform and size

`linux/amd64` only (several tools are x86-64 release binaries), based on
Ubuntu 26.04 LTS. The image is about 6 GB uncompressed because the tools are
built with their full runtime dependencies. It runs on Docker Desktop for
Windows and macOS through their Linux virtual machines; Apple silicon hosts
need amd64 emulation.

## Build it yourself

```sh
git clone --recurse-submodules https://github.com/hevangel/ai_hw_engineer.git
cd ai_hw_engineer
docker build -t ai-hw-engineer .
```

The [Dockerfile](https://github.com/hevangel/ai_hw_engineer/blob/{{REVISION}}/Dockerfile)
and [release manifest](https://github.com/hevangel/ai_hw_engineer/blob/{{REVISION}}/docs/toolchain-releases.md)
record every pin. Report problems in the
[issue tracker](https://github.com/hevangel/ai_hw_engineer/issues).

## Licenses

The project's own scripts and documentation are MIT licensed. Each bundled tool
keeps its upstream license: Verilator (LGPL-3.0 or Artistic-2.0), Yosys,
SymbiYosys and EQY (ISC), xezim (Apache-2.0), Surfer (EUPL-1.2), Verible
(Apache-2.0), Z3 (MIT), Yices 2 (GPL-3.0), UVM (Apache-2.0), and Ubuntu packages
under their respective licenses. Using this image means complying with them.

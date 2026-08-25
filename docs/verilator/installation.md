# Verilator Installation

Source: [veripool.org/guide/latest/install.html](https://veripool.org/guide/latest/install.html)

## Package Manager (Quick)

```bash
# Ubuntu/Debian
sudo apt-get install verilator

# Note: distribution packages often lag behind the latest version
```

## Build from Source (Recommended)

### Prerequisites

```bash
sudo apt-get install git help2man perl python3 make autoconf g++ flex bison ccache
sudo apt-get install libgoogle-perftools-dev libjemalloc-dev numactl perl-doc
sudo apt-get install libfl2 libfl-dev                    # Ubuntu only
sudo apt-get install zlibc zlib1g zlib1g-dev liblz4 liblz4-dev  # Ubuntu only
```

### Build Steps

```bash
git clone https://github.com/verilator/verilator
cd verilator
git checkout stable       # Or: git checkout v5.050
autoconf
./configure
make -j $(nproc)
sudo make install
```

### Run-in-Place (Alternative)

```bash
export VERILATOR_ROOT=$(pwd)
./configure
make -j $(nproc)
# Use $VERILATOR_ROOT/bin/verilator directly
```

## Docker

```bash
# Pre-built executable container
docker run -ti verilator/verilator:latest --version

# With source mounting
docker run -ti -v ${PWD}:/work --user $(id -u):$(id -g) \
  verilator/verilator:latest --cc test.v
```

## Optional Dependencies

| Package | Purpose |
|---------|---------|
| SystemC | `--sc` mode (apt: `libsystemc libsystemc-dev`) |
| Z3 | Constrained randomization (`apt: z3`) |
| GTKWave / Surfer | Waveform viewing |
| ccache | Faster recompilation |
| mold | Faster linking |

## Verify Installation

```bash
verilator --version
# Should print: Verilator 5.0XX ...
```

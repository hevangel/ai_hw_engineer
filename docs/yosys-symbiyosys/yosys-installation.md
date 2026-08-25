# Yosys Installation

Source: [github.com/YosysHQ/yosys](https://github.com/YosysHQ/yosys)

## Package Manager

```bash
# Ubuntu/Debian
sudo apt-get install yosys

# Note: may not be latest version
```

## Build from Source

### Prerequisites

```bash
sudo apt-get install build-essential clang bison flex \
  libreadline-dev gawk tcl-dev libffi-dev git \
  graphviz xdot pkg-config python3 libboost-system-dev \
  libboost-python-dev libboost-filesystem-dev zlib1g-dev
```

### Build

```bash
git clone https://github.com/YosysHQ/yosys.git
cd yosys
make config-gcc    # or: make config-clang
make -j$(nproc)
sudo make install
```

### Custom prefix

```bash
make install PREFIX=/opt/yosys
export PATH=/opt/yosys/bin:$PATH
```

## Install SymbiYosys

```bash
git clone https://github.com/YosysHQ/sby.git
cd sby
sudo make install
```

## Install SMT Solvers (for SymbiYosys)

```bash
# Z3 (recommended)
pip3 install z3-solver
# or: sudo apt-get install z3

# Yices2
sudo apt-get install yices2

# Boolector (optional, good for bitvectors)
git clone https://github.com/boolector/boolector.git
cd boolector
./contrib/setup-cadical.sh
./contrib/setup-btor2tools.sh
./configure.sh && cd build && make -j$(nproc)
sudo cp bin/boolector /usr/local/bin/
```

## Verify Installation

```bash
yosys --version
sby --help
```

## OSS CAD Suite (All-in-One)

The easiest way to get all YosysHQ tools:

```bash
# Download from: https://github.com/YosysHQ/oss-cad-suite-build/releases
wget https://github.com/YosysHQ/oss-cad-suite-build/releases/download/...
tar xzf oss-cad-suite-linux-x64-*.tgz
source oss-cad-suite/environment
```

Includes: Yosys, SymbiYosys, nextpnr, solvers, and more.

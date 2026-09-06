# Yosys Installation

Source: [github.com/YosysHQ/yosys](https://github.com/YosysHQ/yosys)

## Package Manager

```bash
# Ubuntu/Debian
sudo apt-get install yosys

# Note: may not be latest version
```

## Build from Source

Yosys 0.67 replaced the `make config-gcc` flow with a CMake build requiring
CMake >= 3.28 and a C++20 compiler (gcc >= 12 recommended).

### Prerequisites

```bash
sudo apt-get install build-essential g++-12 bison flex \
  libreadline-dev gawk tcl-dev libffi-dev git \
  pkg-config python3 zlib1g-dev
# CMake >= 3.28: distros with an older cmake (e.g. Ubuntu 22.04) can get a
# current one from PyPI:
sudo pip3 install cmake
```

### Build

```bash
git clone https://github.com/YosysHQ/yosys.git
cd yosys
git submodule update --init --recursive
cmake -B build -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=gcc-12 -DCMAKE_CXX_COMPILER=g++-12 \
  -DYOSYS_USE_BUNDLED_LIBS=ON
cmake --build build -j$(nproc)
sudo cmake --install build
```

`YOSYS_USE_BUNDLED_LIBS=ON` takes fmt/slang/cxxopts/tomlplusplus/
boost_regex from the repo's own submodules instead of system packages.

### Custom prefix

```bash
cmake -B build -DCMAKE_INSTALL_PREFIX=/opt/yosys [other options as above]
cmake --build build -j$(nproc)
cmake --install build
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

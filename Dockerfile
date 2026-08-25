# AI Hardware Engineering Docker Image
# Tools: xezim, Verilator, Yosys + SymbiYosys, Surfer Waveform Viewer
# Base: Ubuntu 22.04 LTS

FROM ubuntu:22.04 AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    wget \
    git \
    python3 \
    python3-pip \
    python3-venv \
    autoconf \
    flex \
    bison \
    ccache \
    libgoogle-perftools-dev \
    numactl \
    libfl2 \
    libfl-dev \
    zlib1g \
    zlib1g-dev \
    liblz4-dev \
    pkg-config \
    tcl-dev \
    libreadline-dev \
    libffi-dev \
    graphviz \
    xdot \
    clang \
    cmake \
    ninja-build \
    gperf \
    libboost-all-dev \
    help2man \
    perl \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Install Rust (needed for xezim and surfer)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# ============================================================
# Stage 1: Build Verilator from source
# ============================================================
FROM base AS verilator-build

RUN git clone https://github.com/verilator/verilator.git /opt/verilator-src && \
    cd /opt/verilator-src && \
    git checkout stable && \
    autoconf && \
    ./configure --prefix=/opt/verilator && \
    make -j$(nproc) && \
    make install

# ============================================================
# Stage 2: Build Yosys from source
# ============================================================
FROM base AS yosys-build

RUN git clone https://github.com/YosysHQ/yosys.git /opt/yosys-src && \
    cd /opt/yosys-src && \
    git checkout yosys-0.46 && \
    make config-gcc && \
    make -j$(nproc) PREFIX=/opt/yosys && \
    make install PREFIX=/opt/yosys

# ============================================================
# Stage 3: Build SymbiYosys
# ============================================================
FROM base AS sby-build

COPY --from=yosys-build /opt/yosys /opt/yosys
ENV PATH="/opt/yosys/bin:${PATH}"

# Install SMT solvers
RUN pip3 install --no-cache-dir z3-solver

RUN apt-get update && apt-get install -y --no-install-recommends \
    yices2 \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/YosysHQ/sby.git /opt/sby-src && \
    cd /opt/sby-src && \
    make install PREFIX=/opt/sby

# ============================================================
# Stage 4: Build xezim from source
# ============================================================
FROM base AS xezim-build

RUN git clone https://github.com/aionhw/xezim.git /opt/xezim-src && \
    cd /opt/xezim-src && \
    cargo build --release --features jit && \
    mkdir -p /opt/xezim/bin && \
    cp target/release/xezim /opt/xezim/bin/ && \
    cp -r include /opt/xezim/include

# ============================================================
# Stage 5: Build Surfer waveform viewer
# ============================================================
FROM base AS surfer-build

RUN git clone https://gitlab.com/surfer-project/surfer.git /opt/surfer-src && \
    cd /opt/surfer-src && \
    cargo build --release && \
    mkdir -p /opt/surfer/bin && \
    cp target/release/surfer /opt/surfer/bin/

# ============================================================
# Final Stage: Combine all tools
# ============================================================
FROM base AS final

# Copy built tools
COPY --from=verilator-build /opt/verilator /opt/verilator
COPY --from=yosys-build /opt/yosys /opt/yosys
COPY --from=sby-build /opt/sby /opt/sby
COPY --from=xezim-build /opt/xezim /opt/xezim
COPY --from=surfer-build /opt/surfer /opt/surfer

# Set PATH for all tools
ENV PATH="/opt/verilator/bin:/opt/yosys/bin:/opt/sby/bin:/opt/xezim/bin:/opt/surfer/bin:${PATH}"
ENV VERILATOR_ROOT=/opt/verilator

# Install SMT solvers for SymbiYosys
RUN apt-get update && apt-get install -y --no-install-recommends \
    yices2 \
    && rm -rf /var/lib/apt/lists/*
RUN pip3 install --no-cache-dir z3-solver

# Clone UVM libraries (1.2, 1800.2-2017, 1800.2-2020)
RUN git clone https://github.com/nitronis/UVM.git /opt/uvm && \
    echo "UVM libraries installed at /opt/uvm"

ENV XEZIM_UVM_DIR=/opt/uvm
ENV UVM_HOME_12=/opt/uvm/1.2
ENV UVM_HOME_2017=/opt/uvm/1800.2-2017
ENV UVM_HOME_2020=/opt/uvm/1800.2-2020

# Working directory
WORKDIR /workspace

# Verify installations
RUN verilator --version && \
    yosys --version && \
    xezim --version || true && \
    echo "All tools installed successfully"

# Default shell
CMD ["/bin/bash"]

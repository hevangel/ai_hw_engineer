# AI Hardware Engineering Docker Image
# Tools: xezim, Verilator, Yosys + SymbiYosys + EQY, Surfer, Verible
# Base: Ubuntu 26.04 LTS

FROM ubuntu:26.04@sha256:da6fc2be547864451aa253836dd926da33623312df4a9a243e35dc877c378a78 AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

ARG UBUNTU_SNAPSHOT=20260927T000000Z
# The pinned minimal base has no CA bundle yet. Bootstrap ca-certificates with
# APT TLS peer checks disabled; signed metadata and package hashes remain verified.
RUN rm -f /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources && \
    printf '%s\n' \
      "deb [check-valid-until=no] https://snapshot.ubuntu.com/ubuntu/${UBUNTU_SNAPSHOT} resolute main restricted universe multiverse" \
      "deb [check-valid-until=no] https://snapshot.ubuntu.com/ubuntu/${UBUNTU_SNAPSHOT} resolute-updates main restricted universe multiverse" \
      "deb [check-valid-until=no] https://snapshot.ubuntu.com/ubuntu/${UBUNTU_SNAPSHOT} resolute-security main restricted universe multiverse" \
      "deb [check-valid-until=no] https://snapshot.ubuntu.com/ubuntu/${UBUNTU_SNAPSHOT} resolute-backports main restricted universe multiverse" \
      > /etc/apt/sources.list && \
    apt-get -o Acquire::https::Verify-Peer=false update && \
    apt-get -o Acquire::https::Verify-Peer=false install -y --no-install-recommends \
    autoconf \
    bison \
    build-essential \
    ca-certificates \
    ccache \
    clang \
    cmake \
    curl \
    flex \
    g++ \
    gawk \
    git \
    gperf \
    graphviz \
    help2man \
    libboost-all-dev \
    libffi-dev \
    libfl-dev \
    libfl2 \
    libgoogle-perftools-dev \
    liblz4-dev \
    libreadline-dev \
    libspeechd-dev \
    libssl-dev \
    libwayland-dev \
    libx11-xcb-dev \
    libxcb-render0-dev \
    libxcb-shape0-dev \
    libxcb-xfixes0-dev \
    libxkbcommon-dev \
    make \
    ninja-build \
    numactl \
    perl \
    pkg-config \
    python3 \
    python3-pip \
    python3-venv \
    tcl-dev \
    wget \
    xdot \
    unzip \
    zlib1g \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

ARG BUILD_JOBS=4
ENV CARGO_BUILD_JOBS=${BUILD_JOBS}

ARG RUST_VERSION=1.98.1
ARG RUSTUP_VERSION=1.29.1
ARG RUSTUP_TARGET=x86_64-unknown-linux-gnu
ARG RUSTUP_INIT_SHA256=dda7234360b7f578ca8b0ddcb80145646fa61a67c1720a5abc7051b35c9fcb71
RUN curl --proto '=https' --tlsv1.2 -sSf \
        "https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/${RUSTUP_TARGET}/rustup-init" \
        -o /tmp/rustup-init && \
    echo "${RUSTUP_INIT_SHA256}  /tmp/rustup-init" | sha256sum -c - && \
    chmod +x /tmp/rustup-init && \
    /tmp/rustup-init -y --profile minimal --default-toolchain "${RUST_VERSION}" && \
    rm /tmp/rustup-init
ENV PATH="/root/.cargo/bin:${PATH}"

# ============================================================
# Build Verilator
# ============================================================
FROM base AS verilator-build
ARG VERILATOR_REV=ea338be98e1e838d3518809ce8899f85a009963c
RUN git clone --filter=blob:none https://github.com/verilator/verilator.git /opt/verilator-src && \
    git -C /opt/verilator-src checkout --detach "${VERILATOR_REV}" && \
    cd /opt/verilator-src && \
    autoconf && \
    ./configure --prefix=/opt/verilator && \
    make -j"${BUILD_JOBS}" && \
    make install

# ============================================================
# Build Yosys
# ============================================================
FROM base AS yosys-build
# Yosys 0.69 uses CMake and C++20. Use the release submodules for bundled libraries.
ARG YOSYS_REV=9f75ca1f9834a39a863915b5dae0c7b1e33533bc
ARG CMAKE_PIP_VERSION=4.4.3
RUN python3 -m venv /opt/cmake && /opt/cmake/bin/pip install --no-cache-dir "cmake==${CMAKE_PIP_VERSION}"
ENV PATH="/opt/cmake/bin:${PATH}"
RUN git clone --filter=blob:none https://github.com/YosysHQ/yosys.git /opt/yosys-src && \
    git -C /opt/yosys-src checkout --detach "${YOSYS_REV}" && \
    git -C /opt/yosys-src submodule update --init --recursive && \
    cmake -S /opt/yosys-src -B /opt/yosys-src/build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ \
      -DCMAKE_INSTALL_PREFIX=/opt/yosys \
      -DYOSYS_USE_BUNDLED_LIBS=ON && \
    cmake --build /opt/yosys-src/build -j"${BUILD_JOBS}" && \
    cmake --install /opt/yosys-src/build

# ============================================================
# Install SymbiYosys
# ============================================================
FROM base AS sby-build
COPY --from=yosys-build /opt/yosys /opt/yosys
ENV PATH="/opt/yosys/bin:${PATH}"
ARG SBY_REV=b1a1e98cba941ec8433f8dc27f416cd7bb7f14be
RUN git clone --filter=blob:none https://github.com/YosysHQ/sby.git /opt/sby-src && \
    git -C /opt/sby-src checkout --detach "${SBY_REV}" && \
    make -C /opt/sby-src install PREFIX=/opt/sby

# ============================================================
# Build Yices 2 SMT solver
# ============================================================
# Not packaged in Ubuntu resolute. yices is EQY's preferred SMT solver and the
# checker SBY uses to validate abc-engine counterexamples (aigsmt).
FROM base AS yices-build
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgmp-dev \
    && rm -rf /var/lib/apt/lists/*
ARG YICES_REV=85cf17e44eac76b5d14b297c09fc9bfecf47ef65  # yices-2.7.0
RUN git clone https://github.com/SRI-CSL/yices2.git /opt/yices-src && \
    git -C /opt/yices-src checkout --detach "${YICES_REV}" && \
    cd /opt/yices-src && \
    autoconf && \
    ./configure --prefix=/opt/yices && \
    make -j"${BUILD_JOBS}" && \
    make install

# ============================================================
# Build EQY (equivalence checking with Yosys)
# ============================================================
# EQY plugins are built against the installed Yosys release. SBY and EQY
# have no standalone releases; use pinned upstream revisions.
FROM yosys-build AS eqy-build
ENV PATH="/opt/yosys/bin:${PATH}"
ARG EQY_REV=7a92d8441aa442dd1b5543458d6f1060a8f85dd1
RUN git clone --filter=blob:none https://github.com/YosysHQ/eqy.git /opt/eqy-src && \
    git -C /opt/eqy-src checkout --detach "${EQY_REV}" && \
    make -C /opt/eqy-src install PREFIX=/opt/eqy

# ============================================================
# Build xezim
# ============================================================
FROM base AS xezim-build
ARG XEZIM_REV=6558a1e64e251cbd8d0c4e936860af268cf7e04f
RUN git clone --filter=blob:none https://github.com/aionhw/xezim.git /opt/xezim-src && \
    git -C /opt/xezim-src checkout --detach "${XEZIM_REV}" && \
    cd /opt/xezim-src && \
    cargo build --release --features jit --bin xezim && \
    mkdir -p /opt/xezim/bin && \
    cp target/release/xezim /opt/xezim/bin/ && \
    cp -r include /opt/xezim/include

# ============================================================
# Build Surfer waveform viewer
# ============================================================
FROM base AS surfer-build
ARG SURFER_REV=bd749b1f786c1c62cd67893ca71346cbe6983915
RUN git clone --filter=blob:none https://gitlab.com/surfer-project/surfer.git /opt/surfer-src && \
    git -C /opt/surfer-src checkout --detach "${SURFER_REV}" && \
    git -C /opt/surfer-src submodule update --init --recursive && \
    cd /opt/surfer-src && \
    cargo build --release --locked --bin surfer && \
    mkdir -p /opt/surfer/bin && \
    cp target/release/surfer /opt/surfer/bin/

# ============================================================
# Download pinned Verible pre-built binaries
# ============================================================
FROM base AS verible-download
ARG VERIBLE_VERSION=v0.0-4296-g0f262651
ARG VERIBLE_SHA256=8569defb891d2316067613ea00442af28a7a09d405d95b54c0c91f9942d26635
RUN mkdir -p /opt/verible && \
    curl -fsSL "https://github.com/chipsalliance/verible/releases/download/${VERIBLE_VERSION}/verible-${VERIBLE_VERSION}-linux-static-x86_64.tar.gz" \
        -o /tmp/verible.tar.gz && \
    echo "${VERIBLE_SHA256}  /tmp/verible.tar.gz" | sha256sum -c - && \
    tar -xzf /tmp/verible.tar.gz --strip-components=1 -C /opt/verible && \
    rm /tmp/verible.tar.gz

# ============================================================
# Final image
# ============================================================
# Official Z3 release (glibc 2.39 binaries run on Ubuntu 26.04).
FROM base AS z3-download
ARG Z3_VERSION=5.1.0
ARG Z3_SHA256=f47be8d27d3230e823bf1eeede2fe0abaca55bb78d0b59974370e6689a92284a
RUN curl -fsSL "https://github.com/Z3Prover/z3/releases/download/z3-${Z3_VERSION}/z3-${Z3_VERSION}-x64-glibc-2.39.zip" -o /tmp/z3.zip && \
    echo "${Z3_SHA256}  /tmp/z3.zip" | sha256sum -c - && \
    unzip -q /tmp/z3.zip -d /tmp/z3 && \
    mv /tmp/z3/z3-* /opt/z3 && rm /tmp/z3.zip
FROM base AS final

# Python driver (SBY, EQY) runtime dependencies. Keep this in the final
# stage so changes do not invalidate the expensive compiler-tool build stages.
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-click \
    && rm -rf /var/lib/apt/lists/*

COPY --from=verilator-build /opt/verilator /opt/verilator
COPY --from=yosys-build /opt/yosys /opt/yosys
COPY --from=sby-build /opt/sby /opt/sby
COPY --from=yices-build /opt/yices /opt/yices
COPY --from=eqy-build /opt/eqy /opt/eqy
COPY --from=xezim-build /opt/xezim /opt/xezim
COPY --from=surfer-build /opt/surfer /opt/surfer
COPY --from=z3-download /opt/z3 /opt/z3
COPY --from=verible-download /opt/verible /opt/verible
COPY libs/uvm /opt/uvm

ENV PATH="/opt/verilator/bin:/opt/yosys/bin:/opt/sby/bin:/opt/yices/bin:/opt/eqy/bin:/opt/xezim/bin:/opt/surfer/bin:/opt/verible/bin:/opt/z3/bin:${PATH}"
ENV XEZIM_UVM_DIR=/opt/uvm
ENV UVM_HOME_12=/opt/uvm/1.2
ENV UVM_HOME_2017=/opt/uvm/1800.2-2017
ENV UVM_HOME_2020=/opt/uvm/1800.2-2020

WORKDIR /workspace

# Fail the build if any required command is missing or cannot start.
RUN set -eux; \
    test -x /opt/verilator/bin/verilator; \
    verilator --version; \
    test -x /opt/yosys/bin/yosys; \
    yosys --version; \
    test -x /opt/sby/bin/sby; \
    sby --help >/dev/null; \
    z3 --version; \
    yices-smt2 --version; \
    test -x /opt/eqy/bin/eqy; \
    eqy --help >/dev/null; \
    test -x /opt/xezim/bin/xezim; \
    xezim --help >/dev/null; \
    test -x /opt/surfer/bin/surfer; \
    surfer --version; \
    test -x /opt/verible/bin/verible-verilog-lint; \
    verible-verilog-lint --version; \
    test -f /opt/uvm/1.2/src/uvm_pkg.sv; \
    test -f /opt/uvm/1800.2-2017/src/uvm_pkg.sv; \
    echo "All EDA tools installed successfully"

CMD ["/bin/bash"]

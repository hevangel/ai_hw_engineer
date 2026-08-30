# AI Hardware Engineering Docker Image
# Tools: xezim, Verilator, Yosys + SymbiYosys, Surfer, Verible
# Base: Ubuntu 22.04 LTS

FROM ubuntu:22.04@sha256:2edbbc5dc405e9612ba3584ce95480277e3eb374407b5505fe26f17df77c7dbc AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

ARG UBUNTU_SNAPSHOT=20260824T000000Z
# The pinned minimal base has no CA bundle yet. Bootstrap ca-certificates with
# APT TLS peer checks disabled; signed metadata and package hashes remain verified.
RUN rm -f /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources && \
    printf '%s\n' \
      "deb [check-valid-until=no] https://snapshot.ubuntu.com/ubuntu/${UBUNTU_SNAPSHOT} jammy main restricted universe multiverse" \
      "deb [check-valid-until=no] https://snapshot.ubuntu.com/ubuntu/${UBUNTU_SNAPSHOT} jammy-updates main restricted universe multiverse" \
      "deb [check-valid-until=no] https://snapshot.ubuntu.com/ubuntu/${UBUNTU_SNAPSHOT} jammy-security main restricted universe multiverse" \
      "deb [check-valid-until=no] https://snapshot.ubuntu.com/ubuntu/${UBUNTU_SNAPSHOT} jammy-backports main restricted universe multiverse" \
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
    z3 \
    zlib1g \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

ARG RUST_VERSION=1.98.0
ARG RUSTUP_VERSION=1.29.0
ARG RUSTUP_TARGET=x86_64-unknown-linux-gnu
ARG RUSTUP_INIT_SHA256=4acc9acc76d5079515b46346a485974457b5a79893cfb01112423c89aeb5aa10
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
ARG VERILATOR_REV=3d2421f3bf8cda84b49d8f739e39bce73c93cc46
RUN git clone --filter=blob:none https://github.com/verilator/verilator.git /opt/verilator-src && \
    git -C /opt/verilator-src checkout --detach "${VERILATOR_REV}" && \
    cd /opt/verilator-src && \
    autoconf && \
    ./configure --prefix=/opt/verilator && \
    make -j"$(nproc)" && \
    make install

# ============================================================
# Build Yosys
# ============================================================
FROM base AS yosys-build
ARG YOSYS_REV=26b51148a80ea546481cf4f0516be97e4ba251cc
RUN git clone --filter=blob:none https://github.com/YosysHQ/yosys.git /opt/yosys-src && \
    git -C /opt/yosys-src checkout --detach "${YOSYS_REV}" && \
    git -C /opt/yosys-src submodule update --init --recursive && \
    cd /opt/yosys-src && \
    make config-gcc && \
    make -j"$(nproc)" PREFIX=/opt/yosys && \
    make install PREFIX=/opt/yosys

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
# Build xezim
# ============================================================
FROM base AS xezim-build
ARG XEZIM_REV=4d145813a65ab1ea0b8d2802b0b0f2a2b8a1fe4a
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
ARG SURFER_REV=fef7cf161dca4271406c0cf4d94926449f63304f
RUN git clone --filter=blob:none https://gitlab.com/surfer-project/surfer.git /opt/surfer-src && \
    git -C /opt/surfer-src checkout --detach "${SURFER_REV}" && \
    cd /opt/surfer-src && \
    cargo build --release --locked --bin surfer && \
    mkdir -p /opt/surfer/bin && \
    cp target/release/surfer /opt/surfer/bin/

# ============================================================
# Download pinned Verible pre-built binaries
# ============================================================
FROM base AS verible-download
ARG VERIBLE_VERSION=v0.0-4157-gfdbac312
ARG VERIBLE_SHA256=9e7ead54bc5efcc31476eb87dd970fe51314e8ca6bd00e0646e1ea6cde137448
RUN mkdir -p /opt/verible && \
    curl -fsSL "https://github.com/chipsalliance/verible/releases/download/${VERIBLE_VERSION}/verible-${VERIBLE_VERSION}-linux-static-x86_64.tar.gz" \
        -o /tmp/verible.tar.gz && \
    echo "${VERIBLE_SHA256}  /tmp/verible.tar.gz" | sha256sum -c - && \
    tar -xzf /tmp/verible.tar.gz --strip-components=1 -C /opt/verible && \
    rm /tmp/verible.tar.gz

# ============================================================
# Final image
# ============================================================
FROM base AS final

# SymbiYosys runtime dependency. Keep this in the final stage so changes do not
# invalidate the expensive compiler-tool build stages.
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-click \
    && rm -rf /var/lib/apt/lists/*

COPY --from=verilator-build /opt/verilator /opt/verilator
COPY --from=yosys-build /opt/yosys /opt/yosys
COPY --from=sby-build /opt/sby /opt/sby
COPY --from=xezim-build /opt/xezim /opt/xezim
COPY --from=surfer-build /opt/surfer /opt/surfer
COPY --from=verible-download /opt/verible /opt/verible
COPY libs/uvm /opt/uvm

ENV PATH="/opt/verilator/bin:/opt/yosys/bin:/opt/sby/bin:/opt/xezim/bin:/opt/surfer/bin:/opt/verible/bin:${PATH}"
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

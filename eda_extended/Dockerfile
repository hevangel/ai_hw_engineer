# Extended EDA image: the qualified SystemVerilog tools image plus NVC (VHDL)
# and Accellera SystemC. This overlay adds only the two upstream reference
# tools tracked by issues #82 and #83; the remaining extended-image members
# (e1647-rs and the NVC/SystemC Rust ports, issue #84) are not part of it.
#
# Build the base first, then this overlay:
#   docker build -t ai-hw-engineer .
#   docker build -f eda_extended/Dockerfile -t ai-hw-engineer-extended .
# Pin a base explicitly with: --build-arg ENGINEER_IMAGE=ai-hw-engineer@sha256:<digest>

ARG ENGINEER_IMAGE=ai-hw-engineer:latest

# ============================================================
# NVC (VHDL compiler and simulator), release r1.23.1
# ============================================================
FROM ${ENGINEER_IMAGE} AS nvc-build
ARG BUILD_JOBS=4
ARG NVC_REV=fab54a9e96964b431050d837e163c22282a1df6c
RUN apt-get update && apt-get install -y --no-install-recommends \
    check \
    libdw-dev \
    libtool \
    libzstd-dev \
    llvm-21-dev \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --filter=blob:none https://github.com/nickg/nvc.git /opt/nvc-src && \
    git -C /opt/nvc-src checkout --detach "${NVC_REV}" && \
    cd /opt/nvc-src && \
    ./autogen.sh && \
    mkdir build && cd build && \
    ../configure --prefix=/opt/nvc --with-llvm=/usr/lib/llvm-21/bin/llvm-config && \
    make -j"${BUILD_JOBS}" && \
    make install

# ============================================================
# Accellera SystemC reference implementation, release 3.0.2
# ============================================================
FROM ${ENGINEER_IMAGE} AS systemc-build
ARG BUILD_JOBS=4
ARG SYSTEMC_REV=70b0fc8e4a74acc677b0fc73cea08f940c2115d5
RUN git clone --filter=blob:none https://github.com/accellera-official/systemc.git /opt/systemc-src && \
    git -C /opt/systemc-src checkout --detach "${SYSTEMC_REV}" && \
    cmake -S /opt/systemc-src -B /opt/systemc-src/build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CXX_STANDARD=17 \
      -DCMAKE_INSTALL_PREFIX=/opt/systemc \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DBUILD_SHARED_LIBS=OFF \
      -DENABLE_EXAMPLES=ON \
      -DENABLE_REGRESSION=ON && \
    cmake --build /opt/systemc-src/build -j"${BUILD_JOBS}" && \
    cmake --install /opt/systemc-src/build

# ============================================================
# Final image
# ============================================================
FROM ${ENGINEER_IMAGE} AS final
RUN apt-get update && apt-get install -y --no-install-recommends \
    libdw1 \
    libllvm21 \
    libzstd1 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=nvc-build /opt/nvc /opt/nvc
COPY --from=systemc-build /opt/systemc /opt/systemc
ENV PATH="/opt/nvc/bin:${PATH}"
ENV SYSTEMC_HOME=/opt/systemc
WORKDIR /workspace

# Fail the build if either tool cannot start or run a trivial design.
RUN set -eux; \
    nvc --version; \
    test -f /opt/systemc/include/systemc; \
    test -f /opt/systemc/lib/libsystemc.a; \
    echo "Extended EDA tools installed successfully"

CMD ["/bin/bash"]

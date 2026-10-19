ARG ENGINEER_IMAGE=ai-hw-engineer:latest
FROM ${ENGINEER_IMAGE}

# The base image's Ubuntu snapshot is pinned in the project Dockerfile.
# Icarus is the independent four-state/VPI backend for the motherboard model.
RUN apt-get update && apt-get install -y --no-install-recommends iverilog=12.0-3 \
    && rm -rf /var/lib/apt/lists/*
RUN iverilog -V && vvp -V && test -f /usr/include/iverilog/vpi_user.h

ARG ENGINEER_IMAGE=ai-hw-engineer:latest
FROM ${ENGINEER_IMAGE}

# The base image's Ubuntu snapshot is pinned in the project Dockerfile.
# Icarus is the independent four-state/VPI backend for the motherboard model.
RUN apt-get update && apt-get install -y --no-install-recommends iverilog=12.0-3 \
    && rm -rf /var/lib/apt/lists/*
# Ubuntu 12.0-3 embeds a stray literal "0-3" in both VPI compiler flag
# lists. Remove only that standalone token in these two assignments;
# keep the simulator, include paths, hardening flags and license intact.
RUN sed -i '/^CFLAGS=/s/ 0-3 / /g; /^CXXFLAGS=/s/ 0-3 / /g' /usr/bin/iverilog-vpi

COPY scripts/check_eda_tools.py /opt/eda/check_eda_tools.py
# Exercise compilation, four-state execution, the packaged VPI helper,
# actual VPI loading, and a required failure path at image build time.
RUN python3 /opt/eda/check_eda_tools.py --tools iverilog --work-dir /tmp/iverilog-smoke

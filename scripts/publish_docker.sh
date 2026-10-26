#!/bin/sh
# Build, smoke-test and publish the EDA image to Docker Hub with its overview.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "${PYTHON:-python3}" "$SCRIPT_DIR/publish_docker.py" "$@"

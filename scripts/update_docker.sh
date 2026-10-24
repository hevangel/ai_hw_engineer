#!/bin/sh
# Resolve release pins, update documentation, and rebuild the local Docker image.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec python3 "$SCRIPT_DIR/update_docker.py" "$@"

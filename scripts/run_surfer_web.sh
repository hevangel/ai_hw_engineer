#!/bin/sh
# Run a local, self-hosted Surfer web viewer in Docker for one waveform file.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(dirname "$SCRIPT_DIR")

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <waveform-file>" >&2
    echo "Example: $0 design/alu_74181/work/sim/alu_74181.fst" >&2
    exit 2
fi

WAVEFORM_ARG=$1
case "$WAVEFORM_ARG" in
    /*) WAVEFORM_CANDIDATE=$WAVEFORM_ARG ;;
    *) WAVEFORM_CANDIDATE="$REPO_DIR/$WAVEFORM_ARG" ;;
esac

if [ ! -f "$WAVEFORM_CANDIDATE" ]; then
    echo "ERROR: waveform file not found: $WAVEFORM_CANDIDATE" >&2
    exit 1
fi

WAVEFORM_PATH=$(realpath "$WAVEFORM_CANDIDATE")
WAVEFORM_DIR=$(dirname "$WAVEFORM_PATH")
WAVEFORM_NAME=$(basename "$WAVEFORM_PATH")
IMAGE=${AI_HW_ENGINEER_IMAGE:-ai-hw-engineer:surfer-web}
WEB_PORT=${SURFER_WEB_PORT:-18080}
SURFER_TOKEN=${SURFER_TOKEN:-$(od -An -N18 -tx1 /dev/urandom | tr -d ' \n')}

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "ERROR: Docker image '$IMAGE' is not available." >&2
    echo "Build it from the repository root with: docker build -t $IMAGE ." >&2
    exit 1
fi

echo "Serving waveform: $WAVEFORM_PATH"
echo "The ports are bound to localhost only. Press Ctrl+C to stop."

exec docker run --rm --init \
    -p "127.0.0.1:${WEB_PORT}:8080" \
    -v "$WAVEFORM_DIR:/waveforms:ro" \
    -e "SURFER_WAVEFORM=/waveforms/$WAVEFORM_NAME" \
    -e "SURFER_TOKEN=$SURFER_TOKEN" \
    -e "SURFER_WEB_PUBLIC_PORT=$WEB_PORT" \
    "$IMAGE" \
    /opt/surfer/serve_web.sh

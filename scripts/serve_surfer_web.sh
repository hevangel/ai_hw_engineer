#!/bin/sh
# Container entrypoint for the self-hosted Surfer web viewer.
set -eu

SURFER_WAVEFORM=${SURFER_WAVEFORM:?set SURFER_WAVEFORM to a waveform file in the mounted directory}
SURFER_TOKEN=${SURFER_TOKEN:?set SURFER_TOKEN}

if [ ! -r "$SURFER_WAVEFORM" ]; then
    echo "ERROR: waveform is not readable: $SURFER_WAVEFORM" >&2
    exit 1
fi

surver "$SURFER_WAVEFORM" \
    --bind-address 0.0.0.0 \
    --port 8911 \
    --token "$SURFER_TOKEN" &
SURVER_PID=$!

python3 /opt/surfer/serve_web.py &
WEB_PID=$!

cleanup() {
    kill "$SURVER_PID" "$WEB_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

sleep 1
if ! kill -0 "$SURVER_PID" 2>/dev/null; then
    echo "ERROR: Surver failed to start" >&2
    wait "$SURVER_PID" || true
    exit 1
fi
if ! kill -0 "$WEB_PID" 2>/dev/null; then
    echo "ERROR: Surfer web server failed to start" >&2
    wait "$WEB_PID" || true
    exit 1
fi

WEB_PORT=${SURFER_WEB_PUBLIC_PORT:-8080}
CONNECTION_URL="http://localhost:${WEB_PORT}/${SURFER_TOKEN}"
ENCODED_CONNECTION_URL=$(python3 -c \
    'from urllib.parse import quote; import sys; print(quote(sys.argv[1], safe=""))' \
    "$CONNECTION_URL")

echo "Self-hosted Surfer is ready. Open this local URL in your browser:"
echo "http://localhost:${WEB_PORT}/?load_url=${ENCODED_CONNECTION_URL}"

while kill -0 "$SURVER_PID" 2>/dev/null && kill -0 "$WEB_PID" 2>/dev/null; do
    sleep 1
done

wait "$SURVER_PID" 2>/dev/null || true
wait "$WEB_PID" 2>/dev/null || true

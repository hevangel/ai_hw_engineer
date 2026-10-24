#!/bin/sh
# Refresh official Markdown references alongside the maintained tool guides.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec python3 "$SCRIPT_DIR/update_tool_docs.py" "$@"

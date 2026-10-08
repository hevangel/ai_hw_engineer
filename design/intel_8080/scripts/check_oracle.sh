#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ORACLE_DIR="$SCRIPT_DIR/../../amd_am9080/references/superzazu"
printf '%s\n' \
    'aba87f0e380e607b1971943323c96114305b889c1f76c5db303f5262da73db36 i8080.c' \
    'f78d7461ae649166b189e869c7cfde08347219bd87fac87ff3c6da6c2f0866f6 i8080.h' |
while read -r expected filename; do
    # Git may check out upstream LF text as CRLF on Windows. Normalize only
    # line terminators for integrity checking; never rewrite the oracle files.
    actual=$(sed 's/\r$//' "$ORACLE_DIR/$filename" | sha256sum)
    if [ "${actual%% *}" != "$expected" ]; then
        echo "ERROR: pinned oracle integrity mismatch: $filename" >&2
        exit 1
    fi
    echo "Pinned oracle $filename: OK (canonical LF SHA-256)"
done

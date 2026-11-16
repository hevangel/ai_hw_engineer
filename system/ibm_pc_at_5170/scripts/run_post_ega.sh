#!/bin/sh
# The IBM PC AT 5170 with the EGA card: see run_post_card.sh.
# Usage: scripts/run_post_ega.sh /path/to/atbios.bin
set -eu
exec "$(dirname -- "$0")/run_post_card.sh" ega "$@"

#!/bin/sh
# The IBM PC AT 5170 with the VGA card: see run_post_card.sh.
# Usage: scripts/run_post_vga.sh /path/to/atbios.bin
set -eu
exec "$(dirname -- "$0")/run_post_card.sh" vga "$@"

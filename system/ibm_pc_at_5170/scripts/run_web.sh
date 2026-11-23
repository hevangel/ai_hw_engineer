#!/bin/sh
# Web front end of the IBM PC AT 5170 with the VGA card.
#
# Usage: scripts/run_web.sh /path/to/atbios.bin [port] [server options]
#   server options: --ext-kb N     expansion RAM from 1 MB (1024 = 2 MB machine)
#                   --fda PATH     mount a 1.2 MB or 360 KB image in drive A
#                   --fdb PATH     mount a diskette image in drive B
#                   --fda-type T   drive A type: 1.2 (default), 360 or none
#                   --fdb-type T   drive B type: 1.2, 360 or none (default)
#                   --fda-ro       write-protect drive A
#                   --fdb-ro       write-protect drive B
#                   --write-back   save written sectors to the image on exit
#                   --batch-dir D  also show a batch run's progress and frames
#                   --script F     scripted key input (see the README)
# Checks the BIOS hash, rebuilds/fetches and hash-checks the 8042 and VGA
# ROMs, builds the simulator (scripts/build_host.sh) and serves the page on
# http://localhost:PORT/ (default 8286). Inside Docker, publish the port:
#   docker run -p 8286:8286 -v "$PWD":/work -w /work ai-hw-engineer:latest \
#       sh system/ibm_pc_at_5170/scripts/run_web.sh system/ibm_pc_at_5170/work/software/atbios.bin
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYS_DIR=$(dirname "$SCRIPT_DIR")
if [ "$#" -lt 1 ]; then
    echo "usage: $0 /path/to/atbios.bin [port] [server options]" >&2
    exit 2
fi
BIOS=$1
shift
PORT=8286
case ${1:-} in
    [0-9]*) PORT=$1; shift ;;
esac
HOST_LINE=$(sh "$SCRIPT_DIR/build_host.sh" "$BIOS" | tail -n 1)
set -- $HOST_LINE "$@"
shift   # "HOST"
SIM=$1 ROM=$2 VGA=$3
shift 3
echo "== serving on http://localhost:$PORT/"
exec python3 "$SYS_DIR/host/server.py" "$SIM" "$ROM" "$VGA" --port "$PORT" "$@"

#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p work
cc -std=c11 -Wall -Wextra -Werror -fPIC -shared -I/usr/include/iverilog \
    host/front_panel.c -o work/front_panel.vpi
iverilog -g2012 -s tb_front_panel_transport -o work/front_panel_transport.vvp tb/tb_front_panel_transport.sv
vvp -Mwork -mfront_panel work/front_panel_transport.vvp
python3 - <<'PY'
from pathlib import Path
frame=Path('work/front_panel.frame').read_bytes()
assert len(frame)==107520 and frame[:3]==bytes([1,2,0]) and frame[-1]==1
assert set(frame[2:-1])=={0}
print('PASS frame orientation, size and unknown pixel preservation')
PY

#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/fetch_board_references.py
cc -std=c11 -Wall -Wextra -Werror -shared -fPIC -O2 -I/usr/include/iverilog -Iwork/reference \
    board/cpu_reference.c work/reference/netlist_sim_initialized.c -o work/cpu_reference.vpi
iverilog -g2012 -s tb_cpu_reference -o work/cpu_reference_smoke.vvp tb/tb_cpu_reference.sv
# Poison fresh glibc malloc blocks so an uninitialized solver state cannot pass by chance.
MALLOC_PERTURB_=165 vvp -Mwork -mcpu_reference work/cpu_reference_smoke.vvp

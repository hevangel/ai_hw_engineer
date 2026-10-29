#!/bin/sh
# Seeded-defect check: each mutant of the RTL must be rejected by the oracle.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK="$HERE/work/mutants"
mkdir -p "$WORK"
python3 "$HERE/scripts/fetch_reference.py" > /dev/null
detected=0
total=0
while IFS='#' read -r name from to; do
    [ -n "$name" ] || continue
    total=$((total + 1))
    sed "s/$from/$to/" "$HERE/src/commodore_906114.sv" > "$WORK/$name.sv"
    if cmp -s "$WORK/$name.sv" "$HERE/src/commodore_906114.sv"; then
        echo "MUTANT $name did not apply"; exit 1
    fi
    verilator --binary --top-module tb_top --Mdir "$WORK/obj_$name" -o Vtb \
        "$WORK/$name.sv" "$HERE/tb/tb_top.sv" > "$WORK/$name.build.log" 2>&1
    "$WORK/obj_$name/Vtb" "+out=$WORK/$name.txt" > /dev/null
    if python3 "$HERE/scripts/pla_oracle.py" "$WORK/$name.txt" > "$WORK/$name.log" 2>&1; then
        echo "MUTANT $name SURVIVED"; exit 1
    fi
    detected=$((detected + 1))
    echo "mutant $name detected: $(tail -n 1 "$WORK/$name.log")"
done <<'LIST'
basic_in_ultimax#a13_i \&\& cpu \&\& rw_i \&\& game_on;#a13_i \&\& cpu \&\& rw_i;
charom_loram_term#loram_i \&\& !charen_i \&\& dio#hiram_i \&\& !charen_i \&\& dio
io_read_without_ba#charen_i \&\& dio \&\& cpu \&\& ba_i \&\& rw_i \&\& game_on#charen_i \&\& dio \&\& cpu \&\& rw_i \&\& game_on
roml_on_writes#a13_i \&\& cpu \&\& rw_i \&\& !exrom_i;#a13_i \&\& cpu \&\& !exrom_i;
vic_bank_polarity#va14_i \&\& aec_i \&\& game_on#!va14_i \&\& aec_i \&\& game_on
ultimax_c000_mapped#!a13_i \&\& !a12_i \&\& cpu \&\& ultimax;#!a13_i \&\& !a12_i \&\& cpu \&\& 1'b0;
vic_romh_keeps_ram#(|p\[28:9\]);#(|p[22:9]) || (|p[28:24]);
grw_ignores_cas#!cas_i \&\& dio \&\& cpu \&\& !rw_i#dio \&\& cpu \&\& !rw_i
kernal_16k_dropped#hiram_i \&\& a15_i \&\& a14_i \&\& a13_i \&\& cpu \&\& rw_i \&\& cart16#1'b0
LIST
echo "COMMODORE 906114 MUTANTS: $detected of $total detected"

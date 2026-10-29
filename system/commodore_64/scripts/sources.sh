# Source list for the C64 board (sourced by the other scripts).
C64_SOURCES="
$ROOT/design/mos_6502/src/mos_6502_native.sv
$ROOT/design/mos_6510/src/mos_6510_port.sv
$ROOT/design/mos_6510/src/mos_6510.sv
$ROOT/design/mos_6526/src/mos_6526_timer.sv
$ROOT/design/mos_6526/src/mos_6526_tod.sv
$ROOT/design/mos_6526/src/mos_6526_serial.sv
$ROOT/design/mos_6526/src/mos_6526_irq.sv
$ROOT/design/mos_6526/src/mos_6526.sv
$ROOT/design/mos_6567/src/mos_6567.sv
$ROOT/design/mos_6581/src/mos_6581.sv
$ROOT/design/commodore_906114/src/commodore_906114.sv
$SYSTEM/src/c64_memory.sv
$SYSTEM/src/c64_board.sv
"

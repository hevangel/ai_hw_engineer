# Source list shared by the SNES system scripts (sourced, not executed).
SNES_INC="-I$ROOT/design/sony_s_dsp/src"
SNES_CHIP_SRC="$ROOT/design/wdc_65c816/src/wdc_65c816.sv $ROOT/design/ricoh_5a22/src/ricoh_5a22.sv $ROOT/design/ricoh_5c77/src/ricoh_5c77.sv $ROOT/design/ricoh_5c78/src/ricoh_5c78.sv $ROOT/design/sony_spc700/src/sony_spc700.sv $ROOT/design/sony_s_smp/src/sony_s_smp.sv $ROOT/design/sony_s_dsp/src/sony_s_dsp.sv"
SNES_BOARD_SRC="$SYSTEM/src/snes_controller.sv $SYSTEM/src/snes.sv"
SNES_SRC="$SNES_CHIP_SRC $SNES_BOARD_SRC $SYSTEM/src/snes_memory.sv"

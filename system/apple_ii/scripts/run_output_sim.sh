#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p work
python3 scripts/check_output_wiring.py
for audio in 0 1; do
iverilog -g2012 -Ptb_rev0_outputs.AUDIO_TEST=$audio -s tb_rev0_outputs -o work/outputs.vvp \
    src/apple_ii_video_output.sv src/apple_ii_speaker_output.sv tb/tb_rev0_outputs.sv
vvp work/outputs.vvp >work/outputs.log 2>&1 || { cat work/outputs.log; exit 1; }
cat work/outputs.log
grep -q 'PASS revision-0 output' work/outputs.log
done
python3 scripts/check_output_waveforms.py

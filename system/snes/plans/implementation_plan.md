# SNES implementation plan

Status: steps 1-5 done; step 6 in progress.

1. Specification, sources and firmware provenance: [spec](../spec/spec.md).
   Only the 64-byte S-SMP IPL ROM is firmware; it is fetched to `work/`.
2. Chips: new designs for the WDC 65C816 core, Ricoh 5A22, 5C77, 5C78, the
   Sony SPC700 core, S-SMP and S-DSP, each verified on its own first (CPU
   cores against the SingleStepTests vectors, S-DSP tables against the
   hardware dump).
3. Board: one master clock with clock enables; A-bus decode for work RAM and
   LoROM/HiROM cartridges; B-bus mux for the PPUs, APU ports and work-RAM
   port; APU cycle enable from a phase accumulator; separate power-on and
   reset-button inputs.
4. Host: line-protocol simulator (screen, audio, trace, waveform capture)
   and the web panel shared in style with the NES system.
5. Verification: `scripts/test_software.py` runs every Peter Lemon ROM that
   has a reference screenshot and the SPC700 sound demos;
   `scripts/test_backend.py` checks the panel API; `scripts/run_synth.sh`
   synthesizes the whole board with Yosys.
6. Record results and boundaries in the [final report](../report/final_report.md),
   then update the README and the system index.

# Processor-extension transfer engine checkpoint

The standalone `intel_80286_pedc` implements the transaction order in Intel
210760-002 chapter 6: memory read then port FAh write, or port FAh read then
memory write. Odd words use two byte-lane memory beats. The engine is not yet
connected to the CPU, its arbiter, the native pin wrapper or an 80287; it does
not establish architectural ESC completion. The [channel contract](../spec/processor_extension_channel.md)
records its inputs, the obligations of the future owner, and assumption A26.

`scripts/run_pedc.sh` passes Verilator `-Wall` simulation for both directions,
even and odd words, grant and READY stalls, repeated requests, a held request,
BUSY termination and reset during the first transfer. A separate Yosys 0.69
`synth -top intel_80286_pedc; check -assert` completed successfully. These are
component results, not physical timing, connected-core or real-software tests.
The component's SBY depth-24 BMC and induction tasks pass, and cover reaches
all four witnesses, including both odd-word directions. These properties check
request stability and control invariants, not complete 80287 protocol timing.
The tested PEDC source SHA-256 is
`0dca1889f49963514ebbadffe39c550db8579db7562a8c768ed6537ca3759c9e`.
The canonical full simulation now includes the component test; a new full run
was started in container `codex-286-pedc-full-sim-20261030-01` and has no
terminal result at this checkpoint.

The prior D8-register `run_sim.sh` and `run_software.sh` containers both exited
zero, with 213 and 17 PASS lines respectively. Their CPU runner fingerprint is
`cd7fe32789b9`; the protected replay manifest is under
`work/d8_register_20261030_04/protected_mode_sim_20261030T070035Z/`.
The standalone PEDC files were added while those broader jobs were running, so
the runs are not claimed as a single frozen-tree result for the new component.
The software run includes native IBM AT BIOS checkpoints with captured I/O
replayed into Unicorn; it does not exercise an 80287.

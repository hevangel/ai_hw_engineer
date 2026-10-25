# Am2910 simulation plan

Generate a table-driven independent oracle from the manufacturer's Table I
transcription. Each transition starts with pin-driven JZ, five pushes with
chosen PCs, pops to requested depth, counter load and a direct PC setup.
Check current Y, three decoder outputs, OE and FULL. Clock the instruction;
probe counter via failed JRP, PC via CONT, then all active stack words via
native pops; inactive words are checked by formal watched-slot properties. Empty-stack branch output is not asserted.
Exhaust every opcode Ã— CC/CCEN/CI/RLD/OE combination Ã— depth 0â€“5 with a
counter boundary matrix; add deterministic random 12-bit data/state cases.
Execute Figure 4 manufacturer firmware for conditional subroutine return,
RFCT, RPCT, LOOP and TWB with exact PC traces, including maximum 4096 loops.

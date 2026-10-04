# Implementation plan

1. Establish original clock phases, instruction tables and all status polarities
   from rendered manufacturer pages before writing RTL.
2. Implement a separate combinational four-bit ALU with complete Figure 8
   status outputs, then native CP-controlled port/storage latches and Q flip-flops.
3. Keep tri-state pin drive/value separate, with no fabricated reset.
4. Run the unchanged independently authored Java oracle; record and resolve
   status disagreements against original equations in a separate adapter.
5. Exercise all 512 words, all arithmetic operand pairs and both carry levels,
   destination/shift/address behavior, transparent phases and a real cascade.
6. Run authentic 1975 manufacturer multiplication microcode with exact next-word checks.
7. Prove ALU equations and storage/controller invariants, reach covers, lint
   and synthesize; publish observed results and historical date evidence.

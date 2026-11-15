# Am29338 implementation plan

1. Transcribe Tables 1–4 and the Figures 6/7 byte-stream examples from
   the datasheet page images before RTL; derive the byte-stream model
   (ring, BSW reorder, LSB-first disassembly, pointer window).
2. Implement one module: 128-byte parity ring, queue/dequeue pointers
   with queue-count and dequeue-count registers feeding a combinational
   difference (datasheet Byte-Count Logic), BSW input rotator with
   parity-bit travel, output window, status generation, async RESET and
   RXMIT (RXMIT sampled at DQCLK edges — ledger).
3. Generate a lockstep drive oracle (Figure 6/7 flows, BSW sweep,
   fill-to-full with drop-on-full, full drain, RXMIT retransmit per
   Figure 5, POS quadrants, simultaneous queue/dequeue, 12,000 random
   full-space drives) with validity masking on never-written cells.
4. Prove formal BMC/PDR/cover: status/count contracts, pointer-window
   equality, parity functions, reset hold invariants and covers for all
   byte counts, BSW encodings, statuses and control events (the FULL and
   A-FULL covers need a deeper cover depth — 40 — to fill the queue).
5. Run synthesis with `check -assert`; record results and limits.

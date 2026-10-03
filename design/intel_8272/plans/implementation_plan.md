# Implementation plan

1. Preserve and visually inspect Intel's command/status tables before RTL.
2. Implement edge-qualified host/DMA access, RQM delay and command/result phases.
3. Implement four seek engines, ready polling, head timing and SIS events.
4. Implement media search/read/write/format/scan execution, errors, MT/EOT/TC and status IDs.
5. Add independent FM/MFM word codec and CCITT CRC helper with externally derived vectors.
6. Verify all commands and errors with a real-content virtual media BFM, directed/seeded bus tests, and UVM protocol scoreboard/coverage.
7. Prove control/bounds/handshake invariants and cover non-vacuous command, data and seek paths. Run lint, formal, both simulators and synthesis.
8. Record actual coverage/results and all virtual-media limitations; update historical index/README and open an independent PR from main.

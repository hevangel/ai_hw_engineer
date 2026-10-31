# Commodore 906114-01 implementation plan

1. Pin the reference: VICE memory tables (the oracle) and MAME's pin order
   (interface only). Done: `scripts/fetch_reference.py`.
2. Write the combinational term model on board polarities. Done.
3. Oracle: dump all 65,536 words in Verilator and Icarus and compare with
   the VICE-derived map; check the CAS and BA words against the ledger
   rules. Done: `scripts/run_sim.sh`, `scripts/pla_oracle.py`.
4. Seeded defects that each oracle class must catch. Done: nine mutants.
5. Formal safety properties and reachability covers. Done.
6. Synthesis. Done.
7. Integrate into the Commodore 64 board and confirm original BASIC and
   KERNAL banking against VICE x64sc. Done in `system/commodore_64`.

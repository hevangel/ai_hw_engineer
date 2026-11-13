# Intel 8042 test plan

All simulation checks compare the RTL with the reference model
`scripts/upi42_iss.py`, which is written from the Intel UPI-41A manual and
never from the RTL. On every retired instruction or interrupt vector, the
bench compares:
- the kind, address and opcode of the retired instruction;
- the machine-cycle count and the next PC;
- A, the PSW and the status register;
- the timer count, the prescaler and the timer mode;
- DBBIN and DBBOUT, and the P1 and P2 drive;
- the interrupt flags;
- all 128 RAM bytes.

Every host read value is compared as well.

| Check | Source of truth | Script |
|---|---|---|
| Decoder vs independent disassembler | Tarpai's disassembly of 781 instructions in 1503033 | `check_decoder_vs_listing.py` |
| Manual examples and corner cases (14 tests) | M chapter 2/3 statements and worked examples, exact PCs | `directed_tests.py` |
| Same 14 programs, RTL vs model | Model | `run_sim.sh` |
| Random programs, all 256 opcodes, forced host writes, reads, pin changes | Model | `gen_random_test.py`, `run_sim.sh` (32 seeds x 20,000 retires) |
| IBM 1503033 partial rebuild, command AAh | Model; firmware must stop at the ROM-checksum stage (status 48h, no reply) | `tb/scripts/fw_selftest.txt` |
| IBM 1503033 CRC-balanced test image, BIOS command order | Model; replies must be 55 00 FF 5D CF CF FE 55 | `tb/scripts/fw_bios_cmds.txt` |
| Sequencing, interrupt and host-flag invariants | Formal proof, any program | `formal/upi42_core.sby` |

Mutation check (run during development, not in the regression): three
planted RTL faults were each caught by the random seeds. The faults were
DA losing its carry, JMPP using a wrong page, and a 31-cycle prescaler.

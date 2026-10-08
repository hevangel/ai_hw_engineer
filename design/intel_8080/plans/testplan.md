# Intel 8080 test plan

- Use the pinned external Intel emulator unchanged, without AMD flag patches.
- Exhaust all 16 ALU operations, operands and 32 flag combinations; compare
  A and the complete normalized PSW, including ANA/ANI and DAA.
- Sweep all 244 documented opcodes across 32 initial flag combinations.
  Check exact post-instruction PC, next fetched/executed opcode, registers,
  stack pointer, flags and memory/I/O effects. Poison unused memory with HLT.
- Run original hash-verified TST8080.COM and 8080PRE.COM; compare retirement
  traces and complete BDOS output. BDOS service is provided outside program
  bytes by the harness. Include this regression in `run_all.sh`.
- UVM checks READY stability, HOLD arbitration, EI delay, RST injection,
  HALT exit, reset retention, PSW/register preservation, I/O and validity
  faults. CALL stream tests exercise the provisional contract, not its
  Intel historical sign-off. Register-save ISR code is inherited from the
  AMD handbook and is identified as such, not relabeled Intel historical code.
- Add four bit-3 combinations for both register ANA and immediate ANI;
  expected flags are pinned to Intel's manual, including AC=0 and AC=1 cases.
- Watchdogs, expected case counts, opcode coverage and required success
  messages reject incomplete runs.

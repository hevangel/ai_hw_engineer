# Specification: Intel 80287 numeric processor extension

## 1. Authority

- **[286PRM]** Intel *80286 and 80287 Programmer's Reference Manual*, order 210498-005 (1987). This covers the 80287 instruction set, Table 3-1 (state after initialization), Figure 2-2 (environment layouts) and Appendix B (differences between the 80287 and the 8087).
- **[287DS]** Intel *80287 data sheet*, February 1983. It specifies the pins, the processor-extension I/O ports and the PEREQ/PEACK#, BUSY# and ERROR# protocol.
- **[8087]** Everything not stated as different is inherited from the 8087 specification in [../../intel_8087/spec/spec.md](../../intel_8087/spec/spec.md). [286PRM] Appendix B lists the 80287's differences from the 8087. All of them concern the system interface; none changes arithmetic.

## 2. Implementation boundary (milestone M1)

The design is the shared x87 controller `intel_8087` with `VARIANT = 1`, which selects 80287 behaviour. It uses the shared numeric datapath (`intel_8087_alu`, `intel_8087_trans`, `intel_8087_math.svh`) and adds no copy of the RTL.

M1 is an **architectural** model behind the same transaction interface as the 8087 core. The host supplies:
- the ESC opcode and ModR/M byte;
- the operand's physical address, which the core uses for its byte transfers;
- the instruction pointer and operand pointer values to record, plus the two selectors used in protected-mode images.

The native 80287 interface is milestone M2. In that interface the 80286 moves every operand word through I/O port 00FAh, driven by PEREQ/PEACK#, and sends commands through ports 00F8h–00FEh. Its CPU side already exists in the 80286 core (`design/intel_80286/spec/processor_extension_channel.md`).

### 2.1 Ports added for VARIANT ≥ 1

When `VARIANT = 0` the 8087 ignores these ports, and its regression ties them off.

| Port | Dir | Width | Meaning |
| --- | --- | --- | --- |
| `cs_sel_i` | in | 16 | CS selector of the ESC instruction (protected-mode pointer image) |
| `ds_sel_i` | in | 16 | Selector of the memory operand |
| `protected_i` | in | 1 | CPU in protected mode (used by VARIANT 2; the 80287 uses its own FSETPM state instead) |
| `opsize32_i` | in | 1 | 32-bit operand size for environment and save images (VARIANT 2 only) |
| `ax_write_o` | out | 1 | Pulses with `done_o` for FSTSW AX |
| `ax_o` | out | 16 | Status word for the CPU's AX register |

With `VARIANT ≥ 1`, `address_i`, `instruction_i` and `mem_address_o` are 32 bits wide (parameter `AW = 32`).

## 3. Behaviour that differs from the 8087

| # | 80287 behaviour | Source |
| --- | --- | --- |
| P1 | **Error reporting.** Exceptions are signalled on ERROR#, which does not pass through an interrupt controller. `int_o` represents ERROR# asserted: it is high whenever an unmasked exception is pending, and IEM (control bit 7) has no effect. `cpu_wait_i` is ignored. | [286PRM] App. B item 1 |
| P2 | **FENI/FDISI.** FENI/FNENI (DB E0) and FDISI/FNDISI (DB E1) "perform no specific operation and no internal states will be affected". Their opcode map entries are "reserved (8087 FENI/FDISI)". They complete normally, are not reported as unsupported, and leave the exception pointers unchanged. | [286PRM] p. 2-15, App. B item 2, opcode map |
| P3 | **FSETPM** (DB E4) puts the 80287 into protected mode. Only a hardware RESET returns it to real-address mode; FINIT/FNINIT does not change the mode. | [286PRM] p. 2-16, p. 3-5 |
| P4 | **FSTSW AX / FNSTSW AX** (DF E0) writes the status word to the 80286 AX register. It is modelled as `ax_write_o`/`ax_o`. | [286PRM] p. 2-17 |
| P5 | **Exception pointers.** The instruction address includes any leading prefixes. The host supplies that address; the core records whatever it is given. | [286PRM] App. B item 4 |
| P6 | **Protected-mode environment image (14 bytes).** CW, SW, TW, IP offset, CS selector, operand offset, operand selector; the opcode is not stored. In real-address mode the image is the 8087 layout: IP[15:0]; IP[19:16], 0, opcode[10:0]; OP[15:0]; OP[19:16], 0. FSAVE/FRSTOR use the same 14-byte header followed by the 80-byte register stack. | [286PRM] Fig. 2-2, App. B item 5 |
| P7 | **Initialization** (RESET and FINIT): CW = 03FFh (projective infinity, round to nearest, 64-bit precision, IEM = 1, all exceptions masked), SW = 0, TOP = 0, all tags empty. Registers and exception pointers are unchanged. | [286PRM] Table 3-1 |

All numeric behaviour is the 8087's, including projective/affine infinity control, unnormal and pseudo-zero handling, a single kind of NaN, and the reduced transcendental domains.

## 4. Assumption ledger

| Id | Assumption | Status |
| --- | --- | --- |
| P-A1 | The HMOS 80287 numeric execution unit is the 8087's. Arithmetic, rounding, exceptions and transcendental behaviour are identical. This rests on [286PRM] App. B, which lists only system differences. | Shared with the 8087 evidence; no physical-287 numeric capture is available |
| P-A2 | In protected mode the stored instruction/operand "offset" is the 16-bit offset the host passes. In real mode the core stores the 20-bit physical address, as the 8087 does. | Directed tests only |
| P-A3 | [286PRM] p. 2-19 says both that FSTENV "sets all exception masks" and that it "initializes the 80287 state as if FNINIT had been executed". The second statement repeats the FSAVE description. The 8087 behaviour (mask all exceptions, nothing else) is kept. | Needs a physical 80287 or an original exception handler to confirm |
| P-A4 | A pending unmasked exception asserts ERROR# immediately, regardless of IEM. | Follows from P1; ERROR# pin timing is M2 |
| P-A5 | Hardware reset clears the FSETPM mode. Register contents and pointers survive reset, as for the 8087. | [286PRM] text supports the mode reset; register retention is inherited |

## 5. Not in M1

- **Native interface:** the processor-extension I/O channel and its pins (PEREQ/PEACK#, BUSY#, ERROR#, CMD0/CMD1, NPS1#/NPS2, CKM clock mode).
- **Timing:** instruction timing, and the overlap of the control unit and numeric execution unit.
- **287XL:** a later CHMOS part with an 80387-class core. It is a separate member and is not this design.

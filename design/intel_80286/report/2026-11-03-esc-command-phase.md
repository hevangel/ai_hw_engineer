# ESC D8h-DFh command phase

The core previously sent the 80287 command words only for the D8h register
form and stopped (`fault_code_o=3`) on every other ESC. It now runs the
CPU-side command phase for every ESC opcode D8h-DFh. Register forms run in both
modes. Memory forms run in real mode only.

## Evidence

`scripts/analyze_esc_captures_all.py` surveys the pinned
[SingleStepTests/80286 revision 37c73caf](https://github.com/SingleStepTests/80286/tree/37c73caf53dcd22d3dd369ff09305d13d117a4fe)
ESC captures. That revision publishes only `v1_real_mode/D8.MOO.gz`
(SHA-256 `4fb3540180b6d30e9eb3cb958c6ff81f5be6bb4aac588d682f2dda82b7a3dc4d`);
D9h-DFh files do not exist there. Reproduce from `design/intel_80286`:

```sh
mkdir -p work/esc_capture_all work/hardware
curl -L .../v1_real_mode/D8.MOO.gz -o work/esc_capture_all/D8.MOO.gz
curl -L .../revocation_list.txt -o work/hardware/revocation_list.txt
cd scripts && python3 analyze_esc_captures_all.py ../work/hardware/revocation_list.txt ../work/esc_capture_all/D8.MOO.gz
```

Result: 1,248 register and 3,719 memory captures match the contract, and all
4,967 retire to the following HLT. No capture writes any port other than F8h
and FCh, and none reads an extension port. All 33 exception captures are
exception 13 on a memory form whose effective offset is FFFF. They have
instruction lengths 2-4 bytes and issue no writes.

## Implemented contract

1. Word write `(ModRM << 8) | opcode` to port F8h.
2. Instruction offset, then CS, to port FCh.
3. Memory forms: effective offset, then the selected segment register
   (default or override), to port FCh.
4. Retire. A memory operand at offset FFFF raises exception 13 first (real
   mode), with no writes.

ASSUMPTION A30: D9h-DFh follow the D8h protocol with their own opcode byte,
because the CPU does not decode the extension instruction. No physical capture
covers them. Memory operand transfers belong to the processor extension data
channel, which starts on PEREQ. `intel_80286_pedc` is not connected, so a
system with an attached 80287 would not receive or return operands.
Protected-mode memory forms still stop, because their operand segment checks
belong to that channel.

## Verification

`Vintel_80286 --processor-extension` adds 248 cases. It runs all eight opcodes,
three ModRM reg values, five addressing forms (DS, SS via BP, direct, ES
override, BX+SI), both READY modes, and the offset-FFFF exception 13 for each
opcode. It checks exact I/O addresses and data and the exact following HLT.

# Physical 286 D8 command evidence

The pinned [SingleStepTests/80286 revision 37c73caf](https://github.com/SingleStepTests/80286/tree/37c73caf53dcd22d3dd369ff09305d13d117a4fe) publishes `v1_real_mode/D8.MOO.gz` from a physical Harris 286. The capture file's SHA-256 is `4fb3540180b6d30e9eb3cb958c6ff81f5be6bb4aac588d682f2dda82b7a3dc4d`. The pinned revocation list has no matching D8 hashes. This is an independent CPU trace, subject to the capture generator's documented limitations; it does not establish that an 80287 was connected.

Reproduce the transaction analysis from the worktree root:

```sh
curl -L https://raw.githubusercontent.com/SingleStepTests/80286/37c73caf53dcd22d3dd369ff09305d13d117a4fe/v1_real_mode/D8.MOO.gz -o design/intel_80286/work/esc_capture_20261030/D8.MOO.gz
python3 design/intel_80286/scripts/analyze_esc_capture.py \
  design/intel_80286/work/esc_capture_20261030/D8.MOO.gz \
  design/intel_80286/work/hardware/revocation_list.txt
```

The second input is the pinned list downloaded by `prepare_hardware_tests.py`; both file identities are checked before analysis. Create the destination directory first. The analysis validates MOO framing, pairs each IOW status phase with its next data phase, and checks the captured word lanes. It uses the first phase's address because the address may be pipelined during the data phase; data sampled during the status phase can be stale.

All 5,000 captures were examined. The 1,248 register and 3,719 memory cases without exceptions issued the original D8 and ModRM bytes as a word to F8h, followed by instruction offset and CS words to FCh. The memory forms then issued effective offset and selected segment to FCh. The 33 exception-13 cases issued none of these writes. The analyzer checks prefixes, effective-address forms, displacement, segment selection and exact data, but is evidence analysis, not a replay of RTL against all captured test states. It does not establish fault priority in protected mode or other ESC opcodes.

The core implements the bounded D8 register form by emitting its command and instruction pointer words after the existing EM/TS, BUSY and ERROR checks. This uses the existing byte-compatible or native-word transaction abstraction. Memory forms and D9h–DFh remain diagnostic stops: the processor-extension data channel, PEREQ/PEACK, external 80287 execution, bus lock and its priority/timing are not implemented. Actual reserved-port transfers have hardware timing requirements beyond this transaction-level implementation.

The connected native CPU regression passes with the D8 F8h register encoding, checking the three word I/O beats against the captured `F8D8h`, `0100h`, `F000h` sequence, alongside its existing bus/interrupt checks. `run_native_cpu.sh` compiles with Verilator `-Wall`. The first functional run exposed stale prefix state after BUSY; the implementation now clears it on this route. The corrected `Vintel_80286 --processor-extension` run passes all 64 register encodings under stalled and unstalled READY and checks the exact following HLT. The compiler fingerprint is `cd7fe32789b9`; full simulation, software, synthesis and BMC are separate runs and must be checked for their own results.

# Intel 8087 specification

## Authority and design boundary

The authority is Intel's **The 8086 Family User's Manual, Numerics
Supplement**, July 1980, order 121586-001, particularly S.2–S.7, appendix B,
and the instruction encoding chart. The source URL and cache instructions
are in [references](../references/README.md). This specification precedes RTL.

The target is a synthesizable functional numeric coprocessor. The top accepts
the original D8–DF ESC opcode and ModR/M byte, an already calculated 20-bit
physical operand address, and instruction pointer. It transfers memory over
a byte-wide ready/valid bus. This is an architectural interface suitable for
the repository's 8086 ESC event; it is not the original multiplexed-pin,
prefetch-queue snooping or RQ/GT electrical interface. It does not promise
original instruction cycle counts.

## State and execution

Eight 80-bit temporary-real registers have explicit integer bits, 15-bit
biased exponents (bias 16383), and signs. The stack pointer wraps modulo
eight; push decrements it and pop empties the previous top before increment.
Physical two-bit tags are valid (normal or unnormal)=00, zero=01,
special=10, empty=11.
Control bits are six exception masks, interrupt-disable mask at bit 7,
precision at 9:8 (24/53/64), rounding at 11:10 (nearest-even/down/up/chop),
and projective/affine infinity control at bit 12. Initialization sets CW to
03FFh, TOP to zero, and tags to FFFFh. Registers and exception pointers retain
their values across initialization. Status bit 6 is reserved, not a later
x87 stack-fault bit. Status bits 5:0 are sticky exception indicators.

The instruction interface accepts on `cmd_valid_i && cmd_ready_o`. A single
instruction is outstanding. `done_o` pulses on completion; `unsupported_o`
identifies an encoding outside the implemented contract, rather than silently
executing a NOP. Reset aborts an in-flight command. Memory requests hold all
fields stable until `mem_ready_i`. Addresses increment modulo 2^20; all
formats and environments are little endian. Numeric memory types are binary
integers (16/32/64), real (32/64/80), and 18-digit packed BCD (80).
Environment images are 14 bytes; save images are 94 bytes with logical ST(0)
first. The exception pointer stores physical instruction/operand addresses,
and the eleven-bit ESC opcode in the original real-mode layout.

| Port | Contract |
|---|---|
| `clk`, `rst_n` | Rising-edge clock and synchronous active-low reset |
| `cmd_valid_i`, `cmd_ready_o` | Accept one ESC when both are high |
| `opcode_i`, `modrm_i` | First byte D8–DF and second instruction byte |
| `address_i`, `instruction_i` | Calculated operand and ESC physical addresses |
| `cpu_wait_i` | CPU currently executing WAIT; overrides IEM for a pending interrupt |
| `mem_valid_o`, `mem_ready_i` | Byte transfers on their joint rising edge |
| `mem_write_o`, `mem_address_o`, `mem_wdata_o`, `mem_rdata_i` | Direction, twenty-bit address and byte data |
| `done_o`, `unsupported_o` | One-cycle completion and rejected-encoding indication |
| `busy_o`, `int_o` | Transaction/pending-exception busy and interrupt request |
| `control_o`, `status_o`, `tags_o`, `registers_o` | Architectural observation; physical register zero is in bits 79:0 |

Commands, addresses and input bytes need only be stable on acceptance. Store
results, pops and FSAVE initialization retire after the final accepted write
byte. Reset gates off memory valid and abandons the transfer; already
accepted writes are not rolled back.

## Arithmetic and exceptions

Arithmetic uses integer significands and guard/round/sticky bits, never
SystemVerilog `real` or a host floating-point DPI implementation. Loads widen
exactly. Arithmetic and stores apply the selected rounding mode. Precision
control applies to basic arithmetic, not data movement. Signed zero,
denormals, infinity, quiet/signalling NaNs and integer/BCD indefinite values
require directed tests. Unmasked invalid/denormal/zerodivide exceptions
suppress destination/pop/store. Unmasked register range exceptions retire a
result with exponent adjusted by 24,576; memory range exceptions suppress
store/pop. Precision traps retire rounded results. IR is independent of the
interrupt-disable mask; INT respects that mask unless `cpu_wait_i` reports a
waiting CPU, implementing Intel S.6 deadlock avoidance. Control commands
remain available for recovery.

The implementation coverage and any numeric restrictions must be listed in
the report; an unimplemented encoding cannot be represented as verified.
Original 8087 transcendental domains differ from later x87: FPTAN takes
0 < x < pi/4 and returns a ratio, FPATAN requires 0 < y < x, F2XM1 uses
0 < x < 0.5, and FYL2XP1 uses |x| < 1-sqrt(2)/2. Out-of-domain results
are undefined in the manufacturer specification.

## Assumption ledger

- **ASSUMPTION: transaction interface.** The host supplies decoded ESC bytes
  and physical addresses; queue mirroring and bus arbitration belong to an
  adapter. Validate semantic execution with original Intel program sequences.
- **ASSUMPTION: deterministic undefined state.** Undefined condition-code
  bits may retain their values. The initial hardware register data is not
  specified; tests must never use an empty tag as a numeric value.
- **ASSUMPTION: reserved precision.** PC=01 uses 64 bits. This is outside
  documented software behavior and is excluded from compatibility claims.
- **ASSUMPTION: transcendental approximation.** Convergent reduced-domain
  series replace unrecovered Intel microcode. Sampled results are checked
  against independent mathematical functions at 4e-18 relative tolerance;
  a uniform error bound, complete exception equivalence and original
  transcendental software validation are not established. Do not use this
  evidence as a full original-silicon compatibility sign-off.
- **ASSUMPTION: serialized control.** One command executes at a time and
  BUSY includes command/memory activity; original CU/NEU overlap and exact
  BUSY pulse timing are outside this transaction contract.

## Verification requirements

Strict Verilator lint, formal prove plus non-vacuity cover of protocol and
stack/control state, independent host-x87 arithmetic comparisons, directed
original-8087 control behavior, memory stalls, save/restore, and synthesis.
The aggregate regression must include original manufacturer software from
the manual, not just generated instruction tests. Modern x87 is an oracle
only for shared documented numeric behavior, never for FENI/FDISI,
projective infinity, original NaN encodings, or instruction timing.

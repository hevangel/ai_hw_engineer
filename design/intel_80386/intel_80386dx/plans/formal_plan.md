# Formal plan: Intel 80386 core

| Harness | Property | Mode | Status |
| --- | --- | --- | --- |
| `formal/intel_80386_divider.sby` (W = 4) | At `done`: quotient×divisor + remainder = dividend and remainder < divisor for every start with a nonzero divisor; idle stays idle | prove + cover | pass |
| `formal/intel_80386_alu.sby` | `intel_80386_pkg::alu`: CF/OF against unsigned/signed integer range definitions for ADD/ADC/SUB/SBB/CMP; CF/OF clear for logic ops; INC/DEC keep CF; NEG CF; ZF/SF/PF; result confined to the operand size | prove + cover | see report |

Not yet covered: decoder length and format bounds (an unconstrained 128-bit window ran z3 out of memory, so the harness needs per-field decomposition); core-level invariants (state machine liveness, transaction stability while `req_o` is high); later bus-unit protocol properties (M6/M7).

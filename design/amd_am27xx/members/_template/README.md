# Am27xx member chip template

## Scope

Replace this with chip-specific information including:
- Part number and capacity
- Function description
- Pinout and electrical specifications
- Programming sequences
- Timing requirements

## Evidence

Document sources here, including:
- Original datasheet references
- Technical documentation
- Application notes

## Acceptance

- [ ] Record the exact pin, function and timing contract with a source and assumption ledger
- [ ] Implement synthesizable SystemVerilog and verify this part independently
- [ ] Record lint, simulation, formal, synthesis and the limits of the verification

## Verification

See [verification plan](plans/testplan.md) for test methodology and coverage requirements.

## Design files

- `spec/spec.md` - Detailed specification
- `src/<chip>.sv` - RTL implementation
- `formal/<chip>_props.sv` - Formal properties
- `formal/<chip>.sby` - Formal verification scripts
- `tb/tb_top.sv` - Testbench

## Planning

See [implementation plan](plans/implementation_plan.md) and [formal plan](plans/formal_plan.md) for development approach.
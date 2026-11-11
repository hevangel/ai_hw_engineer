# Am9512 formal plan

## Goal

Prove the stack, status, command-completion and bus-transport behavior of the
Am9512 independent of the arithmetic datapath. The FPU is replaced by an
abstract model with free result/status and a fixed two-cycle handshake, so the
proof can focus on the documented stack movement and the command state machine.

## Model

`formal/model_fpu.sv` implements the `amd_am9512_fpu` interface with:

- free `result_o` and `status_o`,
- a two-cycle `start -> done` handshake,
- `busy_o` high between start and done.

`formal/documented_stack.svh` independently encodes the 1980 chapter's stack
tables and status rules for each command. It is written from the source, not
from the RTL.

## Properties

- Reset: state IDLE, stack zero, status zero, cycle-done/end/service/err clear.
- Command completion: state returns to IDLE, `completion_pulse` is high, the
  stack equals the documented stack for the latched opcode, and the status
  equals the documented status.
- Status bits 0 and 4 are always zero.
- State is IDLE or WAIT; WAIT implies busy.
- END is not asserted while busy.
- PAUSE follows the documented expression.
- Data bus output enable follows CS/RD.

## Cover

- reach WAIT,
- single-precision add completion,
- double-precision divide completion,
- divide, underflow and overflow status bits,
- SVREQ,
- END,
- reset during a command.

## Tasks and known limits

`amd_am9512.sby` runs `bmc`, `prove` and `cover` with z3 and ABC PDR. The
proof is a transport proof, not a proof of the floating-point algorithms. The
data-access stack rotation and the arithmetic datapath are covered by the
independent vector simulation. The proof does not model original microcycle
counts or analog timing.

Run:

```sh
sh design/amd_am9512/scripts/run_formal.sh
```
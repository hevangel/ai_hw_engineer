# SCELBI 8B paper-tape reader: implementation and profile

Status: **implemented and verified at the port level**, with the limits below.

## What SIMH documents

SIMH's SCELBI 8B model (`Intel-Systems/scelbi/scelbi_io.c`) documents the
reader's interface even though SIMH leaves its own PTR unit unimplemented:

```c
Inport 3: used to input data from tape-reader
...
  Flag 2 (bit 1): set to 1 when input available from tape-reader.
  Flag 3 (bit 2): set to 1 when tape in tape-reader.
```

`ptr_svc` in that file is `return SCPE_OK;` — the reference model does nothing.
So this card is built from the **documented port and flag map**, not from a
working reference emulator. That is the single most important qualification in
this note.

## What is implemented

`src/scelbi_8b.sv`:

| Port | Direction | Behaviour |
| --- | --- | --- |
| `INP 3` | read | Returns the byte under the read head and advances one byte |
| `INP 4` bit 1 | read | Data available (head byte present) |
| `INP 4` bit 2 | read | Tape in reader (head byte present) |

The host streams the tape image into a FIFO; the card presents the head byte
combinationally and pops on `INP 3`. There is no analog timing: no sprocket
holes, no reader speed, no start/stop bits. The card is a byte stream.

## Verification

`tb/tb_ptr.sv` (`scripts/run_ptr.sh`) does not just wire the port up — it runs
real 8008 code that reads it:

- A loader at `0x0200` reads `INP 3` in a loop and stores each byte to memory
  with `Lm M`, incrementing `HL`.
- The test preloads a 24-byte tape image and then checks **every byte in memory**
   against the image, at the exact addresses.
- Result: all 24 bytes land in order; `ptr_read_count` equals the tape length.

This catches the failure mode that a port-only test would miss: an off-by-one in
the head advance, or a byte delivered twice.

## What SCELBAL does with it

**Nothing.** SCELBAL's own paper-tape support is unimplemented in the SC1 ROM:

```asm
save:
load:   JMP EXEC        ; By default, save and load isn't implemented.
```

The interpreter never reads INP 3. So the reader is available to *code that asks
for it* — a monitor, a loader, or a program that uses the port — but the shipped
SCELBAL image has no tape routines to call.

This is why the reader is verified by a test loader rather than by a SCELBAL
session. Claiming otherwise would overstate what was tested.

## Limits

- **No analog timing.** No sprocket holes, no reader speed, no optical sensing.
  A byte is available the moment it is pushed.
- **No reference emulator.** SIMH's PTR is a stub, so there is no second
  implementation to diff against. The port and flag semantics come from SIMH's
  documented map, and the loader test is the evidence.
- **256-byte FIFO.** The tape image is bounded by the FIFO depth. A longer tape
  requires the host to keep feeding as the CPU drains.
- **SCELBAL does not use it.** See above.

## Reproduce

```sh
sh system/scelbi_8b/scripts/run_ptr.sh
```

Expected: `PASS: paper-tape reader loaded 24 bytes through INP 3 into 0x1000
(146 instructions)`.
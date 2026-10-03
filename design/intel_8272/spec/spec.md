# Intel 8272A functional specification

## References and integration boundary

Primary: Intel **8272A**, order 210806-001, AFN-01259C, ©1982, [local 19-page scan](../references/intel_8272a.pdf), [archive source](https://www.threedee.com/jcm/terak/docs/Intel%208272A%20Floppy%20Controller.pdf). Page references below are PDF pages. The 8272A is a pin-compatible enhancement of the 8272, principally changing VCO synchronization behavior. The command interface is also compatible with NEC's µPD765 family; [NEC manufacturer's datasheet](https://hxc2001.com/download/datasheet/floppy/thirdparty/FDC/NEC/upd765A.pdf) corroborates the command/status encodings and scan masking.

This design is a **virtual-drive functional core**, not a package-pin replacement. `clk`, synchronous active-low `rst_n`, `us_tick` (one pulse per emulated microsecond), active-low CPU `cs_n/rd_n/wr_n/dack_n`, `a0`, `tc`, split `db_in/db_out/db_oe`, `drq`, and `irq` provide the host interface. Four-drive logical inputs `ready`, `write_protect`, `track0`, `two_sided`, `fault` replace the physical multiplexed drive input pins. `step[3:0]`, `direction[3:0]`, selected drive/head, density, head load and write enable expose functional drive control.

A decoded media interface supplies sector headers (CHRN, deleted/missing data marks, ID CRC status), unbackpressured read-byte pulses, sector-end/data-CRC status and index pulses. Writes publish sector-begin metadata, byte data on each media write-slot pulse, and sector-end. Formatting publishes supplied CHRN and filler data. This boundary supports image-backed virtual drives. A separate synthesizable FM/MFM word codec and CRC module are included and verified, but are **not a complete serial track parser/formatter or PLL adapter**. Analog PLL, raw-flux acquisition, write precompensation, physical gaps and 8272A VCO package timing are outside this implementation. Every result claim must retain this scope.

## Host phases (pages 4–7)

A0=0 reads MSR only. A0=1 transfers command, execution data or result. MSR bits: RQM/DIO/NDM/CB/D3B/D2B/D1B/D0B. Command/result byte transfers incur 12 emulated µs processing delay; tests may parameterize `RQM_DELAY_US` downward. CPU must wait RQM and observe DIO. Illegal bus direction is ignored. Falling-edge-qualified strobes consume one byte when held low. Command collection is busy; asynchronous seek execution leaves the command interface idle while drive-busy bits remain set. A new command is accepted only after all result bytes are consumed.

DMA DACK drops DRQ and retains a transfer token until the corresponding RD/WR strobe; CS/A0 are not required for DMA data. DACK without RD/WR does not consume data. Non-DMA uses CPU data register accesses, RQM and one interrupt per byte. Execution completion raises IRQ; reading the first result byte acknowledges that completion. Reading MSR never acknowledges IRQ. TC during sector read stops host transfers but drains the physical sector/CRC; during write zero-fills the remainder. A TC accompanying an actual data strobe includes that byte. Scan TC completes the current comparison byte and ends the scan.

## Fifteen commands (Table 4)

| Low five opcode bits | Command | Total command bytes | Result bytes |
|---:|---|---:|---:|
| 02 | Read track | 9 | 7 |
| 03 | Specify | 3 | 0 |
| 04 | Sense drive status | 2 | 1 |
| 05 | Write data | 9 | 7 |
| 06 | Read data | 9 | 7 |
| 07 | Recalibrate | 2 | 0 (SIS later) |
| 08 | Sense interrupt status | 1 | 2, or 1 if no pending event |
| 09 | Write deleted data | 9 | 7 |
| 0A | Read ID | 2 | 7 |
| 0C | Read deleted data | 9 | 7 |
| 0D | Format track | 6 | 7 |
| 0F | Seek | 3 | 0 (SIS later) |
| 11 | Scan equal | 9 | 7 |
| 19 | Scan low or equal | 9 | 7 |
| 1D | Scan high or equal | 9 | 7 |

Other codes return ST0=80 without a new IRQ. Flags MT/MFM/SK are bits 7/6/5 for commands that define them. Specify/seek/SIS/sense-drive opcodes require their reserved upper bits to be zero. Read track disallows MT/SK. Read ID/format use MFM only. Write commands disallow SK.

Read/write/scan parameters: unit/head select, C,H,R,N,EOT,GPL,DTL or STP. Normal sector sizes are 128 shifted by N, N=0–6; N=0 read/write limits host data to DTL (zero means the complete 128-byte sector). Media CRC still covers the full sector. N=0 short writes zero-fill beyond DTL. Read ID returns the first header. Read track starts at the next index, consumes EOT sectors in encounter order, retains CRC/error flags and continues. Format waits for index, consumes four host CHRN bytes for each of SC sectors, writes `128 << command N` filler bytes per sector, and completes at the next index after the programmed sectors. Physical gap emission is the media backend's responsibility.

After a normal sector, R increments. At EOT, MT switches head zero to head one and resets R=1; otherwise a TC-ended transfer increments C and resets R=1, toggling H only for MT (Intel Table 8). For ordinary read/write commands without TC, attempting to continue past the final side sets ST1.EN and abnormal ST0. On errors CHRN identifies the sector in error rather than advancing. Scan uses STP=1/2, advances to another sector only on failure and has no implicit seek. Normal scan result-ID advancement follows assumption A6 below. Scan comparisons use disk <=/>= host, all compared bytes must satisfy the selected relation; SH denotes complete equality, SN failure. FF is a masked byte per NEC corroboration (assumption A3).

Deleted mark mismatch with SK=0 transfers that sector, sets CM and stops. SK=1 skips it, advances R, and continues; scans retain CM when skipping. EOS/EOT behavior never depends on a disk image's storage address. Header C mismatch with matching H/R/N sets ND+WC, plus BC when C=FF. Two index pulses without a suitable header terminate with ND; if no header was seen, also MA. Missing data mark sets MA+MD. ID CRC sets DE, data CRC sets DE+DD. Write-protect sets NW; loss of ready sets NR and abnormal ST0; fault sets EC. ST1 unused bits 6/3 and ST2 bit 7 remain zero.

## Timers, drive events and seeks (pages 7, 10–12)

Specify sets SRT (16 minus nibble milliseconds), HUT (nibble×16 ms), HLT (7-bit value×2 ms), ND. Head-load settling precedes media search; consecutive operations while loaded reuse the load interval. Unload follows HUT. Zero HUT means 256 ms; zero HLT means immediate in this functional core (A4).

Each drive has an independent PCN, target and seek timer. Seek produces inward direction=1 when target>PCN, outward=0 otherwise. Recalibrate steps outward until track0 or 77 pulses; failure sets SE+EC and abnormal ST0. Not-ready terminates seeks with SE+NR. Completion stores an event per drive and raises IRQ; SIS returns the lowest-numbered pending drive's ST0/PCN and clears its busy bit when the first result byte is read. SIS acknowledges the seek/poll IRQ latch; further queued events remain available for subsequent SIS commands. New events win over a simultaneous acknowledgement. Non-SIS commands are rejected while a completed seek awaits SIS.

Idle/seek polling samples ready for each drive at 220/220/220/440 µs intervals. Changes generate ST0=C0 plus unit and NR if not ready. Cached ready starts zero, so initially ready drives produce startup polling events. Polling is suspended during data execution and result; seek progression continues independently.

Read/scan service deadline is 13 µs MFM or 27 µs FM; write/format is 15/31 µs. A byte serviced on its deadline is accepted. Unserviced requests, incoming read bytes when the single-byte register is full, or empty write slots after a request expires produce OR. Testbench media byte spacing obeys these deadlines unless deliberately testing error paths.

## Assumption ledger

* **A1:** synchronized bus/media inputs and abstract `us_tick` replace nanosecond timing. Byte/sector/index events are one-cycle pulses; a backend reports CRC after the complete sector and does not promise lossless backpressure. Test held strobes, delayed DACK/RD and exact service deadlines.
* **A2:** one pending asynchronous event per drive, with lowest-unit SIS ordering. New same-drive events replace old status; a new event survives concurrent acknowledgement. MAME corroborates per-drive status storage, but silicon queue priority is not established. Test four overlapping seeks and polling events.
* **A3:** FF scan wildcard is explicit in NEC documentation, absent from this Intel scan; support it for compatible software. Intel determines disk-versus-host ordering, even where emulator implementations disagree. Test mixed comparisons, masks and STP boundaries. No physical-silicon sign-off is claimed.
* **A4:** zero HLT is immediate; zero HUT is 256 ms. Recalibrate direction is outward=0, matching SEEK semantics and independent implementations; Intel's prose says high despite the conflicting SEEK direction definition. Test timer boundaries and track0 failures.
* **A5:** virtual media is responsible for recorded geometry, byte spacing, index rotation, address-mark parsing, CRC error reporting and physical gap bytes. It must supply actual IDs rather than echoing the requested ID. Test wrong cylinder, missing marks, bad CRC, nonsequential format IDs and sector contents with an independent media BFM. The separate codec/CRC does not eliminate this integration requirement.
* **A6:** Intel describes normal scan completion/status but does not separately tabulate scan result CHRN advancement. This model uses the shared read/scan advancement convention in MAME's `read_data_continue` for normal completion, with Intel's STP and comparison rules taking precedence over that emulator's incomplete scan handling. Directed tests pin these IDs; actual Intel scan result IDs have not been checked against silicon or historical software. No physical-silicon sign-off is claimed.

This design is not a CPU. Complete historical operating-system/physical-drive regression is not a sign-off claim; host-level and media protocol tests establish the functional core's behavior within the documented boundary.

`MS_US` defaults to 1000; simulation/formal may lower it to accelerate millisecond seek/head timers. `us_tick` service and polling deadlines retain their documented tick counts. Use positive `MS_US` up to 1000 and nonnegative `RQM_DELAY_US` within the 20-bit timer range. Reset must be asserted for at least one clock. GPL is accepted as a command byte but interpreted by the external media formatter, since raw gap bytes are outside this boundary. Scan TC finishes the comparison just accepted and enters result; read TC drains until backend `media_end`. Format with SC=0 waits for index and returns a deterministic but architecturally meaningless CHRN (command bytes), as does the datasheet's undefined format result ID.

TC aborts a search, index wait, head-load wait or format-ID collection immediately, returning the current IDs. Failed scans terminate normally with SN at a reachable final EOT; skipping past EOT through STP continues searching and terminates abnormally after two index pulses.

# Original TOD latch and stop/restart software

`scripts/run_tod_software.sh` runs unchanged `read-latch.prg` and
`write-stop.prg` from the
[VICE SVN 45953 TOD archive](https://sourceforge.net/p/vice-emu/code/45953/tree/testprogs/CIA/tod/).
SHA-256 pins both binaries and their original assembly. The CPU executes
the original comparison tables, checking the complete results before
writing the D7FF success/failure mailbox. No table or program is rebuilt,
patched or translated; downloaded sources/binaries remain ignored.

## Measured results

Verilator 5.052 and the native NMOS CPU with two assembled CIAs pass:

| Original program | PHI2 clocks | Checked time samples | TOD input rising edges | TOD register reads | Result-store PC | Next executed PC |
|---|---:|---:|---:|---:|---|---|
| read-latch | 10,414,027 | 21 | 529 | 85,584 | 08C0 | 08C3 |
| write-stop | 9,215,023 | 45 | 468 | 389,437 | 0938 | 093B |

Total: **19,629,050 clocks**, 66 original four-byte time comparisons and
997 input rising edges. Both programs write result 00. The fixture asserts
the exact original entry JMP at 080D, its next executed SEI at 0820, the
result store's post-instruction PC and next executed self-loop JMP. It
also requires the exact final original zero-page sample counter, so an
early mailbox write cannot substitute for the full program.

`read-latch` checks hours-triggered snapshots while time keeps running,
tenths-read release, and on-the-fly minute/second/tenths reads.
`write-stop` checks hours-write stop, tenths-write restart, continuing
time after seconds/minutes writes, and alarm-register writes that neither
stop a running clock nor restart a stopped clock. No TOD RTL changes were
needed to pass these programs.

## Declared stimulus and limits

The fixture supplies RAM and a PAL timing stimulus of 63 PHI2 clocks per
line, 312 lines per frame and one TOD rising edge per frame. D012 and D011
raster bit 7 advance from that same counter. This nominal 50 Hz environment
preserves the programs' frame-counted waits. It is not a VIC-II model and
does not implement display DMA. Programs draw their own diagnostic text
into RAM and run without KERNAL stubs or substituted screen results.

The original programs initialize TOD explicitly. These results do not
resolve reset-hour disagreement, mains/raster frequency drift, asynchronous
input synchronization, alarm corner cases or revision-specific electrical
timing. The [specification ledger](../spec/spec.md) retains those gates.

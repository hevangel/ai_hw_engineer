# MOS 6526 serial completion timing escaped the byte tests

## External observation

The unchanged VICE SVN 45953 `CIA/shiftregister/cia-sdr-delay.prg` failed
against the assembled CIA. Its own 21-entry hardware table comes from
C64c and C128D C64-mode measurements documented in the accompanying
readme and [original issue](https://sourceforge.net/p/vice-emu/bugs/1219/).
The initial seven measurements started FCB5-FCBB, versus FCE6/FCE7/FCE8/
FCE9/FCEA/FCE4/FCE5; later iterations sometimes falsely completed early.

## Root cause and verification gap

The transmitter requested its interrupt on the sixteenth baud pulse,
when CNT rose after bit eight. Byte decoding passed because all wire
bits were correct; self-written completion checks agreed with the same
mistaken boundary. The independent CPU program measures when SDR becomes
empty, revealing the missing request pipeline after the fifteenth pulse.

Separately, the ICR current-cycle view returned a fresh serial source and
also captured that source after acknowledging the read. This exposed the
same completion again to the next transfer. Fixing request latency alone
matched 18 samples, but retained false early completion in three samples.
Consuming the serial source already returned by the read fixes all 21.
Timer/FLAG source conventions are not generalized from this observation.

## Correction and prevention

The serial request now follows the fifteenth baud pulse by four PHI2
clocks, while the final wire edge remains on pulse sixteen. Direction
change/reset flush the request pipeline. ICR consumes its currently visible
serial completion. This source-specific read boundary is marked ASSUMPTION
in RTL and the specification; other divider values and silicon revisions
remain independent-capture requirements.

The original hash-pinned program is now required by `run_all.sh`, with
unaltered code and table and exact CPU entry/result/next-instruction PCs.
The independent result buffer is required to contain all 42 output bytes.
Isolated checks cover exact request latency, complete byte pairs and
coincident serial acknowledgment in both simulators; formal covers require
a transmit request without a coincident baud pulse and a concurrent ICR
read/serial source. See the [measured report](../design/mos_6526/report/serial_software_report.md)
for results and remaining limits.

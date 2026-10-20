# CIA TOD and serial foundation results

These isolated blocks supplement the [verified timer](timer_report.md).
They do not yet constitute a complete CIA. The
[specification](../spec/spec.md) pins manufacturer and independent sources,
including reset/profile and subcycle sampling qualifications.

## TOD

`scripts/run_tod_all.sh` passed on Verilator 5.052, xezim 0.11.0 and
Yosys/SymbiYosys 0.69 in `ai-hw-engineer:latest`:

- Every 864,000 valid hour/minute/second/tenth/AM-PM state advances correctly
  against a separate mathematical 24-hour calendar: 8,208,075 native clocks.
  Both 50/60 Hz dividers are exercised. This calendar does not copy the
  RTL's per-digit BCD implementation.
- Directed snapshot/read-release, continued ticking while latched, alarm
  events on clock and register changes, invalid BCD wraps and the independent
  reference's time-hour-12 write quirk pass. Alarm hour writes preserve PM.
- Four-state simulation passes 21 checks, including stopped/restarted
  divider timing, exact 50/60 Hz endpoints and reserved-bit masks.
- Strict lint, BMC/PDR/five reachable covers and synthesis/check pass;
  generic synthesis uses 763 cells.

Yosys requires function-name assignment instead of the SV `return` syntax
used initially. The equivalent function was then checked through the entire
TOD flow, including exhaustive calendar regression.

## Serial

The serial block accepts already-qualified CNT rising edges and timer baud
pulses. It does not silently claim a complete physical synchronizer.

- Verilator passes all 256 receive bytes and all 65,536 buffered transmit
  byte pairs, decoding actual CNT/SP output edges: 3,018,789 native clocks.
  It checks gaps between baud pulses, MSB order, IRQ after bit eight,
  continuous buffered output, final SP retention, pending-buffer overwrite,
  CPU-write/receive precedence and direction-change release.
- Four-state simulation passes all 256 receive bytes, 256 buffered pairs
  and 16,148 checks. The same SV bench also passes Verilator.
- Strict lint, BMC/PDR/five reachable covers and synthesis/check pass;
  generic synthesis uses 125 cells.

The normal byte protocol is specified by the MOS datasheet. Direction
flush, overlapping SDR writes and physical SP sampling retain the explicit
independent-validation requirements in the specification. These gates do
not establish every old/new CIA serial timing race.

## xezim signed-loop reproducer

xezim 0.11.0 treats the following descending `int` loop as unsigned. It
prints 1, 0, then 4294967295 and fails. Verilator terminates after zero.

```systemverilog
module signed_loop_repro;
    int iterations=0;
    initial begin
        for(int index=1;index>=0;index--) begin
            $display("descending index=%0d",index);
            iterations++;
            if(iterations>2) $fatal(1,"Signed loop did not terminate");
            #1;
        end
        $finish;
    end
endmodule
```

The first serial SV bench consequently sent a ninth bit. Its bit loop now
counts upward from 0 through 7 and indexes data with `7-index`; the eight
actual bits and every expected byte/IRQ value are unchanged. The simpler
task-counter hypothesis was separately tested and ruled out. No production
RTL or expected serial behavior was changed to accommodate this tool issue.

## Remaining device work

Integrate PHI2 port sampling, two timer sources/cascade, PB timer overrides,
PC handshake, resolved-pin readback and revision-qualified ICR/IRQ behavior.
Then run complete-device independent timing and historical CIA software,
formal and board integration gates before considering the CIA complete.

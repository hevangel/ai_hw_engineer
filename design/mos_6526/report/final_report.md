# MOS 6526 status and known issues

The sampled digital implementation passes strict lint, whole-chip BMC/PDR,
all 39 reachable covers, Verilator/xezim integration simulation and synthesis.
This is a measured development milestone; compatibility sign-off remains open.

- [Timer oracle and foundation results](timer_report.md)
- [TOD and serial exhaustive/four-state results](tod_serial_report.md)
- [Assembled CIA and interrupt results](integration_report.md)
- [Eleven original Lorenz programs and KERNAL firmware](software_report.md)
- [Original Transactor loss detector and two profiles](transactor_report.md)
- [Original serial hardware timing table](serial_software_report.md)
- [Original TOD latch and stop/restart programs](tod_software_report.md)
- [Source, revision and assumption ledger](../spec/spec.md)

Timer-B/read-ICR loss now has affected/unaffected legacy-latency profiles,
checked by the original detector, unchanged independent CIA and transistor
CPU bus oracle. Known issues and outstanding evidence: physical read-loss
windows, remaining IRQ/read races and timer cascade need complete-device
traces; physical serial synchronizer latency is approximated;
TOD reset profiles disagree. The original serial-delay table now passes all
21 samples after completion/read-boundary corrections; original TOD
latch/stop programs also pass all 66 checked time samples.
Eleven unchanged Lorenz port/timer/cascade/
clock-mode/NMI programs pass with original KERNAL firmware; additional
IRQ/TOD/serial corner-case software and physical evidence remain required before
system compatibility is claimed. Reset must span
both PHI2 phases. Analog timing, setup/hold and pulses shorter than a sample
interval are outside this interface.

`scripts/run_all.sh` runs all existing sampled digital gates. It does not
claim to discharge all historical-software or physical-revision gates.

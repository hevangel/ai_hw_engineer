# MOS 6526 status and known issues

The sampled digital implementation passes strict lint, whole-chip BMC/PDR,
all 34 reachable covers, Verilator/xezim integration simulation and synthesis.
This is a measured development milestone; compatibility sign-off remains open.

- [Timer oracle and foundation results](timer_report.md)
- [TOD and serial exhaustive/four-state results](tod_serial_report.md)
- [Assembled CIA and interrupt results](integration_report.md)
- [Source, revision and assumption ledger](../spec/spec.md)

Known issues and outstanding evidence: old-device timer-B/read-ICR loss is
not implemented; sampled IRQ/read races and timer cascade need independent
complete-device traces; physical serial synchronizer latency is approximated;
TOD reset profiles disagree. Historical CIA software must run against this
implementation before system compatibility is claimed. Reset must span
both PHI2 phases. Analog timing, setup/hold and pulses shorter than a sample
interval are outside this interface.

`scripts/run_all.sh` runs all existing sampled digital gates. It does not
claim to discharge the open historical-software or physical-revision gates.

# Apple II completion work

Keep the original revision-0 physical motherboard as the integration target.
Complete cassette command coverage, Integer BASIC use, observable electrical
outputs and a usable host interface. Preserve the independently checked CPU,
memory, keyboard and serial video paths.

## Cassette command contract

Execute the unmodified original Monitor WRITE at FECD and READ at FEFD,
through actual Monitor command parsing. Check the complete leader and sync,
inclusive address range (including a page crossing), MSB-first data and XOR
checksum. For READ, supply an independent leader/sync/data waveform, test
both polarities and speed variation, and require checksum errors to print ERR.
The source is the original Monitor listing, Red Book printed pp.85 and 88.

Use two verification layers: a compiled authored-CPU firmware harness for
long leaders and error cases, and the actual resolved motherboard for physical
input/output routing. Explicitly identify which layer each result covers;
the firmware harness is not an alternate implementation of the motherboard.
The full physical-command regression must execute the original delays too.

## Source and electrical contract

Audit original schematic sheets together with published corrections from
Mike Willegal's reproduction of real revision-0 copper. Preserve every
source conflict in the ledger. Character-ROM equivalence requires an original
mask/dump or an independently established chart, not another converted EPROM.
Electrical models must use real component values and expose uncertainty in
device parameters and loads. No claim of measured agreement without measurements.

## Plan

1. Execute full original cassette firmware and establish independent tape cases.
2. Extend the physical motherboard regression with complete command execution.
3. Exercise original Integer BASIC, graphics, speaker, paddle and reset paths.
4. Audit connectivity and verify character ROM provenance against primary sources.
5. Implement missing Q3/Q4 output networks and observable composite/audio signals.
6. Add host interaction and run the complete functional acceptance suite.
7. Record measured fidelity separately; do not convert missing evidence into a pass.

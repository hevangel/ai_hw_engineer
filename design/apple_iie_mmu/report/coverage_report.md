# Apple IIe MMU coverage report

Source: xezim code coverage, scope `tb_top.dut`, from the self-checking bench
(`scripts/run_coverage.sh`; raw database at `work/coverage/rtl.json`).

| Metric | Covered | Note |
|---|---|---|
| Statement | 109/109 (100%) | none excluded |
| Branch | 50/50 (100%) | none excluded |
| Toggle | 164/164 (100%) | none excluded |

The last uncovered item before sign-off was the `default` arm of the $C00x
latch case ($C00C-$C00F writes, the IOU-shared flags the MMU accepts but does
not observe). A directed write pair ($C00D, $C00F) in the switch-matrix test
covers it; the readback check confirms no MMU-observable state changes.

Formal cover adds reachability evidence across 25 cover statements (all
reached, zero unreached), including mapping classes, both language-card
banks, the prewrite enable dance, 80STORE/HIRES overrides, the C800 window
lifecycle and the MPON sequence.

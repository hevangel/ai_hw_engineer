# Intel 8086 native bus assumptions missed by instruction tests

Date: 2026-10-11. Design: [intel_8086](../design/intel_8086/README.md).

## External oracle and observation

A manual audit against the [Intel 8086 datasheet](https://www.inf.pucrs.br/calazans/undergrad/orgcomp_EC/mat_microproc/intel-8086_datasheet.pdf), particularly the RQ/GT rules, AD/BHE descriptions and bus waveforms, found native-interface defects after instruction tests had passed. This happened during completion of the draft design, before its final review. The findings came from documentation outside the design's test suite, so this note records the verification gap.

An unlocked odd-address word could yield ownership between its byte transfers. Requests arriving after T2 could receive a T4 grant too early. INTA did not float AD throughout the cycle or drive BHE low in its first T1. Maximum-mode status could become passive during an extended wait, and write data/data enable were not held through T4.

Final code review also found that a one-bit prefetch generation tag could wrap after two redirects during one outstanding fetch. Integrated EU scheduling normally prevents that sequence, but the BIU's unconstrained redirect input permits it. An independent formal abandonment monitor produced a counterexample at step 6 against the original tag implementation.

## Root cause

Architectural agreement only observes completed instructions and their bus effects. It cannot establish every ownership boundary, floating interval or signal's lifetime. The original native tests modeled ordinary transfers, LOCK and waits, but omitted the unlocked odd-word exception, late-request boundary and some INTA/T4 signal details. Their responder accepted valid data without checking all intermediate pin states.

The initial formal properties proved queue bounds and stable stalls without tracking whether an outstanding prefetch had been abandoned. A generation equality check looked sufficient without testing tag wrap under arbitrary redirects.

## Fix and re-verification

The EU now exposes an ownership-inhibit signal for the whole odd-word pair, independent of LOCK. The BIU captures grant eligibility at T2, floats AD for INTA, receives the first-ACK BHE setting, retains active wait status and holds write data/data enable through T4. Pin assertions and directed tests exercise both modes and these exact boundaries.

Prefetch cancellation now uses a persistent discard flag cleared only when a new prefetch begins. A separate formal monitor remembers every abandoned active fetch until its completion, with a cover for two redirects before the response. The old implementation fails that property; the corrected implementation passes bounded and unbounded checks.

The final `design/intel_8086/scripts/run_all.sh` reruns strict lint, all nine formal tasks and 18 non-vacuous covers, eight UVM scenarios, 153 architectural controls, 25 native scenarios, 566,721 physical instruction cases through each of three interfaces, original DEBUG.COM through all three interfaces and synthesis of both tops. See the [verification report](../design/intel_8086/report/final_report.md) for results and scope.

## Prevention

Instruction-oracle success must be accompanied by independent native-pin tests derived from each manufacturer's arbitration exception and signal timing requirement. These regressions now assert INTA floating/BHE, extended-wait status and T4 data holding, request arrival on each relevant phase, and ownership across both bytes of an unlocked word. Formal queue checks now track abandonment independently of the implementation's cancellation mechanism. Future edits must keep these checks in the aggregate script.

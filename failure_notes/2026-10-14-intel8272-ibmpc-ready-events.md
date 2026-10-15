# IBM 5150 BIOS exposed incorrect FDC READY-event handling

Date: 2026-10-14 (America/Vancouver). Design: [Intel 8272](../design/intel_8272/README.md).

## What failed and the external oracle

The unchanged original 1981-04-24 IBM BIOS stalled while sending SPECIFY after
disk-controller reset. It consumes one reset-ready result, then sends SPECIFY;
the controller incorrectly treated other queued READY results as requiring
SIS before any valid command. A new chip test reproduced the rejection as a
direction/RQM timeout (`MSR=D0`) before the RTL fix.

The [Intel datasheet](https://www.threedee.com/jcm/terak/docs/Intel%208272A%20Floppy%20Controller.pdf),
INVALID section, requires SIS after completed SEEK/RECALIBRATE. It does not
impose that restriction on every READY transition, and explicitly allows
Sense Drive Status whenever the host needs it. IBM's published BIOS listing
and the pinned binary provide an independent executable oracle.

After that correction, staggered startup READY interrupts could leave IRQ6
asserted after the BIOS's single reset acknowledgement, hiding the later
recalibration edge and producing diagnostic 601. Independent
[MAME code](https://github.com/mamedev/mame/blob/031d99f427df935056d42fa943476ed1bfb8e879/src/devices/machine/upd765.cpp)
explicitly discusses the 5150's one-IRQ requirement and batches the initial
polling scan. Original BIOS then completes POST and boots DOS after the same
reset behavior is modeled here.

## Why verification missed it

Every controller startup helper waited for the complete polling scan and
drained all four results before sending any command. This stronger-than-BIOS
initialization hid both the broad command rejection and the timing of separate
initial polling interrupts. The initial verification boundary explicitly had
no historical BIOS or integrated DMA regression.

## Fix, validation and prevention

The rejection condition now tests completed seek/recalibrate results, using
their manufacturer-defined SE bit. READY status remains queued and available
to SIS without blocking SPECIFY or Sense Drive Status. The initial scan raises
one IRQ after collecting all four drive samples; subsequent polling keeps its
ordinary change behavior. This reset detail is explicit assumption A7, supported
by an independent implementation and actual IBM firmware, not silicon capture.

The chip suite now senses one READY event, sends SPECIFY and Sense Drive Status
with the others still queued, verifies those results survive, and independently
checks that a completed SEEK still requires SIS. It checks the initial scan's
single interrupt and has a separate 4 MHz test for doubled read deadlines,
overrun, polling and seek timing. The complete controller flow and the IBM PC
historical-software regression are required; actual results are in the
[chip report](../design/intel_8272/report/final_report.md) and
[system report](../system/ibm_pc/report/final_report.md).

Future controller changes must preserve the original BIOS initialization path
in addition to tests that drain every asynchronous result. The system's POST
monitor treats manufacturer diagnostic-message entry as a failure, even if
later firmware clears the visible error and continues.

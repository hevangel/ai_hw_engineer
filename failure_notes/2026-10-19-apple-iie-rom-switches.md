# Apple IIe ROM extension and read-side video switches

## Observation

Connecting the existing chips to unchanged Apple2e.rom failed after 98 bus
cycles at CB25: the CPU received FF instead of the internal firmware byte.
After correcting the ROM path, the original firmware also needs read-side
TEXT/PAGE2/HIRES actions. Real 80-column firmware, not an RTL-derived ISS,
provides the integration stimulus.

## Root cause and external evidence

The MMU required both global internal-ROM selection and the internal-C3
extension latch for C800-CFFF; it also let SLOTC3 override global internal
selection. The IIe TRM Chapter 6, printed p.143, says global selection serves
all C100-CFFF including C300. Its interrupt-handling discussion says a C3
reference switches in the internal C800 extension independently. Correct
C800 service is global selection OR the C3 extension latch. CFFF releases
the latch while global selection still overrides slot ROMs.

The IOU and MMU modeled C050-C05F as write-only. TRM Table 2-1 explicitly
marks TEXT, MIXED, PAGE2 and HIRES R/W. Both models must accept reads.
The original specs, self-written reference models and formal expressions
shared these assumptions, so their agreement did not catch the integration
failure. The chip specs link the primary manual; a local OCR copy was used
for the source check. No assertion was relaxed to allow a failed ROM boot.

## Fix, verification and prevention

Correct chip RTL, reference expectations and formal contracts together, with
TRM citations in the specs. Add directed C3-to-CB25/global-C3/CFFF cases and
read/status cases for the video switches. Preserve the actual 1983 ROM gate
in the platform run_all.sh, with exact reset vector and first opcode fetch,
keyboard-driven POKE/PRINT, and PR#3 auxiliary text. The independent CPU's
existing Klaus/oracle verification is preserved. Verification results are
recorded in the platform and chip reports; no physical timing claim is added.

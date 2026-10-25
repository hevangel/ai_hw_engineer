# Test plan

Verify all registers, 256 DDR values on each port, all IER masks/set-clear
operations, all PCR values, input-latch freezing/release, PA/PB readback,
no-handshake ORA and independent interrupt inputs. Verify every timer load
with equation-derived deadlines, one-shot suppression, free-running periods,
PB7 override, latch-only changes, T2 PB6 pulses and reset/deselection.
Test all eight SR modes using externally specified bytes and bit streams,
internal clock deadlines, continuous mode, repeated external groups and
shared T2 behavior. Include interrupt clear/event races and retriggering.
Use a reduced representative timer sweep in xezim but the same port/control
and serial checks. Record any gap rather than inferring hardware equivalence.

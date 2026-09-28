# Busicom manual replay exposed decimal and board integration defects

## Observation and independent oracles

The user reported a busy front panel, rotating drum digits and an empty tape.
After pulling main at `4a923b6`, static inspection and replay of the scanned
Unicom 141 manual exposed defects still present in the merged source.

- Kintli's recovered firmware, sections 3.2-3.3 and addresses $064-$069,
  $0bc-$0bd, specifies shared shifter data, one LOW keyboard selection,
  and a ROM2 index input identifying printer character zero.
- The [MAME MCS-40 implementation](https://github.com/mamedev/mame/blob/8089ec90d3543a04311fab69733af1ac033fcd39/src/devices/cpu/mcs40/mcs40.cpp)
  independently specifies TCS as `9 + carry` and DAA as retaining carry
  unless the correction sets it. The source was inspected on 2026-09-27.
- [The scanned Unicom manual](../system/busicom_141pf/spec/reference/Unicom_141P_manual_text.pdf)
  supplies the real calculation sequences and expected printed decimal strings.

## Root causes

1. The keyboard shifter polarity had been fixed, but the matrix decoder still
   selected one-HIGH patterns. Its aliveness check used the same obsolete rule.
2. `drum_idx` was an undriven internal board signal. The testbench index pulse
   never reached ROM2, preventing printer phase synchronization.
3. Hammer data subtracted one character position even though the modeled index
   already identified character zero. Captures therefore used the wrong glyph.
4. TCS reversed the two carry cases. DAA overwrote incoming carry with the
   correction's carry, losing it when ACC was below ten. Both the ISS and formal
   golden model repeated these wrong assumptions, so mutual agreement could not
   detect the errors.

## Fixes and prevention

- Connect an explicit `drum_idx_i` board port, decode one-LOW scans, and capture
  the actual drum position when the hammer fires.
- Correct RTL, ISS and formal TCS/DAA semantics from MAME, with source comments
  and corresponding specification updates.
- Preserve the manual OCR, produce readable Markdown and visually checked JSON
  for every numbered example, and replay identical input events with Python or
  the web panel. The checker asserts exact decimal strings, symbols, red ink,
  rounding marks and specified lamps; it preserves duplicate tape rows by ID.
- Add all manual examples to the CPU `run_all.sh` real-software regression.
  Unit/formal model agreement alone is insufficient sign-off.
- Reduce key hold/release from 540 to 64 drum half-spin ticks using the firmware's
  per-sector scanning contract. This remains over two complete drum revolutions;
  real firmware replays check that each key registers exactly once.

## Verification

See the [manual regression report](../system/busicom_141pf/report/manual_regression.md)
for simulator versions, complete case results, source discrepancies, and remaining
limitations. Results are reported separately from Docker executable smoke checks.

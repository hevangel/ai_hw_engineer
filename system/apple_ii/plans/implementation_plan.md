# Apple II revision-0 implementation plan

## Implemented and exercised

1. Preserve physical package locations and pin/net connectivity with a pinned
   source and explicit corrections.
2. Build individual TTL, buffer, ROM, character-generator, and 4116 models.
3. Wire the digital board with identical 48 KiB memory-selection straps,
   resolved data buses, real motherboard strobes, and video/CPU memory sharing.
4. Add 555, NE558, and 741 functional mixed-signal models and reduced RC networks.
5. Connect a physical-pin NMOS 6502 transistor reference without hidden memory.
6. Run authentic Monitor reset, keyboard deposit, and examine commands.
7. Verify serial video scan/blanking/sync and exact pixels for all modes and
   actual Monitor screen clear, commands and readback.

## Remaining requirements

1. Audit every imported connection against original revision-0 schematics;
   confirm optional component/ROM population and original speed-family variants.
2. Compare the font to an original 2513 dump, validate analog color output and
   floating-bus behavior, and audit package timing against vintage measurements.
   Digital graphics/text modes and visible historical Monitor output pass.
3. Replace ideal oscillator/output boundaries with validated mixed-signal
   models, and verify cassette, speaker, and composite-video waveforms.
4. Validate timing, analog tolerances, power-up conditions, and unresolved reads.
5. Complete the authored 6502 and run historical firmware using that design.
6. Reduce the Xezim resolved-bus failure and establish a passing board backend.
7. Add optional expansion cards after the motherboard acceptance gate passes.

## Digital video validation work

1. Initialize deterministic display patterns through physical CPU socket writes.
2. Observe actual counter pins, memory fetches, and B10 serial video pixels.
3. Compare full-frame timing and text page/attribute output to an independent
   software oracle derived from the manual and pinned external timing source.
4. Export the observed monochrome raster for review and retain exact pixel
   comparisons as a regression. Graphics modes and all text attributes pass.
5. Extend the actual Monitor regression with its ESC/@ (physical Shift-P) screen clear and a
   complete observed video frame; compare the raster against independently
   tracked CPU screen writes, and inspect the rendered Monitor output.

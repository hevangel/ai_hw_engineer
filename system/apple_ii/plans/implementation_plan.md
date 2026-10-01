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

## Remaining requirements

1. Audit every imported connection against original revision-0 schematics;
   confirm optional component/ROM population and original speed-family variants.
2. Compare video/font output to original 2513 data and visible historical output;
   validate graphics modes, floating-bus behavior, and video memory sharing.
3. Replace ideal oscillator/output boundaries with validated mixed-signal
   models, and verify cassette, speaker, and composite-video waveforms.
4. Validate timing, analog tolerances, power-up conditions, and unresolved reads.
5. Complete the authored 6502 and run historical firmware using that design.
6. Reduce the Xezim resolved-bus failure and establish a passing board backend.
7. Add optional expansion cards after the motherboard acceptance gate passes.

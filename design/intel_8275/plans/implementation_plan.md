# Implementation plan

1. Preserve Intel's datasheet and pin/protocol specification before RTL.
2. Implement command/parameter status logic and edge-qualified CPU/DMA access.
3. Implement character/raster counters, LC offset, preset, retrace and events.
4. Implement ping-pong row storage, replacement FIFOs, burst spacing, delayed stop and underrun recovery.
5. Decode field/graphics/cursor attributes with independent scanline replay.
6. Add directed and seeded pin-level checks, independent graphics vectors and a UVM sequence/driver/monitor/scoreboard/coverage environment.
7. Prove control/storage invariants and cover useful bus, DMA and raster states; run strict lint, both simulators and synthesis.
8. Report actual results and scope, update index/README, commit and open a review PR.

The prior 8237A PR is unmerged. This design therefore uses a DMA bus functional model and has no dependency on that feature branch.

# IBM PC AT 5170 verification report

Status: specification only (M0). No system RTL exists and no system check
has been run.

What already exists elsewhere (not system evidence): the 286 design's AT
fixtures run the unchanged REV1 BIOS to `F000:03A2` (timer, DMA register,
page register and refresh-indication tests), compared with Unicorn. See
[`design/intel_80286/report/2026-10-29-at-bios-native-refresh.md`](../../../design/intel_80286/report/2026-10-29-at-bios-native-refresh.md).

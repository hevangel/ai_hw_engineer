# XT fixed-disk POST diagnostic required controller SRAM

## Discovery

During pre-PR IBM 5160 integration, unmodified IBM 1982 fixed-disk adapter
ROM 5000059 reported **1701** after original XT POST verified 256 KiB RAM.
The external oracle was the original ROM, not a controller model. The I/O
trace showed **0Fh (WRITE SECTOR BUFFER)** returning error 02h, followed by
REQUEST SENSE reporting unsupported command 20h.

## Cause and verification gap

The initial adapter implemented disk transfers but omitted its separate
512-byte SRAM buffer commands. Bounds and DMA tests covered the medium,
not the ROM's startup buffer diagnostic. Formal range proofs cannot establish
command completeness. Pinned PCjs `hdc.js` independently identifies WRITE
BUFFER as a distinct command.

## Fix and prevention

Implement 0Eh/0Fh against external controller SRAM, separate from disk sectors.
Preserve DMA/IRQ completion and exclude SRAM traffic from physical-disk byte
counters. Add buffer-address/status regressions and retain original adapter
POST in aggregate verification. Strengthen REQ-phase tests against the ROM's
sender at C800:0562h/0590h and initialization-parameter sender.

The corrected path booted unchanged DOS 2.00 from the fixed disk with 69,120
disk bytes read and zero floppy reads. Final cold-boot and persistence
evidence belongs in the system report. No firmware or POST diagnostic was
patched or bypassed.

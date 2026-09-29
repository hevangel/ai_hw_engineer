# Original Apple II system specification

Target: the original 1977 Apple II, not later II+ or IIe extensions. The [Apple II Reference Manual](https://apple2history.org/dl/Apple_II_Redbook.pdf) anchors the memory and I/O map.

Initial intended map: `$0000-$BFFF` RAM (configured to 48 KiB), `$C000-$C0FF` motherboard I/O including keyboard and display soft switches, `$C100-$CFFF` expansion slots, `$D000-$FFFF` firmware ROM. Text page 1 occupies `$0400-$07FF`; its physical row mapping must follow the manual. The keyboard latch at `$C000` and strobe clear at `$C010` need cycle-accurate read side effects.

ASSUMPTION: a 48 KiB RAM configuration is used as the first integration target. Original machines shipped with multiple RAM configurations; this choice is for the first platform build and does not define all Apple II variants.

No Apple ROM binary is included. Firmware provenance and redistribution rights must be established before adding one; the system test can accept a user-supplied ROM path in the meantime.

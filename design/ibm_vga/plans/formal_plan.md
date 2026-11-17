# IBM PS/2 Display Adapter: formal plan

| Target | Engine | Properties | Bounds / abstractions |
|---|---|---|---|
| `vga_dac` | abc pdr (prove), smtbmc yices (cover) | sub-index never 3; address loads (3C8 write mode, 3C7 read mode) reset the sub-index; every data access (either direction) advances it, the third the address; DAC state readback; a shadow entry at an anyconst address holds exactly the last completed triple written to it and reads back R, G, B in order; blanked dots are black | palette abstracted to one shadow entry, other entries unconstrained |
| `vga_graphics_ctrl` | abc pdr / yices | write modes 0-3 on one anyconst bit of one anyconst map, written with index arithmetic independent of the RTL's shifts (write mode 3 mask = Bit Mask AND rotated data); read mode 1 compare; read mode 0 map selection with chain 4 and odd/even; stored register widths | none |
| `vga_crtc` prove_h | abc pdr | horizontal counter < HT+5; horizontal retrace width equals the p.2-60 algorithm; interrupt latch only at retrace start and held clear by VRE bit 4 = 0; retrace starts only at VRS; the row scan changes only at a row-scan tick or frame restart; double-scan phase 0 without MSL bit 7 | HT <= 48, VT <= 3, the retrace does not wrap the line |
| `vga_crtc` prove_v | abc pdr | vertical counter <= VT+1; vertical retrace width equals the p.2-70 algorithm; same latch/row-scan properties | HT <= 2, VT <= 30, no HRTC/2, retrace does not wrap the frame |
| `ibm_vga` | abc pdr / yices | only readable ports of an enabled card drive an I/O read; 3C3 and 46E8h never; memory reads only ROM or the RAM of an enabled card; no drive without a read strobe; a disabled card decodes no 3xx port and no RAM; setup hides the DAC; decode exclusivity; map-mask/chain-4/odd-even write gating; attribute flip-flop; RESET DRV disables the card; enable = 46E8h bit 3 and POS bit 0 | plane RAM and ROM black boxes, DAC shadow entry, ISA protocol assumptions (one strobe, stable address) |

Each `.sby` has a cover task; `run_formal.sh` then plants one fault per proof
(DAC sub-index wrap, write mode 3 mask, horizontal and vertical retrace end
width, DAC decoded in setup) and requires that proof to fail.

# IBM PS/2 Display Adapter (ISA VGA)

The IBM Personal System/2 Display Adapter is IBM's 8-bit ISA card version of
the Video Graphics Array, for the PC, XT, AT and PS/2 Models 25/30. It
carries the VGA function (CRT controller, sequencer, graphics controller and
attribute controller, integrated in one gate array), 256 KB of video memory
as four 64 KB maps, a 256-entry video DAC with 18-bit colour (Inmos IMS G171
compatible), 25.175 and 28.322 MHz oscillators, a 24 KB BIOS ROM at C0000h,
the setup/enable port 46E8h with POS register 102h, and the 15-pin analog
display connector. Compared with the EGA it adds readable registers, a
256-colour 320x200 mode, 640x480 16-colour graphics, 400-line 9x16 text,
double scanning of 200-line modes, 262,144 colours through the DAC and
analog monitor sensing.

## Why it matters

VGA became the baseline of PC graphics: its register set (3C0h-3CFh,
3B4h/3D4h), mode 13h, the 640x480 resolution, the DAC programming model at
3C6h-3C9h and the 15-pin connector are still emulated by every PC graphics
adapter. The PS/2 Display Adapter brought it to ISA machines, so the same
card plugs into the IBM PC AT machine top of this repository as the EGA
does ([`ibm_ega`](../ibm_ega/README.md): same slot ports and bus contract).

## First introduced

**1987.** IBM announcement letter ENUS187-054, "The IBM Personal System/2
Display Adapter, the IBM Personal System/2 Display Adapter 8514/A and the
IBM Personal System/2 8514 Memory Expansion Kit", is dated 2 April 1987,
the PS/2 announcement day (located through Wikipedia's "Video Graphics
Array" citation; IBM's page did not render offline, so the letter text was
not read). The modeled ROM is dated 10/27/86. PC Magazine reviewed the card
on 22 December 1987. The month of first shipment is not established.

Sources (URLs and SHA-256 in the [specification](spec/spec.md)): IBM
*Personal System/2 Hardware Interface Technical Reference* (May 1988),
"Video Subsystem (Type 1)"; IBM *VGA/XGA Technical Reference Manual* (May
1992); IBM *PS/2 and PC BIOS Interface Technical Reference* (April 1987);
the adapter BIOS from the [86Box ROM set](https://github.com/86Box/roms)
(`video/vga/ibm_vga.bin`) checked against MAME's `ibm-vga.bin` entry. MAME
and 86Box sources were read for behaviour and hashes only; no code was
copied.

## Status

Implemented and verified as described in the
[verification report](report/final_report.md): RTL (`src/`, 11 modules),
an independent reference model (`scripts/vga_model.py`), a lockstep
Verilator bench, directed and random tests with a coverage gate, the
geometry of all BIOS mode-table entries against IBM's timing figures, a
static I/O audit of the ROM, execution of the ROM's POST and INT 10h mode
sets in Unicorn replayed on RTL and model with pixel-exact pictures,
mutation testing, formal proofs and synthesis. `clk` must be at least as
fast as the fastest oscillator enable (28.322 MHz); any faster clock and
any enable pattern works.

```sh
python3 design/ibm_vga/scripts/get_rom.py         # downloads into ignored work/
sh design/ibm_vga/scripts/run_all.sh               # installs unicorn and capstone into work/pydeps
```

## Documents

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Verification report](report/final_report.md)

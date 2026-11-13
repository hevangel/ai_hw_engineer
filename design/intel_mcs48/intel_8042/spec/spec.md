# Intel 8042 (UPI-42) specification

Status: processor core, host interface, ports and timer implemented and
verified against an independent reference model; IBM PC AT firmware runs
in lockstep. See [the verification report](../report/final_report.md).

## Sources

| Ref | Document | Use |
|---|---|---|
| M | Intel, *UPI-41A User's Manual*, order 9800504-02B, April 1980. [Mark Ogden's Intel archive](https://mark-ogden.uk/files/intel/publications/9800504-02B%20UPI-41A%20Users%20Manual%20Apr%2080.pdf), SHA-256 `9cf77af8850552f0f068d989c5fba0b4fc7ddf52b547858eb6e7b8a79470a257` | Architecture (ch. 2), instruction set (ch. 3, Table 3-2 and the alphabetic listing) |
| D | Intel, *8742 Universal Peripheral Interface 8-Bit Slave Microcontroller*, order 290256-001, November 1991. [Same archive](https://mark-ogden.uk/files/intel/publications/290256-001%208742%20Universal%20Peripheral%20Interface%208-Bit%20Slave%20Microcontroller-Nov91.pdf), SHA-256 `cc784b505d9f0b28c4766723a4d27b789b81259c6a6f3172cdfb62dce791db7f` | 2K ROM / 128-byte RAM sizes, UPI-42 features, pins |
| L | A. Tarpai (Halicery), *1503033 disassembly* (2010), MIT licence. Submodule `external/halicery/8042` at commit `6ddf1669224342663ed1fc6e9a33f3577ad9ba02` ([Halicery/8042](https://github.com/Halicery/8042)), `8042_1503033.TXT`, SHA-256 `3e10124dfba23726c2e11c2f50812fd1190828f6dd7bc54a4b4d186d1fa5ca98` with LF line endings. PCjs archives identical content (jeffpar/pcjs `1a91d38e`) | IBM firmware bytes; independent disassembler for the decoder cross-check; AT keyboard-line wiring notes |
| R | MAME `src/devices/machine/at_keybc.cpp` (BSD-3-Clause) | Hash of the IBM dump: `1503033.bin`, CRC32 `5a81c0d2`, SHA-1 `0100f8789fb4de74706ae7f9473a12ec2b9bd729` |

The PDFs are not committed. Download them into the ignored
`design/intel_mcs48/work/refs/` folder to check a citation.

## Device

| Item | Value | Source |
|---|---|---|
| Program memory | 2048 x 8 mask ROM, 11-bit PC | D p.1 |
| Data memory | 128 x 8; R0-R7 at 0-7 (bank 0) or 24-31 (bank 1); stack at 8-23 | D p.1, M Fig. 2-7 |
| Machine cycle | 15 crystal clocks: a 400 kHz machine cycle at 6 MHz | M p.2-10 |
| Instruction time | 1 or 2 machine cycles | M Table 3-2 |
| Host interface | DBBIN, DBBOUT, status; CS, RD, WR, A0, D0-D7 | M p.2-13/2-14 |
| Status register | ST7-ST4, F1, F0, IBF, OBF | D p.4, M p.2-14 |
| Ports | P1, P2 quasi-bidirectional; T0, T1 test inputs | D p.3 |
| Timer/counter | 8-bit; timer input = machine cycle / 32; counter input = T1 high-to-low | M p.2-9/2-10 |
| Interrupts | IBF (vector 3), timer overflow (vector 7); single level; IBF first | M p.2-11/2-12 |

## RTL interface

`src/upi42_core.sv` is the processor with an external program-ROM port;
`src/intel_8042.sv` adds the 2K ROM loaded from `ROM_FILE` with
`$readmemh`.

| Port | Meaning |
|---|---|
| `clk`, `ce_i` | One machine cycle per clock with `ce_i` high. A system divides its clock to set the 8042 speed. |
| `rst_n` | RESET pin, synchronous, active low |
| `cs_n_i`, `rd_n_i`, `wr_n_i`, `a0_i`, `d_i`, `d_o`, `d_oe_o` | Host bus. Sampled every clock, independent of `ce_i`. |
| `p1_o`, `p2_o` | Port drive (1 = released high). P24/P25 carry OBF and /IBF after EN FLAGS. |
| `p1_i`, `p2_i` | Pin level after any external pull-down. The board ANDs drive with external drive. |
| `t0_i`, `t1_i` | Test inputs |
| `retire_*`, `illegal_o` | One pulse per completed instruction or interrupt vector |

The core also exposes `pc_o`, `a_o`, `psw_o`, `sts_o`, `t_o`, `dbbin_o`,
`dbbout_o` and `misc_o` (`{0, prescaler[4:0], timer mode[1:0], TF, EN TCNTI,
timer request, EN I, IBF request, in interrupt, EN FLAGS, EN DMA}`) for
verification.

## Behavior

The instruction encodings, cycle counts and effects follow M chapter 3
exactly. The encodings were read from the rendered opcode diagrams in M
(pages 3-5 to 3-26). JMP and CALL carry address bit 10 in opcode bit 7
(M p.3-14 shows `a10 a9 a8 0 0100` for JMP). The IBM firmware confirms
this for CALL: `94 50` is CALL 450h.

RESET (M p.2-12, p.2-14) clears PC, SP, BS, CY, AC, F0, F1, the status
flags, both interrupt enables and requests, the in-interrupt flag, TF and the
prescaler. It stops the timer and sets P1 and P2 to FFh. A, RAM and the
timer count keep their values (M p.2-9: the counter is not cleared by
RESET).

## Assumptions

Each item below is behavior the sources do not state explicitly. The same
tag marks the RTL (`src/upi42_core.sv`) and the reference model
(`scripts/upi42_iss.py`). "Checked" says what real code exercises it.

| Tag | Assumption | Basis | Checked |
|---|---|---|---|
| U1 | RESET clears EN FLAGS and EN DMA | M p.2-12: these are "only cancelled by a device RESET" | IBM firmware sets EN FLAGS after reset |
| U2 | PSW bit 3 ("not used") reads 1 | MCS-48 convention, MAME | Firmware masks the bit (listing 0022h-002Bh) |
| U3 | `@Rr` uses pointer bits 0-6 | M states bits 0-5 for the 64-byte 41A; the 8042 has 128 bytes | Firmware RAM test writes 7Fh down to 01h through @R0 |
| U4 | The 11-bit PC wraps from 7FFh to 000h | Size of program memory | Random tests only |
| U5 | A conditional jump's page is the page of its operand byte | M p.3-11 note on DJNZ at location 255 | Directed test `djnz_at_page_end` |
| U6 | An instruction's effects apply after its machine cycles; the timer ticks during those cycles with the mode in effect before it | Not stated | Firmware timer-interrupt self-test (07ACh) |
| U7 | Counter mode counts T1 high-to-low edges seen between instructions | M p.2-10 gives a maximum rate of one count per three cycles | Random tests only; the IBM firmware does not use counter mode |
| U8 | An interrupt vector takes 2 machine cycles | M p.2-12 gives latency bounds only | Firmware timer-interrupt self-test |
| U9 | ANL/ORL Pp,#data operate on the output latch | M p.3-7/3-21 write `(Pp)`; MAME uses the latch | Firmware `ANL P2,#BFh` at 004Bh |
| U10 | MOVP3 reads 300h-3FFh from either half of the 2K ROM | Firmware ROM checksum reads page 3 with a MOVP3 at 775h | Firmware self-test CRC |
| U11 | Opcodes not in Table 3-2, and the 8243 expander instructions, have no effect; they take 1 cycle (2 for the expander forms) and pulse `illegal_o` | Not stated | Random tests only |
| U12 | DA sets C on a carry out of either adjustment step and otherwise keeps C | M p.3-10 says C is "otherwise cleared", which would lose a BCD carry; MAME keeps C | Directed test `bcd_add_carry`; the firmware does not use DA |
| U13 | RD/WR act on the trailing edge, detected one clock after the strobe ends; a host write completing in the same clock as IN A,DBB leaves IBF set | D p.4: "IBF, OBF, F1 and INT change internally after the trailing edge" | Firmware command sequence |
| U14 | IN A,P2 reads the pins, so P24/P25 read back OBF and /IBF after EN FLAGS | M p.3-12: `(A) <- (Pp)` | Firmware command D0h returns CFh |

## Documentation errata found

- M p.3-10, DA A example: the table gives 9AH + 06H = A1H and a result of
  01H. 9AH + 06H is A0H; the rule as written gives 00H with C set. The
  directed test checks the rule.
- M p.3-8 shows CALL as `0 a9 a8 1 0100` (1K parts); the 8042's 2K space puts
  a10 in bit 7, as M p.3-14 shows for JMP.

## Not modeled

- 8243 expander access (PROG pin, MOVD/ANLD/ORLD); flagged as illegal.
- DMA handshake (EN DMA sets a flag only; DRQ/DACK pin behavior is absent).
- Single step (SS, SYNC), external access (EA) and EPROM programming.
- The status-register lock-out while the host reads it (D p.4).
- Sub-cycle timing of port writes and pin sampling: ports change at the end
  of the instruction; T0/T1 are sampled in the instruction's first cycle.

## IBM PC AT firmware

The AT uses the 8042 with IBM ROM part 1503033 (MAME "IBM 1983"). No
citable raw dump is public. `scripts/rebuild_1503033.py` rebuilds 1,388 of
its 2,048 bytes from listing L. The other 660 bytes, in nine ranges just
below page boundaries, are never executed in the paths tested, but the
self-test (command AAh) computes a 16-bit CRC over all 2,048 bytes and
requires 0000h. With the gaps unknown the self-test fails at status 48h
and sends no reply.

`scripts/make_crc_test_image.py` builds a **test-only** image: gaps filled
with 00h and bytes 7FCh-7FDh solved so the CRC is zero. Every listed byte is
unchanged. It is not the IBM firmware; it lets verification exercise the
firmware's command handling after a passing self-test. A verified dump can
be supplied to `rebuild_1503033.py --dump`, which checks it against R and
against every listed byte.

AT board wiring used by the bench, from L's notes: P26 drives the keyboard
clock through an inverter and T0 reads it; P27 drives keyboard data and T1
reads it. The IBM 5170 Technical Reference schematic is the authority for
the system integration.

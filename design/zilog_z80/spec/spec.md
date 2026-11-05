# Zilog Z80 functional and bus specification

Primary sources are Zilog's [Z80 CPU User Manual UM008011-0816](https://www.zilog.com/docs/z80/um0080.pdf)
(August 2016, revision 11; the companion UM0081 covers the peripheral family, not
the CPU), Sean Young's [The Undocumented Z80
Documented](http://www.z80.info/zip/z80-documented.pdf) (version 0.91, 18
September 2005) for behavior the manufacturer never published, the
[z80.info undocumented-instruction list](http://www.z80.info/z80undoc.htm)
(compiled from Richard Spijkers' 1992 list, Jacco Bot's 1996 update and Bill
Smythe's Northern Bytes article of October 1982), and the
[z80.info flag-affection table](http://www.z80.info/z80sflag.htm) for
per-instruction flag effects. This design targets the **NMOS Z80**
(Zilog Z8400 family: Z80 2.5 MHz, Z80A 4 MHz, Z80B 6 MHz, Z80H 8 MHz); CMOS
Z84C00-only behavior is out of contract and is called out where it differs.

The chip is a July 1976 8-bit microprocessor, designed by Federico Faggin and
Masatoshi Shima, in depletion-load NMOS on a 4 µm process with 8,500
transistors in a 40-pin DIP
([Zilog Z80 historical summary](https://en.wikipedia.org/wiki/Zilog_Z80); the
first working samples returned from Mostek on 9 March 1976 and the part was
officially launched in July 1976). It executes the Intel 8080 instruction set
as a binary-compatible subset and adds the CB, DD, ED and FD prefix pages, the
alternate register file, index registers, block instructions, the I and R
registers, three interrupt modes and DRAM refresh.

## Architecture

### Register set

Eight-bit registers A, F, B, C, D, E, H, L, with a complete alternate file
A', F', B', C', D', E', H', L' selected together by `EXX` (BC, DE, HL) and
independently by `EX AF, AF'`. Sixteen-bit IX, IY, SP and PC. Undocumented
but real 8-bit halves IXH/IXL and IYH/IYL are addressable through DD/FD
prefixes ([z80.info undocumented list](http://www.z80.info/z80undoc.htm), which
tested them on Z80A, Z80B and Z80H parts).

I is the high byte of the mode-2 interrupt vector; R is the 7-bit DRAM refresh
counter whose bit 7 is preserved and never incremented, incremented once per
M1 opcode fetch. WZ (also called MEMPTR) is an internal 16-bit temporary
register: it is not programmer-visible, but its contents leak into the
undocumented F3/F5 flags after `BIT n,(HL)`, `BIT n,(IX+d)`, `BIT n,(IY+d)` and
several ED-prefixed operations
([MEMPTR description](https://gist.github.com/0xcafed00d/17165035be8deb7a86ba082b07b47828)).
The published block diagram shows the CPU needs no more than one such 16-bit
temporary ([Zilog Z80 historical summary](https://en.wikipedia.org/wiki/Zilog_Z80)).

### Status flags

`F` is S at bit 7, Z at 6, F5 at 5, H at 4, F3 at 3, P/V at 2, N at 1 and C at
bit 0. F5 and F3 are the undocumented flag bits; the exerciser summary states
the same layout and defines P/V as parity or two's-complement overflow and N as
the add/subtract indicator
([ZEXALL/ZEXDOC description](https://github.com/agn453/ZEXALL)). Documented
flag effects per instruction follow UM0080's flag definitions and per-instruction
descriptions. Undocumented effects follow these rule families:

- Operations that produce an 8-bit result (ALU group, `INC`/`DEC` r, rotates and
  shifts, `LD A,I`, `LD A,R`, `IN r,(C)`, `CPL`, `SCF`, `CCF`, `DAA`, `NEG`,
  block instructions) copy bit 5 and bit 3 of the produced or consumed byte into
  F5/F3, with instruction-specific sources recorded in the
  [flag-affection table](http://www.z80.info/z80sflag.htm).
- `BIT n,r` copies bits 5 and 3 of the tested register; `BIT n,(HL)` and
  `BIT n,(IX+d)`/`BIT n,(IY+d)` copy them from the internal address path
  (WZ/MEMPTR) instead of the operand byte, which is the visible MEMPTR leak
  described above.
- `16-bit` arithmetic (`ADD/ADC/SBC HL,rr`, `ADD IX,rr`, `ADD IY,rr`) takes F3/F5
  from the high byte of the result, except `ADC HL,rr`/`SBC HL,rr`, whose F3/F5
  source is pinned by the flag table and the Z80 test literature.
- A hidden Q latch records whether the previous instruction wrote F; the
  documented flag behavior of `SCF`/`CCF` depends on it, which is why those two
  instructions can leave H and F3/F5 in states that surprise the unwary.

The exact per-opcode table is not restated here. It is generated from the
sources above, hash-recorded, and used as the RTL contract and the test oracle
in the implementation plan; ZEXALL and Patrik Rak's z80test then act as
independent checks that our reading of the table is right.

### Instruction groups

The full 256-byte primary opcode space plus the CB, DD, ED and FD prefix pages
and the DD-CB/FD-CB composite pages.

- **8080-compatible core.** All documented 8080 instructions with Z80 addressing
  and timing: 8-bit loads, immediate loads, ALU group, rotates on A,
  `DAA`/`CPL`/`SCF`/`CCF`, 16-bit loads and increments, `ADD HL,rr`, jumps,
  conditional and unconditional calls/returns, `RST`, `PUSH`/`POP`,
  `EX (SP),HL`, `EX DE,HL`, `JP (HL)`, `IN A,(n)`, `OUT (n),A`, `DI`/`EI`,
  `HALT`, `NOP`. Binary compatibility extends to undocumented 8080 opcodes that
  the Z80 aliases (`08`, `10`, `18`, `20`, `28`, `30`, `38` execute as `EX AF,AF'`,
  `DJNZ`, `JR`, `JR NZ`, `JR Z`, `JR NC`, `JR C`); this is the historical
  basis of Z80/8080 interchangeability and is part of the compatibility claim,
  not an error path.
- **CB page.** `RLC`, `RRC`, `RL`, `RR`, `SLA`, `SRA`, `SRL` on r/(HL), `BIT`,
  `RES` and `SET` on r/(HL), plus the undocumented `SLL` (`CB 30`–`CB 37`),
  which shifts left and forces bit 0 to one — the same operation the
  undocumented list calls SL1.
- **ED page.** `IN r,(C)`, `OUT (C),r`, `SBC HL,rr`, `ADC HL,rr`,
  `LD (nn),rr`/`LD rr,(nn)` for BC/DE/SP, `NEG`, `RETN`, `RETI`,
  `IM 0/1/2`, `LD I,A`, `LD R,A`, `LD A,I`, `LD A,R`, `RRD`, `RLD`, the block
  transfer/search group (`LDI`, `LDIR`, `LDD`, `LDDR`, `CPI`, `CPIR`, `CPD`,
  `CPDR`) and the block I/O group (`INI`, `INIR`, `IND`, `INDR`, `OUTI`,
  `OTIR`, `OUTD`, `OTDR`). The undocumented `ED 70` (`IN F,(C)`, flags-only
  input) and `ED 71` (`OUT (C),0`) are implemented; the list warns that the
  CMOS parts output 0x00 where NMOS outputs 0xFF, so this design records the
  NMOS data byte as an assumption.
- **DD/FD pages.** Every HL-referencing instruction re-encoded onto IX or IY.
  Undocumented halves IXH/IXL/IYH/IYL are honored for `INC`, `DEC`,
  `LD r,n`, `LD r,r'`, and the ALU group, but not for the mixed `LD H,(IX+d)` /
  `LD L,(IX+d)` forms, where only the memory operand is re-targeted.
- **DD-CB/FD-CB composite.** The documented forms are rotate/shift/`BIT`/`RES`/
  `SET` on `(IX+d)`/`(IY+d)`. Undocumented register-copy variants
  (`DD CB d 00`–`DD CB d 3F` and `80`–`FF`) perform the memory operation **and**
  copy the result into B/C/D/E/H/L/A; `BIT` forms do not copy. The
  undocumented page also lists the `ED` duplicate encodings (`NEG`,
  `RETN`, `RETI`, `IM 0/1/2` repeated across eight columns each), which are
  accepted aliases.
- **Prefix semantics.** Multiple DD/FD prefixes collapse to the last one. ED
  followed by CB/DD/ED/FD is ignored as an instruction and the following opcode
  executes normally; DD/FD followed by ED behaves the same way. These rules are
  observable in real software and are part of the compatibility contract.

### Interrupts

NMI is edge-triggered, recognized at an instruction boundary, pushes the return
PC and jumps to `0x0066` in interrupt mode 0 behavior with IFF2 preserving the
previous IFF1 state; `RETN` restores IFF1 from IFF2. Maskable INT is
level-sensitive and accepted only at an instruction boundary with IFF1 set;
acceptance clears IFF1 and IFF2. Mode 0 executes the instruction placed on the
data bus (normally `RST n`), mode 1 is `RST 38h`, mode 2 forms a vector address
from `I` concatenated with the byte supplied by the interrupting device and
fetches the two-byte handler address from it. `EI` defers recognition until
after the following instruction; `DI` takes effect immediately. `LD A,I` and
`LD A,R` copy IFF2 into P/V. `HALT` freezes PC and executes NOPs while the
refresh cycles continue, and exits on any accepted interrupt
([UM0080](https://www.zilog.com/docs/z80/um0080.pdf) interrupt chapters).

### Refresh

Every M1 opcode fetch is followed by a refresh cycle in T3/T4: `RFSH` and
`MREQ` asserted, the 7-bit R counter driving A0–A6 with A7 fixed at zero, and
A15 carrying IFF2 in place of the normal address bit, A8–A14 undefined. R
increments once per M1 fetch (each prefix byte is its own M1 fetch). This is
the DRAM refresh capability that made the Z80 cheaper to design into a system
than the 8080, and it is why a TRS-80 Model I needs no separate refresh logic.

### Reset

`/RESET` is active-low and must be held for at least three clock cycles. It
zeroes PC, I and R, clears IFF1/IFF2, selects interrupt mode 0 and leaves the
general registers and flags undefined. Software must initialize them; the
functional model exposes a deterministic post-reset value only to make tests
reproducible and marks that choice as a modeling assumption.

## Bus interface

### Pin-level contract (native engine)

40-pin DIP, single +5 V supply, single-phase TTL clock:

| Signal | Direction | Meaning |
|---|---|---|
| `A[15:0]` | out | Address bus; carries R and IFF2 during refresh |
| `D[7:0]` | bidir | Data bus, driven only during write cycles and interrupt acknowledge |
| `M1_n` | out | Opcode fetch cycle indicator |
| `MREQ_n` | out | Memory request |
| `IORQ_n` | out | I/O request; asserted with `M1_n` during interrupt acknowledge |
| `RD_n` | out | Read strobe |
| `WR_n` | out | Write strobe |
| `RFSH_n` | out | Refresh cycle indicator |
| `HALT_n` | out | CPU halted |
| `WAIT_n` | in | Extends the current bus cycle |
| `INT_n` | in | Maskable interrupt request |
| `NMI_n` | in | Non-maskable interrupt request |
| `BUSRQ_n` | in | Bus request; CPU floats the bus when acknowledged |
| `BUSACK_n` | out | Bus acknowledge |
| `RESET_n` | in | Reset |
| `CLK` | in | Single-phase clock |

### Machine cycles

An M1 opcode fetch is four T-states: address on T1, `MREQ`/`RD` through T2 and
T3, opcode sampled on the T3 rising edge, then `RFSH` with the refresh address
in T3/T4. A memory read or write is three T-states. An I/O cycle is four
T-states with one automatic wait state between T2 and T3. `WAIT` is sampled on
the falling edge of T2 and extends the cycle by whole T-states. Interrupt
acknowledge is an M1 cycle with `IORQ` instead of `MREQ`, with two automatic
wait states so that slow peripheral daisy chains can settle, and the vector byte
is sampled at the end. These cycle shapes and the per-instruction M-cycle
sequences follow UM0080's timing and instruction-description chapters and are
the native engine's contract; the functional engine below deliberately does not
claim them.

### Instruction timing

Every instruction's duration is the sum of its machine cycles as tabulated in
UM0080's instruction descriptions. The native engine must reproduce those
T-state counts exactly, including the prefix and indexed-addressing penalties
(`DD`/`FD` add four T-states to the instructions they modify, `DD CB d` forms
cost twenty-three T-states, `LDIR` costs twenty-one per iteration and sixteen
on the final pass). Timing tables are extracted into a machine-readable form,
hash-recorded and checked instruction by instruction; approximate timing is not
acceptable for the TRS-80 Model I integration that depends on this core.

## Implementation interface

Two engines share one architectural core, in the same staged way the
repository's 6502 design separates its functional and native engines:

| Port | Direction | Meaning |
|---|---|---|
| `clk`, `rst_n` | in | Implementation clock, synchronous active-low reset |
| `bus_req_o`, `bus_ready_i` | out/in | Transfer accepted on the rising edge with both high |
| `bus_write_o` | out | Write when high, read when low |
| `bus_addr_o[15:0]` | out | Memory address; the I/O port replicated into both bytes |
| `bus_wdata_o[7:0]`, `bus_rdata_i[7:0]` | out/in | Transfer data |
| `bus_io_o` | out | Selects the separate I/O space |
| `bus_intack_o` | out | Interrupt acknowledge; the device supplies the instruction or vector byte |
| `int_i`, `nmi_i` | in | Maskable and non-maskable interrupt requests |
| `halt_o`, `iff1_o`, `im_o[1:0]` | out | Architectural state observations |
| `retire_o`, `fault_o` | out | Instruction completion pulse, sticky model-validity fault |
| `pc_o[15:0]`, `sp_o[15:0]`, `wz_o[15:0]` | out | Architectural observations for the oracle bridge |
| `regs_o[63:0]` | out | A, F, B, C, D, E, H, L in that order |
| `alt_o[63:0]` | out | A', F', B', C', D', E', H', L' in that order |
| `ix_o`, `iy_o[15:0]`, `i_o`, `r_o[7:0]` | out | Index, interrupt-vector and refresh registers |

The functional engine executes one rising edge per implementation step and
advances architectural state only on an acknowledged transfer, the same
transaction contract the 8080 design uses. The native engine replaces the
transaction handshake with real pin behavior, including refresh cycles, `WAIT`
stretching, bus grant, and interrupt acknowledge cycle shapes, and is the engine
the TRS-80 Model I system builds against. Both engines instantiate the same
decoder, ALU and register file, so an instruction implemented once is available
to both.

### Staging contract

The functional engine is verified against an independent instruction-stepped
oracle, the ZEXALL/ZEXDOC exercisers and historical CP/M software. The native
engine additionally must match the UM0080 cycle shapes and T-state counts
exactly; its verification is a per-instruction bus-cycle comparison against the
timing tables plus the `WAIT`/`BUSRQ`/interrupt cycle shapes. Claiming the
functional engine makes the native engine verified is a defect, and the two
engines' reports stay separate.

## Validity boundaries and assumption ledger

Out of contract: electrical characteristics (drive levels, input thresholds,
propagation delays, power), silicon-level behavior of the later CMOS parts, the
Z180/Z280/eZ80 extensions, and physical validation on a real die. The TRS-80
Model I board, video, keyboard and cassette integration belong to the system
issue that depends on this chip, not to this design.

| Assumption or evidence gap | Independent evidence and validation | Status |
|---|---|---|
| Undocumented instruction encodings (SLL, IXH/IXL/IYH/IYL, DD-CB register copies, ED duplicates, `ED 70`/`ED 71`) are real NMOS hardware behavior | z80.info list tested on Z80A/B/H parts; Sean Young §4; ZEXALL covers SLL, IX halves and DD-CB forms | Provisional; encodes only what both sources agree on until the corpus runs |
| Per-opcode documented flag table | Generated from UM0080 instruction descriptions and the z80.info flag table; differenced against the immutable oracle | Not yet extracted; extraction task is a plan milestone |
| Undocumented F3/F5 sources, including the Q latch and WZ/MEMPTR leaks | Flag-affection table plus the MEMPTR description; ZEXALL exercises F3/F5 but **not** MEMPTR, so Patrik Rak's z80test is a separate required gate | Open; ZEXALL alone cannot sign off this row |
| `OUT (C),0` data byte is 0xFF on NMOS and 0x00 on CMOS | z80.info list notes the CMOS difference; target part is NMOS | Provisional; pin data byte must be confirmed before the native engine signs off |
| R increments once per M1 fetch, bit 7 preserved; interrupt acknowledge increments it twice | UM0080 refresh description and emulator practice; not covered by ZEXALL | Provisional; native timing tests must pin it |
| `EI` delay, `LD A,I`/`LD A,R` P/V = IFF2, `HALT` refresh continuation | UM0080 interrupt chapters and instruction descriptions | Provisional; directed tests required |
| Post-reset general registers are undefined; the model exposes zeros | UM0080 reset description | Modeling assumption; documented in RTL with `ASSUMPTION:` and excluded from oracle comparison |
| NMOS minimum clock frequency (dynamic internal state, roughly 250 kHz) | Historical Z80 tester notes and the CMOS "no lower frequency limit" contrast | Open; native engine must not claim sub-minimum-clock correctness |

Mark unresolved behaviors with `ASSUMPTION:` at their RTL implementation. The
external emulator is never reconstructed from this RTL; it is vendored at a
pinned commit with recorded hashes, exactly as the 8080 design treats its
superzazu oracle. Historical software and test exercisers keep their original
bytes and verified hashes and are never patched.

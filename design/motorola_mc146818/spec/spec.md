# Motorola MC146818 real-time clock plus RAM: specification

Status: implemented and verified against an independent reference model,
directed data-sheet tests, 32 random seeds and the IBM PC AT BIOS port
70h/71h access sequences. See [the verification report](../report/final_report.md).

## Sources

| Ref | Document | Use |
|---|---|---|
| DS | Motorola, *MC146818 Real-Time Clock Plus RAM (RTC)*, Advance Information **ADI-856-R1**, with its one-page addendum, in *Motorola 8-Bit Microprocessor and Peripheral Data* (1983), pp. 3-697 to 3-718 (PDF pages 741-762). [bitsavers mirror](http://bitsavers.trailing-edge.com/components/motorola/_dataBooks/1983_Motorola_8-Bit_Microprocessor_and_Peripheral_Data.pdf), SHA-256 `80ae803cf28b9f054ea9d835bb26f191b47e6d5ab50fc9d054300a30a30cc632` | Primary source for all behavior. Page numbers below (p.3-7xx) refer to it |
| DS81 | Motorola, *MC146818* Advance Information (earlier revision, no document number printed), in *Motorola Microprocessors Data Manual* (1981), pp. 4-1046 ff. (PDF pages 1115-1134). [bitsavers mirror](http://bitsavers.trailing-edge.com/components/motorola/_dataBooks/1981_Motorola_Microprocessors_Data_Manual.pdf), SHA-256 `5bfd7a044a6c0db1eda07330ecc52a850f3c2563042cfaf2dcc3265e3f1b1370` | Dating; cross-check of DS. Differences listed below |
| TR | IBM, *Personal Computer AT Technical Reference* 6280070 (March 1984): "Real-time Clock/CMOS RAM Information" pp. 1-45 to 1-52 and the BIOS listing | Board use, CMOS map, the port 70h/71h access sequences replayed by `scripts/bios_replay.py` |
| MAME | MAME `src/devices/machine/mc146818.cpp` (BSD-3-Clause), commit `b76b3922aa6eb49fe35a85e7689bd1d709bbcaee` | Behavior cross-check only; no code copied |

The PDFs are not committed. To check a citation, download them into the
ignored `design/motorola_mc146818/work/refs/` folder. www.bitsavers.org
returned HTTP 403 to scripted downloads on 2026-11-13. The
bitsavers.trailing-edge.com mirror served the same paths.

### DS81 vs DS

DS81 is an earlier printing of the same sheet. The register functions are the
same. DS corrects these errors in it:
- DS81's interrupt section says the flags and IRQF are in "Register A" and are
  cleared by reading Register A. Everywhere else, and in DS, they are in
  Register C.
- The Figure 16 legend in DS81 gives tUC = 244 us and tBUC = 248/1984 us,
  which is the wrong way round. DS gives tUC = 248/1984 us and tBUC = 244 us,
  as in Table 6 of both versions.
- DS81 calls the registers "Control Register #D" or "Status Register 1" in
  places. DS adds the CE/AS date-code addendum and the IMPORTANT NOTICES page.

DS has errata of its own: p.3-710 gives the update lockout as "1948 us" and
the time base as "1.048567 MHz". Table 6 and p.3-713 give 1984 us and
1.048576 MHz. p.3-713 says "once every 4032 attempts" and then "once every
2032 attempts". This design follows Table 6.

## Interface

`src/motorola_mc146818.sv`, module `motorola_mc146818`. All inputs are
sampled on `clk` (one clock domain). Strobe edges are detected from the
sampled levels.

| Parameter | Default | Meaning |
|---|---|---|
| `NVRAM_FILE` | `""` | `$readmemh` image of the 64 locations at power-on (64 hex bytes, `//` comments allowed). Empty: all zero, so VRT = 0 ("battery lost") |
| `FAST_SHIFT` | `0` | 0 = real time. With s > 0 one `tick_i` counts as 2^s oscillator periods (0..10). Simulation only |

| Port | Dir | Chip pin / meaning | AT board hookup |
|---|---|---|---|
| `clk` | in | Design clock (fast compared with the bus strobes) | System clock |
| `rst_n` | in | Simulation/FPGA power-on reset of internal state (bus latches, divider, update sequencer). Does not change the 64 locations. Not the RESET pin | System power-on reset |
| `tick_i` | in | OSC1 clock enable: one pulse per oscillator period | 32.768 kHz enable |
| `ce_n_i` | in | CE, active low | Low when port 70h/71h is decoded (or tie low and gate AS/DS) |
| `as_i` | in | AS: falling edge latches AD5-AD0 | Pulse on an I/O write to port 70h |
| `ds_i` | in | DS: read data driven while high; write data latched at the falling edge | Pulse on an I/O read or write of port 71h |
| `rw_i` | in | R/W: 1 = read, 0 = write, valid while DS is high | IOR = 1, IOW = 0 for port 71h |
| `ad_i[7:0]` | in | AD7-AD0 into the chip | During a port 70h write: data bits 5-0 (bit 7 goes to the NMI-mask flip-flop, bit 6 unused). During a port 71h write: data |
| `ad_o[7:0]`, `ad_oe_o` | out | AD7-AD0 out and drive enable (`ds_i & rw_i & ~ce_n_i & reset_n_i`) | Port 71h read data |
| `reset_n_i` | in | RESET pin, active low | Board RESET wiring (tie high if unused) |
| `ps_i` | in | PS (power sense) pin. Low clears VRT | Tie high (battery good) unless modeling a battery loss |
| `irq_n_o` | out | IRQ, open drain: 0 = pulled low, 1 = released | IRQ 8 through an inverter |
| `sqw_o` | out | SQW | Not connected on the AT |
| `dbg_addr_i[5:0]`, `dbg_data_o[7:0]` | in/out | Side-effect-free read of any location (architectural view: UIP, IRQF and flags included). Used to dump the contents | Simulation only |

Bus cycle (Motorola mode of MOTEL, p.3-706 to 3-708) as the bench drives it
(one line per `clk`):

```
CE=0 AS=1 AD=addr | AS=0 (address latched) | DS=1 R/W AD=data (>=1 clk) | DS=0 (write / read side effect)
```

Dumping the contents: read `dbg_data_o` for `dbg_addr_i` = 0..63, as
`tb/mc146818_tb.cpp` does for its `DUMP` command. The result is in
`$readmemh` format. You can feed it back as `NVRAM_FILE` to model a battery
that holds the contents.

## Register map (DS Figure 15, Table 3, pp.3-710 to 3-715)

| Addr | Contents | Notes |
|---|---|---|
| 00 | Seconds | Bit 7 read-only; reads 0 (R13) |
| 01 | Seconds alarm | C0-FF = don't care |
| 02 / 03 | Minutes / minutes alarm | |
| 04 / 05 | Hours / hours alarm | 12-hour mode: bit 7 = PM, 01-12 |
| 06 | Day of week | 1-7, Sunday = 1 |
| 07 / 08 / 09 | Date / month / year | 1-31 / 1-12 / 0-99 |
| 0A | A: UIP DV2 DV1 DV0 RS3 RS2 RS1 RS0 | UIP read-only |
| 0B | B: SET PIE AIE UIE SQWE DM 24/12 DSE | All read/write |
| 0C | C: IRQF PF AF UF 0 0 0 0 | Read-only; reading clears the flags |
| 0D | D: VRT 0 0 0 0 0 0 0 | Read-only |
| 0E-3F | 50 bytes of user RAM | Available during updates |

Time bytes are BCD when DM = 0 and binary when DM = 1. The hours byte is
0-23 when 24/12 = 1, or 1-12 plus a PM bit when 24/12 = 0 (Table 3).

## Behavior

**Divider (Table 4, Table 5, p.3-711 to 3-714).** The 22-stage divider is
modeled as a 22-bit count of 4.194304 MHz periods. Each tick adds 2^(N+s),
where DV selects N: 000 gives N = 0, 001 gives N = 2, 010 gives N = 7, and
s is `FAST_SHIFT`. Bit k toggles at 2^22 / 2^(k+1) Hz, so these frequencies
are absolute and independent of the time base. Bit 21 is the 1 Hz update
clock. DV = 11x holds the divider at 0. Releasing it puts the first 1 Hz
edge 2^21 counts (half a second) later, as p.3-714 requires. RS selects
tap bit RS+5. With DV = 010, RS = 1 and RS = 2 select bits 13 and 14
(256 Hz and 128 Hz), which matches the 32.768 kHz column of Table 5. RS = 0
selects nothing.

**Periodic interrupt and SQW.** PF is set on each rising edge of the
selected tap, whatever the state of PIE or SET (p.3-711, p.3-714). SQW
outputs the tap level when SQWE = 1 and is low otherwise. A tap edge falls
between two update cycles, as Figure 16 shows (R6).

**Update cycle (Table 6, Figure 16, p.3-713).** On the 1 Hz edge with
SET = 0, UIP goes to 1. tBUC later the ten time bytes are advanced by one
second and compared with the alarm (AF). tUC after that, UIP returns to 0
and UF is set. tBUC and tUC are 8 and 65 oscillator periods at 32.768 kHz,
256 and 260 at 1.048576 MHz, and 1024 and 1040 at 4.194304 MHz (R4).
Writing SET = 1 aborts a cycle in progress and clears UIP. While SET = 1, no
update cycle starts, but periodic flags and SQW keep running.

**Calendar.** Seconds and minutes run 0-59. Hours run 0-23, or 12, 1-11 in
12-hour mode, where 11:59:59 AM goes to 12:00:00 PM and 11:59:59 PM goes to
12:00:00 AM with a day carry. A day carry advances the day of week (7 to 1)
and the date. The date rolls over at 31, 30, or 28/29 days. February has 29
days when the year is divisible by 4 (R8). Then the month (12 to 1) and the
year (99 to 0) follow. BCD and binary modes use the same rules in their own
encoding.

**Alarm.** Each of the three alarm bytes matches when it equals its time
byte or holds C0-FF. A match of all three after an update sets AF
(p.3-711).

**Daylight saving (DSE = 1, p.3-714).** On the last Sunday in April the
clock goes from 1:59:59 AM to 3:00:00 AM. On the last Sunday in October it
goes from 1:59:59 AM to 1:00:00 AM, the first time only (R10).

**Interrupts (p.3-711, p.3-714).** IRQF = PF·PIE + AF·AIE + UF·UIE.
`irq_n_o` is low exactly when IRQF = 1. A read of register C returns the
flags as latched before DS rose (double latching). At the end of the read
it clears those that read as 1. A flag set during the read stays set.

**RESET pin (p.3-708/709).** While RESET is low, PIE, AIE, UIE, SQWE, PF,
AF and UF are held at 0, IRQ is released and SQW is low. The bus is
ignored: no address latch, no write, no read drive. The pin does not
affect time, RAM, SET, DM, 24/12, DSE, DV, RS, UIP, VRT or the update
cycle.

**PS and VRT (p.3-709, p.3-715, Figure 8).** PS low clears VRT and holds it
at 0. A read of register D sets VRT if PS is high (R12). Nothing else
changes VRT. RESET does not change it.

## Assumptions

Each item is behavior that DS does not state explicitly. The same tag marks
the RTL (`src/motorola_mc146818.sv`) and the reference model
(`scripts/mc146818_model.py`). "Checked" says what exercises it.

| Tag | Assumption | Basis | Checked |
|---|---|---|---|
| R1 | AS, DS, R/W, CE and AD are sampled every clock. The address is latched at the AS falling edge. A write happens at the DS falling edge with the data, R/W and CE of the last clock in which DS was high. A read's side effects happen at the DS falling edge. Nothing happens if CE was high, or if RESET is low at that edge | DS p.3-708 (AS, DS, R/W, CE, AD descriptions); CE "must be stable during DS and AS" | Directed `registers_power_on` (CE-high cycles); random `WN`/`RN` |
| R2 | UIP rises on the 1 Hz divider edge. The update (increment and alarm compare, AF) happens tBUC later. UIP falls and UF is set tUC after the update | Figure 16 and Table 6; DS gives no absolute phase. MAME uses the same order (UIP, then 244 us later the update and AF, then UF after tUC) | `update_cycle_timing`, `fast_uip_window_*`; BIOS SET_TOD poll |
| R3 | DV test codes 011, 100 and 101 hold the divider in reset like 11x | Table 4 note: "used for test purposes only". MAME stops the divider for these codes | `divider_test_codes` |
| R4 | tBUC and tUC are rounded to whole oscillator periods: 8/65 (32.768 kHz), 256/260 (1.048576 MHz), 1024/1040 (4.194304 MHz). With FAST_SHIFT = s each phase lasts ceil(periods / 2^s) ticks | Table 6 gives 244 us, 248 us and 1984 us | `update_cycle_timing`, `fast_uip_window_4m/1m/32k` |
| R5 | During the update cycle (tUC), writes to locations 00-09 are lost and reads return the bytes already advanced. Writes during tBUC (UIP = 1, before the update) are accepted, and the update then advances the written value. If a bus write and the update land in the same clock, the update wins | DS p.3-713: the bytes are "switched off the bus" and read data is "undefined" during the update cycle; DS p.3-712/713 guarantees 244 us after UIP rises. MAME accepts writes at any time | `update_cycle_timing`, `write_during_uip`; random (1,282 writes lost in tUC, 299 writes during tBUC) |
| R6 | PF is set on the rising edge of the selected tap. SQW is the tap level | Figure 16 places UIP midway between PF pulses, which a rising-edge PF gives with this divider. MAME sets PF on the rising half of its square wave | `periodic_rates_*`, `square_wave_and_pie` |
| R7 | A time byte rolls over when its value is greater than or equal to its last legal value, compared as an unsigned byte in the current mode (for example seconds >= 59h in BCD). Out-of-range values therefore recover at the next carry. A BCD increment carries when the low digit is 9 or more, and the high digit wraps modulo 16 | DS defines only the legal ranges (Table 3). MAME notes the out-of-range case as unknown | Calendar check over legal values; random writes of arbitrary bytes |
| R8 | Leap year: the two-digit year is divisible by 4, so 00 is a leap year. In BCD the test uses the tens digit modulo 2 and the units digit | DS: "automatic leap year compensation" with no rule given. MAME treats years as 2000-2099, which is equivalent | `roll_bcd_leap_*`, `roll_bcd_year00_leap`, `roll_bin_*_feb28`; datetime check |
| R9 | A month value outside 1-12 has 31 days | Not stated | Random |
| R10 | Daylight saving is decided on the bytes before the increment, when the time is 01:59:59 with hours byte 01h. "Last Sunday" means day of week = 1 and date >= 24 (April) or >= 25 (October). The October fall-back happens once: an internal flag is set by it and cleared by the first update that leaves the hour at a value other than 01h. The flag is not battery-backed (`rst_n` clears it). The DS note that the time must be set at least two seconds before the changeover (p.3-713) points to precomputed internal state, which is not modeled | DS p.3-714. Not in MAME | `roll_dst_*`, `dst_october_once` |
| R11 | IRQF is derived from the flags and enables at all times. Clearing an enable releases IRQ and makes IRQF read 0 while the flag stays set | DS p.3-714: "IRQF = PF·PIE + AF·AIE + UF·UIE"; "Any time IRQF is 1, IRQ is driven low". MAME is the same | `square_wave_and_pie` |
| R12 | A read of register D returns the VRT value from before the read and then sets VRT, unless PS is low | Figure 8 note and p.3-715: "VRT can only be set by reading Register D". MAME also returns the old value | `vrt_and_ps`; BIOS cold-boot replay (first read 00h, then 80h) |
| R13 | Seconds bit 7 reads 0 and is not stored by writes | DS p.3-709: "read only". The value it reads is not given. MAME reads 0 | `registers_power_on` |
| R14 | `NVRAM_FILE` initializes all 64 locations, including the PF/AF/UF bits (0Ch bits 6-4) and VRT (0Dh bit 7). Image bits that read as constants (00h bit 7, 0Ah bit 7, 0Ch bits 7 and 3-0, 0Dh bits 6-0) are ignored. `rst_n` resets only state the data sheet does not show: the address latch, strobe history, divider count (to 0, so the first update comes 0.5 s after power-on), update sequencer, register C latch and DST flag | Battery-backed contents are a board/simulation concern, outside DS | BIOS warm replay (image with VRT = 1); formal starts from any contents |
| R15 | SET clears UIE only when SET goes from 0 to 1, including in the same write. Writing B with SET already 1 can set UIE | DS p.3-714: "the SET bit going high clears the UIE bit". MAME does the same | `registers_power_on`, `set_bit_behaviour` |
| R16 | Changing DV between running time bases keeps the divider count. Entering 11x (or a test code) clears it and aborts a pending update | Table 4 | `divider_test_codes`, random |

## Differences from MAME (behavior reference only)

- MAME does not abort a pending update when SET is written. It checks SET only
  when UIP rises. This design follows DS p.3-714 and aborts.
- MAME accepts writes to the time bytes during the update cycle (R5).
- MAME does not implement DSE.
- MAME forces VRT = 1 whenever it loads an NVRAM file. Here VRT comes from
  the image (R14).
- MAME has no RESET-pin bus lockout.

## IBM PC AT usage (TR)

The AT BIOS uses addresses 0Eh-3Fh as configuration RAM and keeps a
checksum of 10h-2Dh at 2Eh-2Fh, high byte first. It writes A = 26h
(32.768 kHz, 976.562 us periodic rate) and B = 82h, then 02h (24-hour,
BCD). It reads C and D to clear them. It tests VRT in register D at POST
checkpoint 16. TR calls VRT "VRB", and its note that the flags "are
affected when the interrupts are enabled" is looser than DS, where the flags
set independently of the enables. SET_TOD compares the time bytes with
59h/59h/23h, so it assumes BCD in 24-hour mode. Port 70h bit 7 is the NMI
mask on the AT board and does not reach the chip's address.

## Not modeled

- The Intel ("competitor") mode of MOTEL, where DS is high during AS and acts
  as RD with R/W as WR. Only the Motorola mode is implemented: DS must be
  low while AS is high.
- CKOUT and CKFS (clock output), the crystal oscillator and its start-up
  time, and the electrical and AC timing of the bus (setup, hold, tDDR).
- Power-down behavior, battery switchover, VDD ranges, and the date-code
  CE/AS synchronization addendum.
- Undefined read data during the update cycle. Defined values are returned
  (R5).
- The internal precomputation that makes DS require the time to be set two
  seconds before a DST or month-end change (R10).

# MC146818 test plan

The simulation checks compare the RTL with the reference model
`scripts/mc146818_model.py`. The model was written from data sheet
ADI-856-R1, not from the RTL. Both run the same script. The bench
(`tb/mc146818_tb.cpp`) drives the chip's pins: AS, DS, R/W, CE, AD, RESET,
PS and `tick_i`. The model executes the same operations atomically. The
two traces must match line for line. They contain:
- every bus read value, or Z when the bus is not driven;
- IRQ and SQW after every command;
- every change of IRQ or SQW during runs of ticks;
- full 64-byte dumps through the debug port.

| Check | Source of truth | Script |
|---|---|---|
| Calendar arithmetic, ~20,000 instants x 4 modes (BCD/binary x 12/24 h), biased to month ends; alarm match/don't-care/miss | Python `datetime` | `check_calendar.py` |
| 46 directed tests: power-on values, read-only bits, all of B, user RAM, CE high, AD5-AD0 decode; update timing (UIP, tBUC, tUC, UF); writes during UIP and during the update; rollovers of second, minute, hour, day, month and year, 30/31-day months, leap and common February in BCD and binary, year 00; 12-hour AM/PM transitions; DST April and October (once only), and DSE off; alarm exact, don't-care per byte, 80h-BFh not don't-care, PM bit; every RS rate for the three time bases; SQW waveform; PIE/IRQ/IRQF; SET abort and UIE clear; RESET pin; VRT/PS; register C flag combinations; DV test codes; FAST_SHIFT timing for each base | Literal expected values derived from the data sheet (model checks them); RTL trace equal to model | `directed_tests.py`, `run_sim.sh` |
| 32 random seeds x 1,500 operations at FAST_SHIFT 6, about 3,900 simulated seconds | Model | `gen_random_test.py`, `run_sim.sh` |
| Coverage gate on the random seeds: all 64 locations written and read, every bit value of A and B written, all 15 RS rates, all three flags set and each driving IRQ, UIP, register C clearing, VRT set, SET rising, update aborted, RESET pin, PS low, writes during UIP, writes lost during the update, writes to C/D, every rollover kind including leap day, AM/PM both ways, both DST changes | Model counters | `report_coverage.py --require` |
| IBM PC AT BIOS, cold boot with a dead battery (default image) | Listing: C10A at 01AF/01B3, checkpoint 02 rolling bit (01E6-020D), checkpoints 16/17/19, C7B/C7C, SET_TOD, INITIALIZE_STATUS, INT 1Ah time set, INT 15h EVENT_WAIT PIE, RTC_INT handler | `bios_replay.py`, `run_sim.sh` |
| IBM PC AT BIOS, boot with a valid configuration (`tb/nvram/at_cmos_valid.hex`) | Listing: C7B, C10A, checkpoint 02, battery good, CMOS checksum 10h-2Dh vs 2Eh:2Fh, E20B memory size, SET_TOD UIP wait and BCD limits | `bios_replay.py`, `run_sim.sh` |
| Mutation check: six planted faults must each produce a trace difference | Bench and model | `run_mutation.sh` |

The script format is documented at the top of `tb/mc146818_tb.cpp`.

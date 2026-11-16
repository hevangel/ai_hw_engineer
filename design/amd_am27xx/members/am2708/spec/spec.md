# Am2708 functional specification

## Source

AMD [1977 Bipolar MOS Memories Data Book](https://www.bitsavers.org/components/amd/_dataBooks/1986_AMD_Bipolar_MOS_Memories_Data_Book.pdf), printed pages covering the Am2708 (1K × 8 UV EPROM).

## Digital contract

**Am2708 - 1K × 8 UV EPROM**

| RTL port | Device signal | Meaning |
|---|---|---|
| `ce_n_i` | CE-bar | Chip enable, active low |
| `oe_n_i` | OE-bar | Output enable, active low |
| `pgm_n_i` | PGM-bar | Program enable, active low |
| `erase_n_i` | ERASE-bar | Erase enable, active low |
| `addr_i[9:0]` | A0-A9 | 10-bit address bus |
| `data_i[7:0]` | D0-D7 | 8-bit data bus (output on read, input on program) |
| `pgm_cyc_o` | PGM-CYC | Program cycle in progress indicator |
| `ready_n_o` | READY-bar | Device ready for next command indicator |

**Operation modes:**

1. **Read mode:** Enable with CE-bar low, OE-bar low
   - Address bus selects memory location
   - Data bus outputs stored contents
   - No programming action occurs

2. **Program mode:** CE-bar low, PGM-bar low
   - Address bus selects memory location for programming
   - Data bus provides data to be programmed
   - Internal programming sequence initiated

3. **Erase mode:** CE-bar low, ERASE-bar low
   - Address bus ignored during bulk erase
   - UV light must be present in quartz window
   - Approximately 30-60 minutes erase cycle time

4. **Reset/Idle mode:** All enables high or CE-bar high
   - Device returns to idle state
   - Internal registers cleared
   - Ready for next command

## Timing boundary and legal stimulus

This is a functional reconstruction with timing constraints:

- **Programming cycle:** Maximum 100ms typical, 200ms maximum
- **Read cycle:** 200ns typical, 500ns maximum
- **Erase cycle:** 30-60 minutes with UV light
- **Input timing:** Setup/hold requirements for CE, OE, PGM, ERASE inputs
- **Address stability:** Address must be stable for minimum 100ns before enable assertion
- **No undocumented binary semantics are assumed**

## Assumption ledger

**Unspecified:**
- Power-up state and default contents
- Partial erase behavior (address-dependent vs bulk)
- UV light wavelength requirements
- Exact programming algorithm timing details
- Automatic erase completion detection

**Assumed:**
- JEDEC standard command set compatibility
- TTL-compatible voltage levels (0V, 5V)
- Active-low control signals
- Standard pin organization and numbering
- No concurrent operations allowed

**Verification:**
- Programming sequence functionality
- Address mapping correctness
- Data integrity during read/program/verify operations
- Timing boundary compliance
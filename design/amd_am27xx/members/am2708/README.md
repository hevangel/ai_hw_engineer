# Am2708

## Chip Overview

**AMD Am2708** - 1K × 8 UV EPROM (1024 words × 8 bits)

First-introduced year: 1977* (AMD 1977 Bipolar MOS Memories Data Book)

**Historical context:** The Am2708 represents AMD's first entry into parallel-access EPROM technology, providing 1K × 8 UV EPROM memory with standard JEDEC command set for read, program, and erase operations.

**Technical characteristics:** 
- 10-bit address bus (1K words)
- 8-bit data bus  
- Standard UV EPROM package with quartz window
- JEDEC-standard command set for programming
- TTL-compatible control signals

## Key features

- 1024 × 8 bit storage capacity
- UV erasable (280nm wavelength)
- Standard JEDEC command set
- Chip enable, output enable, write enable controls
- Built-in programmer timer
- Operating voltage: 5V ±5%

## Sources

- [AMD 1977 Bipolar MOS Memories Data Book](https://www.bitsavers.org/components/amd/_dataBooks/1986_AMD_Bipolar_MOS_Memories_Data_Book.pdf)

## Implementation scope

- Synthesizable SystemVerilog implementation with JEDEC command set
- Functional verification against datasheet specifications
- Formal verification of timing and control logic
- Programming sequence verification
- UV window timing simulation
- Power consumption and voltage analysis
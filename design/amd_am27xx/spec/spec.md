# AMD Am27xx series functional specification

## Source

The AMD Am27xx series encompasses parallel EPROMs documented in:
- [AMD 1986 Bipolar MOS Memories Data Book](https://www.bitsavers.org/components/amd/_dataBooks/1986_AMD_Bipolar_MOS_Memories_Data_Book.pdf)
- Additional CMOS EPROM documentation from 1993+

## Digital contract

Parallel EPROMs with common timing and control interfaces. All devices in this family share:
- Common pinout organization for equivalent capacities
- Similar programming/read timing characteristics
- Standard command set for EPROM operations
- Compatible voltage requirements

## Planning scope

This family includes both NMOS and CMOS EPROM variants:
- NMOS UV EPROMs: Am27xx series (1K×8 to 64K×8)
- CMOS EPROMs: Am27Cxx series (8K×8 to 1M×8)

Each member chip implements unique capacity and organization while maintaining family-level compatibility through shared underlying architecture and control logic.

## Design approach

1. Create family-level RTL modules for shared functionality
2. Implement member-specific variations using parameters
3. Verify each member independently against its datasheet specifications
4. Maintain source-backed assumption ledgers for all undocumented behavior
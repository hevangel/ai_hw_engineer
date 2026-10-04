# Am2918 digital specification

The [1979 AMD family book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1979_AMD_2900family.pdf)
PDF209–212 (printed2-201–2-204) specifies the original Schottky Am2918.
Its truth table is PDF211 and original application circuits PDF212. The
earlier [1978 book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf)
already contains this datasheet on PDF162–165; exact first shipment year is
not established. Do not confuse Am2918 with the separate low-power Am29LS18.

Four D inputs capture on native CP LOW-to-HIGH. There is no clock enable,
clear, reset or defined startup. Q always carries the four non-inverted stored
bits. Y carries the same stored bits with independent active-low OE gating;
OE HIGH releases all four Y pins, without changing Q or inhibiting capture.
D changes during steady HIGH/LOW CP and falling edges leave state unchanged.
The internal inverted-clock/complementary-output drawing still implements
positive-edge, non-inverted external behavior, confirmed by the truth table.

Represent Y using value plus common output enable for external digital bus
resolution. ASSUMPTION: settled digital setup/hold; electrical delays,
fanout, metastability and contention are outside the model. Released Y data
is irrelevant. Tests initialize through actual clocks, never forced state.

Manufacturer MPR-188 bidirectional circuit: the left chip samples bus A and
drives bus B; the right samples B and drives A. The schematic pins establish
these cross-connections (the adjacent prose repeats A for the left output).
MPR-189 serial converter uses two chips, D0=serial, each subsequent D=previous
Q and common CP/OE. The eight-bit Q word shifts toward bit7; serial output is
the last Q. Both circuits are included as actual RTL application tests.

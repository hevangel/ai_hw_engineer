# Manufacturer truth tables

`encoder.csv` transcribes the ten rows of the encoder table on PDF164 /
printed2-156 of the [1979 family book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1979_AMD_2900family.pdf).
Columns reverse the printed bit order into ordinary descending binary order;
`x` preserves the original don't-care inputs. `gates.csv` records the separate
output-gate table. Both were authored before RTL, after visual inspection.

The oracle generator compiles the tables into a formal case statement and
an exhaustive C++ lookup array, checking that overlapping gate rows agree and
every input has exactly one encoder row. Neither artifact reads RTL. The
simulation's cascade/hierarchy scoreboard also uses a separate search over
the full request vector, rather than composing the chip's golden lookup.

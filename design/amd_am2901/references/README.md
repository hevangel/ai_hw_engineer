# Independent reference and historical microprogram

## External emulator

Christian Femers' [Am2900ME](https://github.com/MaisiKoleni/Am2900ME)
is pinned to commit `8cf4747cdf3bb2b434359ddc248f230f9f06f81d`.
Six Java source files and the original MIT license are vendored unchanged
under `am2900me/`; `SHA256SUMS` verifies them before each regression.
The compile adapter is project-owned `scripts/Oracle.java`. It accesses the
original package interface without modifying the emulator or using DUT state.

The emulator supplies source selection, ALU data, RAM/Q destinations and shift
pin values/enables. Its status equations are not reliable enough to accept
unchanged: its arithmetic `_G` masks an already-reduced one-bit carry with
`0b1_1110`, and complemented operands also affect its unmasked propagation
division; other logic status differences occur. The observed 98,304 vectors
contain 38,865 status disagreements. The adapter records this count and uses
the manufacturer's original Figure 8 for **all** status expectations, keeping
the original source immutable. A separate formal model checks every status
equation independently using integer arithmetic and a complemented chain.
The external data/destination/shifter comparison has zero discrepancies.

## Actual historical software

`multiply_1975.txt` transcribes the five rows of Figure 21, printed 2-21 /
PDF 29, in AMD's [1978 family book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf).
Its original program is dated **8/5/75**, credited **J.S.** The original's
five source/function/destination words are octal 0034, 0243, 0401, 0411,
0232; in the two shift rows I1 is the complement of Q0. Cn is zero on
the repeated add row and one on the final subtract row. Don't-care fields
are explicitly assigned zero. Figure 20 supplies the adjacent shift wiring;
the highest RAM3 input is F3 XOR OVR and highest Q3 receives whole-word RAM0.

The test loads the original rows as a microstore and independently checks
their numeric words, addresses, carry, exact sequence and pin directions.
It runs the original repeated-add/final-subtract algorithm for a 16-bit word
on four actual DUT slices. Expected intermediate states use full signed
integer arithmetic; final products use host multiplication. This chip has
no program counter: the fixture supplies microaddresses, and the test checks
the exact word driven/executed. It does not claim to verify an Am2909 sequencer.

The board fixture captures the external Q3 shift input while CP is low and
holds it across the rising edge. This enforces the manufacturer's shift-input
setup/hold contract in a zero-delay simulation, where opening RAM read latches
would otherwise change F0 in the same event. The chip RTL remains native;
no forced register state, invented reset, padding, or new software is used.

The source book's hash and page references are in
[the shared cache manifest](../../../references/amd/README.md).

# Independent manufacturer oracle and real microprogram sequences

The external artifact is AMD's original **Figure 6 transition table**,
printed 2-78 / PDF 86, rendered and inspected before RTL. It explicitly
shows every selection with hold, push and pop, and distinguishes current
µPC from selected address. The test's reference uses a top-first four-entry
list: push prepends old PC and displaces the bottom; pop rotates top to
bottom. This is distinct from the hardware's circular memory/pointer and
is derived from the manufacturer's rows, not by reading RTL.

Original software sequence artifacts are **Figures 7 and 8**, printed 2-79 /
PDF 87. They provide actual microword control settings, pipelined execution,
fetched addresses, µPC values and return-stack linkage. Figure 8 includes a
nested subroutine consisting of one instruction. The C++ fixture transcribes
CONTINUE, JSR A/JSR B and RTS from those exact settings; generic intervening
I(address) words have the table's CONTINUE sequence controls. There is no
claim of a recovered complete computer ROM or instruction datapath.

The manufacturer's symbolic addresses are instantiated twice: J=00FE,
A=03FD, B=09FF to cross nibble boundaries, and J=0010, A=0120, B=0800.
Literal executed/fetched address lists remain independent of the state
model. Unused microstore entries are POISON. Every next-executed landing
must identify the exact defined word. The final published fetch ends each
trace without pretending to execute an additional invented program.

Initialization uses ZERO, address-register load and four real stack pushes;
there are no internal forces or fabricated reset. Four fills establish known
stack contents regardless of its initial physical pointer. Visible register/
stack selections and four pop rotations inspect every retained word after
control tests, then a real direct branch restores the counter.

Source: [AMD 1978 family book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf).
The shared [source cache manifest](../../../references/amd/README.md) records
its hash; original figures remain source references and are paraphrased here.

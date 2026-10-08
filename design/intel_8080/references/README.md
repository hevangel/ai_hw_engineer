# Intel 8080 sources and independent verification

## Manufacturer sources

- [Intel September 1975 Microcomputer Systems User's
  Manual](https://bitsavers.trailing-edge.com/components/intel/MCS80/98-153B_Intel_8080_Microcomputer_Systems_Users_Manual_197509.pdf):
  chapter 2, status table 2-1, interrupt/reset/HOLD discussions; chapter 4,
  documented instruction set and EI recognition delay.
- [Intel 8080 Assembly Language Programming Manual, 1975 Rev.
  B](https://altairclone.com/downloads/manuals/8080%20Programmers%20Manual.pdf):
  instruction behavior and chapter 5 interrupt programming.
- [Intel 8080/8085 Assembly Language Programming
  Manual](https://deramp.com/downloads/intel/8080-8085%20Programmers%20Manual.pdf),
  printed 1-12: explicitly distinguishes Intel 8080 AND AC (OR of operand
  bit 3) from 8085 AND AC (always one). Prefer this clarification over the
  inconsistent early logical-instruction descriptions.
- [Intel's 8080
  history](https://www.intel.com/content/www/us/en/newsroom/news/50-years-ago-the-influential-intel-8080.html):
  1974 launch and Altair context.

## Immutable oracle

Reuse the unchanged MIT-licensed [superzazu source already vendored in this
repository](../../amd_am9080/references/superzazu/), at [upstream commit
274ffd700b81baabea99b0963bc1260b67132185](https://github.com/superzazu/8080/tree/274ffd700b81baabea99b0963bc1260b67132185).
`i8080.c` SHA-256 is
`aba87f0e380e607b1971943323c96114305b889c1f76c5db303f5262da73db36`.
Its license is retained alongside it. Scripts verify canonical LF hashes of
both source and header before using the oracle, accepting Git's Windows
CRLF checkout conversion without changing the vendor files. Header SHA-256:
`f78d7461ae649166b189e869c7cfde08347219bd87fac87ff3c6da6c2f0866f6`.
There is no AMD ANA/ANI flag override for this core.
The oracle predates the RTL and supplies exact post-instruction states and
memory/I/O effects. Formal ALU equations also cite its helper functions.

## Original historical software

Download original diagnostic binaries from [Altair Clone's CPU test
archive](https://altairclone.com/downloads/cpu_tests/) into ignored `work/`.
The harness checks these SHA-256 values and never edits program bytes:

| Program | SHA-256 |
|---|---|
| TST8080.COM (Microcosm Associates, 1980) | `9561c6fb6c99efe3de00eb77e4044fd102151058b39ac2d7bce10483838a08e7` |
| 8080PRE.COM | `18eb3c79cba42c0718f160be6a1853cb64cdce7aa47d65780189a57bdd98c4e0` |

Bootstrap and CP/M BDOS emulation are separate harness bytes outside the
diagnostic image. Every retirement, exact next fetch and console output is
checked. The inherited UVM register-save ISR comes from AMD handbook 15-2;
it is compatibility code, not claimed as an Intel-specific historical oracle.

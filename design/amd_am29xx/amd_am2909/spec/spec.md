# Am2909 microprogram sequencer specification

Primary source: AMD 1978 Am2900 Family Data Book, printed 2-74–2-87,
PDF 82–95. Rendered Figures 2, 5–8 establish physical controls, priority,
return linkage and exact original microinstruction sequences.

Four-bit slice with a microprogram counter, separately enabled address
register and four-word circular return stack. There is no reset or guaranteed
power-up initialization. `cp_i` clocks state on LOW-to-HIGH transitions.

| Input | Meaning |
|---|---|
| `select_i[1:0]` | 0=µPC, 1=address register, 2=stack top, 3=direct D |
| `d_i[3:0]` | Direct branch address |
| `r_i[3:0]`, `re_n_i` | Separate address-register data, active-low load enable |
| `or_i[3:0]` | Per-bit address OR after source selection |
| `zero_n_i` | LOW forces all internal Y address bits zero, overriding OR |
| `oe_n_i` | LOW enables external Y; HIGH releases pins |
| `cn_i` | Active-high increment input; LOW repeats the selected address |
| `fe_n_i`, `push_i` | Stack operation enabled LOW; HIGH push / LOW pop |

Internal Y is `(selected | OR)` when ZERO is HIGH, otherwise zero. The
external Y value/enable ports represent tri-state pins; OE does not freeze
the internal counter or other state. Carry-out is the fifth bit of internal
Y+Cn, independent of external output enable. µPC loads Y+Cn on every edge.
Address-register load and stack controls operate independently of selection.

Push increments the two-bit stack pointer, then stores the **pre-edge µPC**
at the new top. It does not store branch Y, Y+1, or the newly loaded µPC.
Pop decrements the pointer; it does not erase the popped memory word. Stack
selection alone holds the pointer and can support looping. Four pushes fill
every physical word regardless of the initial pointer. No underflow/overflow
flag is invented. Values read from unwritten stack words are unspecified.

Figure 6 is the independent next-state oracle. Its top-first four-word view
is implemented by a verification list, distinct from the RTL's circular
memory/pointer. Figures 7 and 8 supply actual historical microprograms and
exact Y/µPC/stack traces, including a nested one-instruction subroutine.

The chip exposes next addresses, not instruction data. Historical software
runs on a three-slice 12-bit sequencer with a real microstore/pipeline fixture.
Every executed and next-fetched microaddress is checked exactly; unused
microstore addresses are poisoned. A wrong landing must fail, not find padding.

Digital behavior is defined for timing-valid input changes. Electrical SRAM
write waveforms and propagation delays are not modeled. No undocumented
semantic assumption is added beyond the rendered manufacturer's transition
table; state initialization occurs through actual external controls.

Source: [manufacturer book](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf).

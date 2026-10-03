# Am2902 look-ahead carry specification

Primary contract: Am2902A in AMD's 1978 Am2900 Family Data Book, printed
2-26/2-27 (PDF 34/35). Its rendered logic diagram and physical pin bubbles
must be consulted; OCR loses the overbars. This implements the documented
digital equation and physical interface without electrical propagation delays.

Inputs `p_n_i[3:0]`, `g_n_i[3:0]` are the four physical **active-low**
propagate/generate groups, ordered least to most significant. `cn_i` is the
carry-in level, matching the active-high Am2901 carry convention. Outputs
`carry_o[2:0]` are the active-high carries into groups 1, 2 and 3. The device
has **three**, not four, carry-output pins. `p_n_o`, `g_n_o` are physical
active-low aggregate propagate/generate for a higher look-ahead level.

For decoded P=~p_n_i and G=~g_n_i, with + as OR and juxtaposition as AND:

```
C1 = G0 + P0 Cn
C2 = G1 + P1 G0 + P1 P0 Cn
C3 = G2 + P2 G1 + P2 P1 G0 + P2 P1 P0 Cn
Ggroup = G3 + P3 G2 + P3 P2 G1 + P3 P2 P1 G0
Pgroup = P3 P2 P1 P0
```

All 512 physical input combinations are defined, including P and G asserted
together. Group outputs do not depend on Cn. A caller can calculate a fourth
carry from aggregate G/P, but this is not an extra manufacturer output pin.
The chip is combinational: no reset, clock, storage, processor software,
power-up state, or undocumented assumptions.

Verify against sequential carry recurrence rather than repeating the expanded
RTL equations. Use actual Am2901 ALUs for a 16-bit arithmetic cascade and
five real Am2902 instances for a two-level 64-bit look-ahead network.

Source: [manufacturer datasheet](https://bitsavers.trailing-edge.com/components/amd/bitslice/1978_The_Am2900_Family_Data_Book.pdf).

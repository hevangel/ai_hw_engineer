# Formal plan: Am3101

Use an `anyconst` four-bit watch address. A separate global-clock history
oracle records only selected writes to that address. Do not initialize DUT
memory or constrain any input. After an observed write, assert inverted
read data when that address is selected and W is HIGH. Writes to other
addresses must leave the watched data intact.

Prove output-valid control decode, selected-write inversion, and deselected
read release independently of memory initialization. `multiclock on` models
level-sensitive storage through clk2fflogic; the oracle records sampled
write windows and is checked only after they close. Cover written/read
nonzero data, subsequent different-address activity, and invalid
deselected-write mode. Run depth-16 BMC, unbounded proof, and reachable covers.

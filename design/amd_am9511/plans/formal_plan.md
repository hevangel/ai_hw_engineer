# Am9511 formal verification boundary

The fixed-unit configuration proves direct addition, subtraction and negation,
reset, iteration bounds and protocol; multiply/divide values are independent
simulation obligations. The transport configuration replaces the three numeric
engines with unconstrained outputs and a two-cycle completion handshake. It
proves the real chip's stack survivors (an independently compiled manufacturer
CSV checker), affected/preserved status fields, byte pushes/rotation, read
latching, busy/status access, reset stack retention and acknowledgment behavior.
This is an interface proof for arbitrary numeric outputs, not a numerical proof
of floating-point or transcendental accuracy. BMC, PDR and cover are required;
43 command-completion covers and six transport covers prevent vacuity.

Full numeric RTL remains present in all simulations and synthesis. High-precision
mathematical references and pinned third-party sources validate numerical values.

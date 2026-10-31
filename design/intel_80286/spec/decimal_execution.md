# Decimal and ASCII adjustment extension

Specification written before RTL. Primary source: Intel 210498-005 Appendix B
B-15 through B-18 and B-36/B-37, linked in the chip README. These instructions
update AX and the documented flags without memory or I/O operand transactions.

Implement 27 DAA, 2F DAS, 37 AAA, 3F AAS, D4 ib AAM and D5 ib AAD. Intel
documents decimal base 0A for the last two. The independent Intel-CPU branch in
[86Box at revision 1db9ae4cc910b0b7e6e9b49995910b0cc19747a0](https://github.com/86Box/86Box/blob/1db9ae4cc910b0b7e6e9b49995910b0cc19747a0/src/cpu/x86_ops_bcd.h)
also supplies explicit arbitrary-base and zero-base behavior; preserve this
as an externally sourced extension rather than inferring it from newer x86.

DAA adjusts the low digit by six if the original AL nibble exceeds nine or AF
is set; its high correction is 60 when original AL exceeds 99 or original CF
is set. DAS subtracts those corrections, with CF additionally retaining a
borrow from the low correction. AH is preserved. Set SF/ZF/PF from final AL,
AF from the low correction and CF as specified; OF is undefined.

AAA/AAS use the same low-digit condition, add/subtract 0106 to/from the entire
AX when adjustment is needed, then clear AL's high nibble. CF=AF indicates
adjustment. The whole-AX carry/borrow is a 286-specific detail explicitly
identified in the pinned independent implementation. Intel's prose describes
AL/AH changes separately, so it alone does not settle these non-BCD edge inputs.
Do not substitute an 8086 implementation. SF/ZF/PF/OF are undefined.

AAD produces AL=(old AL+old AH*base) modulo 256, AH=0. AAM divides unsigned old
AL by the base, returning quotient in AH and remainder in AL. AAM base zero
delivers real-mode #DE, without retirement or AX/DX changes, stacking the
original instruction PC including prefixes. AAD base zero returns old AL with
AH cleared. Both instructions set SF/ZF/PF from final AL; CF/AF/OF are undefined.
Continue A3's deterministic preservation of undefined flags and mask them in
independent comparisons. These choices do not claim defined silicon values.

Verification uses pinned external instruction execution for the complete AL
space and input AF/CF combinations, high-byte wrap/borrow cases, bases 0..255,
valid packed/unpacked decimal arithmetic chains and exact successor execution.
Manufacturer/independent-source directed tests check fault restart and AH
propagation. A separate combinational formal reference is derived from the
pinned external artifact; it is not translated from RTL. Keep all prior
formal, historical-software, lint, synthesis, reset and mutation gates.

ASSUMPTION A7: the pinned independent Intel-CPU implementation resolves
whole-AX carry/borrow at AAA/AAS edge inputs, arbitrary AAM/AAD bases and
zero-base AAM #DE where the primary 286 text is ambiguous or documents only
base 0A. Shared independent vectors and the external-artifact formal reference
check this choice. Historical decimal-software validation and a 286-specific
edge oracle/native evidence remain required before full-chip sign-off; modern
Unicorn agreement alone does not close that gate.

The unchanged IBM AT ROM helper at F000:0543 now validates DAA in actual
firmware hex conversion for all sixteen nibbles, including A..F. The separate
bootstrap/return-frame fixture preserves every BIOS byte and compares all
464 instruction states and both display writes against the external engine.
This strengthens historical DAA evidence; it does not independently validate
the remaining A7 whole-AX/general-base silicon edge behavior or full POST.

# Am9511 implementation plan

1. Transcribe original command and stack-effects tables before implementation.
   Inspect manufacturer scans for ambiguous status, rounding and timing details.
2. Pin and assess an independent emulator and original manufacturer software;
   retain immutable source/license/hashes. Write any manufacturer correction
   adapter independently and enumerate every correction.
3. Implement and verify a shared signed fixed arithmetic datapath, including
   documented minimum-negative and discarded-product-half behavior.
4. Implement native float arithmetic and conversions. Verify normalized input
   edges, full exponent span, overflow/underflow wrapping and conversion widths.
5. Implement synthesizable derived functions with bounded iterative arithmetic.
   Match manufacturer argument bounds and accuracy; document approximation
   architecture without claiming recovery of the original internal microcode.
6. Integrate the sixteen-byte rotating stack, all command-specific survivors,
   status, busy/PAUSE host transactions, END and SVREQ.
7. Run independent comparisons, original software, exact transfer-sequence
   tests, formal BMC/proof/nonvacuous covers, lint and synthesis.
8. Record actual results, limitations and assumption evidence; update the chip
   index/series ledger and draft PR only when all required work passes.

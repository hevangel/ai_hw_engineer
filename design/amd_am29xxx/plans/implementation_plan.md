# Am29xxx series implementation plan

1. Source pass per member: bind the member issue to its own dated source
   (1985 Am29300 handbook and 1988 Am29C300/29300 data book for the
   Am29300 group; the 1986 Am29500 handbook and later 29K family data
   books for the others), transcribe device tables into
   `members/<chip>/references/` before RTL, and record the assumption
   ledger in the member spec.
2. Member order follows system pull, not catalog order: the Am29331
   sequencer is implemented first (member #170). The natural next tranche
   completes the 1985-documented microprogram core: Am29332 ALU (#171),
   Am29334 register file (#172), then the remaining Am29300 support
   devices, then the Am295xx group, and finally the 29K RISC CPU members
   with their real-software regressions.
3. Per-member verification follows the am29331 pattern: external table
   oracle generated from the transcribed CSV, black-box C++ testbench
   over native pins, formal BMC/PDR/cover against the CSV-derived
   reference, synthesis with `check -assert`, and a final report of
   results and limits.
4. Shared subgroups stay distinct contracts: CMOS 29C members share
   bipolar RTL only where the vendor documents identical function; A
   revisions live in one source file with an explicit revision selection
   and separate verification contracts.
5. CPU members (29K, Am292xx) additionally require real historical
   software running against the reconstructed processor before sign-off,
   with an independent-oracle reference model per the repository's
   escaped-defect rules.

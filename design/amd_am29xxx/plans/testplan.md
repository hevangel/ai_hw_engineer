# Am29xxx series test plan

- Series gate: each member must pass its own
  `members/<chip>/scripts/run_all.sh` in the repository toolchain (lint,
  formal BMC/PDR/cover, simulation, synthesis) before its member issue
  records evidence; the series card closes only when every member issue
  passes its own contract.
- Oracle discipline: every member transcribes its manufacturer tables into
  `references/` before RTL; the generator interprets the CSV, never RTL
  cases; `--check-table` guards the committed formal oracle against
  transcription drift (this guard caught a stale-oracle failure during the
  am29331 bring-up).
- Verification boundaries are recorded per member in
  `report/final_report.md`: electrical timing, undefined-state semantics
  and unreproduced behaviors stay outside the contract with an explicit
  assumption ledger entry each.
- CPU members add real-software regressions with independent-oracle
  reference models; support-chip members add datasheet microcode or
  application flows with exact address/step checking where the vendor
  documents them.
- The series index (`design/README.md`), this family's README table and
  `scripts/design_families.json` update with every added member.

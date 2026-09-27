# busicom_141pf keyboard 4003 data polarity inverted

- **Date found:** 2026-09-27
- **Found by:** Lajos Kintli's annotated 141-PF firmware source
  (v1.0.1, `system/busicom_141pf/spec/reference/Busicom-141PF-Calculator_asm_rel-1-0-1.txt`),
  added to the repo by the user — not by any design verification
- **Fixed in:** PR #22 (system/fix-kbd-4003-polarity)
- **Design touched:** system/busicom_141pf (board RTL only)

## What happened

The keyboard 4003 shift register's serial data input was inverted in the
board RTL:

```systemverilog
.cp_i(rom0_port[0]), .data_in_i(~rom0_port[1]), .en_i(1'b1),
```

The `~` flips every bit the firmware shifts into the keyboard matrix
column-select shifter. The firmware's keyboard scan ($0B0) shifts nine
HIGH bits to deactivate columns 1-9, then one LOW bit to select column 0
(active-low selection); with the inversion the shifter holds the exact
complement — column 0 deactivated, columns 1-9 asserted — so the ROM1 row
nibble is sampled against the wrong column. Observed symptom: every key
registered as a scrambled wrong digit (e.g. 7→'5', 4→'7', 1→'8'), varying
run to run because the inversion also corrupts the two-key and
press/release edge cases the firmware guards with.

## How it escaped verification

The inversion dates to the initial board bring-up commit (d97bdfa,
2026-09-02) — it was a guess about the board wiring, never validated. The
board has no self-check for the 4003 polarity: the bring-up tests drove
`keys_mask` directly and asserted the decoded nibble, which exercises the
`kb_scan_o → kb_col` mux but not the serial shift path the firmware
actually uses. The printer 4003s (non-inverted, correct) were validated
against printed output; the keyboard path was validated only against the
developer's own mental model of "active-high select", which the inversion
happened to satisfy in the direct-drive tests.

Kintli's source pins the correct behavior twice:

1. **Hardware doc (§3.1):** "ROM0 bit1 = shifter data (shared for printer
   and keyboard matrix shifter)". Shared data cannot be inverted for one
   consumer and not the other without a hardware inverter that does not
   exist on the board.
2. **Code comments ($064/$065):** "shift high bit into keyboard shifter
   (Clock=1, Data=1)" to *deactivate* columns, "shift one low bit into
   keyboard shifter (select the first column, other columns are high)".
   Active-low selection with non-inverted data. The RTL's `~` produces the
   complement of this documented sequence.

## The fix

One character: remove the `~`.

```systemverilog
.cp_i(rom0_port[0]), .data_in_i(rom0_port[1]), .en_i(1'b1),
```

## Verification

- **Source-vs-binary:** the user-supplied Kintli source was parsed
  (1280 bytes, addresses 0x000-0x4FF) and compared byte-for-byte against
  `src/rom/rom_4001_{0..4}.hex` — **0 mismatches**. The binary the sim
  runs is bit-identical to the annotated source, so the source's comments
  are authoritative for the hardware behavior.
- **Matrix mapping:** the RTL's `keys_mask` bit positions were checked
  against Kintli's §3.2 keyboard matrix table (10 columns × 4 rows, scan
  codes 0x81-0xA0) — the mapping matches exactly (e.g. shifter bit6 /
  ROM1 bit0 = "7" = scan 0x99 = mask bit 24). Only the shift polarity was
  wrong.
- **E2E:** `scripts/check_panel.py` (C1+2+= → 3, etc.) — pending a full
  run; the web-panel E2E on the current branch was too slow to complete
  in-session (sim had not reached the tick-2000 ready gate after 5+
  minutes at ~95% CPU).

## Prevention plan

1. **Pin every `ASSUMPTION:` in board RTL to an external source.** The
   `~` was an undocumented assumption about board wiring. Board-level
   signal polarities that the primary docs do not state explicitly get an
   `ASSUMPTION:` comment and a validation task against the firmware
   source before sign-off (extends the assumption-ledger rule from CPU
   designs to board designs).
2. **Shift-path tests, not just mux tests.** The bring-up tests must drive
   the 4003 through its serial input (CP + data) the way the firmware
   does, not just the parallel `keys_mask`. A test that shifts the $0B0
   sequence (9×HIGH, 1×LOW) and asserts the one-hot position would have
   caught the inversion immediately.
3. **Cross-check shared signals.** When one firmware bit drives two
   consumers (here ROM0 bit1 → keyboard + printer shifters), the RTL must
   use the same polarity for both unless the schematic shows an inverter.
   The printer was correct; the keyboard was not — a review checklist item.

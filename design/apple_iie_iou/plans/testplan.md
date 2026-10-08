# Test Plan — Apple IIe IOU

Plain SV self-checking bench (`tb/tb_top.sv`) + an independent reference
model written from spec.md (TRM tables + frozen-signal expected sequences),
never from the RTL. Same style as `design/apple_iie_mmu/tb/tb_top.sv`:
one `#1` checker block, `cap_*` captures of pre-edge buses, directed tests +
random soak, `TEST PASSED` sentinel line.

## Bench architecture

- **Clock/cycle procedure** `cycle()`: one full PHI_0 cycle. Drives
  `phi0=1` half: sets `q3=0`, `c0xx_n`, `a6`, `ra_sense` = row byte of the
  CPU address `{a8,a7,a5,a4,a3,a2,a1,a0}`; then `phi0=0` half: drives
  `pras_n` 1→0 and captures the IOU `ra_o` row/col bytes for the checker.
  All model updates in the single `#1` block.
- **Reference model**: full mirror of spec §4-§9 — its own 21-bit counter
  with identical update rules, switch latches, keyboard state machine, and
  the display-address functions of spec §7.5. Checked per cycle:
  `ra_o` (row and col), wndw_n, sync_n, clrgat_n, h0, sega/segb/vc, gr,
  ra9_n/ra10_n, s80vid_n; per access: md7/md7_oe, spkr/casso, an0-3,
  kstrb/akd.

## Directed tests

1. **Reset state**: after reset — counter at the A6 stand-in, PG2/HIRES/AN0-3
   cleared, ITEXT/MIX cleared (A4), IOUDIS off, SPKR/CASSO low, KEY clear.
2. **Full-frame text scan** (default mode): run from reset through the first
   TC and one full 262-line frame; every cycle's row/col RA bytes compared to
   the reference display function (text map of §7.5), including the
   start-of-line `+0x68` HBL addresses and the blanked-region free-run;
   WNDW'/HBL/VBL windows and SYNC' pulse positions checked per line; first
   frame = 512 lines (A6) asserted.
3. **Mode matrix**: for each of {text, lores, hires} × {page1, page2} ×
   {80STORE off/on} scan a bounded window of screen lines (via the formal
   anyconst trick is not available in sim — instead preload the reference
   counter and let the DUT catch up, or run targeted windows after waiting
   the required cycles from reset; windows chosen to cover the interleave
   corners: text rows 0/1/8/16/23, hires lines 0/1/8/63/64/191) and compare
   full address + page bits.
4. **Mixed mode**: enable MIXED+HIRES+graphics; check the graphics→text
   region switch at L=160 (gr flag one-state skew included in the reference),
   SEGA/SEGB source switch (VA/VB vs H0/hires-bar), and the text-page
   address bits in the bottom four lines.
5. **Soft-switch writes/readbacks**: every switch off/on write; MD7 readbacks
   of C019-C01F, C07E/C07F; the C008-C00F-read-returns-KEY quirk (A9);
   C05x IOUDIS gating (AN0-2 writes ignored, AN3/DHIRES live);
   IOUDIS on/off; reset clears PG2/HIRES/AN0-3 but the ITEXT/MIX-reset
   difference is asserted directly on the latch (A4).
6. **Speaker/cassette**: read and write accesses to C02x/C03x toggle once;
   accesses outside the range (incl. C040, C060, C080 with LA7=1... LA7=1
   requires driving ra_sense accordingly) do not.
7. **Keyboard flow**: IKSTRB pulse → KSTRB pin pulse 2 cycles later → KEY
   set → C000 read bit 7 = 1 → C010 write clears → C010 read returns AKD
   level; AKD retiming on the pin; auto-repeat: hold IAKD, after 3 CTC14S
   ticks + PAKST edge the KEY flag re-sets without a new IKSTRB; key-up
   clears the delay chain.
8. **CPU address latch**: driven row-phase bus values appear on the latched
   LA bits (white-box) and steer the decode; LA7=1 (address ≥ $C080) makes
   every select dead.
9. **Q3 gating**: a switch write with Q3=1 is ignored; with Q3=0 lands.
10. **Random soak**: 20000+ cycles of random accesses (random address in
    C0xx space, random rw/q3/a6/ra_sense, random vid6/7, random IKSTRB/IAKD
    events) with the reference model checking everything each cycle.

## Sentinels

- `Apple IIe IOU TEST PASSED` on success; nonzero failures abort with the
  first mismatch (address, cycle number, expected vs got).

## Runners

- `scripts/run_sim.sh [seed]`: Verilator `--binary --timing` then xezim
  `--sv2017 --error-exit` with XEZIM_COV_DB; both must print the sentinel.
- `scripts/run_coverage.sh`: xezim code coverage on `tb_top.dut` scope,
  summarized by `scripts/summarize_coverage.py` (JSON via stdin).
- Targets: 100% statement/branch on the RTL; the only expected exclusions
  are the `ifdef FORMAL` blocks.

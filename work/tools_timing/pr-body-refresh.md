## Why

The 4116 model retains data forever, so the board's reliance on the video scan
for refresh was an assumption. Review item **P2** in #60 asked for a
refresh-violation counter that turns it into a checkable property — and calls it
"a genuinely novel verification of the board's video/refresh interlock".

## What

* **`tb/apple_ii_refresh_check.sv`** — watches the RAS/row-address bus (shared by
  all eight banks), records the gap between successive accesses to each row, and
  counts gaps beyond the 4116's 2 ms requirement.
* **`tb_rev0_boot.sv`** instantiates it, **asserts that all 128 rows are
  refreshed** (coverage, so the check cannot pass vacuously) and prints the
  measured margin in the gate log.
* **`scripts/run_refresh_check.sh`** — negative control: the same board with an
  idle CPU socket, where the video scan is the only refresh source. It requires
  ≥1 violation, proving the checker is not stuck at zero.
* Assumption ledgers updated (chip spec + system spec): retention stays ideal,
  refresh coverage is now measured.

## Measured (Icarus 12.0-3, apple-ii image)

| Configuration | Rows refreshed | RAS accesses | Worst same-row gap | Gaps over 2 ms |
|---|---|---|---|---|
| authored Monitor boot, CPU running (183 ms) | 128/128 | 373,928 | **1.9668 ms** | 0 |
| video scan only, CPU socket idle (40 ms) | 128/128 | 81,635 | **2.2215 ms** | 48 |

The 4116 requires every row within 2 ms. With the CPU executing, the board is
inside the limit. With the CPU idle, the video-only path runs **11% past** it,
and every row sits in the 1.85–2.22 ms band, so the overrun is the sweep itself
rather than a few slow rows.

That second line is a **finding, not a pass**: part of the refresh budget is
carried by CPU accesses. The real machine works, so either the device tolerance
is wider than the datasheet figure at room temperature or the model's row
addressing differs from silicon — recorded as an open question rather than
explained away.

## Verification

```
$ sh scripts/run_authored_boot.sh
REFRESH rows=128 accesses=373928 worst_gap=1966751000 violations_over_2ms=0
PASS historical Monitor ... instructions=64393 unknown read samples=4516
PASS historical Monitor video: ... 107520 exact visible pixel samples
EXIT=0

$ sh scripts/run_refresh_check.sh
VIDEO-ONLY rows=128 accesses=81635 worst_gap=2221535000 violations_over_2ms=48
PASS refresh checker reports the video-only margin (negative control)
EXIT=0
```

`scripts/run_reference_boot.sh` (transistor-level CPU through VPI) also compiles
the checker now but was **not run** here.

Refs #60 (P2). Follow-up to #94 and #96.

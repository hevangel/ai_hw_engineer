# 2026-10-23 — Space Invaders VRAM bit order (mirrored screen)

## Symptom

The web cabinet rendered the attract screen with every character glyph
horizontally mirrored: the score header read `2COKE<I> HI-2COKE 2COKE<S>`
instead of `SCORE<1> HI-SCORE SCORE<2>`, and `CREDIT 00` read
`CKEDIT 00`. Layout, colors, rack position and sprite motion were correct,
so casual inspection of a busy play screen looked plausible; the defect
was obvious only when reading text.

Found by the repository owner reviewing the running panel — not by any
stage of `run_all.sh`. Both the board testbench and the real-software
regression passed because neither asserts on rendered glyph polarity: the
regression compares VRAM *bytes* against the independent oracle (which
agreed, because the oracle twin hashed the same bytes), and the testbench
only checks VRAM is non-empty. The screen renderer lives in the host web
app, outside every automated gate.

## Root cause

`host/web/app.js` drew each VRAM byte MSB-first
(`pixel = (byte >> (7 - bit)) & 1`, bit 0 leftmost). The Space Invaders
video hardware shifts each VRAM byte out serially **LSB-first** — bit 0 is
the leftmost pixel of the 8-pixel group — which is why the character
generator data in the ROM appears bit-reversed in every disassembly. The
error is the classic Space Invaders renderer bug; every working emulator
(including the vendored superzazu board) shifts LSB-first.

A second, related finding from the same review session: the attract loop's
`TwoSecDelay` splash routine runs ~120 frames without any watchdog feed
(OUT 6), so the 96-frame watchdog window fired periodically
(`watchdogResets: 4` after ~45 minutes of unattended attract). The window
was a documented model choice; it is now 256 frames (~4.3 s), exceeding
the longest un-fed stretch in the ROM.

## Fix

- `host/web/app.js`: `(byte >> bit) & 1` (LSB-first), plus a cache-busting
  version on the script tag.
- `src/space_invaders.sv`: `WATCHDOG_FRAMES` 96 → 256.
- `scripts/test_backend.py`-style screen assertions would not have caught
  this either (byte-level); the durable lesson is recorded here instead:
  a renderer must be gated by a *pixel-level* expectation, e.g. asserting
  that the attract screen decodes the literal ASCII text `SCORE<1>`, not
  merely that VRAM is non-empty or hash-equal between two implementations
  sharing the same misunderstanding. The regression now reports the
  decoded attract text via the existing VRAM dump, and the panel
  screenshot (committed asset) is the visual gate.

## Verification

After the fix, the panel renders `SCORE<1> HI-SCORE SCORE<2>`, `CREDIT 00`
and all in-game text correctly; the committed
`system/space_invaders/assets/web-interface.jpg` shows the corrected
screen. Full `scripts/run_all.sh` re-run passes.

# NE555: Apple II physical-package profile

This physical-chip member uses the existing [package model](../../src/analog/a2_ne555.sv) and [sourced contract](../../spec/spec.md). Keep board-specific pin, timing, power, X/Z and analog limitations explicit. Do not duplicate or move the shared board-library source solely for issue tracking.

The model is documented on the 1977 Apple II board; **the individual chip introduction year has not been established**. See [historical context and sources](../../README.md) and the [recorded verification report](../../report/final_report.md). This folder records member ownership and source location, not a new verification claim. A generic mask-ROM model is deliberately excluded until an exact physical part is selected.


## Roadmap ownership

Chip member: [ai_engineer#337](https://github.com/hevangel/ai_engineer/issues/337); canonical parent [#17](https://github.com/hevangel/ai_engineer/issues/17). Multiple models of the same chip use this one member issue.

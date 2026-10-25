# 74LS161: Apple II physical-package profile

This physical-chip member uses the existing [package model](../B:\ai_hw_engineer\worktree\chip-family-roadmap\design\apple_ii_chips\src\a2_74ls161.sv) and [sourced contract](../B:\ai_hw_engineer\worktree\chip-family-roadmap\design\apple_ii_chips\spec\spec.md). Keep board-specific pin, timing, power, X/Z and analog limitations explicit. Do not duplicate or move the shared board-library source solely for issue tracking.

The model is documented on the 1977 Apple II board; **the individual chip introduction year has not been established**. See [historical context and sources](../B:\ai_hw_engineer\worktree\chip-family-roadmap\design\apple_ii_chips\README.md) and the [recorded verification report](../B:\ai_hw_engineer\worktree\chip-family-roadmap\design\apple_ii_chips\report\final_report.md). This folder records member ownership and source location, not a new verification claim. A generic mask-ROM model is deliberately excluded until an exact physical part is selected.


## Roadmap ownership

Chip member: [ai_engineer#317](https://github.com/hevangel/ai_engineer/issues/317); canonical parent [#4](https://github.com/hevangel/ai_engineer/issues/4). Multiple models of the same chip use this one member issue.

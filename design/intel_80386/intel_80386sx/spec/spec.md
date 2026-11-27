# Specification: Intel 80386SX profile

## 1. Overview

The 386SX is the 386 architecture behind a 16-bit external data bus and a 24-bit physical address. Architectural behaviour (instruction set, modes, faults, paging) is exactly the shared core's, specified in the [386DX specification](../../intel_80386dx/spec/spec.md). This document covers only what differs.

## 2. Differences from the DX

| Item | 386DX | 386SX |
| --- | --- | --- |
| Data bus | D31–D0, BE3#–BE0# | D15–D0, BHE#/BLE# |
| Address | A31–A2 (4 GB) | A23–A1 (16 MB) |
| Dynamic bus sizing | BS16# selects 16-bit cycles | always 16-bit; no BS16# |
| Coprocessor | 80387 | 80387SX |

## 3. Status

Not implemented. Required evidence before RTL: the Intel 386SX datasheet bus-cycle definitions (T1/T2 states, pipelined addressing, the order in which misaligned and 32-bit transfers are split) and a physical SX or board-level trace. The 386EX captures used for the core are not SX bus evidence.

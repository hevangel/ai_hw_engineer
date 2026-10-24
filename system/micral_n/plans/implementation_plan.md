# Implementation plan

1. Preserve the R2E January 1974 manual PDF and Markdown OCR, Intel 8008 manual PDF and Markdown, and MO5 demo source/binary with provenance.
2. Connect the Intel 8008 RTL to 16 KiB paged memory, accumulator-indexed input groups (R2E II.2.5.2), output latches, and panel substitution/control signals; arbitrate host writes so a POKE stalls the CPU instead of swallowing a store.
3. Recover and integrate the original firmware — the MO5/hxc2001 boot EPROM and MIC-01 monitor ROM, hash-verified against the published checksums — and model the board devices the monitor depends on: the ASR-33 teletype card (group 0 data/status, OUT 8) and the Pile card (byte LIFO on OUT 30 / INP 6).
4. Build a Verilator host that runs instructions, steps bus cycles, observes memory and outputs, accepts commands and teletype input over a private pipe, and captures monitor output.
5. Serve a web console with R2E's panel controls, a teletype pane, and live simulator state; bind to loopback by default.
6. Test the system RTL (MO5 demos, front-panel semantics, monitor boot through the manual's procedure) and the HTTP backend (controls, TRAP, teletype round-trip). Record exact behavior and limitations.

# Implementation plan

1. Preserve the R2E January 1974 manual PDF and Markdown OCR, Intel 8008 manual PDF and Markdown, and MO5 demo source/binary with provenance.
2. Connect the Intel 8008 RTL to 16 KiB paged memory, input groups, output latches, and panel substitution/control signals.
3. Build a Verilator host that runs instructions, steps bus cycles, observes memory and outputs, and accepts commands over a private pipe.
4. Serve a web console with R2E's panel controls and live simulator state.
5. Test the system RTL and the HTTP backend with the MO5 input/output binary. Record exact behavior and limitations.

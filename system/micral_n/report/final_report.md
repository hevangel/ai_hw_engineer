# Micral N verification report

Environment: `ai-hw-engineer:latest`, Verilator 5.052, Python 3, and a browser.

| Check | Result |
|---|---|
| Strict Verilator lint of the integrated 8008 and Micral RTL | Pass, zero warnings |
| MO5 input/output program | Pass: polls input group 5 and writes output port 23 after D7 is set |
| MO5 hello-world program | Pass: copies `HELLO WORLD` to RAM at 0x1000 and halts after 224 instructions |
| HTTP API and persistent Verilator simulator | Pass: STEP, AUTO, P/P, input switch, memory POKE, SUB and INIT |
| Browser front panel | Pass: controls and live CPU, bus and output state exercised in browser |
| JavaScript syntax | Pass: `node --check host/web/app.js` |

The downloaded January 1974 R2E user manual and its Markdown transcription are in `spec/reference/`. The simulator uses the included MO5 demonstration binaries because the recovered MIC-01 boot and monitor ROM bytes were unavailable from the published ROM map. The model covers the CPU, memory, basic I/O groups, and console controls; it does not emulate every optional Micral peripheral card or electrical Pluribus timing.

# Micral N verification report

Environment: `ai-hw-engineer:latest`, Verilator 5.052, Python 3, and a browser.

| Check | Result |
|---|---|
| Strict Verilator lint of the integrated 8008 and Micral RTL | Pass, zero warnings |
| MO5 input/output program | Pass: polls input group 5 and writes output port 23 after D7 is set |
| MO5 hello-world program | Pass: copies `HELLO WORLD` to RAM at 0x1000 and halts after 224 instructions |
| Front-panel semantics at the RTL level (`tb_panel`) | Pass: cycle step advances one byte per clock, every instruction retires within the 8-tick STEP bound, TRAP stops at the configured post-retirement PC, SUB executes a substituted HLT byte, INIT clears PC and counters, and a POKE while running lands without swallowing CPU state |
| Original MIC-01 monitor ROM (`tb_monitor`) | Pass: boots via the manual's front-panel procedure (SUB `44 30 3B`), prints its CR/LF/SP prompt with the software-parity CR (0x8D), echoes command letters with `: `, answers unknown commands with `?`, and cancels `M` on CR — 18 TTY bytes asserted exactly |
| HTTP API and persistent Verilator simulator | Pass: STEP, AUTO, P/P, input switch, memory POKE, SUB, INIT, TRAP, and the teletype round-trip (`/api/tty`); the backend repeats the monitor boot and command flow over HTTP |
| Browser front panel | Pass: controls, live CPU, bus, output, and teletype state exercised in browser (the tool image carries no JavaScript runtime, so panel JS is verified in the browser rather than by a lint step) |

## Review corrections applied (2026-10-23, issue #59)

- The spec described accumulator-indexed input groups the RTL did not implement; the RTL now implements R2E section II.2.5.2 (the accumulator precharges the byte index of group G), which is also what the recovered monitor requires.
- A host write in the same clock as a CPU write silently won; the board now stalls the CPU (`ready` low) for that cycle so a POKE can never swallow a store, proven by the `tb_panel` POKE-while-running check.
- TRAP, SUB, STEP, CYCLE, and INIT were only exercised through the HTTP backend; `tb_panel` covers them at the RTL level.
- The server bound 0.0.0.0; it now binds loopback by default and warns if `MICRAL_HOST` opts out.
- The MO5 assembly source says `OUT 015` / "output #1/5" while the shipped binary drives port 23 (`0x6F`); a note in the source explains the notation mismatch, and the spec states that /17 is hexadecimal.

The downloaded January 1974 R2E user manual and its Markdown transcription are in `spec/reference/`, alongside the recovered original ROM images and their provenance record (`micral_rom_recovery.md`). The model covers the CPU, memory, the teletype and Pile cards, basic input groups, and console controls; it does not emulate the floppy system, the real-time clock / interrupt controller, the Canal card, or electrical Pluribus timing — see the spec's assumptions.

# scelbi_8b implementation plan

Status: implemented.

1. Preserve firmware and documentation provenance: the SCELBAL SC1 binary
   (Mike Willegal's archive, the image SIMH's guide loads), the SCELBAL book
   (language reference, chapter 14), and the 1974 PCC Shooting Stars listing.
2. Board RTL: the repository's Intel 8008 core, 16 KiB RAM, and the
   bit-banger console card per SIMH's SCELBI 8B model — 9 INPs per received
   character (bit 7 forced, data LSB first), 10 OUTs per transmitted
   character, both port variants (INP 2/5, OUT 10/14), and the INP 4 flag
   port. Host writes stall the CPU.
3. Host simulator: private line protocol with a keyboard byte queue
   (backpressured by the board's FIFO-full flag), transmit log, panel
   controls, TRAP, POKE.
4. HTTP console: /api/state, /api/control, /api/tty (keyboard), /api/load
   (types a listing with CR line endings); loopback bind; glass-teletype web
   panel with number keys and the LOAD *STARS* flow.
5. Verification: RTL regressions (calculator session; full Shooting Stars
   play-through) and the HTTP backend test; record results in the report.

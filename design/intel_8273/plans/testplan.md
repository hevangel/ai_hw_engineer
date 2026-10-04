# Verification plan

Directed tests compare every transmitted bit with separately generated HDLC
vectors (Python C CRC oracle), replay independent frames to receive, and compare
data/result ordering. Sweep payload patterns, lengths, NRZ/NRZI, buffered and
unbuffered modes, selective matches/rejects, flag streams, preframe sync,
transparent data, non-DMA interrupts, bus stretching and reset cancellation.
Inject corrupt FCS, abort, idle, modem loss, missed data service, memory limits,
unread results, disabled receive, SDLC EOP and loop turnaround. Exercise a real
8237A moving Tx and Rx information bytes on a two-core bit-serial link.
Compare all wire bits and received bytes at the 65,535-byte information limit.
Exercise receive through the DPLL for every initial oversample phase and periods
31, 32 and 33, with preframe synchronization.

Use Verilator and Xezim for directed/link tests and Xezim for UVM. UVM stimulus
comes from sequences, drivers only implement protocols, monitors publish actual
reads, the scoreboard compares expected bytes, and coverage lives in a collector.
Formal proves state bounds and handshake persistence independently of payload
content; covers show non-vacuous command/result and serial paths. Functional
protocol behavior is primarily verified in simulation, not claimed fully proven.

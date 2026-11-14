# Am29338 digital specification

Primary contract: AMD 1988 *Am29C300/29300 Data Book*, "Am29338 32-Bit
Byte Queue" advance information (PDF 242–263 of
[the bitsavers scan](https://bitsavers.trailing-edge.com/components/amd/bitslice/1988_AMD_32-Bit_Microprogrammable_Products_Am29C300_29300_Data_Book.pdf)):
pin descriptions, functional description, Figures 1–7 and Tables 1–4,
page images inspected.

A 128-byte ring FIFO built from four 32 × 9 RAM slices with stored byte
parity. Up to four bytes queue per QCLK edge (Table 1) and up to sixteen
dequeue per DQCLK edge (Table 2; counts above four serve the horizontally
cascaded four-chip configuration). The input word is byte-reordered per
the BSW pins (Table 3) and disassembled LSB-first; the output window
presents the four bytes following the dequeue pointer LSB-aligned with
their stored parity. Byte counts: CNT0–6, FULL, A-FULL (less than four
bytes of space), EMPTY, A-EMPTY (less than four bytes stored). RESET and
RXMIT are asynchronous, active low; the dequeue pointer takes the
POS-programmed quadrant base (Table 4) at RESET/RXMIT. Parity is even;
PDERR flags bad parity on the bytes about to be queued, PYERR flags
stored-vs-recomputed parity mismatches on the output window.

## Assumption ledger

- ASSUMPTION: RXMIT is modeled as sampled at DQCLK edges (synchronous
  assertion) rather than purely asynchronous — a single always_ff here
  cannot carry two independent asynchronous controls (see the
  implementation note in the RTL). A system pulsing RXMIT relative to
  DQCLK observes the documented retransmit behavior; the purely
  asynchronous assertion timing is outside the digital contract.
- ASSUMPTION: RESET is asynchronous with priority; while RESET stays low
  the reset values are re-assigned at each clock edge, so POS changes
  during reset take effect at the next clock edge, not combinationally.
- ASSUMPTION: the RAM writes are modeled at the clock edges; the
  datasheet writes during QCLK low with pointer updates at the edge
  (byte-stream equivalent).
- ASSUMPTION: queuing into a full queue drops the bytes that do not fit
  (count saturates at 128); dequeuing an empty queue floors the count at
  0 while the dequeue pointer still advances (the cross-chip cascade
  consumes bytes other chips supply). The datasheet documents neither
  overflow nor underflow behavior; both are deterministic model choices.
- ASSUMPTION: CNT0–6 shows the byte count modulo 128 (a full 128-byte
  queue reads as 0 with FULL high); the datasheet's seven-bit CNT cannot
  display 128.
- ASSUMPTION: parity bits travel with their bytes through the input
  rotator (the check runs on the original D/PD lanes per Figure 1);
  stored parity is the input PD bit, so a PDERR byte re-emerges with
  PYERR on the output window.
- ASSUMPTION: the queue-side operation runs while RXMIT is asserted
  (only RESET suppresses it); the datasheet does not state the
  interaction.
- Contents after RESET are invalid (the model retains stale bytes;
  verification masks value checks on never-written cells). Electrical
  timing is outside the contract.

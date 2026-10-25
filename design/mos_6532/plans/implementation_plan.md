# Implementation plan

1. Implement native phase-two falling-edge transfers with split bus enables.
2. Keep RAM outside reset; implement all address aliases and PA/PB readback.
3. Implement N*P+1 timer scheduling, /1 underflow, acknowledgment and restart.
4. Keep edge flag, timer flag and their enables independent.
5. Verify with directed/exhaustive port, RAM and address tests; independently
   calculate timer deadlines using the manufacturer equation.
6. Prove reset, RAM preservation at an arbitrary address, write isolation,
   port latches, timer transitions and interrupt logic. Reach both IRQ sources.
7. Run strict RTL lint, BMC/prove/cover, Verilator and xezim simulation,
   then Yosys synthesis. Record actual results and compatibility limits.

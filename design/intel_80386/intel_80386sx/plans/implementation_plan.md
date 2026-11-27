# Implementation plan: 386SX profile

1. Source the Intel 386SX datasheet (bus-cycle timing, pinout, reset) and record its order number in the spec.
2. Write `intel_80386sx_bus.sv`. It takes the shared core's transaction port and splits each request into one to three 16-bit cycles (misaligned dword = three cycles) with BHE#/BLE#, ADS#, W/R#, D/C#, M/IO#, READY# waits, NA# pipelining, LOCK# and HOLD/HLDA.
3. Add a `intel_80386sx` top module that pairs the core with this bus unit, and a native-pin replay. That replay checks the 16-bit cycle sequence of the EX captures only where the EX and SX are documented to agree, and keeps the disagreements as explicit exclusions.
4. Add formal properties for the bus unit (one ADS# per cycle, byte enables match the address and size, every request completes).
5. Integrate with the IBM PS/2 Model 25 SX / 35 SX system issues.

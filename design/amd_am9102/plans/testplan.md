# Test plan

The pin-level interface uses exhaustive direct stimulus rather than a bus/UVM
transaction abstraction. An independently maintained expected 1024-bit array
follows the manufacturer's stated write/read contract.

- Initialize exclusively through actual writes, with no DUT initialization.
- Exhaust all 1024 addresses, both DIN values and four CS/WE combinations.
  Read the accessed word and all ten one-bit-address neighbors after each
  case to detect address aliasing and deselected-write corruption.
- Toggle DIN twice inside each selected write window, verifying output
  feedthrough and final stored data for every address.
- March C- sequence (ascending/descending read-before-write with complements)
  and full address-parity/complement patterns cover retention and decoding.
- Vary address/data/WE throughout legal standby and read back every word;
  selected standby must be explicitly invalid and still preserve storage.
- Build an actual two-chip 2048-bit bank with decoded CS and shared tri-state
  bus; check every word and both output-disable and non-selected protection.
- A watchdog and exact case counts reject incomplete runs.

# Intel 8237A specification

## Sources and scope

[Intel September 1993 datasheet, order 231466-005](https://www.pcjs.org/documents/datasheets/intel/INTEL_8237A_DMA.pdf), pages 4-10 and Figures 11-14, is the primary reference. The [compatible Intersil 82C37A datasheet](https://www.renesas.com/en/document/dst/82c37a-datasheet), pages 8-9, clarifies memory-to-memory source counts. Additional CMOS register readbacks are excluded.

Implement four channels, the NMOS register map, all four service modes, three legal transfer types, fixed/rotating priority, software requests, masks, polarity, address increment/decrement, automatic reinitialization, memory copy/fill, READY stalls and external EOP.

This single-clock functional reconstruction samples synchronous inputs on `clk` with synchronous active-low `rst_n`. Split input/output ports replace bidirectional pins. No electrical, half-clock, package, metastability or nanosecond timing equivalence is claimed. External address latches, data routing and IBM-PC page registers belong in system wrappers.

## Interface

| Signal | Meaning |
|---|---|
| `cs_n`, `ior_n`, `iow_n`, `reg_addr[3:0]`, `data_i[7:0]` | CPU register bus; one access per selected rising edge when idle/released, HLDA low and exactly one strobe low |
| `data_o[7:0]`, `data_oe` | Register read data, S1 high address byte, or memory-copy destination byte |
| `dreq[3:0]`, `dack[3:0]` | Command-selectable request/acknowledgment polarity |
| `hrq`, `hlda` | Ownership request/grant; re-arbitration waits for HLDA low after release |
| `ready`, `eop_n` | Readiness and external active-low termination |
| `dma_addr[15:0]`, `addr_oe`, `adstb`, `aen` | Convenience full address, drive enable, high-byte strobe, address enable |
| `memr_n`, `memw_n`, `dma_ior_n`, `dma_iow_n` | Active-low memory/peripheral strobes |
| `eop_out_n` | Open-drain equivalent, low during terminal S4 |
| `transfer_valid`, `transfer_channel[1:0]` | Convenience commit indication for one bus half-transfer at a rising edge; not original chip pins |

Normal I/O DMA routes data directly between memory and peripheral. Memory-copy source data enters `data_i`, is latched in Temporary, and leaves `data_o` during destination writes.

## Programming

Offsets 0/1, 2/3, 4/5, 6/7 select address/count of channels 0-3. Successive reads **and** writes share one global low/high-byte flip-flop. Writes update base and current values; reads return current values only.

| Offset | Read | Write |
|---|---|---|
| 8 | Raw normalized hardware/software requests in 7:4, sticky EOP/TC in 3:0; clears low bits | Command |
| 9 | Undefined | Bit 2 sets/clears software request selected by bits 1:0 |
| A | Undefined | Bit 2 sets/clears mask selected by bits 1:0 |
| B | Undefined | Mode selected by bits 1:0 |
| C | Undefined | Clear global byte flip-flop |
| D | Temporary | Master Clear |
| E | Undefined | Clear all masks |
| F | Undefined | Write masks from bits 3:0 |

Command bits 0-7: memory-copy enable, source hold, disable, compressed timing, rotating priority, extended write, active-low DREQ, active-high DACK. Bits 3/5 do not alter memory-copy four-state halves.
Mode bits 3:2: verify / I/O-to-memory / memory-to-I/O / illegal. Bit 4 autoinitializes; bit 5 decrements address. Bits 7:6: demand / single / block / cascade. Illegal types cannot request normal service; cascade ignores type bits.

Reset/Master Clear clears command, request, status, Temporary, byte phase and priority, masks all channels and releases ownership. Hardware reset additionally zeroes otherwise unspecified channel programming; Master Clear preserves it.

## Service and timing

Count N-1 produces N transfers: 0 means one, FFFF means 65536. Normal commits increment/decrement address modulo 65536 and decrement count. Underflow sets sticky status, clears software request, emits EOP and either reloads base registers or masks the channel. External EOP terminates at the current commit and performs the same status/reload/mask actions without underflow.

Hardware requests obey masks; block-mode software requests bypass masks. Fixed priority is 0,1,2,3. Rotation starts at 0; completing/pausing service makes that channel lowest priority. No preemption during service. Register accesses take precedence over starting DMA.

Single releases after one transfer; demand releases when DREQ is inactive after the current transfer, retaining current registers; block continues after DREQ falls until EOP. Cascade asserts HRQ and selected DACK only, ignores READY and changes no registers. It does not drive address, AEN or transfer strobes.

S1 emits high address with ADSTB; S2 starts read; S3 extends read; S4 writes and commits. Extended write begins in S3. Compressed timing skips S3 and asserts both strobes in S4/wait. Sequential normal transfers omit S1 except on low-byte carry/borrow. READY inserts waits; this synchronous contract also holds S4 if READY is withdrawn before commit. Verify ignores READY and keeps all strobes inactive. HLDA must remain high until HRQ falls; outputs/commits are gated by HLDA.

## Memory-to-memory

Program channels 0/1 in block mode and initiate channel 0 software request. Source 0 and destination 1 each use four-state halves with S1; READY may stall either. DACKs remain inactive. Source hold affects address 0 only. Both counts decrement; destination underflow terminates and sets destination status. Source underflow alone emits no EOP/status/mask, but independently reloads source if auto enabled. Equal counts permit both channels to reload. Channel 1 is reserved from independent arbitration while memory-copy is enabled; channels 2/3 remain available.

External EOP in the source half is retained through destination completion and reloads source if enabled. It also terminates/reloads destination. EOP in destination affects destination only. Intel says to apply external EOP in both bus cycles to reload both channels; the enhanced CMOS device differs here.

## Assumption ledger

- **A1:** Undefined reads return zero with output disabled; simultaneous CPU strobes do nothing. This is deterministic wrapper behavior, not silicon readback.
- **A2:** Hardware reset initializes unspecified channel registers; Master Clear preserves them. Program channels before enabling requests.
- **A3:** Source-count behavior follows the compatible Intersil clarification, filling a gap in Intel's short description. Equal/unequal count tests pin this decision; NMOS silicon comparison remains future work.
- **A4:** Source-half external EOP is retained until destination commit, so a byte is not half-copied; source reload remains phase-qualified per Intel. Dedicated phase tests pin this adaptation.
- Inputs must be synchronous and strobes identify individual clock-edge accesses. The convenience commit interface is the authoritative boundary for external functional memory/peripheral BFMs.

Historical firmware and physical-chip comparison are not included in this peripheral sign-off.

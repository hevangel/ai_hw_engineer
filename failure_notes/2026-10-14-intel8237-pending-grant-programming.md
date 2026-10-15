# 8237 dropped CPU programming while waiting for HLDA

Date: 2026-10-14. External oracle: unchanged 1981 IBM BIOS and PC DOS FORMAT.

## Failure and cause

The first drive-B format attempt returned FDC ST1.OR. The I/O trace showed the
BIOS writing DMA mode 4Ah, but the first format-ID DMA cycle still used the
previous transfer direction. Other retries behaved differently depending on
refresh timing. DMA register accesses were accepted only in IDLE/RELEASE;
the GRANT state silently ignored a CPU access even while HLDA was low.

PIT refresh can request the bus during an in-flight CPU I/O cycle. That CPU
cycle still belongs to the CPU and must complete before the bus adapter grants
ownership. Intel's [8237A datasheet](https://www.pcjs.org/documents/datasheets/intel/INTEL_8237A_DMA.pdf),
“DMA OPERATION,” explicitly permits programming in S0 until HLDA arrives.
GRANT is this core's S0. It now accepts CPU reads/writes there.

## Why it escaped

The chip testbench required both HRQ and HLDA low for every programming access.
That unnecessarily strong stimulus restriction excluded the manufacturer's
legal S0 programming window. The standalone scoreboards and formal properties
never tested a CPU mode write racing a real refresh request.

## Regression

The chip test now raises a channel-0 request, delays HLDA, writes channel-2's
mode/address, reads the exact address back, completes refresh, then verifies
the channel-2 transfer direction/address. The CPU access helper permits HRQ
high while requiring HLDA low. The IBM PC aggregate runs the complete DMA
flow and the unchanged formatter with PIT/refresh active.

The software test separately exposed DACK-only read verification, documented
in the [FDC specification](../design/intel_8272/spec/spec.md) as assumption A8.
That change does not activate the DMA core's strobes in VERIFY mode: Intel
requires all those strobes to remain inactive.

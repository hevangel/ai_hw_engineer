# Intel 8088

**First introduced: 1979. Status: complete documented architecture on the shared 8086 execution unit, with a native four-byte byte-fetch BIU, 8-bit bus pins and independent physical-8088 tests.**

Intel introduced the 8088 on **June 1, 1979** per its [Microprocessor Quick Reference Guide](https://www.intel.com/content/www/us/en/newsroom/resources/microprocessor-quick-reference-guide.html). Designed at Intel's Haifa laboratory as a lower-cost variant of the 8086, it keeps the 16-bit architecture and one-megabyte addressing but moves the data path to eight bits and shortens the prefetch queue from six bytes to four with an adapted refill rule ([Intel 8088 overview](https://en.wikipedia.org/wiki/Intel_8088), sourcing the Intel *iAPX 86,88 User's Manual*). As the CPU of the IBM PC 5150 (1981, 4.77 MHz) and XT 5160 it carried x86 into mass use.

`intel_8088_chip` is the shared 8086 execution unit (referenced from [intel_8086](../intel_8086/README.md), never duplicated) behind a native BIU: four-byte queue filled one byte per cycle whenever a byte is free, byte-only bus cycles where every 16-bit transaction is two ascending cycles completing as one transfer, non-multiplexed A8–A15, the reversed IO/M polarity, SS0 on pin 34 in place of BHE/S7, READY waits, and 8086-family HOLD/HLDA and RQ/GT arbitration. Native pins use explicit output enables; electrical delays, original EU clock-for-clock timing and the physical 4.77 MHz environment are outside the RTL contract.

- [Specification, interfaces and assumptions](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Verification plan](plans/verification_plan.md)
- [Results, corrections and limits](report/final_report.md)
- [Original historical software regressions](tb/software/README.md)
- Shared EU evidence: [8086 specification](../intel_8086/spec/spec.md), [encoding ledger](../intel_8086/report/encoding_coverage.md), [physical-chip reference provenance](../intel_8086/references/README.md)

Technical authority: the [Intel 8088/8088-2 datasheet](https://www.limpulsion.fr/upload/docs/80882.PDF) ([mirror](https://www.100y.com.tw/pdf_file/34-INTEL-8088,8088-2.pdf)), the [iAPX 86/88, 186/188 User's Manual — Hardware Reference](https://ardent-tool.com/CPU/docs/Intel/808x/manuals/210912-001.pdf) and the [8086 Family User's Manual, October 1979](https://bitsavers.org/components/intel/8086/9800722-03_The_8086_Family_Users_Manual_Oct79.pdf) for the shared architecture; Ken Shirriff's die-level [8088 prefetch circuitry article](http://www.righto.com/2024/03/8088-prefetch-circuitry.html) for the physical queue. Independent instruction expectations come from the [SingleStepTests/8088](https://github.com/SingleStepTests/8088) corpus captured on a physical AMD D8088 (NMOS, 1982); unchanged Microsoft DEBUG.COM supplies the original-software regression.

Run from the repository root inside the tool image:

```sh
sh design/intel_8086_8088/intel_8088/scripts/run_all.sh
```

The first run downloads pinned, integrity-checked references (physical-8088 vectors and DEBUG.COM) to ignored `work/`. The report distinguishes documented behavior, finite verification evidence and timing/electrical limits; it does not claim exhaustive silicon equivalence.

## Roadmap ownership

Chip member: [ai_engineer#271](https://github.com/hevangel/ai_engineer/issues/271); the family grouping lives in the [family README](../README.md). Multiple models of the same chip use this one member issue; the AMD 8088 alternative is tracked separately as [ai_engineer#220](https://github.com/hevangel/ai_engineer/issues/220).

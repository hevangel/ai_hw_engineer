# Intel 8237A programmable DMA controller

The Intel 8237A transfers data between memory and peripherals using four programmable channels. It takes ownership of the system bus, arbitrates requests, generates addresses/strobes and counts transfers, allowing the CPU to do other work. Channels 0 and 1 can also copy memory or fill a block with one byte.

## Historical context

The **8237 family dates to 1979**: the [Intel 8237/8237-2 datasheet](https://web.cecs.pdx.edu/~mpj/llp/references/Intel-8237-dma.pdf) is catalogued as May 1979 in the [OSDev technical specification index](https://wiki.osdev.org/Technical_Specifications), and the [family history](https://en.wikipedia.org/wiki/Intel_8237) cites Intel's May/June 1979 *Preview* announcement. The exact introduction date of the later **8237A** revision has not been established here; 1979 is the family's year, not a claim that the A revision shipped then. The implemented behavior follows Intel's September 1993 A-revision datasheet.

The family became central to PC-compatible DMA and its programming model persisted in later integrated chipsets. Intel's [ICH4 datasheet, section 5.4](https://www.intel.com/content/dam/www/public/us/en/documents/datasheets/82801db-io-controller-hub-4-datasheet.pdf) still describes two compatible DMA controllers with a cascade channel. Recreating it adds bus ownership, channel arbitration and bulk data movement to this project's existing timer, serial, parallel and interrupt devices.

## Implementation and integration

The core implements the NMOS programming map, shared byte flip-flop, fixed/rotating priority, demand/single/block/cascade, read/write/verify, polarity, masks and software requests, count underflow, automatic reload, external EOP, normal/extended/compressed timing, READY stalls and memory copy/fill.

This is a synchronous functional core with separated data input/output/enable signals, not a package replacement. All inputs must meet the `clk` domain. Memory/peripheral wrappers commit data once at a rising edge with `transfer_valid`; raw strobes may span several cycles. `dma_addr` supplies the full 16-bit convenience address, while S1/ADSTB and `data_o` also expose the high-address multiplexing. Normal I/O data passes directly between memory and the peripheral; only memory copying uses the controller's Temporary register. The system supplies address latches, data routing and page registers when required.

Cascade forwards a selected acknowledgment without driving address, AEN or data strobes. See the specification for reset adaptation, undefined read behavior, memory-source count clarification and EOP phase assumptions.

## Running verification

From the repository root using the existing toolchain image:

```sh
docker run --rm -v "$PWD:/workspace" -w /workspace ai-hw-engineer:latest \
    sh design/intel_8237/scripts/run_all.sh
```

Inside the container, individual scripts accept a formal task or simulation seed:

```sh
sh design/intel_8237/scripts/run_formal.sh all
sh design/intel_8237/scripts/run_sim.sh 1
sh design/intel_8237/scripts/run_coverage.sh
sh design/intel_8237/scripts/run_synth.sh
```

## Documentation

- [Specification and assumption ledger](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Simulation test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Reference provenance](references/README.md)
- [Coverage report](report/coverage_report.md)
- [Final report](report/final_report.md)

Technical source: [Intel 8237A datasheet](https://www.pcjs.org/documents/datasheets/intel/INTEL_8237A_DMA.pdf). The [Intersil compatible-device datasheet](https://www.renesas.com/en/document/dst/82c37a-datasheet) clarifies memory-copy source counts; enhanced CMOS-only register readbacks are excluded. Source material is summarized in original prose; archival Intel material retains its original copyright.

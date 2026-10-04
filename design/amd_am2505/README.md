# AMD Am2505: Booth multiplier slice

**First introduced: 1971.** A contemporary
[September 13, 1971 Electronics report](https://www.worldradiohistory.com/Archive-Electronics/70s/71/Electronics-1971-09-13.pdf)
describes the new Am2505, and designer Clive Ghest explains it in
[Electronics, November 22, 1971, pages 56 onward](https://www.worldradiohistory.com/Archive-Electronics/70s/71/Electronics-1971-11-22.pdf).
An [AMD advertisement on December 6, 1971, page 11](https://www.worldradiohistory.com/Archive-Electronics/70s/71/Electronics-1971-12-06.pdf)
states quantity availability. These establish the year, without guessing
an exact initial-shipment month.

The Am2505 made high-speed signed multiplication available as a small
iterative building block before integrated CPUs had fast multiplier units.
Wider arrays were useful for minicomputers, FFTs, and digital filters. Its
four-by-two label hides important overlap inputs and carry wiring needed
for Booth recoding: it is not simply a modern multiply operator in a package.

This digital recreation follows the original
[AMD 1974 Data Book](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1974_AMD_Data_Book.pdf),
including the manufacturer's multiplier application note. It preserves the
partial-product interface, caller-supplied subtraction correction, separate
carry, signed extension, and both voltage logic polarities. Electrical
timing and floating inputs are outside the model.

- [Specification and wiring contract](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Verification report](report/final_report.md)
- [Series progress](../../plans/amd_historical_series.md)

Run in the repository's `ai-hw-engineer:latest` image:

```sh
sh design/amd_am2505/scripts/run_all.sh
```

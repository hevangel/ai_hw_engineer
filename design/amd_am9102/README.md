# AMD Am9102: 1024-bit static RAM

**First introduced: 1974*** (earliest located dated availability evidence).
AMD's [May 30, 1974 Electronics advertisement](https://www.worldradiohistory.com/Archive-Electronics/70s/74/Electronics-1974-05-30.pdf)
names the Am9102, Am9102A and Am9102B and their speed/standby guarantees.
The exact first shipment may be earlier; a later 1975 date from informal
timelines is inconsistent with this primary evidence.

This NMOS static RAM provided 1024 individually addressed bits from a single
5 V supply. Its tri-state output supported larger memory banks, and retained
low-voltage standby supported battery backup and reduced power. AMD marketed
it as an improved plug-compatible 2102 alternative, marking its expansion
from bipolar logic/memory into MOS memory before its processor era.

The reconstruction follows AMD's [1974 Data Book, pages 5-61 to 5-66](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1974_AMD_Data_Book.pdf).
It preserves asynchronous writes, non-inverting read and write-feedthrough,
tri-state enable and retained standby. A supply-mode input represents voltage
state; it is not an invented chip pin. Electrical speed grades share the
same zero-delay binary core.

- [Specification and standby contract](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Verification report](report/final_report.md)
- [Series progress](../../plans/amd_historical_series.md)

```sh
sh design/amd_am9102/scripts/run_all.sh
```

# AMD Am9300: four-bit shift register

The Am9300 was AMD's first product, a TTL MSI building block for serial and
parallel data handling rather than a CPU. Its JK first stage also supports
feedback counters, hold, and toggle, while all four stages support parallel
loading. It illustrates the discrete datapath components AMD sold before
its microprocessor business.

**First introduced: 1970 (commercial availability); first working silicon
is generally dated to November 1969.** These are different milestones.
AMD's own June 3, 1974 prefatory letter in the [1974 Data Book](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1974_AMD_Data_Book.pdf)
(PDF page 4) dates its original 18-device product-line introduction to
April 1970. This directly supports the commercial year while distinguishing
the broader line launch from first working silicon or individual shipments.
[Thomas Skornia's first-person AMD history](https://archive.computerhistory.org/resources/access/text/2019/01/102721657-05-01-acc.pdf),
chapter VI, describes initial product shipments in March 1970, whereas
the [AMD-sourced timeline reproduced in Strategic Management](https://library.uniq.edu.iq/storage/books/file/Strategic%20A.%20Hitt/166678277829.pdf)
dates the first Am9300 good die to November 1969. The latter timeline says
there were still no sales at fiscal year-end 1970, conflicting with Skornia;
the year is recorded without asserting an exact first-shipment month. The
[Computing History museum overview](https://www.computinghistory.org.uk/det/919/AMD/)
identifies Am9300 as the first AMD product.

The digital behavior follows AMD's original
[1974 Data Book](https://bitsavers.trailing-edge.com/components/amd/_dataBooks/1974_AMD_Data_Book.pdf),
pages 2-33 to 2-38. This reconstruction preserves positive-edge CP,
asynchronous active-low MR, physical K-bar polarity, both load/shift modes,
and the complementary Q3 output. It makes no electrical timing claims.

## Design documents

- [Specification and pin mapping](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Test plan](plans/testplan.md)
- [Formal plan](plans/formal_plan.md)
- [Verification report](report/final_report.md)
- [Series progress](../../plans/amd_historical_series.md)

## Verification

From the repository root, inside `ai-hw-engineer:latest`:

```sh
sh design/amd_am9300/scripts/run_all.sh
```

Individual formal, simulation, and synthesis scripts accept the same
environment. Build products and traces go under ignored `work/`.

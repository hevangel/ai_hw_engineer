# MOS 6581 / 8580 SID

The Sound Interface Device is the Commodore 64's synthesizer: three
oscillators (triangle, sawtooth, pulse, noise and their combinations) with
ring modulation and hard sync, three ADSR envelope generators, a
multimode analog filter and paddle (POT) inputs. Its distinctive filter
and the software techniques it enabled made it one of the best-known
sound chips; the C64 system build depends on it. The 6581 is the original
NMOS part; the 8580 is the later HMOS revision with a different filter,
DACs and combined-waveform behavior.

This design implements the **digital core** of both models in one module
(`MOS8580` parameter): registers, oscillators, noise, envelopes, sync/ring,
OSC3/ENV3/POT reads and the decaying bus latch. The analog pull-down of
combined waveforms enters through a sampled table interface; the DACs,
filter and mixer are a separate analog stage that is not yet implemented.

First-introduced year: **by 1983 for the 6581, exact launch year
unconfirmed; 8580 unconfirmed.** Commodore's
[Commodore 64 Programmer's Reference Guide](https://archive.org/details/c64-programmer-ref),
eighth printing explicitly dated 1983 (copyright 1982), contains the
"6581 Sound Interface Device (SID) Chip Specifications" (appendix O). The
1982 copyright does not date every page of that printing, and this review
located no dated primary document naming the 8580.

The oracle is the unchanged reSIDfp engine pinned from
[MAME's 3rdparty tree](https://github.com/mamedev/mame/tree/41a494b6ef80adc924ccb2bdba1ee69580276e0c/3rdparty/residfp)
(GPL-2.0-or-later, fetched into ignored `work/` for tests only).

- [Specification and assumptions](spec/spec.md)
- [Implementation plan](plans/implementation_plan.md)
- [Measured report and remaining work](report/final_report.md)
- [Source review and preserved disagreements](../../plans/mos_sid_source_review.md)
- [Full chip/system queue](../../plans/mos_historical_series.md)

Run `sh design/mos_6581/scripts/run_all.sh` in the documented tool container.

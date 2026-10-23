# Sources and licensing

The digital-function baseline is adapted from Kevin Coleman's
[sn74xx_sv](https://github.com/birdybro/sn74xx_sv), commit `037825fb35c24ec41f89747d10efcd3102e22060`,
under the [MIT license](LICENSE.sn74xx_sv). The copyright and license notice
are retained here for all derived sources and tests.
Its catalogue was used to freeze the requested numeric range; its previous
validation claims are not used as local evidence. All code and tests are
included locally; builds do not fetch dependencies from that repository.

Manufacturer datasheet URLs appear in [the manifest](../manifest.json) and
[per-part specifications](../spec/chips/). TI's
[1985 TTL Data Book volume 2](https://archive.org/details/bitsavers_tidataBookVol2_45945352)
provides independent classic truth/transition tables. Its scan/OCR is a research
cache, not redistributed library content. Additional family-specific sources
are linked where the original TTL function differs from later families.

The original 74181 is retained with its original local TI/Fairchild datasheets
and its own historical documentation; the upstream simplified ALU is not used.

## Extension above 74299

The same pinned catalog supplies numbered larger-footprint and wide-bus entries,
without a numeric upper limit. `catalog_scope.json` freezes selection and allowed
analog exclusions. Reference missing/blocked status is preserved as pending,
with rejected placeholders and omitted boundary-scan functions added to that list.
This is implementation provenance, not independent functional validation.

Independent primary references consulted for the extension include TI
[SN74HC595](https://www.ti.com/lit/ds/symlink/sn74hc595.pdf),
[SN74LS390](https://www.ti.com/lit/ds/symlink/sn74ls390.pdf) and
[SN74HC393](https://www.ti.com/lit/ds/symlink/sn74hc393.pdf).
Their publication dates do not establish initial product launch dates.

Some extended models remain normalized approximations, including DRAM control,
rate multiplication and bus protocol adapters. The error-correction models use
an explicitly documented extended-Hamming matrix; they do not reproduce the
manufacturer's check-bit pin matrix. Passing those tests is not native conformance.

## Source-reviewed continuation

Continuation models record `source_review` in the manifest: primary artifact URL,
PDF SHA-256, exact table/diagram pages and review date. Their per-part notes
identify the manufacturer family, signal mapping and unresolved assumptions.
Reviewed sources include TI universal bus-driver/transceiver and DIMM tables,
GTL/GTLP control tables, passive-switch connectivity diagrams, and CD74HC4059
preset equations plus LE-to-Q timing entries. A primary artifact may be an
unaltered manufacturer document preserved by an archival host.

Analog-only exclusions added during review require a manufacturer description or
schematic establishing an electrical network without a digital function. They
also update the frozen exclusion map. Missing digital functionality stays pending.
Datasheet publication dates continue to be recorded separately from unknown launch
dates. Catalog membership is pinned; it is not a claim that every possible
manufacturer-specific 74-series ordering suffix is represented.

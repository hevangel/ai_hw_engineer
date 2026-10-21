# Sources and licensing

The digital-function baseline is adapted from Kevin Coleman's
[sn74xx_sv](https://github.com/birdybro/sn74xx_sv), commit `037825fb35c24ec41f89747d10efcd3102e22060`,
under the [MIT license](LICENSE.sn74xx_sv). The copyright and license notice
are retained here and SPDX headers identify derived sources and tests.
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

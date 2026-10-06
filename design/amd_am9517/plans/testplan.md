# Am9517 test plan

Retain broad register/global-byte-pointer, all service/type/timing/polarity,
fixed/rotating contention, READY waits, address rollover, auto reload, EOP,
copy/fill and full65536-transfer tests from the reusable peripheral environment.
Change expectations from the original AMD primary source, never by reading the
new RTL. Add grant-time reprioritization, programming while HREQ awaits HACK,
hardware-only status, original illegal-E adapter, software-only memory-copy,
immediate asynchronous reset and real two-controller cascade.

Run original STUP/SDMA published objects unchanged on Am9080A; compare each
retirement and next fetch to the pinned independent Superzazu ISS. Document the
AMD ANA flag adapter against manufacturer semantics. Check DMA memory/peripheral
streams separately and exact caller PC after inline parameters, with no padding.
All assumptions require recorded source and software/integration evidence.

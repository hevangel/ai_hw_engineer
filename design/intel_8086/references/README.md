# Independent reference provenance

Instruction vectors: [SingleStepTests/8086](https://github.com/SingleStepTests/8086), immutable commit `e71c68d215a6bb8c356bd4cb3842de3bef345ca9`, all 323 `v1/*.json.gz` files and `v1/metadata.json`. Daniel Balsom generated the tests with ArduinoX86/MartyPC and a physical Intel P80C86A-2. The MIT license and README are retained in ignored `work/reference/`.

Each object is checked against its Git blob SHA from the pinned complete Git tree before conversion; a SHA-256 manifest is also retained. Expected values come from silicon, not an RTL-derived ISS. The converter expands captured memory/I/O writes into ordered bytes using ALE, BHE and T3 data, and applies the upstream masks to undefined flags only. It reports every exclusion. See the generated [selection counts](../report/vector_coverage.json) and [encoding ledger](../report/encoding_coverage.md).

The upstream README says all code fetched after the tested instruction is 90h, and recommends injecting the captured initial queue. Native corpus mode reproduces these external test-fixture conditions, including cases where a CODE fetch and data read at one address return different values. This policy is confined to corpus mode. Unified-memory native tests and unchanged historical software separately exercise realistic queue/coherency behavior. No original instruction cycle-count identity is inferred from state/write agreement.

Manufacturer authorities:

- Intel, [8086 Family User's Manual](https://www.inf.pucrs.br/~calazans/undergrad/orgcomp_EC/mat_microproc/intel-8086_family_Users_Manual.pdf), October 1979, 9800722-03; chapters 2 and 4, including figure 2-63. [Bitsavers archive](https://bitsavers.org/components/intel/8086/9800722-03_The_8086_Family_Users_Manual_Oct79.pdf). Local copy: [PDF](../../../references/intel_8086_family_users_manual_1979.pdf).
- Intel, [8086 datasheet](https://www.inf.pucrs.br/calazans/undergrad/orgcomp_EC/mat_microproc/intel-8086_datasheet.pdf); pin tables, READY/status timing, INTA floating/BHE and four RQ/GT arbitration conditions.
- Intel, [80386 compatibility notes](https://www.scs.stanford.edu/05au-cs240c/lab/i386/s14_07.htm), item 7, independently describing original segment-offset word wrap.

Original die/microcode research by Ken Shirriff resolves behavior beyond terse instruction descriptions:

- [Interrupt entry](https://www.righto.com/2023/02/8086-interrupt.html): vector reads precede stack writes.
- [String instructions](https://www.righto.com/2023/04/8086-microcode-string-operations.html): interrupted REP backs the corrected PC up by two, losing earlier prefixes.
- [Undocumented instructions](https://www.righto.com/2023/07/undocumented-8086-instructions.html): explains why POP CS is undocumented despite the external corpus metadata calling 0F normal. Undefined behavior remains outside the documented contract.

Original historical software and its license/hash are described in [the software provenance](../tb/software/README.md). Manufacturer scans and downloaded binaries are linked/cached, not redistributed as new repository sources.

# Numbered 74-series digital library specification

## Scope

Implement the distinct numbered digital functions from 7400 upward, without a numeric upper limit,
including explicitly different classic family functions (for example 7451 and
74LS51). The user extended the range above 74299 on 2026-10-20 and excluded analog/timing
variants. Exclude 7431 delay elements, 74121/122/123/130/221 monostables and 74124
VCOs. Keep digital counters, dividers and the digital 74297 filter in scope.
Do not create devices for unassigned numbers. Schmitt inputs receive ideal
digital levels; hysteresis, voltage, current, fan-out and propagation delays are
outside this functional library.

## Interfaces and abstraction

One module per source file. `ttl_74xNN` denotes a generic digital function;
explicit family differences retain their letters. Aliases are listed in the
manifest. Datasheet active-low signals use `_n`; native asynchronous controls,
falling clock edges and transparent storage are device-specific.

Every part's interface and initial behavioral contract is recorded in
`chips/<module>.md`. Baseline adaptations must be reviewed against manufacturer
data. A clocked adapter, masked output or unspecified power-up content must not
be described as a native pin model. Some supplied models use normalized
functional interfaces; the per-part document is part of the interface contract.
Explicit output-drive enables represent high impedance for split digital buses.
Open-collector values represent the logical level with a pull-up; zero sinks,
one releases. Wiring multiple OC outputs requires an AND at the board boundary.

## Sources and provenance

The inventory and MIT-licensed RTL/test baseline are pinned in
`../references/provenance.json`. Manufacturer datasheet links are in
`../manifest.json`; the per-part notes describe the implemented functions.
TI's [1985 TTL Data Book, volume 2](https://archive.org/details/bitsavers_tidataBookVol2_45945352)
provides independent truth/transition tables for the classic TTL devices.
The imported library's prior pass claims are not validation results for this
repository. Current runs are recorded separately under `../report/`.

## Assumptions

- ASSUMPTION: Inputs obey digital setup/hold requirements. Analog metastability
  and hazards are outside this model; logical control behavior remains in scope.
- ASSUMPTION: Unless a datasheet fixes power-up contents, storage is unspecified
  until initialized through its normal controls. ROM contents require an image.
- ASSUMPTION: Physical voltage/drive variations share a model only when their
  truth and transition functions agree. Distinct family functions remain separate.

## Verification contract

The manifest drives fail-fast per-part lint, simulation and synthesis. An entry
must have source, specification and executable checks, with explicit exclusion
status for analog/timing-only parts. Aggregate commands verify inventory
integrity before invoking tools. New formal control checks include cover tasks;
the existing 74181 exhaustive/UVM/prove/cover flow is retained independently.

## Extended catalog coverage

`../catalog_scope.json` freezes every selected part, including pending entries.
`status: pending` means no usable implementation is supplied. A pending entry is
not an analog exclusion, and tool success on other parts does not complete it.
Each model records its interface abstraction in `model_level`; its local contract is
specified separately from package timing. Baseline tests alone do not establish
full manufacturer-table conformance. All absent or rejected implementations stay
in the public index with their reason. The full completion gate fails while any
digital part remains pending.

## Source-reviewed continuation

New control-heavy models record primary PDF SHA-256, URL and table pages in
`source_review`. Digital behavior includes logical asynchronous controls, native
capture-edge polarity, independent banks and weak/passive bus connectivity where
specified. Analog receiver thresholds may be replaced with classified digital
inputs; that boundary is explicit in each specification. Absence of analog timing
does not justify removing a native logical control.

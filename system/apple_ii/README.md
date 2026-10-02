# Apple II revision-0 reconstruction

The Apple II first shipped in **1977**, as recorded by the
[Computer History Museum](https://www.computerhistory.org/tdih/june/10/).
This system reconstructs the revision-0 motherboard's IC package functions
and numbered pin connections. The
[Apple II Reference Manual](https://apple2history.org/dl/Apple_II_Redbook.pdf)
anchors the circuit and memory-selection wiring.

The reference system instantiates **83 IC packages**: 24 individual 4116s,
six ROM sockets, a 2513 character generator, TTL/bus-interface packages,
555 and NE558 timers, a 741 amplifier, and either the authored NMOS 6502
or an independent simulation-only transistor reference. All digital shared-memory
transactions pass through the wired buffers, address multiplexers, strobes,
and data latches.

The original Monitor boots, clears its screen through physical keyboard
input, and accepts `300:A5 5A`, then `300.301`. The regression checks the
deposited bytes, CPU-bus readback, printed text, and every visible serial
video pixel in a complete frame. Nine further full frames cover text
attributes/pages, lores, hires, mixed-mode boundaries, blanking, and sync.
The project's authored [6502 core](../../design/mos_6502/) now runs the same
Monitor, display and cassette-byte regressions on this motherboard. The
transistor reference remains an independent comparison option.

## Run

```sh
# From repository root, after building the main tools image:
docker build -f system/apple_ii/Dockerfile -t ai-hw-engineer-apple-ii .
docker run --rm -v "$PWD:/work" -w /work/system/apple_ii \
    ai-hw-engineer-apple-ii sh scripts/run_all.sh
```

The optional CPU/ROM artifacts are fetched to ignored `work/` with pinned
revisions and SHA-256 checks. See [dependency ownership and licenses](board/DEPENDENCIES.md)
before using the external reference. The solver is MIT; its transistor
netlist is CC BY-NC-SA 3.0. The historical ROM is not relicensed by this project.

`run_all.sh` runs actual firmware, then deliberately reports incomplete
system sign-off: exact analog reconstruction and original-dump font comparison
remain outstanding. The authored CPU documented-instruction gate passes.
Individual regressions have separate passing scripts. The motherboard uses
Icarus; package tests use Xezim.
The retained Xezim board regression currently exposes a resolved-bus failure.

## Documents

- [System specification](spec/spec.md)
- [Chip inventory](spec/chip_inventory.md)
- [Analog boundary and assumptions](spec/analog.md)
- [Cassette byte-routine contract](spec/cassette.md)
- [Connectivity provenance and corrections](board/README.md)
- [Implementation plan](plans/implementation_plan.md)
- [Verification evidence and remaining work](report/final_report.md)
- [Supporting package library](../../design/apple_ii_chips/README.md)

## Digital video evidence

Run `sh scripts/run_video_sim.sh` for the nine diagnostic frames, or
`sh scripts/run_reference_boot.sh` for the historical Monitor display.
Both require Icarus and the pinned external font/firmware cache described above.
The generated `work/video_0.png` through `work/video_8.png` and
`work/monitor_video.png` contain observed B10 output samples. They are decoded
monochrome rasters, not an analog composite-voltage or color simulation.
The scripts also retain raw CSV captures and require exact pixel comparisons.

Revision 0 ignores the high bit of hires bytes; it has no later-board half-dot
delay. The [video specification](spec/spec.md#digital-video-acceptance-contract)
identifies the original schematic and circuit-analysis sources for that behavior.
The Monitor clear uses ESC then `$40` (`@`, physical Shift-P), rather than a
modern uppercase P keycode.

## Cassette evidence

Run `sh scripts/run_cassette_sim.sh` for the original F8 WRITE body and
RDBYTE routines, entered with `D000G` through the Monitor and keyboard pins.
Only the D0 socket holds the project-authored exerciser. Both input polarities
must produce the six test bytes and checksum, followed by actual DRAM readback.
Physical J13 output edges must match exact firmware cycle counts and byte
order. The cassette jack exposes R18/R19 divider voltage with explicit
configurable TTL-level and recorder-load assumptions. Raw edge and input
captures are retained in `work/`. The standard leader and full READ command,
including sync acquisition and checksum/error handling, remain extended work.

## Authored CPU option

Run `sh scripts/run_authored_boot.sh` and `sh scripts/run_authored_cassette.sh`
to execute firmware using `apple_ii_rev0_authored` and its 40-pin H7 adapter.
The same motherboard, physical RAM path, analog support and test stimuli are
used. These runs do not load the external CPU VPI module. `run_all.sh` includes
both authored and reference firmware options; whole-system analog sign-off
remains incomplete as described in the report.

# Apple II physical-package simulation library

## Contract

Ports named p1, p2, ... are physical DIP pin numbers. No additional reset
or clock is introduced into a device. Sequential devices use their actual
asynchronous clear/preset inputs. Uninitialized storage remains X.
Shared outputs use resolved four-state nets and drive Z when disabled.
Power pins are explicit: invalid digital supply levels corrupt outputs to X.
Negative-voltage and analog supplies require a separate analog boundary.

The reference target is the original Apple II revision-0 motherboard.
TTL equations and package pinouts follow Texas Instruments' device data
sheets; the board connectivity is recorded separately from the
package functions and requires comparison against the original schematics. LS, standard TTL, and Schottky variants share
logical functions only where their data sheets agree.

## Sources

- [Apple reference manual and schematics](https://apple2history.org/dl/Apple_II_Redbook.pdf)
- [TI 1976 TTL Data Book, 2nd edition (Bitsavers scan)](https://bitsavers.trailing-edge.com/components/ti/_dataBooks/1976_TI_The_TTL_Data_Book_2ed/)
- [Local TI 74-series TTL Data Book copy](../../../references/1976_TI_The_TTL_Data_Book_2ed.pdf)
- [TI 74LS51](https://www.ti.com/lit/ds/symlink/sn74ls51.pdf)
- [TI 74LS195A](https://www.ti.com.cn/cn/lit/gpn/SN54LS195A)
- [Revision-0 connectivity transcription](https://github.com/reifsnyderb/Apple-II-R0/tree/db72624ab23c02f782235bb4420d91695dc17d4e)

## Assumption ledger and limits

- ASSUMPTION: functional TTL outputs use zero propagation delay by default;
  T_PD can supply a uniform delay for experiments. This is not a characterized
  timing model, and neither maximum clock rate nor analog fidelity is claimed.
- ASSUMPTION: supply pins use ideal digital power-good levels (one means
  present for positive and negative rails; ground remains zero). Supply ramp,
  current, temperature, fan-out, and ground bounce are outside this library.
- ASSUMPTION: DRAM storage does not decay. RAS-only refresh is accepted but
  retention deadlines are not modeled. Power-up contents remain unknown.
- Floating TTL inputs are not silently coerced high inside device models.
  Any board-level pull-up or floating-input approximation must be explicit.
- These support devices are simulation models. Full-board correctness still
  requires original schematics comparison, real ROM execution, waveform
  checks, and a complete CPU. Passing a package test is not system sign-off.

Analog package contracts are in [analog.md](analog.md). Optional output delay
`T_PD` is an integer count of nanoseconds under the model's 1 ns timescale.

The package tests leave `T_PD` at zero. The motherboard generator reads
[board/timing.json](../../../system/apple_ii/board/timing.json), which records,
for every part, the manufacturer document, printed page and URL that publish
its delay (the literature number where the scan prints one), and can build the
board with typical (`--timing typ`) or published maximum (`--timing max`)
delays. Its checked-in default remains the earlier uniform 5 ns TTL/ROM and
20 ns DRAM placeholder until the directed testbenches are retimed; memory
delays stay idealized because the 4116 model has no row-access or refresh
behaviour. These are model options, not a claim of characterized timing.

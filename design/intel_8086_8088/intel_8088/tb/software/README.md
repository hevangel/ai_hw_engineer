# Original historical software regressions

The Intel 8088 executes the identical instruction set as the Intel 8086
through the same shared execution-unit RTL, so this member runs the 8086
member's original-software fixture through the 8088 chip's native byte bus:

- `startup.S` is referenced from `../../intel_8086/tb/software/startup.S`;
  it assembles the Intel 1979 figure 2-63 example program. The 8088 runner
  checks every exact instruction boundary and the final architectural state
  in both native bus modes.
- `scripts/prepare_software.py` downloads the unchanged Microsoft MS-DOS 1.25
  `DEBUG.COM` (pinned commit, SHA-256 verified) into the ignored `work/`
  directory. The external DOS service fixture lives in `../tb_dos.hpp` and
  runs the unchanged debugger entirely in RTL with trap-based single stepping;
  the transcript assertions check exact register dumps and the `IP=0105`
  single-step boundary.

Run both regressions with:

```sh
sh design/intel_8086_8088/intel_8088/scripts/run_software.sh
```

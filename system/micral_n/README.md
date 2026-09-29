# Micral N virtual system

R2E introduced the Intel 8008-based Micral N in **1973**. Its modular Pluribus design supported configurable memory and I/O cards; the optional front console was intended for development and service. This reconstruction wires the repository's 8008 CPU into a 16 KiB system memory, I/O input groups and output latches, and a browser front panel.

## Run

From the repository root, using the project's tool image:

```sh
docker run --rm -p 127.0.0.1:8082:8080 -v "$PWD:/work" -w /work \
  ai-hw-engineer:latest sh system/micral_n/scripts/run_system.sh
```

Open <http://localhost:8082/>. The included MO5 I/O exercise polls input group 5. Toggle input bit **D7** on the panel, then press **AUTO**; the output port value changes as the simulated CPU executes. **P/P** pauses, **AV / STEP** advances an instruction or cycle, **TRAP** stops at a chosen PC, **SUB** supplies the data-switch byte in place of memory reads, and **INIT** resets the CPU. These controls follow section VI of the R2E manual. The panel shows live address, data, cycle, PC, accumulator, flags, output latches, and a memory window.

Run the automated system test with `sh system/micral_n/scripts/run_sim.sh` in the same image.

## References

- [R2E Micral N User Manual, January 1974 (original PDF)](spec/reference/MICRAL_N_Users_Manual_Jan74.pdf), [searchable Markdown OCR](spec/reference/MICRAL_N_Users_Manual_Jan74.md), and [source OCR text](spec/reference/MICRAL_N_Users_Manual_Jan74_ocr.txt). [PDF archive](https://www.mirrorservice.org/sites/www.bitsavers.org/pdf/r2e/MICRAL_N_Users_Manual_Jan74.pdf); [OCR archive](https://archive.org/download/bitsavers_r2eMICRALN_19057147/MICRAL_N_Users_Manual_Jan74_djvu.txt).
- [Intel 8008 manual and Markdown transcription](../../design/intel_8008/README.md).
- [MO5's Micral N I/O exercise source](spec/reference/mo5_input_output.asm) and [binary](src/rom/mo5_input_output.bin) from [MO5's virtual Micral N project](https://github.com/Asso-MO5/virtual_micral_n/tree/main/data). The default image is a modern demonstration, not the original R2E monitor.
- [Restored Micral N ROM map and checksums](https://hxc2001.pages-perso.free.fr/micral-n/index.html). The original boot and monitor ROM bytes were not available from that page, so the platform does not claim to run them.

See the [system specification](spec/spec.md), [implementation plan](plans/implementation_plan.md), and [test report](report/final_report.md) for the exact modeled behavior and limitations.

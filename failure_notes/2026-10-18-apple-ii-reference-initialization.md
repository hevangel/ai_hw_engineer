# Apple II optional CPU reference startup initialization

## Observation and external oracle

During the October 18, 2026 integration, the previously retained original
Monitor regression crashed in the VPI CPU reference before boot. An
AddressSanitizer build identified a heap-buffer-overflow in `group_clear`
while the first `setNode` initialized reset. The same startup/reset-vector
case passes after the allocation fix, including under AddressSanitizer.

## Root cause and escaped assumption

The pinned [perfect6502 solver](https://github.com/mist64/perfect6502/blob/09fc542877a84318291aa42dab143a3e2c3db974/netlist_sim.c)
allocates `state_t` with `malloc` and never initializes `groupcount` before
`group_clear` reads it. Correct behavior depended on allocator contents.
The standalone transistor pin tests passed with the original allocator state;
loading the same solver through VPI exposed the invalid initial count.
Hash pinning guarantees reproducibility of source bytes, not defined memory
initialization or correctness of an external oracle.

## Fix and verification

The fetcher still verifies and retains the original source bytes unchanged.
It requires exactly one matching state allocation and writes a separate
`work/reference/netlist_sim_initialized.c`, replacing only that allocation
with `calloc(1, sizeof(state_t))`. All reference users compile this derived
copy. No transistor data, instruction behavior, bus comparisons or assertions
are changed. The downloaded artifacts retain their original licenses.

The new VPI startup test checks both reset-vector reads and the exact first
fetch at FF59. It passes normally and with AddressSanitizer (leak checking
is disabled for the process-lifetime reference instance). The initialized
solver also passes all 648 transistor pin scenarios / 116,501 compared cycles.
Historical Monitor boot/full raster and both cassette input polarities also pass with the initialized reference. They remain required by `run_all.sh`.

## Prevention

Run `run_reference_smoke.sh` before the longer firmware tests. Keep allocation
fixes explicit and derived, preserve original checksum checks, and record any
change to an independent reference separately from CPU RTL behavior.

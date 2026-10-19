# Model 30 application workloads

`primes.bas` is a new workload for the unchanged IBM BASICA 3.30 interpreter
from the hash-pinned original DOS disk. It is not historical application
source. All variables use BASIC software floating point; no 8087 is present.
The program sieves primes through 1000. A separate Python trial-division
oracle requires 168 primes with sum 76,127. The regression saves the
interpreter's tokenized program through DOS to C:, discards its in-memory
program, clears prior output, reloads the disk file and requires the same
result again. It also checks INT(SQR(2)*1000000) = 1,414,213.

The same regression executes unchanged EDLIN.COM to create and edit a text
file. An independent FAT16 reader checks exact CR/LF/1Ah bytes and the .BAK
original. COMMAND.COM reads the resulting file through TYPE. Only physical
keyboard scan codes and external media enter the running machine; no CPU
register or BIOS/DOS service hooks are used.

Run `python3 system/ibm_ps2_model30/scripts/test_real_software.py` after
`test_harddisk.py` has installed DOS and produced its battery-clock image.
The test clones those guest-generated images under ignored `work/`; it
preserves the front panel's live disk and clock. The full `run_all.sh` calls
these scripts in that order. Binary hashes and command authorities are in
the [reference manifest](../../spec/reference/README.md).

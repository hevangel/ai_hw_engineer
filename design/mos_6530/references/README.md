# KIM-1 original mask-ROM references

These two 1024-byte images are original MOS Technology firmware, not new
project-authored programs. MOS's manufacturer manual Appendix I contains
the program listing (revision D dated October 18, 1975). Their copyright
remains with the original rights holders; no new license for the original
firmware is asserted. All newly authored RTL/tests are separate.

Retrieved 2026-10-19 from the [Commodore archive](https://www.zimmers.net/anonftp/pub/cbm/src/kim-1/index.html):

| Mask | Binary source | SHA-256 |
|---|---|---|
| 6530-002 | [6530-002.bin](https://www.zimmers.net/anonftp/pub/cbm/src/kim-1/6530-002.bin) | `79c6dbd54aa3911f53c1068c4310aabceb7a6ce9714d1c402b73af76ea109237` |
| 6530-003 | [6530-003.bin](https://www.zimmers.net/anonftp/pub/cbm/src/kim-1/6530-003.bin) | `80f5c6393e0bbcfc8a5b68fd73858da34e6d6a415f32d4820f21edb52fecafec` |

The bytewise `.hex` files preserve those exact binary bytes. Run
`python3 scripts/make_roms.py --check` in the design to validate lengths,
hashes and packed constant generation. The separate source/listing at that
archive and the [manufacturer manual transcription](https://kim-1.com/usrman.htm)
pin addresses: 002 is the monitor at 1C00, 003 the cassette extension at
1800. The archive's informal lower/upper labels are reversed relative to
those addresses; mask identity and the actual bytes take precedence.

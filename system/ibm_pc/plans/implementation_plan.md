# IBM PC implementation plan

1. Pin IBM technical references, original BIOS/BASIC/CGA ROMs and PC DOS disk;
   verify artifact hashes and implement reproducible converters.
2. Build the byte bus/four-byte queue adapter and motherboard decode, memory,
   PIC/PIT/PPI/DMA wiring, keyboard and CGA register interface in RTL.
3. Connect the existing FDC to a diskette media responder and DMA channel 2.
   Boot original BIOS and PC DOS with no instruction/interrupt emulation.
4. Add persistent simulation protocol, HTTP server, CGA display and original
   keyboard front panel. Verify actual software through that public interface.
5. Run lint, directed board checks, formal/structural checks, historical
   software and browser/backend regressions. Record escaped defects, actual
   evidence, assumptions and limits. Update system/chip documentation as needed,
   then commit, push and open a reviewable system PR.

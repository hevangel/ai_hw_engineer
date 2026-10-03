# Source provenance

* [intel_8275.pdf](intel_8275.pdf): Intel 8275 AFN-00224B, catalog pages 8-223–8-246, 24 scanned pages. Downloaded 2026-10-01 from [CPU Galaxy's archive](https://www.cpu-galaxy.at/CPU/Ram%20Rom%20Eprom/Other_Intel_chips/other_intel-Dateien/8275_Datasheet.pdf). SHA-256 `aec733a972739cd70361560ba26249ec139f919f71f50167cdfde30a72826736`. The scan's footer identifies the document; a first-publication date is not inferred from the archive file date. Original Intel content is preserved as a technical reference, not relicensed as project code.
* [mame_graphics_reference.txt](mame_graphics_reference.txt): verbatim `character_attribute[3][16]` table excerpt from [MAME i8275.cpp at ef548b3f1c29d1a128baeaac48c42e95155b2c2e](https://github.com/mamedev/mame/blob/ef548b3f1c29d1a128baeaac48c42e95155b2c2e/src/devices/video/i8275.cpp). Authors Curt Coder and AJR, BSD-3-Clause; license below. Downloaded full source SHA-256 `a6b85a9eec2035ec2a6882cb6301ac3d6b69d9f28b215b99fe15009b5d6e3c1b`. Only the independently authored table is needed at runtime; the rest of MAME is not a dependency.
* [extract_graphics.py](extract_graphics.py) regenerates [graphics_vectors.hex](graphics_vectors.hex) exclusively from that external excerpt. Rows are above/on/below underline; bits are LA1, LA0, VSP, LTEN. All 33 defined graphics cases were visually cross-checked against Intel Table 2, PDF page 13. Simulation checks the vector values against DUT outputs rather than duplicating the RTL function.
* Historical year: [May 26, 1977 Electronics](https://www.worldradiohistory.com/Archive-Electronics/70s/77/Electronics-1977-05-26.pdf) describes the new 8275 and says sample quantities are forthcoming. This supports public introduction in 1977, not a precise first-shipment date.

Important cross-checks: Intel states character blink refresh/32 and cursor blink refresh/16, whereas MAME's internal counters use longer periods. Intel also explicitly supports spaced rows, which the referenced MAME implementation rejects. Graphics inherit field RVV/GPA per Intel page 15. No claim of full MAME equivalence is made.

## BSD-3-Clause for the MAME excerpt

Copyright Curt Coder and AJR. All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

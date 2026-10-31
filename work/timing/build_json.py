import json

TI = "https://www.ti.com/lit/ds/symlink/{}.pdf"
COND = "VCC=5V, CL=15pF, TA=25C"

def p(typ, mx, param, src, doc, page, notes):
    return {"tpd_typ_ns": typ, "tpd_max_ns": mx, "parameter": param,
            "conditions": COND, "source": src, "document": doc,
            "page": page, "notes": notes}

parts = {
 "74LS00": p(10, 15, "tPLH/tPHL", TI.format("sn74ls00"), "SDLS025D", "7",
   "Table 6.9 (SNx4LS00), RL=2k. tPLH 9/15, tPHL 10/15. Worst-case row tPHL used."),
 "74LS02": p(10, 15, "tPLH/tPHL", TI.format("sn74ls02"), "SDLS027", "4",
   "SN54/74LS02 switching characteristics, RL=2k. tPLH 10/15, tPHL 10/15."),
 "74LS04": p(10, 15, "tPLH/tPHL", TI.format("sn74ls04"), "SDLS029C", "6",
   "SN54/74LS04 table, RL=2k. tPLH 9/15, tPHL 10/15. Worst-case row tPHL used."),
 "74LS08": p(10, 20, "tPLH/tPHL", TI.format("sn74ls08"), "SDLS033", "4",
   "SN54/74LS08 table, RL=2k. tPLH 8/15, tPHL 10/20. Worst-case row tPHL used."),
 "74LS11": p(10, 20, "tPLH/tPHL", TI.format("sn74ls11"), "SDLS131", "3",
   "SN54/74LS11 table, RL=2k. tPLH 8/15, tPHL 10/20. Worst-case row tPHL used."),
 "74LS20": p(10, 15, "tPLH/tPHL", TI.format("sn74ls20"), "SDLS079", "4",
   "SN54/74LS20 table, RL=2k. tPLH 9/15, tPHL 10/15. Worst-case row tPHL used."),
 "74LS32": p(14, 22, "tPLH/tPHL", TI.format("sn74ls32"), "SDLS100", "4",
   "SN54/74LS32 table, RL=2k. tPLH 14/22, tPHL 14/22."),
 "74LS51": p(12.5, 20, "tPLH/tPHL", TI.format("sn74ls51"), "SDLS113", "5",
   "SN54/74LS51 table, RL=2k. tPLH 12/20, tPHL 12.5/20. Worst-case row tPHL used."),
 "74LS74": p(25, 40, "tPLH/tPHL", TI.format("sn74ls74a"), "SDLS119", "5",
   "SN74LS74A table, RL=2k, CL=15pF. tPLH 13/25, tPHL 25/40 (clock/clear/set to output). Worst-case row tPHL used."),
 "74LS86": p(20, 30, "tPLH/tPHL", TI.format("sn74ls86a"), "SDLS124", "4",
   "SN74LS86A table, RL=2k. Other input low: tPLH 12/23, tPHL 10/17. Other input high: tPLH 20/30, tPHL 13/22. Worst case 20/30."),
 "74LS138": p(18, 41, "tPLH/tPHL", TI.format("sn74ls138"), "SDLS014", "4",
   "RL=2k. Paths (typ/max): select 2-level 11/20, 18/41; select 3-level 21/27, 20/39; enable 2-level 12/18, 20/32; enable 3-level 14/26, 13/38. Worst pair 18/41."),
 "74LS139": p(25, 38, "tPLH/tPHL", TI.format("sn74ls139a"), "SDLS013A", "3",
   "SN74LS139A, RL=2k. Select 2-level 13/20, 22/33; select 3-level 18/29, 25/38; enable 16/24, 21/32. Worst pair 25/38."),
 "74LS151": p(25, 38, "tPLH/tPHL", TI.format("sn74ls151"), "SDLS054", "4",
   "SN74LS151 ('151A column), RL=400 ohm. Select 4-level 25/38; 3-level 17/26, 19/30; strobe 21/33, 22/33 and 14/21, 15/23; data 13/20, 18/27 and 8/14. Worst 25/38."),
 "74LS153": p(25, 38, "tPLH/tPHL", TI.format("sn74ls153"), "SDLS055A", "5",
   "SN74LS153, RL=2k. Data 10/15, 17/26; select 19/29, 25/38; strobe 16/24, 21/32. Worst pair 25/38."),
 "74LS161": p(None, 30, "tPLH/tPHL", "https://eater.net/datasheets/74ls161.pdf",
   "DS006397 (Fairchild DM74LS161A/DM74LS163A)", "6",
   "Fairchild AC table gives Min/Max only (no Typ column). At CL=15pF: clock-to-RC 25/30; clock-to-Q 22/27 and 24/27; enable-T 14/15; clear 28. Worst max 30 (tPHL clock to ripple carry). Typ not published."),
 "74LS166": p(19, 30, "tPHL/tPLH", TI.format("sn74ls166a"), "not printed in this scan (SN54LS166A/SN74LS166A)", "6",
   "RL=2k. fmax 25/35 MHz; clear-to-output tPHL 19/30; clock-to-output tPHL 14/25 and tPLH 11/20. Worst pair 19/30 (clear)."),
 "74LS174": p(23, 35, "tPLH/tPHL", TI.format("sn74ls174"), "SDLS068A", "5",
   "Combined LS174/LS175 table, RL=2k, 'LS174 columns. Clock 20/30 (tPLH), 21/30 (tPHL); clear 20/30, 23/35. Worst pair 23/35."),
 "74LS175": p(20, 30, "tPLH/tPHL", TI.format("sn74ls175"), "SDLS068A", "5",
   "Combined LS174/LS175 table, RL=2k, 'LS175 columns. Clock 13/25 (tPLH), 16/25 (tPHL); clear 20/30, 20/30. Worst pair 20/30."),
 "74LS194": p(19, 30, "tPHL/tPLH", TI.format("sn74ls194a"), "SDLS075", "7",
   "SN74LS194A, RL=2k. fmax 25/36 MHz; clock 14/22 (tPLH), 17/26 (tPHL); clear 19/30. Worst pair 19/30."),
 "74LS195": p(19, 30, "tPLH/tPHL", "https://www.sycelectronica.com.ar/semiconductores/74LS195.pdf",
   "ON Semiconductor SN74LS195A (no doc number printed)", "4",
   "AC CHARACTERISTICS TA=25C, VCC=5.0V, CL=15pF. fMAX 30/39 MHz; clock 14/22 (tPLH), 17/26 (tPHL); MR 19/30. Worst pair 19/30."),
 "74LS251": p(29, 45, "tPLH/tPHL", TI.format("sn74ls251"), "SDLS085", "6",
   "RL=2k. Select 4-level 29/45, 28/45; 3-level 20/33, 21/33; D->Y 17/28, 18/28; D->W 10/15, 9/15. Enable/disable paths use tPZH/tPZL/tPHZ/tPLZ (30/45 etc, disable at CL=5pF). Worst tpd 29/45."),
 "74LS257": p(None, 21, "tPLH/tPHL", "https://www.datasheets.pl/elementy_czynne/IC/7/74LS257.pdf",
   "Signetics 257 (54S/74S257, 54LS/74LS257); no document number printed", "3",
   "AC CHARACTERISTICS VCC=+5.0V, TA=25C, 54/74LS columns at CL=15pF; Min/Max only, no Typ. In->Zn max 18, S->Zn max 21, enable 30, disable 30/25. Worst tpd 21. RL for LS propagation rows not stated (enable/disable rows note RL=2k). TI SN74LS257B publishes only CL=45pF data."),
 "74LS259": p(19, 30, "tPLH/tPHL", TI.format("sn74ls259b"), "SDLS086", "4",
   "SN74LS259B, RL=2k. CLR 12/18; data 19/30, 13/20; address 17/27, 14/20; G 15/24, 15/24. Worst pair 19/30."),
 "74LS283": p(16, 24, "tPLH/tPHL", TI.format("sn74ls283"), "SDLS095A", "4",
   "SN74LS283, RL=2k. C0->sum 16/24, 15/24; Ai/Bi->sum 15/24; C0->C4 11/17, 11/22; Ai/Bi->C4 11/17, 12/17. Worst pair 16/24."),
}

out = {"parts": parts, "unresolved": []}
with open("ls_logic.json", "w", encoding="utf8") as f:
    json.dump(out, f, indent=2)
    f.write("\n")

print("parts:", len(parts))
print("null typ:", [k for k, v in parts.items() if v["tpd_typ_ns"] is None])
print("null max:", [k for k, v in parts.items() if v["tpd_max_ns"] is None])
print("non-numeric:", [k for k, v in parts.items()
                       if not isinstance(v["tpd_typ_ns"], (int, float, type(None)))
                       or not isinstance(v["tpd_max_ns"], (int, float, type(None)))])

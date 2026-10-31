// Directed real-mode #UD cases derived from Intel order 210498-005:
// Chapter 3 p. 3-1 (unlisted patterns), Chapter 5 pp. 5-4..5-7 (real-mode
// vector and restart linkage), Chapter 9 §9.6.1 p. 9-10 (no error code), and
// Appendix B pp. B-8, B-21, B-59..B-71, B-102, B-107.  D6 remains
// undocumented/disputed.  F6/F7 /1 are excluded because pinned physical
// captures identify those encodings as TEST aliases rather than #UD cases.
static void undefined_opcode_contracts() {
    auto prepare = [](Bench& b, bool enable_trace_flags,
                      const std::vector<uint8_t>& instruction) {
        b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
        uint16_t pc=0x0100;
        auto emit=[&](std::initializer_list<uint8_t> bytes) {
            for (uint8_t byte:bytes) b.memory[0xf0000+pc++]=byte;
        };
        emit({0xbc,0x00,0x80});                 // MOV SP,8000h
        emit({0xb8,0x34,0x12});                 // MOV AX,1234h
        emit({0xbb,0xef,0xbe});                 // MOV BX,BEEFh
        emit({0xb9,0x45,0x23});                 // MOV CX,2345h
        emit({0xba,0x56,0x34});                 // MOV DX,3456h
        emit({0xbd,0x67,0x45});                 // MOV BP,4567h
        emit({0xbe,0x78,0x56});                 // MOV SI,5678h
        emit({0xbf,0x89,0x67});                 // MOV DI,6789h
        if (enable_trace_flags) {
            // TF and IF are set immediately before the fault.  #UD has higher
            // priority than single-step, and entry must clear both live bits.
            emit({0xb8,0x03,0x07});             // MOV AX,0703h
            emit({0x50});                       // PUSH AX
            emit({0x9d});                       // POPF
        } else {
            emit({0xf9});                       // STC
            emit({0xfd});                       // STD
        }
        const uint16_t start=pc;
        for (uint8_t byte:instruction) b.memory[0xf0000+pc++]=byte;
        return start;
    };

    struct InvalidCase {
        const char* label;
        std::vector<uint8_t> bytes;
    };
    const std::vector<InvalidCase> cases={
        {"unassigned 64h byte",{0x64}},
        {"invalid second opcode byte",{0x0f,0xff}},
        {"segment prefix retained on #UD",{0x26,0x0f,0xff}},
        {"REP prefix retained on #UD",{0xf3,0x64}},
        {"ARPL is invalid in real mode",{0x63,0xc0}},
        {"SLDT is invalid in real mode",{0x0f,0x00,0xc0}},
        {"LAR is invalid in real mode",{0x0f,0x02,0xc0}},
        {"LSL is invalid in real mode",{0x0f,0x03,0xc0}},
        {"LEA requires a memory operand",{0x8d,0xc0}},
        {"LES requires a memory operand",{0xc4,0xc0}},
        {"LDS requires a memory operand",{0xc5,0xc0}},
        {"BOUND requires a memory operand",{0x62,0xc0}},
        {"MOV CS is an invalid segment-register operand",{0x8e,0xc8}},
        {"SGDT requires a memory operand",{0x0f,0x01,0xc0}},
        {"0F 01 /5 is undefined on the 80286",{0x0f,0x01,0xe8}},
        {"0F 01 /7 is undefined on the 80286",{0x0f,0x01,0xf8}},
    };

    unsigned runs=0;
    for (const auto& test:cases) for (bool wait:{false,true}) {
      try {
        Bench b;
        const uint16_t start=prepare(b,true,test.bytes);
        b.reset();
        b.step(0xfffff0,0xea,0xf000,0x0100,wait);
        // The preparatory code is a fixed sequence ending with POPF; the
        // invalid instruction follows it immediately, so an enabled TF tests
        // instruction-exception priority without an intervening instruction.
        uint16_t pc=0x0100;
        const std::vector<std::vector<uint8_t>> setup={
            {0xbc,0x00,0x80},{0xb8,0x34,0x12},{0xbb,0xef,0xbe},
            {0xb9,0x45,0x23},{0xba,0x56,0x34},{0xbd,0x67,0x45},
            {0xbe,0x78,0x56},{0xbf,0x89,0x67},{0xb8,0x03,0x07},{0x50},{0x9d}
        };
        for (const auto& ins:setup) {
            b.step(0xf0000+pc,ins[0],0xf000,uint16_t(pc+ins.size()),wait);
            pc=uint16_t(pc+ins.size());
        }
        check(pc==start,"#UD setup length drift");
        check((b.d.flags_o&0x0703)==0x0703,"#UD precondition did not set CF/TF/IF/DF");
        b.ud_fault(start,wait);
        check((b.d.flags_o&0x0300)==0,"#UD left live TF/IF set");
        ++runs;
      } catch (const std::exception& error) {
        throw std::runtime_error(std::string("80286 #UD case ")+test.label+": "+error.what());
      }
    }

    // Repair the offending byte in the handler, IRET to the exact saved IP,
    // and execute the repaired byte plus its exact successor.  This proves
    // restart linkage is actionable rather than merely checking the frame.
    for (bool wait:{false,true}) {
      try {
        Bench b;
        const uint16_t start=prepare(b,false,{0x64,0x43,0xf4});
        const std::vector<uint8_t> handler={
            0x50,                               // PUSH AX
            0x1e,                               // PUSH DS
            0xb8,0x00,0xf0,                     // MOV AX,F000h
            0x8e,0xd8,                           // MOV DS,AX
            0xc6,0x06,uint8_t(start),uint8_t(start>>8),0x90, // replace byte with NOP
            0x1f,                               // POP DS
            0x58,                               // POP AX
            0xcf                                // IRET to the original fault IP
        };
        for (unsigned i=0;i<handler.size();++i) b.memory[0x20100+i]=handler[i];
        b.reset();
        b.step(0xfffff0,0xea,0xf000,0x0100,wait);
        uint16_t pc=0x0100;
        const std::vector<std::vector<uint8_t>> setup={
            {0xbc,0x00,0x80},{0xb8,0x34,0x12},{0xbb,0xef,0xbe},
            {0xb9,0x45,0x23},{0xba,0x56,0x34},{0xbd,0x67,0x45},
            {0xbe,0x78,0x56},{0xbf,0x89,0x67},{0xf9},{0xfd}
        };
        for (const auto& ins:setup) {
            b.step(0xf0000+pc,ins[0],0xf000,uint16_t(pc+ins.size()),wait);
            pc=uint16_t(pc+ins.size());
        }
        check(pc==start,"#UD retry setup length drift");
        b.ud_fault(start,wait);

        uint16_t hp=0x0100;
        const std::vector<std::vector<uint8_t>> handler_ins={
            {0x50},{0x1e},{0xb8,0x00,0xf0},{0x8e,0xd8},
            {0xc6,0x06,uint8_t(start),uint8_t(start>>8),0x90},{0x1f},{0x58},{0xcf}
        };
        for (unsigned i=0;i<handler_ins.size();++i) {
            const auto& ins=handler_ins[i];
            const bool iret=i+1==handler_ins.size();
            b.step(0x20000+hp,ins[0],iret?0xf000:0x2000,
                   iret?start:uint16_t(hp+ins.size()),wait);
            hp=uint16_t(hp+ins.size());
        }
        check(b.memory.at(0xf0000+start)==0x90,"#UD handler did not repair the faulting byte");
        check(b.d.flags_o==0x0403,"IRET did not restore pre-fault FLAGS");
        b.step(0xf0000+start,0x90,0xf000,uint16_t(start+1),wait);
        b.step(0xf0000+start+1,0x43,0xf000,uint16_t(start+2),wait);
        check(b.reg(3)==0xbef0,"IRET did not retry at the exact repaired instruction");
        b.step(0xf0000+start+2,0xf4,0xf000,uint16_t(start+3),wait);
        check(b.d.halted_o,"repaired #UD path missed exact HLT successor");
        ++runs;
      } catch (const std::exception& error) {
        throw std::runtime_error(std::string("80286 #UD IRET-repair path: ")+error.what());
      }
    }

    // Load a relocated IDTR with LIDT in real mode, then deliver #UD through
    // its vector-6 entry.  The default IVT contains a poisoned handler, so the
    // successful event must use the loaded base.  A real handler increments
    // the saved IP word and IRETs to the exact HLT after the invalid 64h byte.
    unsigned relocated_idtr_runs=0;
    for (bool wait:{false,true}) {
      try {
        Bench b;
        const uint16_t start=0x0108;
        b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
        b.put(0xf0100,{0xbc,0x00,0x80,             // MOV SP,8000h
                       0x0f,0x01,0x1e,0x00,0x20, // LIDT [2000h]
                       0x64,0xf4});               // invalid 64h; exact HLT successor
        b.put(24,{0x78,0x56,0x34,0x12});            // poisoned default-IVT vector 6
        b.put(0x2000,{0xff,0x03,0x00,0x30,0x00,0x00}); // limit=03FFh, base=3000h
        b.put(0x20100,{0x83,0x06,0xfa,0x7f,0x01,0xcf}); // ADD [7FFAh],1; IRET
        b.reset();
        b.step(0xfffff0,0xea,0xf000,0x0100,wait);
        b.step(0xf0100,0xbc,0xf000,0x0103,wait);
        b.data_transfers.clear();
        b.step(0xf0103,0x0f,0xf000,0x0108,wait);
        check(b.data_transfers.size()==6,"LIDT relocated-IDTR descriptor traffic");
        const uint8_t descriptor[]={0xff,0x03,0x00,0x30,0x00,0x00};
        for (unsigned i=0;i<6;++i) {
            const auto& transfer=b.data_transfers[i];
            check(transfer.address==0x2000+i && !transfer.write && !transfer.io &&
                  transfer.value==descriptor[i],"LIDT did not read DS=0 descriptor bytes in order");
        }
        check(b.memory.at(24)==0x78 && b.memory.at(25)==0x56 &&
              b.memory.at(26)==0x34 && b.memory.at(27)==0x12,
              "relocated-IDTR test lost the poisoned default IVT");
        b.ud_fault(start,wait,0x3000);
        check(b.d.event_vector_o==6 && b.cs()==0x2000 && b.d.ip_o==0x0100,
              "#UD did not use relocated IDTR vector 6");
        check(b.memory.at(24)==0x78 && b.memory.at(25)==0x56 &&
              b.memory.at(26)==0x34 && b.memory.at(27)==0x12,
              "#UD consulted or modified the poisoned default IVT");
        b.step(0x20100,0x83,0x2000,0x0105,wait);
        check((unsigned(b.memory.at(0x7ffa)) |
               (unsigned(b.memory.at(0x7ffb))<<8))==start+1,
              "real relocated-IDTR handler did not advance the saved IP");
        b.step(0x20105,0xcf,0xf000,uint16_t(start+1),wait);
        check(b.reg(4)==0x8000 && b.d.flags_o==2,
              "relocated-IDTR IRET did not restore SP/FLAGS");
        check(b.memory.at(0xf0108)==0x64 && b.memory.at(0xf0109)==0xf4,
              "relocated-IDTR handler changed instruction bytes");
        b.step(0xf0109,0xf4,0xf000,0x010a,wait);
        check(b.d.halted_o,"relocated-IDTR IRET missed exact HLT successor");
        ++runs;
        ++relocated_idtr_runs;
      } catch (const std::exception& error) {
        throw std::runtime_error(std::string("80286 relocated-IDTR #UD case: ")+error.what());
      }
    }

    // Calibrate each wait mode with Bench::ud_fault(), then reset after every
    // cycle from immediately after setup through vector reads and all six
    // frame writes.  Every cut is followed by a fresh real-instruction replay
    // through #UD, a handler-side saved-IP increment, IRET, and exact HLT.
    unsigned reset_cuts=0;
    const auto prepare_reset_cut=[](Bench& b,bool wait) {
        b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
        b.put(0xf0100,{0xbc,0x00,0x80,0x64,0xf4});
        b.put(0x20100,{0x83,0x06,0xfa,0x7f,0x01,0xcf});
        b.reset();
        b.step(0xfffff0,0xea,0xf000,0x0100,wait);
        b.step(0xf0100,0xbc,0xf000,0x0103,wait);
        return uint16_t(0x0103);
    };
    const auto replay_after_cut=[](Bench& b,uint16_t start,bool wait) {
        b.step(0xfffff0,0xea,0xf000,0x0100,wait);
        b.step(0xf0100,0xbc,0xf000,0x0103,wait);
        b.ud_fault(start,wait);
        b.step(0x20100,0x83,0x2000,0x0105,wait);
        b.step(0x20105,0xcf,0xf000,uint16_t(start+1),wait);
        check(b.reg(4)==0x8000,"#UD reset replay IRET did not restore SP");
        b.step(0xf0104,0xf4,0xf000,0x0105,wait);
        check(b.d.halted_o,"#UD reset replay missed exact HLT successor");
    };
    for (bool wait:{false,true}) {
        Bench calibration;
        const uint16_t start=prepare_reset_cut(calibration,wait);
        const unsigned after_setup=calibration.cycles;
        calibration.ud_fault(start,wait);
        const unsigned entry_cycles=calibration.cycles-after_setup;
        check(entry_cycles>0 && calibration.data_transfers.size()==10,
              "#UD reset-cut calibration did not reach complete vector/frame entry");

        std::vector<bool> progress_seen(11,false);
        for (unsigned cut=0;cut<=entry_cycles;++cut) {
            Bench b;
            const uint16_t cut_start=prepare_reset_cut(b,wait);
            b.put(24,{0x00,0x01,0x00,0x20}); // same IVT image installed by ud_fault()
            b.data_transfers.clear();
            for (unsigned n=0;n<cut;++n) {
                b.tick(wait);
                check(!b.d.fault_o && !b.d.retire_o,
                      "#UD reset cut retired or entered a diagnostic stop");
            }
            check(b.data_transfers.size()<=10,"#UD reset cut produced extra bus traffic");
            progress_seen[b.data_transfers.size()]=true;
            check(bool(b.d.event_o)==(cut==entry_cycles),
                  "#UD calibrated cut did not stop at the event-entry boundary");
            b.reset();
            for (unsigned reg=0;reg<8;++reg)
                check(b.reg(reg)==0,"#UD reset cut left a GPR/stack value");
            check(!b.d.event_o && !b.d.retire_o && !b.d.bus_req_o &&
                  !b.d.fault_o && !b.d.halted_o,
                  "#UD reset cut left event or execution outputs active");
            b.accepted.clear();
            replay_after_cut(b,cut_start,wait);
            ++reset_cuts;
        }
        for (unsigned transfers=0;transfers<=10;++transfers)
            check(progress_seen[transfers],"#UD reset cuts missed an IVT/frame transfer boundary");
    }
    std::cout<<"PASS: "<<runs<<" real-mode #UD cases, including prefix restart, no-error-code frame, TF/IF priority, repaired IRET retry, "
             <<relocated_idtr_runs<<" relocated-IDTR runs; "<<reset_cuts
             <<" cycle-by-cycle #UD reset cuts across IVT/frame entry with complete reset/replay\n";
}

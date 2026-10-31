// Directed real-mode protection/interrupt-table fault tests. Expected
// vectors, restart linkage, and the ten-byte erratum case are derived from
// Intel 210498-005 §§5.2.3, 9.6.1, Appendix B (BOUND, LDS/LES), plus the
// pinned Harris-286 SingleStepTests captures for the length-overrun erratum.
// The tests exercise the public Bench bus/event contract; they do not derive
// expected architectural state from the RTL.

static void protection_fault_contracts() {
    struct FaultCase {
        const char* label;
        std::vector<uint8_t> bytes;
    };

    const std::vector<FaultCase> segment_overrun_cases={
        {"A1 word moffs at DS:FFFF",{0xa1,0xff,0xff}},
        {"A3 word moffs at DS:FFFF",{0xa3,0xff,0xff}},
        {"MOV AX,[DS:FFFF]",{0x8b,0x06,0xff,0xff}},
        {"MOV [DS:FFFF],AX",{0x89,0x06,0xff,0xff}},
        {"MOV AX,SS:[BP+0] at FFFF",{0x8b,0x46,0x00}},
        {"MOV AX,ES:[FFFF]",{0x26,0x8b,0x06,0xff,0xff}},
        {"MOV AX,CS:[FFFF]",{0x2e,0x8b,0x06,0xff,0xff}},
        {"LES doubleword spans past FFFF",{0xc4,0x06,0xfd,0xff}},
        {"LDS doubleword spans past FFFF",{0xc5,0x06,0xfd,0xff}},
        {"BOUND two-word span reaches past FFFF",{0x62,0x06,0xfd,0xff}},
    };

    const std::vector<std::vector<uint8_t>> setup={
        {0xbc,0x00,0x80}, // MOV SP,8000h: leave ample room for the 6-byte frame
        {0xb8,0x34,0x12}, // MOV AX,1234h
        {0xbd,0xff,0xff}, // MOV BP,FFFFh for the SS:BP case
        {0xf9},            // STC
        {0xfd},            // STD
    };

    const auto install_common_image=[&](Bench& b, uint16_t start,
                                        const std::vector<uint8_t>& faulting,
                                        unsigned skip_length) {
        b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
        uint16_t pc=0x0100;
        for (const auto& ins:setup) {
            for (uint8_t byte:ins) b.memory[0xf0000+pc++]=byte;
        }
        check(pc==start,"#GP shared setup length drift");
        for (uint8_t byte:faulting) b.memory[0xf0000+pc++]=byte;
        b.memory[0xf0000+pc++]=0x40; // exact resumed successor: INC AX
        b.memory[0xf0000+pc]=0xf4;   // exact successor after INC AX: HLT
        b.put(0x20100,{0x83,0x06,0xfa,0x7f,uint8_t(skip_length),0xcf});
    };

    const auto run_setup=[&](Bench& b, bool wait, uint16_t expected_start) {
        b.reset();
        b.step(0xfffff0,0xea,0xf000,0x0100,wait);
        uint16_t pc=0x0100;
        for (const auto& ins:setup) {
            b.step(0xf0000+pc,ins[0],0xf000,uint16_t(pc+ins.size()),wait);
            pc=uint16_t(pc+ins.size());
        }
        check(pc==expected_start,"#GP shared setup did not end at the faulting instruction");
        check(b.reg(4)==0x8000 && b.reg(0)==0x1234 && b.reg(5)==0xffff,
              "#GP setup registers are not the documented test inputs");
        check(b.d.flags_o==0x0403,"#GP setup did not establish CF=1 and DF=1");
    };

    const auto finish_after_fault=[](Bench& b, bool wait, uint16_t start,
                                      unsigned skip_length, const char* label) {
        b.step(0x20100,0x83,0x2000,0x0105,wait);
        b.step(0x20105,0xcf,0xf000,uint16_t(start+skip_length),wait);
        check(b.reg(4)==0x8000 && b.reg(0)==0x1234,
              "fault handler/IRET changed SP or the unretired AX input");
        const uint16_t successor=uint16_t(start+skip_length);
        b.step(0xf0000+successor,0x40,0xf000,uint16_t(successor+1),wait);
        check(b.reg(0)==0x1235 && (b.d.flags_o&0x0401)==0x0401,
              "#GP IRET did not reach exact INC successor or preserve CF/DF");
        b.step(0xf0000+successor+1,0xf4,0xf000,uint16_t(successor+2),wait);
        check(b.d.halted_o,"#GP IRET missed the exact HLT successor");
        (void)label;
    };

    unsigned segment_overrun_runs=0;
    for (const auto& test:segment_overrun_cases) for (bool wait:{false,true}) {
        try {
            Bench b;
            constexpr uint16_t start=0x010b;
            install_common_image(b,start,test.bytes,unsigned(test.bytes.size()));
            run_setup(b,wait,start);
            b.processor_fault(13,start,wait);
            finish_after_fault(b,wait,start,unsigned(test.bytes.size()),test.label);
            ++segment_overrun_runs;
        } catch (const std::exception& error) {
            throw std::runtime_error(std::string("80286 real-mode #GP case ")+
                                     test.label+": "+error.what());
        }
    }

    // The pinned Harris-286 corpus records this exact TEST instruction as an
    // 11-byte instruction ending in 57h, followed by HLT.  Intel 210498-005
    // Appendix C item 10 describes the 10-byte limit but says #UD; the
    // physical Harris captures show the 286 erratum delivers vector 13.
    // The core must reject it before accepting byte 11 and save the first
    // prefix address.  This exercises that bus boundary without assuming a
    // modern x86 decoder's length-fault behavior.
    unsigned overlength_runs=0;
    const std::vector<uint8_t> overlength={
        0x26,0x3e,0x36,0x36,0x26, // five segment prefixes
        0xf7,0x8b,0x44,0xf7,0xf9,0x57 // TEST word [..],57F9h; byte 11 is 57h
    };
    for (bool wait:{false,true}) {
        try {
            Bench b;
            constexpr uint16_t start=0x010b;
            install_common_image(b,start,overlength,unsigned(overlength.size()));
            run_setup(b,wait,start);
            b.accepted.clear();
            b.data_transfers.clear();
            b.processor_fault(13,start,wait);
            // ModR/M already determines this encoding's displacement and
            // immediate sizes. A functional decoder may reject it before
            // consuming all ten legal prefix bytes; native prefetch timing
            // is outside this test's contract. Exact fault/return PCs remain
            // checked by processor_fault() and finish_after_fault().
            check(b.accepted.size()>=7 && b.accepted.size()<=10,
                  "overlength #GP fetched beyond the known instruction-size limit");
            for (unsigned i=0;i<b.accepted.size();++i)
                check(b.accepted[i]==0xf0000+start+i,
                      "overlength #GP changed fetch order before the length limit");
            for (uint32_t address:b.accepted)
                check(address!=0xf0000+start+10,
                      "overlength #GP accepted the eleventh instruction byte");
            finish_after_fault(b,wait,start,unsigned(overlength.size()),"11-byte native case");
            ++overlength_runs;
        } catch (const std::exception& error) {
            throw std::runtime_error(std::string("80286 real-mode #GP overlength case: ")+
                                     error.what());
        }
    }

    // A real-mode IDTR limit of 0023h includes vector 8 at bytes 20h..23h,
    // but excludes INT 30h at C0h..C3h.  The failed prefixed INT must raise
    // vector 8, retain its prefix in the saved IP, and skip to INC/HLT after
    // the handler increments that saved IP by the complete 3-byte length.
    unsigned idtr_limit_runs=0;
    constexpr uint16_t int30_start=0x010d;
    for (bool wait:{false,true}) {
        try {
            Bench b;
            b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
            b.put(0xf0100,{0xbc,0x00,0x80,             // MOV SP,8000h
                           0xb8,0x34,0x12,             // MOV AX,1234h
                           0xf9,0xfd,                 // STC; STD
                           0x0f,0x01,0x1e,0x00,0x20, // LIDT [2000h]
                           0x26,0xcd,0x30,             // prefixed INT 30h (out of limit)
                           0x40,0xf4});                // exact resumed INC/HLT
            b.put(0x2000,{0x23,0x00,0x00,0x00,0x00,0x00}); // limit=23h, base=0
            b.put(0x00c0,{0x55,0x55,0x44,0x44}); // poison out-of-limit vector 30h
            b.put(0x20100,{0x83,0x06,0xfa,0x7f,0x03,0xcf}); // add length, IRET
            b.reset();
            b.step(0xfffff0,0xea,0xf000,0x0100,wait);
            b.step(0xf0100,0xbc,0xf000,0x0103,wait);
            b.step(0xf0103,0xb8,0xf000,0x0106,wait);
            b.step(0xf0106,0xf9,0xf000,0x0107,wait);
            b.step(0xf0107,0xfd,0xf000,0x0108,wait);
            check(b.d.flags_o==0x0403 && b.reg(0)==0x1234 && b.reg(4)==0x8000,
                  "IDTR-limit test setup state");
            b.data_transfers.clear();
            b.step(0xf0108,0x0f,0xf000,0x010d,wait);
            check(b.data_transfers.size()==6,"LIDT did not consume exactly six descriptor bytes");
            const uint8_t descriptor[]={0x23,0x00,0x00,0x00,0x00,0x00};
            for (unsigned i=0;i<6;++i) {
                const auto& transfer=b.data_transfers[i];
                check(transfer.address==0x2000+i && !transfer.write && !transfer.io &&
                      transfer.value==descriptor[i],
                      "LIDT did not read the limit/base descriptor in order");
            }
            b.data_transfers.clear();
            b.accepted.clear();
            b.processor_fault(8,int30_start,wait,0);
            check(b.d.event_vector_o==8 && b.cs()==0x2000 && b.d.ip_o==0x0100,
                  "out-of-limit INT 30h did not use the in-limit real vector 8");
            check(b.memory.at(0x00c0)==0x55 && b.memory.at(0x00c1)==0x55 &&
                  b.memory.at(0x00c2)==0x44 && b.memory.at(0x00c3)==0x44,
                  "IDTR-limit test modified the poisoned vector 30h entry");
            b.step(0x20100,0x83,0x2000,0x0105,wait);
            check((unsigned(b.memory.at(0x7ffa)) |
                   (unsigned(b.memory.at(0x7ffb))<<8))==int30_start+3,
                  "vector-8 handler did not skip the complete prefixed INT");
            b.step(0x20105,0xcf,0xf000,int30_start+3,wait);
            check(b.reg(4)==0x8000 && b.reg(0)==0x1234 && b.d.flags_o==0x0403,
                  "vector-8 IRET did not restore the faulting context");
            b.step(0xf0000+int30_start+3,0x40,0xf000,int30_start+4,wait);
            check(b.reg(0)==0x1235 && (b.d.flags_o&0x0401)==0x0401,
                  "vector-8 IRET missed the exact INC successor");
            b.step(0xf0000+int30_start+4,0xf4,0xf000,int30_start+5,wait);
            check(b.d.halted_o,"vector-8 IRET missed the exact HLT successor");
            ++idtr_limit_runs;
        } catch (const std::exception& error) {
            throw std::runtime_error(std::string("80286 real-mode IDTR-limit fault case: ")+
                                     error.what());
        }
    }

    std::cout<<"PASS: "<<segment_overrun_runs
             <<" real-mode #GP segment-boundary replays, "<<overlength_runs
             <<" native overlength-erratum replays, and "<<idtr_limit_runs
             <<" real-mode vector-8 IDTR-limit replays across stalled/unstalled buses\n";
}

// Physical Harris-286 state comes exclusively from the pinned MOO captures.
// Setup executes real instructions; it does not deposit DUT internals.
static void hardware_vectors(const char* path) {
    std::ifstream input(path);
    check(bool(input),"physical-286 vector file missing");
    std::string token,label;
    unsigned cases=0,runs=0;
    const bool survey=std::getenv("I286_HW_SURVEY")!=nullptr;
    std::map<std::string,unsigned> survey_failures;
    try {
        while (input>>token) {
            // HWSTRING/HWSTRFAULT: MOVS/CMPS/STOS/LODS/SCAS records with their
            // captured REP/REPNE prefixes; operand traffic is expected, and a
            // fault record may follow completed elements.
            // HWGEN/HWGENFAULT: any selected opcode, with operand traffic and
            // control transfer allowed; the importer supplies the defined-
            // FLAGS mask and, for faults, the vector.
            const bool general_case=token=="HWGEN" || token=="HWGENFAULT";
            const bool fault_case=token=="HWFAULT" || token=="HWSTRFAULT" || token=="HWGENFAULT";
            const bool string_case=token=="HWSTRING" || token=="HWSTRFAULT" || general_case;
            check(token=="HWCASE" || fault_case || string_case,"malformed physical case marker");
            std::string code;
            unsigned opcode,mask;
            input>>label>>code>>std::hex>>opcode>>mask;
            unsigned exception=0;
            if (fault_case) input>>exception;
            check(bool(input) && code.size()>=4 && code.size()%2==0 && code.size()<=24,
                  "malformed physical encoded instruction");
            check(std::all_of(code.begin(),code.end(),[](char c) {
                return std::string("0123456789abcdef").find(c)!=std::string::npos;
            }),"nonhex physical instruction");
            uint16_t initial[14],final[14];
            for (unsigned state=0;state<2;++state) {
                input>>token;
                check(token==(state==0?"INITIAL":"FINAL"),"missing physical register state");
                for (unsigned i=0;i<14;++i) {
                    unsigned value; input>>value;
                    check(bool(input) && value<=65535,"invalid physical register value");
                    (state==0?initial:final)[i]=uint16_t(value);
                }
            }
            std::unordered_map<uint32_t,uint8_t> initial_ram,final_ram;
            for (unsigned state=0;state<2;++state) {
                input>>token;
                check(token==(state==0?"RAM_INITIAL":"RAM_FINAL"),"missing physical RAM state");
                unsigned count; input>>count;
                check(bool(input) && count<=1048576,"invalid physical RAM count");
                auto& memory=state==0?initial_ram:final_ram;
                for (unsigned i=0;i<count;++i) {
                    unsigned address,value; input>>address>>value;
                    check(bool(input) && address<0x1000000 && value<256,"invalid physical RAM entry");
                    check(memory.emplace(address,uint8_t(value)).second,"duplicate physical RAM address");
                }
            }
            input>>token; check(bool(input) && token=="END","truncated physical case");
            const bool arithmetic_immediate = opcode==0x04 || opcode==0x05 ||
                opcode==0x14 || opcode==0x15 || opcode==0x1c || opcode==0x1d ||
                opcode==0x2c || opcode==0x2d || opcode==0x3c || opcode==0x3d;
            const bool test_alias=opcode==0xf6 || opcode==0xf7;
            const bool string_opcode=(opcode>=0xa4 && opcode<=0xa7) || (opcode>=0xaa && opcode<=0xaf);
            check(general_case ? (mask & ~0x7fd7u)==0 :
                  (string_case ? string_opcode && mask==0x7fd7u :
                   (arithmetic_immediate || (opcode>=0x40 && opcode<=0x4f) || test_alias) &&
                   mask==(test_alias && !fault_case ? 0x7fc7u : 0x7fd7u)),
                  "physical file needs an explicit instruction/flag contract");
            check(!fault_case || (general_case ? exception<32 :
                  exception==13 && (opcode==0xf7 || string_case)),"unsupported physical exception contract");
            check(!(initial[13]&0x7300),"physical initial FLAGS need unsupported state/debug setup");
            const bool hlt_suffix=code.substr(code.size()-2)=="f4";
            check(hlt_suffix || general_case,"physical successor is not HLT");
            const unsigned instruction_bytes=unsigned(code.size()/2)-(hlt_suffix ? 1 : 0);
            check(fault_case || general_case ||
                  (final[9]==initial[9] && final[12]==uint16_t(initial[12]+instruction_bytes+1)),
                  "physical non-flow final PC accounting mismatch");
            try {
            for (bool wait:{false,true}) {
                Bench b;
                // SingleStepTests README: every IN form reads FFh / FFFFh.
                if (general_case) b.port_default=0xff;
                // Near JMP preserves the special reset CS base, providing an
                // isolated high bootstrap outside every real-mode capture.
                b.put(0xfffff0,{0xe9,0x0d,0x10});
                struct Ins { uint16_t at,next; uint8_t op; };
                std::vector<Ins> setup; uint16_t pc=0x1000;
                auto emit=[&](std::initializer_list<uint8_t> bytes) {
                    const uint16_t at=pc;
                    for (auto byte:bytes) b.memory[0xff0000+pc++]=byte;
                    setup.push_back({at,pc,*bytes.begin()});
                };
                emit({0xbc,0,0x70});
                emit({0xb8,uint8_t(initial[13]),uint8_t(initial[13]>>8)});
                emit({0x50}); emit({0x9d});
                for (unsigned role:{0u,2u,3u}) {
                    const uint16_t selector=initial[8+role];
                    emit({0xb8,uint8_t(selector),uint8_t(selector>>8)});
                    emit({0x8e,uint8_t(0xc0+(role<<3))});
                }
                for (unsigned reg=0;reg<8;++reg)
                    emit({uint8_t(0xb8+reg),uint8_t(initial[reg]),uint8_t(initial[reg]>>8)});
                emit({0xea,uint8_t(initial[12]),uint8_t(initial[12]>>8),uint8_t(initial[9]),uint8_t(initial[9]>>8)});
                b.reset(); b.step(0xfffff0,0xe9,0xf000,0x1000,wait);
                for (unsigned i=0;i<setup.size();++i) {
                    const auto& ins=setup[i];
                    b.step(0xff0000+ins.at,ins.op,i+1==setup.size()?initial[9]:0xf000,
                           i+1==setup.size()?initial[12]:ins.next,wait);
                }
                for (const auto& byte:initial_ram) {
                    check(byte.first<0xff0000,"physical RAM aliases isolated high bootstrap");
                    b.memory[byte.first]=byte.second;
                }
                auto compare=[&](const uint16_t* expected) {
                    for (unsigned reg=0;reg<8;++reg) if (b.reg(reg)!=expected[reg]) {
                        std::ostringstream message;
                        message<<"physical register "<<reg<<" actual="<<std::hex<<b.reg(reg)<<" expected="<<expected[reg];
                        throw std::runtime_error(message.str());
                    }
                    const uint64_t segments=uint64_t(expected[8]) | (uint64_t(expected[9])<<16) |
                        (uint64_t(expected[10])<<32) | (uint64_t(expected[11])<<48);
                    check(b.d.segs_o==segments,"physical segment-register mismatch");
                    if ((b.d.flags_o^expected[13])&mask) {
                        std::ostringstream message;
                        message<<"physical FLAGS actual="<<std::hex<<b.d.flags_o<<" expected="<<expected[13]<<" mask="<<mask;
                        throw std::runtime_error(message.str());
                    }
                };
                compare(initial);
                check(b.d.ip_o==initial[12] && b.d.cs_base_o==uint32_t(initial[9])*16,
                      "physical initial CS cache/IP setup mismatch");
                b.accepted.clear(); b.data_transfers.clear();
                const uint32_t start=uint32_t(initial[9])*16+initial[12];
                const auto retired_before=b.retired;
                if (fault_case) {
                    for (unsigned n=0;n<(string_case ? 2000000u : 2048u) && !b.d.event_o;++n) {
                        b.tick(wait);
                        check(!b.d.fault_o && b.retired==retired_before,"physical exception stopped or retired");
                    }
                    check(b.d.event_o && b.d.event_vector_o==exception && !b.d.retire_o,
                          "physical exception vector/entry");
                    check(b.cs()==final[9] && b.d.ip_o==uint16_t(final[12]-1),
                          "physical exact exception handler entry CS:IP");
                    check(string_case ? b.data_transfers.size()>=10 : b.data_transfers.size()==10,
                          "physical exception operand/frame transaction count");
                    const std::size_t frame=b.data_transfers.size()-10;
                    for(unsigned i=0;i<10;++i) {
                        const auto& transfer=b.data_transfers[frame+i];
                        // A general record's frame sits below the SP the
                        // fault left (final SP + 6), which an instruction
                        // such as POP m may already have moved.
                        const uint16_t frame_sp=general_case ? uint16_t(final[4]+6) : initial[4];
                        const uint32_t expected=i<4 ? 4*exception+i : uint32_t(initial[10])*16+
                            uint16_t(frame_sp-2*(1+(i-4)/2))+(i&1);
                        if (!(transfer.address==expected && transfer.write==(i>=4) && !transfer.io)) {
                            std::ostringstream message;
                            message<<"physical exact exception IVT/frame addresses: transfer "<<i
                                   <<" actual="<<std::hex<<transfer.address<<(transfer.write?" W":" R")
                                   <<" expected="<<expected<<" all:";
                            for (const auto& t:b.data_transfers)
                                message<<" "<<t.address<<(t.write?"W":"R");
                            message<<" sp="<<b.reg(4);
                            throw std::runtime_error(message.str());
                        }
                    }
                } else b.step(start,uint8_t(opcode),final[9],uint16_t(final[12]-1),wait);
                compare(final);
                // A control transfer's captured byte list can include bytes
                // past the instruction, so only bound its fetch count.
                const bool transfer=general_case &&
                    !(final[9]==initial[9] && final[12]==uint16_t(initial[12]+instruction_bytes+1));
                check(fault_case ? !b.accepted.empty() && b.accepted.size()<=10 :
                      transfer ? !b.accepted.empty() && b.accepted.size()<=instruction_bytes :
                      b.accepted.size()==instruction_bytes,"physical tested-instruction fetch length");
                for (unsigned i=0;i<b.accepted.size();++i) check(b.accepted[i]==start+i,
                                                               "physical tested-instruction exact fetch address");
                const uint32_t halt_pc=uint32_t(final[9])*16+uint16_t(final[12]-1);
                b.accepted.clear(); b.step(halt_pc,0xf4,final[9],final[12],wait);
                compare(final);
                check(b.d.halted_o && b.accepted.size()==1 && b.accepted[0]==halt_pc,
                      "physical exact HLT successor");
                if (general_case) {
                    // Only the port I/O opcodes may reach I/O space.
                    const bool io_opcode=(opcode>=0xe4 && opcode<=0xe7) ||
                        (opcode>=0xec && opcode<=0xef) || (opcode>=0x6c && opcode<=0x6f);
                    check(io_opcode || std::none_of(b.data_transfers.begin(),b.data_transfers.end(),
                              [](const auto& t) { return t.io; }),"physical record issued unexpected I/O");
                } else if (string_case)
                    check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                              return t.io;
                          }),"physical string record issued I/O");
                else check(fault_case ? b.data_transfers.size()==10 : b.data_transfers.empty(),
                           "physical unexpected operand/I/O effects");
                for (const auto& byte:final_ram) check(b.memory.at(byte.first)==byte.second,
                                                       "physical final RAM mismatch");
                ++runs;
            }
            } catch (const std::exception& error) {
                // I286_HW_SURVEY: report every failing file instead of
                // stopping at the first record (evidence survey only).
                if (!survey) throw;
                const std::string file=label.substr(0,label.find(':'));
                if (survey_failures[file]++==0)
                    std::cout<<"SURVEY-FAIL "<<label<<" "<<code<<": "<<error.what()<<"\n";
            }
            ++cases;
        }
        check(cases!=0 && input.eof(),"physical vector file empty or malformed");
    } catch (const std::exception& error) {
        throw std::runtime_error("Physical 286 "+label+": "+error.what());
    }
    if (survey) {
        unsigned failed=0;
        for (const auto& entry:survey_failures) {
            std::cout<<"SURVEY "<<entry.first<<" failures="<<entry.second<<"\n";
            failed+=entry.second;
        }
        check(failed==0,"physical survey found mismatching records");
    }
    std::cout<<"PASS: "<<cases<<" physical Harris-286 captures, "<<runs
             <<" stalled/unstalled executions with exact registers/flags/RAM/PC and HLT successors\n";
}

// Included after the shared replay helpers inside the anonymous namespace.
// Oracle: Intel LOADALL memo p14, qualified by the 1984-10-15 REP correction.
// Expected fault repair: MOVS source SI/CX(+1), MOVS destination SI/DI/CX(+2),
// STOS DI/CX(+2), OUTS SI/CX(+2). These are corrected post-C2 expectations.
#ifndef INTEL_80286_PROTECTED_STRING_REPLAY_H
#define INTEL_80286_PROTECTED_STRING_REPLAY_H

enum class StringFaultKind { MoveSource, MoveDestination, Store, Output, CompareSource, CompareDestination };

struct StringTransfer {
    uint32_t address;
    uint8_t value;
    bool write;
    bool io;
    uint8_t segment;
};

void run_string_fault_fixture(StringFaultKind kind, bool word, bool repeat,
                              bool waits, bool backward=false, unsigned count=2, bool wrap=false,
                              bool not_equal=false) {
    if ((backward && repeat) || (wrap && (repeat || backward || !word)))
        fail("unsupported string boundary fixture combination");
    const bool move=kind==StringFaultKind::MoveSource || kind==StringFaultKind::MoveDestination;
    const bool compare=kind==StringFaultKind::CompareSource || kind==StringFaultKind::CompareDestination;
    if (not_equal && !compare) fail("REPNE profile requires CMPS");
    const bool source_fault=kind==StringFaultKind::MoveSource || kind==StringFaultKind::Output ||
        kind==StringFaultKind::CompareSource;
    const bool advance_si=move || kind==StringFaultKind::Output || kind==StringFaultKind::CompareSource;
    const bool advance_di=kind==StringFaultKind::MoveDestination || kind==StringFaultKind::Store || compare;
    const unsigned repair_cx=(kind==StringFaultKind::MoveSource || kind==StringFaultKind::CompareDestination) ? 1 : 2;
    const unsigned width=word ? 2 : 1;
    const int delta=backward ? -static_cast<int>(width) : static_cast<int>(width);
    const unsigned completed=repeat ? 1 : 0;
    const unsigned remaining=repeat ? count-1 : 1;
    const uint16_t bad_offset=wrap ? 0xffff : (word ? 0x000f : 0x0010);
    const uint16_t initial_bad=repeat ? bad_offset-width : bad_offset;
    const uint16_t initial_si=source_fault ? initial_bad : 0x0020;
    const uint16_t initial_di=source_fault ? 0x0020 : initial_bad;
    const uint16_t fault_base_si=initial_si+completed*delta;
    const uint16_t fault_base_di=kind==StringFaultKind::Output ? initial_di : initial_di+completed*delta;
    const uint16_t retry_si=wrap && source_fault ? 0x000f : fault_base_si;
    const uint16_t retry_di=wrap && !source_fault ? 0x000f : fault_base_di;
    const uint16_t fault_si=advance_si ? fault_base_si+delta :
        (compare ? fault_base_si : initial_si);
    const uint16_t fault_di=advance_di ? fault_base_di+delta : fault_base_di;
    const uint16_t fault_cx=repeat ? count-completed-repair_cx : count;
    // Equal comparisons produce ZF/PF, unequal 0101-0000 produces neither.
    // No comparison has completed on the unprefixed fault path.
    const uint16_t saved_flags=(backward ? 0x0400 : 0) |
        (compare && completed ? (not_equal ? 0x0202 : 0x0246) : 0x0203);
    constexpr uint16_t wide_es_selector=0x0038;
    constexpr uint32_t wide_es_base=0x00060000;
    const uint16_t source_selector=source_fault ? fixture::kNarrowDsSelector : fixture::kWideDataSelector;
    const uint32_t before_source=source_fault ? fixture::kNarrowDataBase : fixture::kWideDataBase;
    const uint32_t after_dest=source_fault ? fixture::kEsDataBase : wide_es_base;
    auto memory=initial_memory();
    memory[fixture::kRealCodeBase+0x010b]=backward ? 0xfd : 0xfc;
    memory[0x40]=0x3f; // GDTR limit includes one additional wide ES descriptor.
    const uint8_t wide_es[] = {0xff,0x00,0x00,0x00,0x06,0x92,0x00,0x00};
    place(memory,fixture::kGdtBase+wide_es_selector,wide_es);
    if (!source_fault) memory[fixture::kGdtBase+0x20]=0x0f;
    for (unsigned offset=0; offset<0x100; ++offset) {
        memory[fixture::kNarrowDataBase+offset]=static_cast<uint8_t>(0x20+offset);
        memory[fixture::kWideDataBase+offset]=static_cast<uint8_t>(0x80+offset);
        memory[fixture::kEsDataBase+offset]=0xcc;
        memory[wide_es_base+offset]=0xdd;
        if (compare) {
            memory[fixture::kNarrowDataBase+offset]=not_equal ? 1 : 0x5a;
            memory[fixture::kWideDataBase+offset]=not_equal ? 1 : 0x5a;
            memory[fixture::kEsDataBase+offset]=not_equal ? 0 : 0x5a;
            memory[wide_es_base+offset]=not_equal ? 0 : 0x5a;
        }
    }

    std::vector<fixture::ExpectedPc> trace(fixture::kPcTrace,fixture::kPcTrace+10);
    std::vector<uint8_t> program, handler_code;
    uint16_t pc=0x0200;
    auto emit=[&](std::initializer_list<uint8_t> bytes) {
        const uint16_t start=pc;
        program.insert(program.end(),bytes.begin(),bytes.end());
        pc+=bytes.size();
        trace.push_back({8,start,8,pc});
    };
    auto mov_imm=[&](uint8_t opcode, uint16_t value) {
        emit({opcode,static_cast<uint8_t>(value),static_cast<uint8_t>(value>>8)});
    };
    mov_imm(0xb8,source_selector); emit({0x8e,0xd8}); // DS
    mov_imm(0xb8,0x0020); emit({0x8e,0xc0});          // ES
    mov_imm(0xb8,0x0028); emit({0x8e,0xd0});          // SS
    mov_imm(0xbc,0x0080);
    mov_imm(0xbe,initial_si); mov_imm(0xbf,initial_di);
    mov_imm(0xba,0x1234); mov_imm(0xb9,count); mov_imm(0xb8,0xcafe);
    const uint16_t fault_ip=pc;
    program.push_back(0x3e); // Include the first prefix in the saved IP.
    if (repeat) program.push_back(not_equal ? 0xf2 : 0xf3);
    const uint8_t opcode=move ? (word ? 0xa5 : 0xa4) :
        compare ? (word ? 0xa7 : 0xa6) :
        kind==StringFaultKind::Store ? (word ? 0xab : 0xaa) : (word ? 0x6f : 0x6e);
    program.push_back(opcode);
    const uint16_t successor_ip=fault_ip+(repeat ? 3 : 2);
    program.push_back(0x45); program.push_back(0xf4); // INC BP; HLT, no padding.
    std::copy(program.begin(),program.end(),memory.begin()+fixture::kCodeBase+0x0200);

    uint16_t handler_pc=0x0300;
    auto handler_emit=[&](std::initializer_list<uint8_t> bytes) {
        const uint16_t start=handler_pc;
        handler_code.insert(handler_code.end(),bytes.begin(),bytes.end());
        handler_pc+=bytes.size();
        trace.push_back({fixture::kHandlerSelector,start,fixture::kHandlerSelector,handler_pc});
    };
    handler_emit({0x83,0xc4,0x02}); handler_emit({0x50});
    handler_emit({0xb8,static_cast<uint8_t>(source_fault ? 0x10 : wide_es_selector),0x00});
    handler_emit({0x8e,static_cast<uint8_t>(source_fault ? 0xd8 : 0xc0)});
    handler_emit({0x58});
    if (advance_si) handler_emit({0x83,static_cast<uint8_t>(backward ? 0xc6 : 0xee),static_cast<uint8_t>(width)});
    if (advance_di) handler_emit({0x83,static_cast<uint8_t>(backward ? 0xc7 : 0xef),static_cast<uint8_t>(width)});
    if (wrap) handler_emit({static_cast<uint8_t>(source_fault ? 0xbe : 0xbf),0x0f,0x00});
    if (repeat) handler_emit({0x83,0xc1,static_cast<uint8_t>(repair_cx)});
    handler_code.push_back(0xcf);
    trace.push_back({fixture::kHandlerSelector,handler_pc,8,fault_ip});
    trace.push_back({8,fault_ip,8,successor_ip});
    trace.push_back({8,successor_ip,8,static_cast<uint16_t>(successor_ip+1)});
    trace.push_back({8,static_cast<uint16_t>(successor_ip+1),8,static_cast<uint16_t>(successor_ip+2)});
    std::copy(handler_code.begin(),handler_code.end(),memory.begin()+fixture::kHandlerBase+0x0300);

    // External-memory and port oracle: enumerate successful prefix elements,
    // the already-completed MOVS source read, and the exact retry transfers.
    std::vector<StringTransfer> expected;
    auto source_reads=[&](uint32_t base,uint16_t offset,uint8_t segment=3) {
        for (unsigned byte=0; byte<width; ++byte)
            expected.push_back({base+offset+byte,memory[base+offset+byte],false,false,segment});
    };
    auto destination_writes=[&](uint32_t base,uint16_t offset,uint32_t source_base,uint16_t source_offset) {
        for (unsigned byte=0; byte<width; ++byte) {
            const uint8_t value=kind==StringFaultKind::Store ?
                static_cast<uint8_t>(byte==0 ? 0xfe : 0xca) : memory[source_base+source_offset+byte];
            expected.push_back({kind==StringFaultKind::Output ? 0x1234+byte : base+offset+byte,
                value,true,kind==StringFaultKind::Output,0});
        }
    };
    for (unsigned i=0; i<completed; ++i) {
        const uint16_t si=initial_si+i*delta, di=initial_di+i*delta;
        if (compare) source_reads(fixture::kEsDataBase,di,0);
        if (kind!=StringFaultKind::Store) source_reads(before_source,si);
        if (!compare) destination_writes(fixture::kEsDataBase,di,before_source,si);
    }
    if (kind==StringFaultKind::MoveDestination) source_reads(before_source,retry_si);
    if (kind==StringFaultKind::CompareSource) source_reads(fixture::kEsDataBase,fault_base_di,0);
    const size_t before_fault=expected.size();
    for (unsigned i=0; i<remaining; ++i) {
        const uint16_t si=retry_si+i*delta, di=retry_di+i*delta;
        if (compare) source_reads(after_dest,di,0);
        if (kind!=StringFaultKind::Store) source_reads(fixture::kWideDataBase,si);
        if (!compare) destination_writes(after_dest,di,fixture::kWideDataBase,si);
    }

    VerilatedContext context;
    Vintel_80286 dut(&context);
    dut.clk=0; dut.rst_n=0; dut.bus_ready_i=1; dut.bus_rdata_i=0;
    dut.intr_i=0; dut.nmi_i=0; dut.inta_ready_i=1; dut.inta_vector_i=0;
    for (unsigned i=0; i<3; ++i) {
        dut.clk=0; dut.eval(); dut.clk=1; dut.eval(); context.timeInc(1);
    }
    dut.clk=0; dut.rst_n=1;
    bool packet=false, entered=false, stalled=false, saw_operand_stall=false;
    BusSnapshot previous{};
    size_t observed=0, retired=0;
    unsigned elements=0, cycles=0;
    std::vector<Transfer> frame;
    for (; cycles<50000 && !dut.halted_o; ++cycles) {
        dut.clk=0; dut.eval();
        const uint32_t address=dut.bus_addr_o & 0xffffffu;
        const bool ready=!waits || !dut.bus_req_o || stalled;
        dut.bus_ready_i=ready; dut.bus_rdata_i=memory[address]; dut.eval();
        BusSnapshot bus{dut.bus_req_o!=0,address,dut.bus_fetch_o!=0,dut.bus_write_o!=0,
            dut.bus_io_o!=0,dut.bus_segmented_o!=0,static_cast<uint8_t>(dut.bus_segment_o),
            static_cast<uint8_t>(dut.bus_kind_o),static_cast<uint16_t>(dut.bus_offset_o),
            static_cast<uint8_t>(dut.bus_size_o),static_cast<uint8_t>(dut.bus_wdata_o)};
        if (stalled && !(bus==previous)) fail("string fault bus changed while READY stalled");
        const bool operand=bus.io || (bus.address>=fixture::kWideDataBase &&
            bus.address<fixture::kStackBase) ||
            (bus.address>=wide_es_base && bus.address<wide_es_base+0x10000);
        if (bus.request && operand) {
            if (observed>=expected.size()) fail("extra string operand request");
            const auto& item=expected[observed];
            if (bus.address!=item.address || bus.write!=item.write || bus.io!=item.io ||
                bus.fetch || bus.size!=width || bus.segmented==bus.io ||
                (!bus.io && bus.segment!=item.segment) ||
                (!bus.io && bus.kind!=(bus.write ? 1 : 0)) ||
                (bus.write ? bus.write_data : dut.bus_rdata_i)!=item.value)
                fail("string fault operand order/address/data mismatch");
            if (!ready) saw_operand_stall=true;
            if (ready) ++observed;
        }
        if (bus.request && ready && bus.write && !bus.io) {
            memory[bus.address]=bus.write_data;
            if (packet && !entered && bus.address>=fixture::kStackBase+0x78 && bus.address<=fixture::kStackBase+0x7f)
                frame.push_back({bus.address,bus.write_data,true});
        }
        stalled=bus.request && !ready; previous=bus;
        dut.clk=1; dut.eval(); context.timeInc(1);
        if (dut.fault_o) fail("string fault recovery stopped the CPU");
        if (dut.element_o) ++elements;
        if (dut.event_packet_valid_o && !packet) {
            packet=true;
            if (!dut.event_packet_protected_o || dut.event_vector_o!=13 ||
                !dut.event_packet_error_valid_o || dut.event_packet_error_code_o!=0 ||
                !dut.event_packet_restartable_o || dut.event_packet_saved_cs_o!=8 ||
                dut.event_packet_saved_ip_o!=fault_ip || dut.event_packet_saved_flags_o!=saved_flags ||
                dut.event_packet_saved_sp_o!=0x80 || reg(dut,0)!=0xcafe ||
                reg(dut,6)!=fault_si || reg(dut,7)!=fault_di || reg(dut,1)!=fault_cx ||
                elements!=completed || observed!=before_fault)
                fail("string-fault packet or native indices/count mismatch");
        }
        if (dut.event_o) {
            if (!packet || entered || visible_cs(dut)!=fixture::kHandlerSelector || dut.ip_o!=0x0300 ||
                reg(dut,4)!=0x78 || dut.flags_o!=(saved_flags & 0xfcff))
                fail("string fault handler entry mismatch");
            entered=true;
        }
        if (dut.retire_o) {
            if (retired>=trace.size()) fail("extra string-fault retirement");
            const auto& item=trace[retired++];
            if (dut.retire_pc_o!=physical_pc(item.cs,item.ip) || visible_cs(dut)!=item.next_cs || dut.ip_o!=item.next_ip)
                fail("string-fault exact retirement/successor mismatch");
        }
    }
    const uint16_t final_si=(move || compare || kind==StringFaultKind::Output) ? retry_si+remaining*delta : initial_si;
    const uint16_t final_di=kind==StringFaultKind::Output ? initial_di : retry_di+remaining*delta;
    // The exact successor is INC BP, so the final visible status flags are
    // distinct from the saved comparison flags checked in the fault frame.
    const uint16_t final_flags=(backward ? 0x0400 : 0) | (compare ? 0x0202 : 0x0203);
    if (cycles==50000 || !packet || !entered || retired!=trace.size() || observed!=expected.size() ||
        elements!=completed+remaining || reg(dut,6)!=final_si || reg(dut,7)!=final_di ||
        reg(dut,1)!=(repeat ? 0 : count) || reg(dut,0)!=0xcafe || reg(dut,4)!=0x80 || reg(dut,5)!=1 ||
        visible_ds(dut)!=fixture::kWideDataSelector ||
        visible_es(dut)!=(source_fault ? fixture::kEsSelector : wide_es_selector) ||
        dut.flags_o!=final_flags || (waits && !saw_operand_stall)) {
        std::fprintf(stderr,
            "DETAIL: kind=%u compare=%u source_fault=%u repeat=%u completed=%u remaining=%u cycles=%u packet=%u entered=%u retired=%zu/%zu transfers=%zu/%zu elements=%u/%u\n"
            "  SI=%04x/%04x DI=%04x/%04x CX=%04x/%04x AX=%04x SP=%04x BP=%04x DS=%04x/%04x ES=%04x/%04x FLAGS=%04x/%04x stalls=%u\n",
            static_cast<unsigned>(kind),compare,source_fault,repeat,completed,remaining,cycles,packet,entered,
            retired,trace.size(),observed,expected.size(),elements,completed+remaining,
            reg(dut,6),final_si,reg(dut,7),final_di,reg(dut,1),repeat ? 0 : count,reg(dut,0),reg(dut,4),
            reg(dut,5),visible_ds(dut),fixture::kWideDataSelector,visible_es(dut),
            source_fault ? fixture::kEsSelector : wide_es_selector,dut.flags_o,final_flags,saw_operand_stall);
        fail("string fault final checkpoint mismatch");
    }
    const fixture::ExpectedDataTransfer expected_frame[] = {
        {fixture::kStackBase+0x7e,static_cast<uint8_t>(saved_flags),true},
        {fixture::kStackBase+0x7f,static_cast<uint8_t>(saved_flags>>8),true},
        {fixture::kStackBase+0x7c,0x08,true},{fixture::kStackBase+0x7d,0x00,true},
        {fixture::kStackBase+0x7a,static_cast<uint8_t>(fault_ip),true},
        {fixture::kStackBase+0x7b,static_cast<uint8_t>(fault_ip>>8),true},
        {fixture::kStackBase+0x78,0x00,true},{fixture::kStackBase+0x79,0x00,true}
    };
    compare_transfers(frame,expected_frame,8,"string fault frame");
    const char* name=kind==StringFaultKind::MoveSource ? "MOVS source" :
        kind==StringFaultKind::MoveDestination ? "MOVS destination" :
        kind==StringFaultKind::Store ? "STOS" : kind==StringFaultKind::Output ? "OUTS source" :
        kind==StringFaultKind::CompareSource ? "CMPS source" : "CMPS destination";
    std::printf("PASS: %s %s%s%s count=%u DF=%u native fault/repair, exact bus and PC%s\n",
        name,word ? "word" : "byte",repeat ? (not_equal ? " REPNE" : " REP/REPE") : "",wrap ? " 64K-wrap" : "",
        count,backward ? 1 : 0,
        waits ? " with READY stalls" : " without stalls");
}

#endif

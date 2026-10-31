#include "Vintel_80286.h"
#include "protected_mode_fixture.h"
#include "verilated.h"
#include <cstdint>
#include <fstream>
#include <iostream>
#include <iterator>
#include <limits>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <unordered_map>
#include <vector>
#include <algorithm>
#include <utility>

static void check(bool ok, const char* message) {
    if (!ok) throw std::runtime_error(message);
}

struct Bench {
    Vintel_80286 d;
    std::unordered_map<uint32_t, uint8_t> memory;
    std::vector<uint32_t> accepted;
    std::unordered_map<uint16_t,uint8_t> ports;
    struct Transfer {
        uint32_t address; uint8_t value; bool write,io;
        bool segmented=false; unsigned role=0,kind=0,offset=0,size=0;
    };
    std::vector<Transfer> data_transfers;
    unsigned cycles = 0;
    unsigned retired = 0;
    unsigned stalls = 0;
    bool wait_mode = true;
    bool acknowledge = false;
    uint8_t interrupt_vector = 0;
    unsigned acknowledgements = 0;

    Bench() {
        d.intr_i=0; d.nmi_i=0; d.inta_ready_i=0; d.inta_vector_i=0;
        d.busy_i=0; d.error_n_i=1;
    }

    void put(uint32_t address, std::initializer_list<uint8_t> bytes) {
        for (auto byte : bytes) memory[address++] = byte;
    }
    uint16_t reg(unsigned n) const {
        return uint16_t(d.regs_o[n / 2] >> ((n % 2) * 16));
    }
    uint16_t cs() const { return uint16_t(d.segs_o >> 16); }
    uint32_t cache_base(unsigned n) const {
        const unsigned bit=n*24,word=bit/32,shift=bit%32;
        uint64_t value=d.seg_bases_o[word];
        if (shift>8 && word<2) value|=uint64_t(d.seg_bases_o[word+1])<<32;
        return uint32_t(value>>shift)&0xffffff;
    }
    void check_real_caches() const {
        check(!(d.msw_o&1),"cache prelude unexpectedly enabled PE");
        check(d.seg_limits_o==0xffffffffffffffffULL && d.seg_access_o==0x93939393 && d.seg_valid_o==15,
              "real-cache limits/usability/A14 attributes");
        for (unsigned n=0;n<4;++n) {
            const uint16_t selector=uint16_t(d.segs_o>>(16*n));
            const uint32_t expected=n==1 && selector==0xf000 && d.cs_base_o==0xff0000 ? 0xff0000 : uint32_t(selector)<<4;
            check(cache_base(n)==expected,"visible selector/real hidden-base coherence");
        }
        check(cache_base(1)==d.cs_base_o,"CS cache debug packing");
    }
    void tick(bool wait = true, int ready_override = -1) {
        const uint32_t bases_before[]={d.seg_bases_o[0],d.seg_bases_o[1],d.seg_bases_o[2]};
        const uint32_t regs_before[]={d.regs_o[0],d.regs_o[1],d.regs_o[2],d.regs_o[3]};
        const uint64_t segs_before=d.segs_o;
        const auto limits_before=d.seg_limits_o;
        const auto access_before=d.seg_access_o;
        const auto valid_before=d.seg_valid_o;
        d.clk = 0;
        d.bus_ready_i = ready_override < 0 ? (!wait || (cycles % 4 == 3)) : ready_override != 0;
        d.inta_ready_i = acknowledge && (!wait || cycles%4==3);
        d.inta_vector_i = d.inta_ready_i ? interrupt_vector : uint8_t(cycles^0x5a);
        d.bus_rdata_i = uint8_t(cycles ^ 0xa5); // Deliberately invalid until accepted.
        d.eval();
        const bool pending = d.bus_req_o;
        const bool pending_ack = d.inta_req_o;
        if (pending_ack && d.inta_ready_i) ++acknowledgements;
        check(!(pending && pending_ack),"memory transfer overlapped INTR acknowledgement");
        const uint32_t address = d.bus_addr_o;
        const unsigned operation=(d.bus_fetch_o<<2)|(d.bus_write_o<<1)|d.bus_io_o;
        const unsigned write_data=d.bus_wdata_o;
        const unsigned segment=d.bus_segment_o,kind=d.bus_kind_o,offset=d.bus_offset_o,size=d.bus_size_o;
        const bool segmented=d.bus_segmented_o;
        if (pending) {
            if (d.bus_fetch_o) check(!d.bus_write_o && !d.bus_io_o,
                                    "instruction fetch asserted write/I/O controls");
            if (d.bus_fetch_o) check(segmented && segment==1 && kind==2 && size==1 && offset==d.ip_o,
                                    "instruction fetch lost CS/execute context");
            if (segmented) check(!d.bus_io_o && address==((cache_base(segment)+offset)&0xffffff) && size>=1 && size<=6,
                                 "segmented bus address/context incoherent");
            if (d.bus_io_o) check(!segmented,"I/O request entered segmented path");
        }
        if (pending && d.bus_ready_i) {
            if (d.bus_fetch_o) {
                auto it = memory.find(address);
                if (it == memory.end()) {
                    std::ostringstream detail;
                    detail << "unmapped instruction fetch at 0x" << std::hex << address
                           << " for CS:IP " << cs() << ":" << d.ip_o
                           << " base 0x" << d.cs_base_o
                           << " (bus offset 0x" << d.bus_offset_o << ")";
                    throw std::runtime_error(detail.str());
                }
                d.bus_rdata_i = it->second;
                accepted.push_back(address);
            } else {
                if (d.bus_io_o) {
                    if (d.bus_write_o) ports[uint16_t(address)]=d.bus_wdata_o;
                    else d.bus_rdata_i=ports[uint16_t(address)];
                } else {
                    if (d.bus_write_o) memory[address]=d.bus_wdata_o;
                    else d.bus_rdata_i=memory[address];
                }
                data_transfers.push_back({address,uint8_t(d.bus_write_o?d.bus_wdata_o:d.bus_rdata_i),
                                          bool(d.bus_write_o),bool(d.bus_io_o),segmented,segment,kind,offset,size});
            }
        }
        d.eval();
        d.clk = 1;
        d.eval();
        // Section 8.3's post-load validation faults switch into the incoming
        // task context before the exception handler's event_o pulse.
        bool incoming_task_fault_context=d.event_packet_valid_o && d.event_packet_protected_o &&
            d.segs_o!=segs_before;
        for (unsigned i=0;i<4;++i)
            incoming_task_fault_context=incoming_task_fault_context ||
                (d.event_packet_valid_o && d.event_packet_protected_o && d.regs_o[i]!=regs_before[i]);
        if (d.rst_n && !d.retire_o && !d.event_o && !incoming_task_fault_context) {
            for (unsigned i=0;i<3;++i) check(d.seg_bases_o[i]==bases_before[i],"partial hidden base escaped before commit");
            check(d.seg_limits_o==limits_before && d.seg_access_o==access_before && d.seg_valid_o==valid_before,
                  "partial cache attributes escaped before commit");
        }
        if (pending_ack && !d.inta_ready_i && d.rst_n)
            check(d.inta_req_o && !d.bus_req_o,"INTR acknowledgement did not hold");
        if (pending && !d.bus_ready_i && d.rst_n) {
            check(d.bus_req_o && d.bus_addr_o == address, "request changed during wait");
            check(operation==unsigned((d.bus_fetch_o<<2)|(d.bus_write_o<<1)|d.bus_io_o),"bus operation changed during wait");
            if (d.bus_write_o) check(d.bus_wdata_o==write_data,"write data changed during wait");
            check(d.bus_segmented_o==segmented && d.bus_segment_o==segment && d.bus_kind_o==kind &&
                  d.bus_offset_o==offset && d.bus_size_o==size,"reference context changed during wait");
            ++stalls;
        }
        if (d.retire_o) ++retired;
        ++cycles;
    }
    void reset() {
        d.rst_n = 0;
        tick(); tick();
        check(d.ip_o == 0xfff0 && cs() == 0xf000, "reset CS:IP");
        check(d.cs_base_o == 0xff0000 && d.flags_o == 2 && d.msw_o == 0xfff0,
              "reset cache/FLAGS/MSW");
        check((d.segs_o & 0xffffffff0000ffffULL) == 0, "reset data segments");
        check(!d.bus_req_o && !d.fault_o && !d.halted_o && !d.shutdown_o && !d.retire_o, "reset outputs");
        check(!d.event_o && !d.element_o,"reset left an event/element pulse active");
        check(!d.event_packet_valid_o && !d.event_packet_protected_o &&
              !d.event_packet_error_valid_o && !d.event_packet_restartable_o &&
              d.event_packet_error_code_o==0 && d.event_packet_saved_cs_o==0 &&
              d.event_packet_saved_ip_o==0 && d.event_packet_saved_flags_o==0 &&
              d.event_packet_saved_sp_o==0 && !d.event_packet_deferred_valid_o &&
              !d.event_packet_deferred_flags_valid_o &&
              !d.event_packet_deferred_register_write_o && !d.event_packet_deferred_sp_valid_o &&
              d.event_packet_deferred_register_o==0 && d.event_packet_deferred_flags_o==0 &&
              d.event_packet_deferred_register_value_o==0 && d.event_packet_deferred_sp_o==0 &&
              d.event_packet_deferred_ip_o==0 && !d.event_packet_deferred_call_o,
              "reset left an exception packet active");
        check_real_caches();
        d.rst_n = 1;
        d.clk = 0; d.eval();
        check(!d.bus_req_o && d.bus_addr_o == 0xfffff0, "reset boundary/vector physical address");
    }
    void step(uint32_t pc, uint8_t op, uint16_t next_cs, uint16_t next_ip,
              bool wait) {
        for (unsigned n = 0; n < 2000000; ++n) {
            tick(wait);
            if (d.fault_o) {
                std::string detail="unexpected diagnostic stop at CS:IP " +
                    std::to_string(cs()) + ":" + std::to_string(d.ip_o) +
                    " code " + std::to_string(d.fault_code_o) +
                    " event " + std::to_string(d.event_vector_o) +
                    " packet " + std::to_string(d.event_packet_valid_o) +
                    " error-valid " + std::to_string(d.event_packet_error_valid_o) +
                    " error " + std::to_string(d.event_packet_error_code_o) +
                    " transfers " + std::to_string(data_transfers.size());
                if (!data_transfers.empty()) {
                    const auto& last=data_transfers.back();
                    detail+=" last="+std::to_string(last.address)+":"+
                        std::to_string(last.write)+":"+std::to_string(last.value);
                }
                throw std::runtime_error(detail);
            }
            if (d.retire_o) {
                if (d.retire_pc_o != pc || d.retire_opcode_o != op)
                    throw std::runtime_error("retirement origin/opcode: expected PC/op="+
                        std::to_string(pc)+"/"+std::to_string(op)+", got "+
                        std::to_string(d.retire_pc_o)+"/"+std::to_string(d.retire_opcode_o)+
                        " at CS:IP "+std::to_string(cs())+":"+std::to_string(d.ip_o)+
                        " base "+std::to_string(d.cs_base_o));
                if (cs()!=next_cs || d.ip_o!=next_ip) {
                    throw std::runtime_error("exact post-instruction CS:IP at "+
                        std::to_string(pc)+" opcode "+std::to_string(op)+": got "+
                        std::to_string(cs())+":"+std::to_string(d.ip_o)+", expected "+
                        std::to_string(next_cs)+":"+std::to_string(next_ip));
                }
                if (!(d.msw_o & 1)) check_real_caches();
                if (d.bus_req_o && !d.halted_o)
                    check(d.bus_addr_o == d.cs_base_o + next_ip,"next instruction fetch");
                // Bus-idle event boundaries may delay the next fetch. Its
                // actual bytes/address and next retirement are checked by
                // tick/step; no instruction padding or PC tolerance is used.
                return;
            }
        }
        throw std::runtime_error("instruction timeout");
    }
    void step(uint32_t pc, uint8_t op, uint16_t next_cs, uint16_t next_ip) {
        step(pc,op,next_cs,next_ip,wait_mode);
    }
    void stop(unsigned code, uint16_t ip) {
        const auto before = retired;
        for (unsigned n = 0; n < 100 && !d.fault_o; ++n) tick();
        check(d.fault_o && d.fault_code_o == code && d.ip_o == ip, "diagnostic code/IP");
        check(retired == before && !d.bus_req_o, "unsupported instruction retired/requested");
        for (unsigned n = 0; n < 8; ++n) tick();
        check(retired == before && !d.bus_req_o, "diagnostic stop persistence");
    }
    void processor_fault(unsigned vector, uint16_t saved_ip, bool wait=true,
                         uint32_t vector_base=0, unsigned accepted_acks=0) {
        const auto saved_flags=uint16_t(d.flags_o),saved_cs=cs(),saved_sp=reg(4);
        uint16_t saved_regs[8];
        for (unsigned r=0;r<8;++r) saved_regs[r]=reg(r);
        const auto saved_segments=uint64_t(d.segs_o);
        const auto before=retired,acks=acknowledgements;
        const auto stack=cache_base(2);
        put(vector_base+4*vector,{0,1,0,0x20});
        data_transfers.clear();
        for (unsigned n=0;n<2048 && !d.event_o;++n) {
            tick(wait);
            check(!d.fault_o,"#UD became a diagnostic stop");
            check(retired==before,"invalid instruction retired during #UD entry");
        }
        check(d.event_o && d.event_vector_o==vector && cs()==0x2000 && d.ip_o==0x100,
              "#UD vector/handler entry");
        check(d.event_packet_valid_o && !d.event_packet_protected_o &&
              !d.event_packet_error_valid_o && d.event_packet_error_code_o==0 &&
              d.event_packet_saved_cs_o==saved_cs && d.event_packet_saved_ip_o==saved_ip &&
              d.event_packet_saved_flags_o==saved_flags && d.event_packet_saved_sp_o==saved_sp,
              "real-mode event lost its frozen fault/frame packet");
        check(!d.retire_o && retired==before && acknowledgements==acks+accepted_acks,"fault retirement/acknowledgement");
        check(reg(4)==uint16_t(saved_sp-6),"#UD pushed an error code or wrong frame size");
        for (unsigned r=0;r<8;++r) if(r!=4) check(reg(r)==saved_regs[r],"#UD changed input GPR");
        check((uint64_t(d.segs_o)&0xffffffff0000ffffULL)==(saved_segments&0xffffffff0000ffffULL),
              "#UD changed data/stack selectors");
        check(d.flags_o==(saved_flags&0xfcff),"#UD live FLAGS/IF/TF");
        const uint16_t words[]={saved_flags,saved_cs,saved_ip};
        check(data_transfers.size()==10,"#UD touched an operand or produced extra frame traffic");
        for(unsigned i=0;i<10;++i) {
            const auto& transfer=data_transfers[i];
            const uint32_t address=i<4 ? vector_base+4*vector+i :
                stack+uint16_t(saved_sp-2*(1+(i-4)/2))+(i&1);
            check(transfer.address==address && transfer.write==(i>=4) && !transfer.io,
                  "#UD exact IVT/frame transaction");
            if (i>=4) check(transfer.value==uint8_t(words[(i-4)/2]>>((i&1)*8)),
                            "#UD saved FLAGS/CS/prefix IP");
        }
    }
    void ud_fault(uint16_t saved_ip, bool wait=true, uint32_t vector_base=0) {
        processor_fault(6,saved_ip,wait,vector_base);
    }
};

#include "hardware_replay.h"
#include "undefined_opcode_cases.h"
#include "protection_fault_cases.h"

static void directed(bool wait) {
    Bench b;
    b.put(0xfffff0, {0xea,0x00,0x01,0x00,0xf0});
    uint32_t p = 0xf0100;
    for (unsigned n = 0; n < 8; ++n) {
        b.put(p, {uint8_t(0xb8+n),uint8_t(0x10+n),uint8_t(0xa0+n)});
        p += 3;
    }
    for (unsigned n = 0; n < 8; ++n) {
        b.put(p, {uint8_t(0xb0+n),uint8_t(0x30+n)}); p += 2;
    }
    b.put(p, {0xf9,0xf5,0xf9,0xf8,0xfb,0xfa,0xfd,0xfc,0x90,0xe9,0x24,0x00});
    b.put(0xf0158, {0xeb,0x06});
    b.put(0xf0160, {0xeb,0xfc});
    b.put(0xf015e, {0xf4});
    b.reset();
    b.step(0xfffff0,0xea,0xf000,0x0100,wait);
    check(b.d.cs_base_o == 0xf0000, "same-selector far jump must reload hidden base");
    p = 0xf0100;
    uint16_t expected[8] = {};
    for (unsigned n = 0; n < 8; ++n) {
        b.step(p,uint8_t(0xb8+n),0xf000,uint16_t(p+3),wait);
        expected[n] = uint16_t(((0xa0+n)<<8) | (0x10+n));
        for (unsigned r=0;r<8;++r) check(b.reg(r)==expected[r], "MOV word immediate register");
        p += 3;
    }
    for (unsigned n = 0; n < 8; ++n) {
        b.step(p,uint8_t(0xb0+n),0xf000,uint16_t(p+2),wait);
        unsigned r = n & 3;
        expected[r] = n < 4 ? uint16_t((expected[r]&0xff00)|(0x30+n))
                           : uint16_t((expected[r]&0xff)|((0x30+n)<<8));
        for (unsigned j=0;j<8;++j) check(b.reg(j)==expected[j], "MOV byte alias preservation");
        p += 2;
    }
    const uint8_t ops[] = {0xf9,0xf5,0xf9,0xf8,0xfb,0xfa,0xfd,0xfc,0x90};
    const uint16_t flags[] = {3,2,3,2,0x202,2,0x402,2,2};
    for (unsigned n=0;n<9;++n) {
        b.step(p,ops[n],0xf000,uint16_t(p+1),wait);
        check(b.d.flags_o==flags[n], "FLAGS control or preservation"); ++p;
    }
    b.step(p,0xe9,0xf000,0x0158,wait);
    b.step(0xf0158,0xeb,0xf000,0x0160,wait);
    b.step(0xf0160,0xeb,0xf000,0x015e,wait);
    b.step(0xf015e,0xf4,0xf000,0x015f,wait);
    const auto count = b.retired;
    for (unsigned n=0;n<12;++n) b.tick(wait);
    check(b.d.halted_o && !b.d.bus_req_o && b.retired==count, "HLT must retire only once");
    if (wait) check(b.stalls>0, "wait-state test vacuity");
    b.reset();
}

static void boundaries() {
    Bench b;
    b.put(0xfffff0,{0xe9,0x00,0x01});
    b.put(0xff00f3,{0x90,0xea,0x10,0x00,0xff,0xff});
    b.put(0x100000,{0xf4});
    b.reset();
    b.step(0xfffff0,0xe9,0xf000,0x00f3);
    check(b.d.cs_base_o==0xff0000, "near jump must retain reset base");
    b.step(0xff00f3,0x90,0xf000,0x00f4);
    b.step(0xff00f4,0xea,0xffff,0x0010);
    b.step(0x100000,0xf4,0xffff,0x0011);

    Bench wrap;
    wrap.put(0xfffff0,{0xea,0xfc,0xff,0x00,0xf0});
    wrap.put(0xffffc,{0xe9,0xa7,0x00});
    wrap.put(0xf00a6,{0xf4});
    wrap.reset();
    wrap.step(0xfffff0,0xea,0xf000,0xfffc);
    wrap.step(0xffffc,0xe9,0xf000,0x00a6);
    wrap.step(0xf00a6,0xf4,0xf000,0x00a7);

    Bench bad;
    bad.put(0xfffff0,{0x0f,0xff}); bad.reset(); bad.ud_fault(0xfff0); bad.reset();
    Bench limit;
    limit.put(0xfffff0,{0xea,0xfe,0xff,0x00,0xf0});
    limit.put(0xffffe,{0xb8}); limit.reset();
    limit.step(0xfffff0,0xea,0xf000,0xfffe); limit.stop(2,0xfffe);
    check(limit.accepted.size()==6, "cross-limit operands must not be fetched");

    Bench stalled;
    stalled.reset();
    stalled.d.bus_ready_i=0;
    // reset() used two cycles, so the next tick is a guaranteed stalled cycle.
    stalled.tick();
    check(stalled.accepted.empty(), "stall reset precondition");
    stalled.reset();

    Bench partial;
    partial.put(0xfffff0,{0xb8,0x34,0x12});
    partial.reset();
    for (unsigned n=0;n<100 && partial.accepted.size()<2;++n) partial.tick();
    check(partial.accepted.size()==2,"partial immediate fetch timeout");
    check(partial.reg(0)==0 && partial.retired==0, "partial immediate committed early");
    partial.reset();
    partial.put(0xfffff0,{0xf4});
    partial.step(0xfffff0,0xf4,0xf000,0xfff1);
    check(partial.reg(0)==0, "partial instruction survived reset");
}

static void rejection_and_reset() {
    unsigned rejected=0;
    auto reject = [&](uint8_t opcode,uint8_t modrm) {
        Bench b;
        b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
        b.put(0xf0100,{0xb8,0x34,0x12,0xf9,opcode,modrm});
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100);
        b.step(0xf0100,0xb8,0xf000,0x103); b.step(0xf0103,0xf9,0xf000,0x104);
        const bool undocumented_shift=(opcode==0xc0 || opcode==0xc1 || (opcode>=0xd0 && opcode<=0xd3));
        if (undocumented_shift) b.stop(1,0x104);
        else b.ud_fault(0x104);
        check(b.reg(0)==0x1234 && b.d.flags_o==3,"rejected encoding changed input state");
        for (unsigned r=1;r<8;++r) if(r!=4) check(b.reg(r)==0,"rejected encoding changed other register");
        check(b.accepted.size()==11,"rejected encoding fetched an operand");
        ++rejected;
    };
    for (auto op : {0xc0,0xc1,0xd0,0xd1,0xd2,0xd3})
        for (unsigned r=0;r<8;++r) reject(uint8_t(op),uint8_t(0xf0|r)); // undocumented /6
    for (auto op : {0xfe,0xff,0xf6,0xf7})
        for (unsigned extension=0;extension<8;++extension) {
            const bool supported = op==0xff ? extension<=2 || extension==4 || extension==6 :
                                   op==0xfe ? extension<2 : true;
            if (!supported)
                for (unsigned r=0;r<8;++r) reject(uint8_t(op),uint8_t(0xc0|extension*8|r));
        }
    for (auto op : {0x8c,0x8e})
        for (unsigned extension=0;extension<8;++extension)
            if (extension>=4 || (op==0x8e && extension==1))
                for (unsigned r=0;r<8;++r) reject(uint8_t(op),uint8_t(0xc0|extension*8|r));
    for (unsigned encoding=0xc0;encoding<=0xff;++encoding) reject(0x62,uint8_t(encoding));

    for (unsigned cut=0;cut<100;++cut) {
        Bench b;
        b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
        b.put(0xf0100,{0xb8,0x01,0x80,0xb1,0x1f,0xd3,0xe0,0xf4});
        b.reset();
        for (unsigned n=0;n<cut;++n) b.tick();
        b.reset();
        for (unsigned r=0;r<8;++r) check(b.reg(r)==0,"reset left partial register state");
        b.step(0xfffff0,0xea,0xf000,0x100);
        b.step(0xf0100,0xb8,0xf000,0x103);
        b.step(0xf0103,0xb1,0xf000,0x105);
        b.step(0xf0105,0xd3,0xf000,0x107);
        check(b.reg(0)==0 && b.reg(1)==31 && (b.d.flags_o&0xc4)==0x44,"shift/reset replay result");
        b.step(0xf0107,0xf4,0xf000,0x108);
    }
    Bench limit;
    limit.put(0xfffff0,{0xea,0xfd,0xff,0x00,0xf0});
    limit.put(0xffffd,{0x81,0xc0}); limit.reset();
    limit.step(0xfffff0,0xea,0xf000,0xfffd); limit.stop(2,0xfffd);
    check(limit.accepted.size()==7,"ModR/M immediate crossed segment boundary");
    std::cout<<"PASS: "<<rejected<<" rejected ModR/M encodings, 100 reset cut points and immediate limit\n";
}

static void intel_shift_carry() {
    // Intel 210498-005 B-97 describes repeated shifts and the final bit shifted
    // into CF. Modern x86 oracles leave CF undefined for large logical counts,
    // so check the 286 contract directly with arithmetic/bit-index expectations.
    unsigned cases=0;
    for (unsigned wide=0;wide<2;++wide)
        for (unsigned right=0;right<2;++right)
            for (unsigned count=0;count<256;++count)
                for (unsigned value : {0u,1u,0x8181u,0xffffu}) {
                    const unsigned width=wide?16:8, mask=wide?0xffff:0xff, n=count&31;
                    const unsigned source=value&mask;
                    unsigned result=source, carry=1;
                    if (n) {
                        result=n>=width ? 0 : (right ? source>>n : (source<<n)&mask);
                        carry=n>width ? 0 : (right ? ((source>>(n-1))&1) : ((source>>(width-n))&1));
                    }
                    Bench b;
                    const uint8_t op=uint8_t(0xc0+wide);
                    b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
                    b.put(0xf0100,{0xb8,uint8_t(value),uint8_t(value>>8),0xf9,op,
                                   uint8_t(right?0xe8:0xe0),uint8_t(count),0xf4});
                    b.reset(); b.step(0xfffff0,0xea,0xf000,0x100);
                    b.step(0xf0100,0xb8,0xf000,0x103); b.step(0xf0103,0xf9,0xf000,0x104);
                    b.step(0xf0104,op,0xf000,0x107);
                    check(b.reg(0)==(wide?result:((value&0xff00)|result)),"Intel 286 shift result/count mask");
                    check((b.d.flags_o&1)==carry,"Intel 286 final shifted carry");
                    if (n==0) check(b.d.flags_o==3,"zero-count shift changed flags");
                    b.step(0xf0107,0xf4,0xf000,0x108); ++cases;
                }
    std::cout<<"PASS: "<<cases<<" Intel 286 shift-count/carry boundary cases\n";
}

static void memory_boundaries() {
    Bench reset_cs;
    reset_cs.put(0xfffff0,{0x2e,0xa0,0x10,0xf0,0xf4});
    reset_cs.put(0xfff010,{0xa5}); reset_cs.reset();
    reset_cs.step(0xfffff0,0xa0,0xf000,0xfff4);
    check(reset_cs.reg(0)==0xa5 && reset_cs.data_transfers.size()==1 &&
          reset_cs.data_transfers[0].address==0xfff010,"reset CS override used a 20-bit base");
    reset_cs.step(0xfffff4,0xf4,0xf000,0xfff5);
    for (unsigned count : {9u,10u}) {
        Bench b; b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
        for (unsigned n=0;n<count;++n) b.memory[0xf0100+n]=0x26;
        b.memory[0xf0100+count]=0x90; b.memory[0xf0101+count]=0xf4;
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100);
        if (count==9) {
            b.step(0xf0100,0x90,0xf000,0x10a); b.step(0xf010a,0xf4,0xf000,0x10b);
        } else {
            b.processor_fault(13,0x100); check(b.accepted.size()==15,"overlong instruction fetched an eleventh byte");
        }
    }
    for (uint8_t op : {uint8_t(0x8b),uint8_t(0x89),uint8_t(0xc5)}) {
        Bench b; b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
        b.put(0xf0100,{op,0x06,0xff,0xff}); b.reset();
        b.step(0xfffff0,0xea,0xf000,0x100); b.processor_fault(13,0x100);
    }
    Bench lea; lea.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
    lea.put(0xf0100,{0x8d,0x06,0xff,0xff,0xf4}); lea.reset();
    lea.step(0xfffff0,0xea,0xf000,0x100); lea.step(0xf0100,0x8d,0xf000,0x104);
    check(lea.reg(0)==0xffff && lea.data_transfers.empty(),"LEA incorrectly accessed memory or applied operand limit");
    lea.step(0xf0104,0xf4,0xf000,0x105);

    Bench partial; partial.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
    partial.put(0xf0100,{0xb8,0x01,0x01,0xf9,0x01,0x06,0x00,0x50,0xf4});
    partial.put(0x5000,{0xff,0x12}); partial.reset();
    partial.step(0xfffff0,0xea,0xf000,0x100);
    partial.step(0xf0100,0xb8,0xf000,0x103); partial.step(0xf0103,0xf9,0xf000,0x104);
    unsigned writes=0;
    for (unsigned n=0;n<100 && !writes;++n) {
        partial.tick(); writes=0;
        for (const auto& t : partial.data_transfers) if (t.write) ++writes;
    }
    check(writes==1 && partial.retired==3 && partial.d.flags_o==3,"partial memory write committed flags/retirement early");
    check(partial.memory[0x5000]==0 && partial.memory[0x5001]==0x12,"first memory byte acceptance");
    partial.reset();
    check(partial.memory[0x5000]==0 && partial.memory[0x5001]==0x12,"reset incorrectly rolled back/completed external write");
    Bench popf; popf.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
    popf.put(0xf0100,{0xbc,0x00,0x80,0x68,0x00,0x70,0x9d,0xf4}); popf.reset();
    popf.step(0xfffff0,0xea,0xf000,0x100); popf.step(0xf0100,0xbc,0xf000,0x103);
    popf.step(0xf0103,0x68,0xf000,0x106); popf.step(0xf0106,0x9d,0xf000,0x107);
    // Intel 210498-005 B-86: real-mode POPF does not alter NT or IOPL.
    check(popf.d.flags_o==2 && popf.reg(4)==0x8000,"80286 real-mode POPF changed NT/IOPL");
    popf.step(0xf0107,0xf4,0xf000,0x108);
    std::cout<<"PASS: memory/prefix/limit boundaries and reset between accepted word-write bytes\n";
}

static void real_mode_events() {
    auto word_at=[](const Bench& b,uint32_t a) {
        auto byte=[&](uint32_t p){auto i=b.memory.find(p); return i==b.memory.end()?0u:unsigned(i->second);};
        return byte(a)|(byte(a+1)<<8);
    };
    for (unsigned variant=0;variant<4;++variant) {
        Bench b; b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
        b.put(0xf0100,{0xbc,0x00,0x80,0xfb});
        const uint8_t vector=variant&1 ? 0x21 : 3;
        std::vector<uint8_t> code;
        if (variant&2) code.push_back(0x26);
        code.push_back(variant&1 ? 0xcd : 0xcc);
        if (variant&1) code.push_back(vector);
        for(unsigned n=0;n<code.size();++n) b.memory[0xf0104+n]=code[n];
        const uint16_t next=uint16_t(0x104+code.size());
        b.memory[0xf0000+next]=0x46; b.memory[0xf0001+next]=0xf4;
        b.put(unsigned(vector)*4,{0x00,0x01,0x00,0x20}); b.put(0x20100,{0x43,0xcf});
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100); b.step(0xf0100,0xbc,0xf000,0x103);
        b.step(0xf0103,0xfb,0xf000,0x104); b.step(0xf0104,variant&1?0xcd:0xcc,0x2000,0x100);
        check(b.d.event_o && b.d.event_vector_o==vector && b.reg(4)==0x7ffa,"software interrupt event/frame pointer");
        check(word_at(b,0x7ffa)==next && word_at(b,0x7ffc)==0xf000 && word_at(b,0x7ffe)==0x202,"software interrupt saved frame");
        check(b.d.flags_o==2,"software interrupt did not clear IF/TF");
        b.step(0x20100,0x43,0x2000,0x101); b.step(0x20101,0xcf,0xf000,next);
        check(b.d.flags_o==0x202 && b.reg(4)==0x8000 && b.reg(3)==1,"IRET did not restore the interrupted state");
        b.step(0xf0000+next,0x46,0xf000,uint16_t(next+1));
        check(b.reg(6)==1,"interrupt return did not execute the exact next instruction");
        b.step(0xf0001+next,0xf4,0xf000,uint16_t(next+2));
    }
    struct DivideFault { uint16_t ax,dx,bx; std::vector<uint8_t> code; };
    const std::vector<DivideFault> faults={
        {0x017e,0x1357,0,{0xf6,0xf3}}, {0x0100,0x1357,1,{0xf6,0xf3}},
        {0xff80,0x1357,0xffff,{0xf6,0xfb}}, {0x8000,0xffff,0xffff,{0xf7,0xfb}},
        {0,1,1,{0xf7,0xf3}}, {0x0201,0x1357,1,{0xf6,0xf4}},
        {0x1234,2,1,{0xf7,0xf2}}, {0,0x8000,0xffff,{0xf7,0xfb}},
        {0x1234,0x5678,0,{0x2e,0xf7,0xf3}}, {0x1234,0x5678,1,{0xf7,0x36,0x00,0x40}},
        {0x1234,0x5678,1,{0xd4,0}}, {0xbeef,0x5678,1,{0x2e,0xd4,0}}
    };
    for (const auto& test : faults) {
        Bench b; b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
        b.put(0xf0100,{0xbc,0x00,0x80,0xb8,uint8_t(test.ax),uint8_t(test.ax>>8),
                       0xba,uint8_t(test.dx),uint8_t(test.dx>>8),0xbb,uint8_t(test.bx),uint8_t(test.bx>>8)});
        for(unsigned n=0;n<test.code.size();++n) b.memory[0xf010c+n]=test.code[n];
        const uint16_t next=uint16_t(0x10c+test.code.size());
        b.memory[0xf0000+next]=0x46; b.memory[0xf0001+next]=0xf4;
        b.put(0,{0x00,0x01,0x00,0x20});
        // A real handler edits the saved PC to skip the known faulting encoding;
        // the test first asserts that hardware saved its original start address.
        b.put(0x20100,{0x83,0x06,0xfa,0x7f,uint8_t(test.code.size()),0xcf});
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100); b.step(0xf0100,0xbc,0xf000,0x103);
        b.step(0xf0103,0xb8,0xf000,0x106); b.step(0xf0106,0xba,0xf000,0x109);
        b.step(0xf0109,0xbb,0xf000,0x10c);
        const auto retired=b.retired;
        for(unsigned n=0;n<1024 && !b.d.event_o;++n) {b.tick(); check(!b.d.fault_o,"divide error became a development stop");}
        check(b.d.event_o && b.d.event_vector_o==0 && b.cs()==0x2000 && b.d.ip_o==0x100,"divide error vector/entry");
        check(b.retired==retired && !b.d.retire_o,"faulting division retired");
        check(b.reg(0)==test.ax && b.reg(2)==test.dx && b.reg(3)==test.bx,"faulting division changed its input/result registers");
        check(word_at(b,0x7ffa)==0x10c && word_at(b,0x7ffc)==0xf000 && word_at(b,0x7ffe)==2,"divide error saved the wrong PC/flags");
        check(b.data_transfers.size()>=10,"missing divide-error frame transactions");
        const unsigned start=unsigned(b.data_transfers.size()-10);
        const uint32_t addresses[]={0,1,2,3,0x7ffe,0x7fff,0x7ffc,0x7ffd,0x7ffa,0x7ffb};
        for(unsigned n=0;n<10;++n)
            check(b.data_transfers[start+n].address==addresses[n] && b.data_transfers[start+n].write==(n>=4),"divide-error frame transaction order");
        b.step(0x20100,0x83,0x2000,0x105); b.step(0x20105,0xcf,0xf000,next);
        check(b.reg(4)==0x8000,"divide-handler IRET stack adjustment");
        b.step(0xf0000+next,0x46,0xf000,uint16_t(next+1)); check(b.reg(6)==1,"divide handler return landing");
        b.step(0xf0001+next,0xf4,0xf000,uint16_t(next+2));
    }
    Bench into; into.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
    into.put(0xf0100,{0xbc,0x00,0x80,0xb0,0x7f,0x04,0x01,0xce,0xf4});
    into.put(16,{0x00,0x01,0x00,0x20}); into.put(0x20100,{0xcf}); into.reset();
    into.step(0xfffff0,0xea,0xf000,0x100); into.step(0xf0100,0xbc,0xf000,0x103);
    into.step(0xf0103,0xb0,0xf000,0x105); into.step(0xf0105,0x04,0xf000,0x107);
    into.step(0xf0107,0xce,0x2000,0x100); check(into.d.event_vector_o==4,"INTO vector");
    into.step(0x20100,0xcf,0xf000,0x108); into.step(0xf0108,0xf4,0xf000,0x109);
    std::cout<<"PASS: software interrupts, INTO, twelve precise divide/AAM faults and exact IRET handler returns\n";
}

static void decimal_contracts() {
    // Intel B-15..18/B-36..37 plus pinned 86Box 1db9ae4 whole-AX edge behavior.
    struct Decimal {uint8_t op;uint16_t ax;uint8_t lowflags,base;uint16_t result,flags;};
    const Decimal tests[]={
        {0x37,0xfffa,0,10,0x0100,0x13}, {0x3f,0,0x10,10,0xfe0a,0x13},
        {0x27,0x00fa,0,10,0x0060,0x17}, {0x2f,0,0x10,10,0x00fa,0x97},
        {0x2f,0x009a,0,10,0x0034,0x13}, {0xd5,0xffff,0,0xff,0,0x46},
        {0xd4,0xabff,0,10,0x1905,6}, {0xd4,0x00ff,0,1,0xff00,0x46},
        {0xd4,0xabfe,0,0xff,0x00fe,0x82}, {0xd5,0xabcd,0,0,0x00cd,0x82}
    };
    for(const auto& test:tests) {
        Bench b; b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
        b.put(0xf0100,{0xb4,test.lowflags,0x9e,0xb8,uint8_t(test.ax),uint8_t(test.ax>>8),
                       0xba,0x34,0x12,0x2e,test.op});
        uint16_t next=0x10b;
        if(test.op==0xd4 || test.op==0xd5) b.memory[0xf0000+next++]=test.base;
        b.memory[0xf0000+next]=0x46; b.memory[0xf0001+next]=0xf4;
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100); b.step(0xf0100,0xb4,0xf000,0x102);
        b.step(0xf0102,0x9e,0xf000,0x103); b.step(0xf0103,0xb8,0xf000,0x106);
        b.step(0xf0106,0xba,0xf000,0x109); b.step(0xf0109,test.op,0xf000,next);
        check(b.reg(0)==test.result && b.d.flags_o==test.flags,"decimal adjustment edge result/flags");
        check(b.reg(2)==0x1234 && b.data_transfers.empty(),"decimal adjustment changed DX or touched operands");
        b.step(0xf0000+next,0x46,0xf000,uint16_t(next+1)); check(b.reg(6)==1,"decimal successor landing");
        b.step(0xf0001+next,0xf4,0xf000,uint16_t(next+2));
    }
    std::cout<<"PASS: whole-AX AAA/AAS propagation, DAA/DAS carries, AAM/AAD bases, flags and exact successors\n";
}

static void string_contracts() {
    for(uint8_t op : {0xa4,0xa5,0xa6,0xa7,0xaa,0xab,0xae,0xaf,0x6c,0x6d,0x6e,0x6f}) {
        Bench b; b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
        b.put(0xf0100,{0xb9,0,0,0xbe,0xff,0xff,0xbf,0xff,0xff,0xf9,0xfd,0xf3,op,0x43,0xf4});
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100); b.step(0xf0100,0xb9,0xf000,0x103);
        b.step(0xf0103,0xbe,0xf000,0x106); b.step(0xf0106,0xbf,0xf000,0x109);
        b.step(0xf0109,0xf9,0xf000,0x10a); b.step(0xf010a,0xfd,0xf000,0x10b);
        b.step(0xf010b,op,0xf000,0x10d);
        check(b.data_transfers.empty() && !b.d.element_o,"zero-count REP accessed an element");
        check(b.reg(1)==0 && b.reg(6)==0xffff && b.reg(7)==0xffff && b.d.flags_o==0x403,"zero-count REP changed pointers/flags");
        b.step(0xf010d,0x43,0xf000,0x10e); check(b.reg(3)==1,"zero-count REP successor");
        b.step(0xf010e,0xf4,0xf000,0x10f);
    }
    Bench partial; partial.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
    partial.put(0xf0100,{0xb9,2,0,0xbe,0xfd,0xff,0xbf,0,0x20,0xf3,0xa5,0xf4});
    partial.put(0xfffd,{0x34,0x12}); partial.put(0x2000,{0xaa,0xbb,0xcc,0xdd}); partial.reset();
    partial.step(0xfffff0,0xea,0xf000,0x100); partial.step(0xf0100,0xb9,0xf000,0x103);
    partial.step(0xf0103,0xbe,0xf000,0x106); partial.step(0xf0106,0xbf,0xf000,0x109);
    unsigned elements=0; const auto retired=partial.retired;
    for(unsigned n=0;n<256 && elements==0;++n) {
        partial.tick(); if(partial.d.element_o) ++elements;
        check(partial.retired==retired,"partially completed REP retired");
    }
    check(elements==1 && partial.reg(1)==1 && partial.reg(6)==0xffff && partial.reg(7)==0x2002,"REP lost completed-element progress");
    check(partial.data_transfers.size()==4 && partial.memory[0x2000]==0x34 && partial.memory[0x2001]==0x12 && partial.memory[0x2002]==0xcc,"REP limit accessed an incomplete element");
    partial.processor_fault(13,0x109);
    for(unsigned cut=0;cut<=12;++cut) {
        Bench b; b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
        b.put(0xf0100,{0xb9,3,0,0xbe,0,0x10,0xbf,0,0x20,0xf3,0xa5,0x43,0xf4});
        b.put(0x1000,{0x11,0x22,0x33,0x44,0x55,0x66});
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100); b.step(0xf0100,0xb9,0xf000,0x103);
        b.step(0xf0103,0xbe,0xf000,0x106); b.step(0xf0106,0xbf,0xf000,0x109);
        for(unsigned n=0;n<512 && b.data_transfers.size()<cut;++n) b.tick();
        check(b.data_transfers.size()==cut,"REP reset cut missed its transfer");
        const auto memory=b.memory; b.reset(); check(b.memory==memory,"REP reset rolled back accepted writes");
        b.put(0xfffff0,{0xf4}); b.step(0xfffff0,0xf4,0xf000,0xfff1);
        check(b.data_transfers.size()==cut && b.reg(1)==0 && b.reg(6)==0 && b.reg(7)==0 && !b.d.element_o,"REP continuation survived reset");
    }
    Bench ins; ins.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
    ins.put(0xf0100,{0xb9,1,0,0xbf,0xff,0xff,0xf3,0x6d}); ins.reset();
    ins.step(0xfffff0,0xea,0xf000,0x100); ins.step(0xf0100,0xb9,0xf000,0x103);
    ins.step(0xf0103,0xbf,0xf000,0x106); ins.processor_fault(13,0x106);

    Bench ins_ok; ins_ok.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
    ins_ok.put(0xf0100,{0xba,0x20,0x00,0xbf,0xfe,0xff,0x6d,0xf4});
    ins_ok.ports[0x20]=0x5a; ins_ok.ports[0x21]=0xa5; ins_ok.reset();
    ins_ok.step(0xfffff0,0xea,0xf000,0x100); ins_ok.step(0xf0100,0xba,0xf000,0x103);
    ins_ok.step(0xf0103,0xbf,0xf000,0x106); ins_ok.step(0xf0106,0x6d,0xf000,0x107);
    check(ins_ok.data_transfers.size()==4,"INS word transaction count");
    check(ins_ok.data_transfers[0].io && !ins_ok.data_transfers[0].write &&
          ins_ok.data_transfers[0].address==0x20 && ins_ok.data_transfers[0].value==0x5a &&
          ins_ok.data_transfers[1].io && !ins_ok.data_transfers[1].write &&
          ins_ok.data_transfers[1].address==0x21 && ins_ok.data_transfers[1].value==0xa5 &&
          !ins_ok.data_transfers[2].io && ins_ok.data_transfers[2].write &&
          ins_ok.data_transfers[2].address==0xfffe && ins_ok.data_transfers[2].value==0x5a &&
          !ins_ok.data_transfers[3].io && ins_ok.data_transfers[3].write &&
          ins_ok.data_transfers[3].address==0xffff && ins_ok.data_transfers[3].value==0xa5,
          "INS checked destination then read port before writing ES");
    check(ins_ok.memory[0xfffe]==0x5a && ins_ok.memory[0xffff]==0xa5,"INS word destination contents");
    ins_ok.step(0xf0107,0xf4,0xf000,0x108);
    std::cout<<"PASS: zero-count strings, partial REP limit progress, every MOVSW transfer reset cut and INS precheck ordering\n";
}

// Independent frame/boundary contracts from Intel 210498-005 5.2, 9.2,
// MOV/POP/REP/HLT, with STI/shadow ambiguity explicitly recorded as A9.
static void interrupt_vector(Bench& b,unsigned vector,uint16_t segment=0x2000) {
    b.put(vector*4,{0,1,uint8_t(segment),uint8_t(segment>>8)});
    b.put((uint32_t(segment)<<4)+0x100,{0x43,0xcf});
}
static void interrupt_setup(Bench& b) {
    b.put(0xfffff0,{0xea,0,1,0,0xf0});
    b.put(0xf0100,{0xbc,0,0x80,0xb8,0,0,0x8e,0xd0,0x90});
    b.reset(); b.step(0xfffff0,0xea,0xf000,0x100);
    b.step(0xf0100,0xbc,0xf000,0x103); b.step(0xf0103,0xb8,0xf000,0x106);
    b.step(0xf0106,0x8e,0xf000,0x108); b.step(0xf0108,0x90,0xf000,0x109);
}
static void interrupt_entry(Bench& b,unsigned vector,uint16_t saved_ip,uint16_t saved_flags,
                            uint16_t handler_segment=0x2000,uint16_t saved_cs=0xf000,uint16_t handler_ip=0x100) {
    const auto retired=b.retired;
    const auto fetches=b.accepted.size();
    const uint16_t frame=uint16_t(b.reg(4)-6);
    bool entered=false;
    for(unsigned n=0;n<2048 && !entered;++n) {
        b.tick(); check(!b.d.fault_o,"hardware event diagnostic stop");
        check(b.retired==retired,"hardware entry fabricated retirement");
        check(b.accepted.size()==fetches,"instruction fetched before hardware event delivery");
        entered=b.d.event_o;
    }
    check(entered && b.d.event_vector_o==vector,"hardware event vector/timeout");
    check(!b.d.halted_o && b.cs()==handler_segment && b.d.ip_o==handler_ip,"hardware handler landing");
    check(b.reg(4)==frame && b.d.flags_o==(saved_flags&~0x300),"hardware frame SP/flags");
    const uint8_t expected[]={uint8_t(saved_ip),uint8_t(saved_ip>>8),uint8_t(saved_cs),uint8_t(saved_cs>>8),
                              uint8_t(saved_flags),uint8_t(saved_flags>>8)};
    for(unsigned i=0;i<6;++i) check(b.memory[uint16_t(frame+i)]==expected[i],"hardware frame byte");
}
static void hardware_interrupt_contracts() {
    // Every vector, IF masking, STI's following instruction, held ack and
    // exact IRET/following-instruction PCs. INTR vector 2 is still maskable.
    for(unsigned vector=0;vector<256;++vector) {
        Bench b; interrupt_setup(b); interrupt_vector(b,vector);
        b.put(0xf0109,{0xfb,0x90,0x43,0xf4}); b.d.intr_i=1;
        b.step(0xf0109,0xfb,0xf000,0x10a);
        check(!b.d.inta_req_o,"STI acknowledged before following instruction");
        b.step(0xf010a,0x90,0xf000,0x10b);
        const auto fetches=b.accepted.size();
        const auto retired=b.retired;
        for(unsigned n=0;n<12;++n) {
            b.tick(); check(!b.d.bus_req_o && !b.d.event_o && b.retired==retired,"ack stall changed CPU");
        }
        check(b.d.inta_req_o && !b.acknowledgements && b.accepted.size()==fetches,"missing held ack");
        b.interrupt_vector=uint8_t(vector); b.acknowledge=true; b.d.intr_i=0;
        interrupt_entry(b,vector,0x10b,0x202);
        check(b.acknowledgements==1 && !b.d.nmi_blocked_o,"INTR acknowledged twice or blocked NMI");
        b.step(0x20100,0x43,0x2000,0x101); b.step(0x20101,0xcf,0xf000,0x10b);
        b.step(0xf010b,0x43,0xf000,0x10c); check(b.reg(3)==2,"INTR handler/successor execution");
        b.step(0xf010c,0xf4,0xf000,0x10d);
    }
    // Masked INTR cannot wake HLT; NMI wakes with post-HLT IP and no extra retirement.
    {
        Bench b; interrupt_setup(b); interrupt_vector(b,2,0x2100);
        b.put(0xf0109,{0xf4,0x43,0xf4}); b.d.intr_i=1;
        b.step(0xf0109,0xf4,0xf000,0x10a); const auto retired=b.retired;
        for(unsigned n=0;n<20;++n) {b.tick();check(b.d.halted_o && b.retired==retired && !b.d.inta_req_o,"masked INTR woke HLT");}
        b.d.nmi_i=1; interrupt_entry(b,2,0x10a,2,0x2100);
        b.d.intr_i=0; b.d.nmi_i=0;
        b.step(0x21100,0x43,0x2100,0x101); b.step(0x21101,0xcf,0xf000,0x10a);
        b.step(0xf010a,0x43,0xf000,0x10b); b.step(0xf010b,0xf4,0xf000,0x10c);
    }
    // STI;HLT wakes for INTR and resumes after HLT, without a second HLT retirement.
    {
        Bench b; interrupt_setup(b); interrupt_vector(b,0x20);
        b.put(0xf0109,{0xfb,0xf4,0x43,0xf4}); b.d.intr_i=1;
        b.step(0xf0109,0xfb,0xf000,0x10a); b.step(0xf010a,0xf4,0xf000,0x10b);
        for(unsigned n=0;n<12;++n) {b.tick();check(b.d.halted_o && !b.d.bus_req_o,"HLT lost during vector wait");}
        check(b.d.inta_req_o,"INTR did not wake halted acknowledgement");
        b.interrupt_vector=0x20; b.acknowledge=true; b.d.intr_i=0;
        interrupt_entry(b,0x20,0x10b,0x202);
        b.step(0x20100,0x43,0x2000,0x101); b.step(0x20101,0xcf,0xf000,0x10b);
        b.step(0xf010b,0x43,0xf000,0x10c); b.step(0xf010c,0xf4,0xf000,0x10d);
        check(b.reg(3)==2,"HLT resume skipped successor");
    }
    // NMI wins a simultaneous request; INTR stays pending across its handler.
    {
        Bench b; interrupt_setup(b); interrupt_vector(b,2,0x2100); interrupt_vector(b,0x20);
        b.put(0xf0109,{0xfb,0x90,0x43,0xf4});
        b.step(0xf0109,0xfb,0xf000,0x10a); b.step(0xf010a,0x90,0xf000,0x10b);
        b.d.intr_i=1; b.d.nmi_i=1; b.interrupt_vector=0x20; b.acknowledge=true;
        interrupt_entry(b,2,0x10b,0x202,0x2100); b.d.nmi_i=0;
        check(!b.acknowledgements,"NMI priority consumed INTR vector");
        b.step(0x21100,0x43,0x2100,0x101); b.step(0x21101,0xcf,0xf000,0x10b);
        interrupt_entry(b,0x20,0x10b,0x202); b.d.intr_i=0;
        b.step(0x20100,0x43,0x2000,0x101); b.step(0x20101,0xcf,0xf000,0x10b);
        b.step(0xf010b,0x43,0xf000,0x10c); b.step(0xf010c,0xf4,0xf000,0x10d);
        check(b.reg(3)==3 && b.acknowledgements==1,"priority handler/successor count");
    }
    // One remembered edge while NMI is blocked; held level does not repeat.
    {
        Bench b; interrupt_setup(b); interrupt_vector(b,2,0x2100);
        b.put(0xf0109,{0x90,0xf4}); b.d.nmi_i=1; interrupt_entry(b,2,0x109,2,0x2100);
        check(b.d.nmi_blocked_o && !b.d.nmi_pending_o,"NMI initial ownership");
        b.step(0x21100,0x43,0x2100,0x101);
        b.d.nmi_i=0; b.tick(); b.d.nmi_i=1;
        b.step(0x21101,0xcf,0xf000,0x109);
        check(b.d.nmi_pending_o && !b.d.nmi_blocked_o,"IRET lost queued NMI");
        interrupt_entry(b,2,0x109,2,0x2100); b.d.nmi_i=0;
        b.step(0x21100,0x43,0x2100,0x101); b.step(0x21101,0xcf,0xf000,0x109);
        b.step(0xf0109,0x90,0xf000,0x10a); b.step(0xf010a,0xf4,0xf000,0x10b);
        check(b.reg(3)==2 && !b.acknowledgements,"held NMI repeated/acknowledged");
    }
    // Both SS-load forms inhibit NMI through a prefixed successor.
    for(bool pop : {false,true}) {
        Bench b; interrupt_setup(b); interrupt_vector(b,2,0x2100); b.put(0x8000,{0,0});
        if(pop) b.put(0xf0109,{0x17,0x2e,0x90,0x43,0xf4});
        else b.put(0xf0109,{0x8e,0xd0,0x2e,0x90,0x43,0xf4});
        for(unsigned n=0;n<32 && b.accepted.back()!=0xf0109;++n) b.tick();
        check(b.accepted.back()==0xf0109,"SS-load fetch not reached"); b.d.nmi_i=1;
        const uint16_t prefix=pop?0x10a:0x10b, successor=uint16_t(prefix+2);
        b.step(0xf0109,pop?0x17:0x8e,0xf000,prefix);
        b.step(0xf0000+prefix,0x90,0xf000,successor);
        interrupt_entry(b,2,successor,2,0x2100); b.d.nmi_i=0;
        b.step(0x21100,0x43,0x2100,0x101); b.step(0x21101,0xcf,0xf000,successor);
        b.step(0xf0000+successor,0x43,0xf000,uint16_t(successor+1));
        b.step(0xf0001+successor,0xf4,0xf000,uint16_t(successor+2));
    }
    // Request during the first MOVSW read/write transaction. Complete exactly
    // one element, save the original F3/CS prefix PC, resume remaining two.
    {
        Bench b; interrupt_setup(b); interrupt_vector(b,2,0x2100);
        b.put(0xf0109,{0xb9,3,0,0xbe,0,0x10,0xbf,0,0x20,0xf3,0x2e,0xa5,0x43,0xf4});
        b.put(0xf1000,{0x11,0x22,0x33,0x44,0x55,0x66});
        b.step(0xf0109,0xb9,0xf000,0x10c); b.step(0xf010c,0xbe,0xf000,0x10f);
        b.step(0xf010f,0xbf,0xf000,0x112);
        for(unsigned n=0;n<128 && b.data_transfers.empty();++n) b.tick();
        check(b.data_transfers.size()==1,"REP first transfer missing"); b.d.nmi_i=1;
        for(unsigned n=0;n<128 && !b.d.element_o;++n) {b.tick();check(!b.d.event_o && !b.d.inta_req_o,"event split REP element");}
        check(b.d.element_o && b.reg(1)==2 && b.reg(6)==0x1002 && b.reg(7)==0x2002,"REP progress before interrupt");
        check(b.memory[0x2000]==0x11 && b.memory[0x2001]==0x22 && !b.memory.count(0x2002),"REP partial memory");
        interrupt_entry(b,2,0x112,2,0x2100); b.d.nmi_i=0;
        b.step(0x21100,0x43,0x2100,0x101); b.step(0x21101,0xcf,0xf000,0x112);
        b.step(0xf0112,0xa5,0xf000,0x115);
        check(b.reg(1)==0 && b.reg(6)==0x1006 && b.reg(7)==0x2006,"REP restart lost remaining count/pointers");
        unsigned writes=0;
        for(const auto& t:b.data_transfers) if(t.write && t.address>=0x2000 && t.address<0x2006) ++writes;
        check(writes==6,"REP restart duplicated a completed write");
        for(unsigned i=0;i<6;++i) check(b.memory[0x2000+i]==b.memory[0xf1000+i],"REP restarted byte");
        b.step(0xf0115,0x43,0xf000,0x116); b.step(0xf0116,0xf4,0xf000,0x117);
    }
    // Cancel an unaccepted acknowledgement and every IVT/frame transfer cut.
    // External writes already accepted before reset must remain accepted.
    for(int cut=-1;cut<=10;++cut) {
        Bench b; interrupt_setup(b); interrupt_vector(b,0x20);
        b.put(0xf0109,{0xfb,0x90,0x43,0xf4});
        b.step(0xf0109,0xfb,0xf000,0x10a); b.step(0xf010a,0x90,0xf000,0x10b);
        b.d.intr_i=1; b.interrupt_vector=0x20;
        for(unsigned n=0;n<16 && !b.d.inta_req_o;++n) b.tick();
        check(b.d.inta_req_o,"reset cut missing acknowledge");
        if(cut>=0) {
            b.acknowledge=true;
            for(unsigned n=0;n<256 && b.data_transfers.size()<unsigned(cut);++n) b.tick();
            check(b.data_transfers.size()==unsigned(cut),"reset missed event transfer cut");
        }
        const auto accepted_memory=b.memory;
        b.d.intr_i=0; b.d.nmi_i=0; b.acknowledge=false; b.reset();
        check(b.memory==accepted_memory && !b.d.inta_req_o && !b.d.nmi_pending_o && !b.d.nmi_blocked_o,"event survived reset");
        b.put(0xfffff0,{0xf4}); b.step(0xfffff0,0xf4,0xf000,0xfff1);
        for(unsigned n=0;n<16;++n) {b.tick();check(!b.d.event_o && !b.d.inta_req_o && b.d.halted_o,"stale event after reset");}
    }
    std::cout<<"PASS: 256 INTR vectors, STI/SS shadows, NMI priority/retention, HLT wake, prefixed REP restart and 12 event reset cuts\n";
}

static void debug_handler(Bench& b) {
    // A debugger clears TF in its saved frame using real instructions.
    b.put(0x20100,{0x55,0x89,0xe5,0x81,0x66,6,0xff,0xfe,0x5d,0xcf});
}
static void debug_return(Bench& b,uint16_t target) {
    b.step(0x20100,0x55,0x2000,0x101); b.step(0x20101,0x89,0x2000,0x103);
    b.step(0x20103,0x81,0x2000,0x108); b.step(0x20108,0x5d,0x2000,0x109);
    b.step(0x20109,0xcf,0xf000,target);
}
static void debug_setup(Bench& b) {
    interrupt_setup(b); interrupt_vector(b,1); debug_handler(b);
    b.put(0x8000,{2,1}); // Program POPF enables TF using a real stack load.
}
static void debug_trap_contracts() {
    // Newly enabled TF waits for the following instruction, including its
    // prefix; a debugger can clear TF in the frame and return normally.
    {
        Bench b; debug_setup(b); b.put(0xf0109,{0x9d,0x2e,0x43,0x90,0xf4});
        b.step(0xf0109,0x9d,0xf000,0x10a);
        b.step(0xf010a,0x43,0xf000,0x10c);
        interrupt_entry(b,1,0x10c,0x102); debug_return(b,0x10c);
        check(b.d.flags_o==2 && !b.acknowledgements,"debug return/acknowledgement");
        b.step(0xf010c,0x90,0xf000,0x10d); b.step(0xf010d,0xf4,0xf000,0x10e);
    }
    // Clearing TF via POPF does not erase its instruction-start sample.
    {
        Bench b; debug_setup(b); b.put(0x8002,{2,0}); b.put(0xf0109,{0x9d,0x9d,0x90,0xf4});
        b.step(0xf0109,0x9d,0xf000,0x10a); b.step(0xf010a,0x9d,0xf000,0x10b);
        interrupt_entry(b,1,0x10b,2); debug_return(b,0x10b);
        b.step(0xf010b,0x90,0xf000,0x10c); b.step(0xf010c,0xf4,0xf000,0x10d);
    }
    // A normal debugger IRET restores TF and steps the next program opcode,
    // not IRET itself or the first handler opcode.
    {
        Bench b; debug_setup(b); interrupt_vector(b,1);
        b.put(0xf0109,{0x9d,0x90,0x90,0xf4});
        b.step(0xf0109,0x9d,0xf000,0x10a); b.step(0xf010a,0x90,0xf000,0x10b);
        interrupt_entry(b,1,0x10b,0x102);
        b.step(0x20100,0x43,0x2000,0x101); b.step(0x20101,0xcf,0xf000,0x10b);
        b.step(0xf010b,0x90,0xf000,0x10c); interrupt_entry(b,1,0x10c,0x102);
        b.step(0x20100,0x43,0x2000,0x101); check(b.reg(3)==2,"restored-TF successor count");
    }
    // HLT retires once, traps immediately and resumes at its successor.
    {
        Bench b; debug_setup(b); b.put(0xf0109,{0x9d,0xf4,0x43,0xf4});
        b.step(0xf0109,0x9d,0xf000,0x10a); b.step(0xf010a,0xf4,0xf000,0x10b);
        interrupt_entry(b,1,0x10b,0x102); debug_return(b,0x10b);
        b.step(0xf010b,0x43,0xf000,0x10c); b.step(0xf010c,0xf4,0xf000,0x10d);
    }
    // MOV SS inhibits its own step and permits a prefixed successor before #1.
    {
        Bench b; debug_setup(b); b.put(0xf0109,{0x9d,0x8e,0xd0,0x2e,0x90,0x43,0xf4});
        b.step(0xf0109,0x9d,0xf000,0x10a); b.step(0xf010a,0x8e,0xf000,0x10c);
        b.step(0xf010c,0x90,0xf000,0x10e); interrupt_entry(b,1,0x10e,0x102);
        debug_return(b,0x10e); b.step(0xf010e,0x43,0xf000,0x10f); b.step(0xf010f,0xf4,0xf000,0x110);
    }
    // Software INT clears the pending TF request per pinned external A10.
    // Its handler is entered and returned by actual instructions.
    {
        Bench b; debug_setup(b); interrupt_vector(b,3,0x2100);
        b.put(0x21100,{0x90,0xcf}); b.put(0xf0109,{0x9d,0xcc,0x90,0xf4});
        b.step(0xf0109,0x9d,0xf000,0x10a); b.step(0xf010a,0xcc,0x2100,0x100);
        b.step(0x21100,0x90,0x2100,0x101); b.step(0x21101,0xcf,0xf000,0x10b);
        b.step(0xf010b,0x90,0xf000,0x10c); interrupt_entry(b,1,0x10c,0x102);
        debug_return(b,0x10c); b.step(0xf010c,0xf4,0xf000,0x10d);
    }
    // STI inhibits INTR, but must not inhibit its own sampled single-step.
    {
        Bench b; debug_setup(b); b.put(0xf0109,{0x9d,0xfb,0x90,0xf4});
        b.step(0xf0109,0x9d,0xf000,0x10a); b.step(0xf010a,0xfb,0xf000,0x10b);
        interrupt_entry(b,1,0x10b,0x302); debug_return(b,0x10b);
        b.step(0xf010b,0x90,0xf000,0x10c); b.step(0xf010c,0xf4,0xf000,0x10d);
    }
    // A faulting instruction does not retire or create a second debug entry.
    {
        Bench b; debug_setup(b); interrupt_vector(b,0,0x2100); b.put(0x21100,{0x90,0xcf});
        b.put(0xf0109,{0x9d,0xf6,0xf3});
        b.step(0xf0109,0x9d,0xf000,0x10a); const auto retired=b.retired;
        for(unsigned n=0;n<512 && !b.d.event_o;++n) {b.tick();check(b.retired==retired,"stepped divide fault retired");}
        check(b.d.event_o && b.d.event_vector_o==0 && b.d.ip_o==0x100 && b.cs()==0x2100,"stepped divide fault vector");
        check(b.reg(4)==0x7ffc && b.memory[0x7ffc]==0x0a && b.memory[0x7ffd]==1 &&
              b.memory[0x8000]==2 && b.memory[0x8001]==1,"stepped divide fault frame");
        b.step(0x21100,0x90,0x2100,0x101);
    }
    // A pending NMI survives higher-priority #1 and enters before the first
    // debugger instruction. The nested frame saves the debugger CS:IP.
    {
        Bench b; debug_setup(b); interrupt_vector(b,2,0x2100);
        b.put(0xf0109,{0x9d,0x90,0x43,0xf4});
        b.step(0xf0109,0x9d,0xf000,0x10a); b.step(0xf010a,0x90,0xf000,0x10b);
        b.d.nmi_i=1; interrupt_entry(b,1,0x10b,0x102);
        interrupt_entry(b,2,0x100,2,0x2100,0x2000); b.d.nmi_i=0;
        b.step(0x21100,0x43,0x2100,0x101); b.step(0x21101,0xcf,0x2000,0x100);
        debug_return(b,0x10b); b.step(0xf010b,0x43,0xf000,0x10c); b.step(0xf010c,0xf4,0xf000,0x10d);
        check(b.reg(3)==2,"debug/NMI priority successor count");
    }
    for(bool zero : {false,true}) {
        Bench b; debug_setup(b);
        b.put(0xf0109,{0xb9,uint8_t(zero?0:3),0,0xbe,0,0x10,0xbf,0,0x20,0x9d,0xf3,0x2e,0xa5,0x43,0xf4});
        b.put(0xf1000,{0x11,0x22,0x33,0x44,0x55,0x66});
        b.step(0xf0109,0xb9,0xf000,0x10c); b.step(0xf010c,0xbe,0xf000,0x10f);
        b.step(0xf010f,0xbf,0xf000,0x112); b.step(0xf0112,0x9d,0xf000,0x113);
        if(zero) {
            b.step(0xf0113,0xa5,0xf000,0x116); check(!b.d.element_o,"zero REP emitted element");
            interrupt_entry(b,1,0x116,0x102); debug_return(b,0x116);
            check(b.reg(1)==0 && b.reg(6)==0x1000 && b.reg(7)==0x2000,"zero REP debug pointers");
        } else {
            for(unsigned n=0;n<256 && !b.d.element_o;++n) {b.tick();check(!b.d.event_o && !b.d.retire_o,"REP trapped before completing element");}
            check(b.d.element_o && b.reg(1)==2 && b.reg(6)==0x1002 && b.reg(7)==0x2002,"debug REP progress");
            interrupt_entry(b,1,0x113,0x102); debug_return(b,0x113);
            b.step(0xf0113,0xa5,0xf000,0x116);
            check(b.reg(1)==0 && b.reg(6)==0x1006 && b.reg(7)==0x2006,"debug REP restart progress");
            unsigned writes=0;
            for(const auto& t:b.data_transfers) if(t.write && t.address>=0x2000 && t.address<0x2006) ++writes;
            check(writes==6,"debug REP duplicated write");
        }
        b.step(0xf0116,0x43,0xf000,0x117); b.step(0xf0117,0xf4,0xf000,0x118);
    }
    std::cout<<"PASS: instruction-start TF, POPF/IRET timing, HLT wake, SS inhibition, INT suppression, NMI priority and REP debug restart\n";
}

static void procedure_reset_contracts() {
    for(unsigned cut=0;cut<64;++cut) {
        Bench b; b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
        b.put(0xf0100,{0xb8,0x34,0x12,0xba,0x00,0x00,0xbb,0x07,0x00,0xf7,0xf3,0xf4});
        auto setup=[&]() {
            b.step(0xfffff0,0xea,0xf000,0x100); b.step(0xf0100,0xb8,0xf000,0x103);
            b.step(0xf0103,0xba,0xf000,0x106); b.step(0xf0106,0xbb,0xf000,0x109);
        };
        b.reset(); setup();
        for(unsigned n=0;n<cut;++n) b.tick();
        b.reset(); setup(); b.step(0xf0109,0xf7,0xf000,0x10b);
        check(b.reg(0)==0x299 && b.reg(2)==5 && b.reg(3)==7 && b.d.flags_o==2,"reset/replay of iterative DIV");
        b.step(0xf010b,0xf4,0xf000,0x10c);
    }
    for(bool event : {false,true}) for(unsigned cut=0;cut<=(event?6u:16u);++cut) {
        Bench b; b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
        b.put(0xf0100,{0xbc,0x00,0x80,0xb8,0x34,0x12,0xfb,uint8_t(event?0xcc:0x60),0xf4});
        b.put(12,{0x00,0x01,0x00,0x20}); b.put(0x20100,{0xcf});
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100); b.step(0xf0100,0xbc,0xf000,0x103);
        b.step(0xf0103,0xb8,0xf000,0x106); b.step(0xf0106,0xfb,0xf000,0x107);
        unsigned writes=0;
        for(unsigned n=0;n<512 && writes<cut;++n) {
            b.tick(); writes=0; for(const auto& t:b.data_transfers) if(t.write) ++writes;
            check(!b.d.fault_o && !b.d.event_o && !b.d.retire_o,"frame/push committed before all bytes were accepted");
            check(b.reg(4)==0x8000 && b.d.flags_o==0x202,"frame/push partially committed architecture");
        }
        check(writes==cut,"reset cut did not reach requested accepted byte");
        const auto image=b.memory; const auto transfers=b.data_transfers.size();
        b.reset();
        check(b.memory==image && b.data_transfers.size()==transfers,"reset completed or rolled back frame/push bytes");
        b.put(0xfffff0,{0xf4}); b.step(0xfffff0,0xf4,0xf000,0xfff1);
        check(b.data_transfers.size()==transfers && b.reg(4)==0 && b.d.flags_o==2,"old frame/push continuation survived reset");
    }
    std::cout<<"PASS: 64 iterative-division reset cuts and every PUSHA/event-frame accepted-byte reset cut\n";
}

static void bounds_translation_contracts() {
    // Intel section 5.2: #BR saves the first byte of BOUND, including prefixes.
    struct Bounds { uint16_t index,lower,upper; };
    for (unsigned r=0;r<8;++r) for (const Bounds test : {
            Bounds{0xffff,0,0x7fff}, Bounds{0x8000,0x8001,0x7fff},
            Bounds{0x7fff,0x8000,0x7ffe}, Bounds{0,1,0xffff}, Bounds{1,0xffff,0}}) {
        if (r==4 && test.index==1) continue; // Separate stack-exception work remains open.
        for (bool prefix : {false,true}) {
            Bench b; b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
            b.put(0xf0100,{0xbc,0x00,0x80,uint8_t(0xb8+r),uint8_t(test.index),uint8_t(test.index>>8),0xf9});
            uint32_t p=0xf0107;
            if (prefix) b.memory[p++]=0x2e;
            b.memory[p++]=0x62; b.memory[p++]=uint8_t(r*8+6); b.memory[p++]=0; b.memory[p++]=0x40;
            b.memory[p++]=0x46; b.memory[p]=0xf4;
            const unsigned length=prefix?5:4;
            const uint32_t table=prefix?0xf4000:0x4000;
            b.put(table,{uint8_t(test.lower),uint8_t(test.lower>>8),uint8_t(test.upper),uint8_t(test.upper>>8)});
            const uint16_t sp=r==4?test.index:0x8000;
            const uint16_t frame=uint16_t(sp-6);
            b.put(20,{0x00,0x01,0x00,0x20});
            b.put(0x20100,{0x83,0x06,uint8_t(frame),uint8_t(frame>>8),uint8_t(length),0xcf});
            b.reset(); b.step(0xfffff0,0xea,0xf000,0x100); b.step(0xf0100,0xbc,0xf000,0x103);
            b.step(0xf0103,uint8_t(0xb8+r),0xf000,0x106); b.step(0xf0106,0xf9,0xf000,0x107);
            uint16_t registers[8]; for(unsigned n=0;n<8;++n) registers[n]=b.reg(n);
            const auto retired=b.retired;
            for(unsigned n=0;n<512 && !b.d.event_o;++n) {b.tick(); check(!b.d.fault_o,"BOUND failed to deliver vector 5");}
            check(b.d.event_o && b.d.event_vector_o==5 && b.cs()==0x2000 && b.d.ip_o==0x100,"BOUND vector/handler entry");
            check(b.retired==retired && !b.d.retire_o,"out-of-range BOUND retired");
            auto word_at=[&](uint16_t a){return unsigned(b.memory[a])|(unsigned(b.memory[uint16_t(a+1)])<<8);};
            check(word_at(frame)==0x107 && word_at(uint16_t(frame+2))==0xf000 && word_at(uint16_t(frame+4))==3,"BOUND restart frame");
            for(unsigned n=0;n<8;++n) if(n!=4) check(b.reg(n)==registers[n],"BOUND changed source registers");
            check(b.data_transfers.size()==14,"BOUND missing operand/vector/frame transfers");
            for(unsigned n=0;n<4;++n) check(b.data_transfers[n].address==table+n && !b.data_transfers[n].write,"BOUND bounds read address/order");
            b.step(0x20100,0x83,0x2000,0x105); b.step(0x20105,0xcf,0xf000,uint16_t(0x107+length));
            check(b.reg(4)==sp && b.d.flags_o==3,"BOUND IRET state restoration");
            b.step(0xf0107+length,0x46,0xf000,uint16_t(0x108+length));
            check(b.reg(6)==uint16_t(registers[6]+1),"BOUND return landing");
            b.step(0xf0108+length,0xf4,0xf000,uint16_t(0x109+length));
        }
    }
    for (unsigned offset : {0xfffc,0xfffd,0xfffe,0xffff}) {
        Bench b; b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
        b.put(0xf0100,{0x62,0x06,uint8_t(offset),uint8_t(offset>>8),0xf4});
        b.put(offset,{0,0,0xff,0x7f}); b.reset(); b.step(0xfffff0,0xea,0xf000,0x100);
        if(offset==0xfffc) {b.step(0xf0100,0x62,0xf000,0x104); check(b.data_transfers.size()==4,"BOUND endpoint bytes");}
        else b.processor_fault(13,0x100);
    }
    Bench x; x.put(0xfffff0,{0xbb,0xff,0xff,0xb0,0x02,0x2e,0xd7,0xf4});
    x.put(0xff0001,{0xa5}); x.reset(); x.step(0xfffff0,0xbb,0xf000,0xfff3);
    x.step(0xfffff3,0xb0,0xf000,0xfff5); x.step(0xfffff5,0xd7,0xf000,0xfff7);
    check(x.reg(0)==0xa5 && x.reg(3)==0xffff && x.d.flags_o==2,"XLAT unsigned offset wrap/reset cache");
    check(x.data_transfers.size()==1 && x.data_transfers[0].address==0xff0001 && !x.data_transfers[0].write,"XLAT hidden-CS table read");
    x.step(0xfffff7,0xf4,0xf000,0xfff8);
    std::cout<<"PASS: signed BOUND restart/IRET, operand limits and XLAT reset-cache/wrap contracts\n";
}

static void manufacturer_stack_contracts() {
    Bench b; b.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
    uint16_t original[8]; uint32_t pc=0xf0100;
    for(unsigned r=0;r<8;++r) {
        original[r]=r==4?0x8000:uint16_t(0x1101*(r+1));
        b.put(pc,{uint8_t(0xb8+r),uint8_t(original[r]),uint8_t(original[r]>>8)}); pc+=3;
    }
    const uint32_t push_pc=pc; b.memory[pc++]=0x60;
    for(unsigned r=0;r<8;++r) if(r!=4) {b.put(pc,{0x31,uint8_t(0xc0|r*8|r)}); pc+=2;}
    const uint32_t pop_pc=pc; b.memory[pc++]=0x61; b.memory[pc]=0xf4;
    b.reset(); b.step(0xfffff0,0xea,0xf000,0x100);
    for(unsigned r=0;r<8;++r) b.step(0xf0100+r*3,uint8_t(0xb8+r),0xf000,uint16_t(0x103+r*3));
    b.data_transfers.clear(); b.step(push_pc,0x60,0xf000,uint16_t(push_pc+1));
    check(b.reg(4)==0x7ff0 && b.data_transfers.size()==16,"PUSHA frame size");
    for(unsigned r=0;r<8;++r) for(unsigned byte=0;byte<2;++byte) {
        const auto& t=b.data_transfers[r*2+byte];
        check(t.write && !t.io && t.address==0x7ffe - r*2+byte && t.value==uint8_t(original[r]>>(byte*8)),
              "Intel B-88 PUSHA AX..DI push order/original SP");
    }
    pc=push_pc+1;
    for(unsigned r=0;r<8;++r) if(r!=4) {b.step(pc,0x31,0xf000,uint16_t(pc+2));pc+=2;}
    b.memory[0x7ff6]=0xef; b.memory[0x7ff7]=0xbe; // Discarded SP image must not be loaded.
    b.data_transfers.clear(); b.step(pop_pc,0x61,0xf000,uint16_t(pop_pc+1));
    for(unsigned r=0;r<8;++r) check(b.reg(r)==original[r],"POPA register restoration/original SP slot discard");
    check(b.data_transfers.size()==14,"POPA read discarded SP image");
    unsigned index=0;
    for(unsigned slot=0;slot<8;++slot) if(slot!=3) for(unsigned byte=0;byte<2;++byte)
        check(!b.data_transfers[index].write && b.data_transfers[index++].address==0x7ff0+slot*2+byte,"POPA frame read order");
    b.step(pop_pc+1,0xf4,0xf000,uint16_t(pop_pc+2));

    Bench reset_entry; reset_entry.put(0xfffff0,{0xcc});
    reset_entry.put(12,{0x00,0x01,0x00,0x20}); reset_entry.put(0x20100,{0xcf});
    reset_entry.put(0x0ffff1,{0x46,0xf4}); reset_entry.reset();
    reset_entry.step(0xfffff0,0xcc,0x2000,0x100); reset_entry.step(0x20100,0xcf,0xf000,0xfff1);
    check(reset_entry.d.cs_base_o==0xf0000,"IRET failed to reload the reset CS hidden base");
    reset_entry.step(0x0ffff1,0x46,0xf000,0xfff2); reset_entry.step(0x0ffff2,0xf4,0xf000,0xfff3);
    Bench no_overflow; no_overflow.put(0xfffff0,{0xce,0x46,0xf4}); no_overflow.reset();
    no_overflow.step(0xfffff0,0xce,0xf000,0xfff1); check(!no_overflow.d.event_o,"INTO entered without overflow");
    no_overflow.step(0xfffff1,0x46,0xf000,0xfff2); no_overflow.step(0xfffff2,0xf4,0xf000,0xfff3);
    std::cout<<"PASS: manufacturer PUSHA/POPA contracts, INTO fall-through and reset-cache IRET reload\n";
}

static void software(const char* path) {
    std::ifstream file(path,std::ios::binary);
    check(bool(file), "BIOS file missing");
    std::vector<uint8_t> rom((std::istreambuf_iterator<char>(file)),{});
    check(rom.size()==65536, "original AT ROM size");
    Bench b;
    for (unsigned n=0;n<rom.size();++n) {
        b.memory[0xf0000+n]=rom[n];
        b.memory[0xff0000+n]=rom[n]; // Board ROM alias; CPU does not mask A20.
    }
    b.reset();
    b.step(0xfffff0,0xea,0xf000,0xe05b);
    b.step(0xfe05b,0xe9,0xf000,0x00a6);
    b.step(0xf00a6,0xfa,0xf000,0x00a7);
    b.step(0xf00a7,0xb4,0xf000,0x00a9);
    check((b.reg(0)>>8)==0xd5 && b.d.flags_o==2, "IBM AT POST entry state");
    // IBM's original flags self-test branches to HLT on failure. These exact
    // sequential landings are from the unchanged ROM/listing, not an RTL ISS.
    const uint16_t pcs[] = {0xa9,0xaa,0xac,0xae,0xb0,0xb2,0xb3,0xb5,0xb7,0xb9,0xbb,
        0xbd,0xbf,0xc1,0xc2,0xc4,0xc6,0xc8,0xc9,0xcb,0xcd,0xcf,0xd1,0xd3,0xd9,0xdc};
    const uint8_t ops[] = {0x9e,0x73,0x75,0x7b,0x79,0x9f,0xb1,0xd2,0x73,0xb0,0xd0,
        0x71,0x32,0x9e,0x76,0x78,0x7a,0x9f,0xb1,0xd2,0x72,0xd0,0x70,0xeb,0xb8,0x8e};
    std::vector<uint32_t> expected = {0xfffff0,0xfffff1,0xfffff2,0xfffff3,0xfffff4,
        0xfe05b,0xfe05c,0xfe05d,0xf00a6,0xf00a7,0xf00a8};
    for (unsigned n=0;n<26;++n) {
        const uint16_t next = n==25 ? 0xde : pcs[n+1];
        b.step(0xf0000+pcs[n],ops[n],0xf000,next);
        const unsigned size = n==23 ? 2 : unsigned(next-pcs[n]);
        for (unsigned j=0;j<size;++j) expected.push_back(0xf0000+pcs[n]+j);
    }
    check((b.d.segs_o>>48)==0x40 && b.reg(0)==0x40, "IBM flags-test success/DS initialization");
    check(rom[0xde]==0xe4, "first unimplemented original BIOS opcode changed");
    // The I/O instruction at this checkpoint is now implemented; the separate
    // independent firmware trace continues beyond it.
    check(b.retired==30 && b.accepted==expected, "historical flags-test exact byte trace");
    std::cout << "PASS: unchanged IBM AT BIOS, first 30 instructions through flags-test success\n";
}

// Original IBM AT 01/10/1984 ROM disassembly is the independent artifact for
// these exact paths. RAM/IVT fixture supplies a timer request and BDA state;
// every handler instruction, nested INT 1C and both IRETs execute in RTL.
// This is an ISR regression, not a PIT model, POST or whole-CPU equivalence.
static void bios_timer_interrupt(const char* path) {
    std::ifstream file(path,std::ios::binary); check(bool(file),"BIOS timer ROM missing");
    std::vector<uint8_t> rom((std::istreambuf_iterator<char>(file)),{});
    check(rom.size()==65536 && rom[0xfea5]==0xe9 && rom[0x4684]==0xfb &&
          rom[0x46c2]==0xcd && rom[0x46c3]==0x1c && rom[0xff53]==0xcf,"original timer ISR identity");
    unsigned cases=0, handler_states=0;
    for(uint32_t ticks : {0u,0xffffu,0x17ffffu,0x1800afu}) for(unsigned motor : {1u,2u}) {
        Bench b;
        for(unsigned i=0;i<rom.size();++i) b.memory[0xf0000+i]=rom[i];
        b.put(0xfffff0,{0xea,0,0x10,0,0});
        b.put(0x1000,{0xbc,0,0x80,0xb8,0x34,0x12,0xba,0x78,0x56,0xbb,0x56,0x34,
                      0xb9,0x11,0x11,0x8e,0xd9,0xfb,0x90,0x43,0xf4});
        b.put(8*4,{0xa5,0xfe,0,0xf0}); b.put(0x1c*4,{0x53,0xff,0,0xf0});
        b.put(0x46c,{uint8_t(ticks),uint8_t(ticks>>8),uint8_t(ticks>>16),uint8_t(ticks>>24),0});
        b.put(0x43f,{0xff,uint8_t(motor)});
        b.reset(); b.step(0xfffff0,0xea,0,0x1000);
        for(auto pc : {0x1000u,0x1003u,0x1006u,0x1009u,0x100cu}) b.step(pc,b.memory[pc],0,uint16_t(pc+3));
        b.step(0x100f,0x8e,0,0x1011); b.step(0x1011,0xfb,0,0x1012); b.step(0x1012,0x90,0,0x1013);
        b.d.intr_i=1; b.acknowledge=true; b.interrupt_vector=8;
        interrupt_entry(b,8,0x1013,0x202,0xf000,0,0xfea5); b.d.intr_i=0;
        // Literal path comes from the original ROM, including its public
        // compatibility entry jump, DS helper and original default INT 1C.
        std::vector<uint16_t> pcs={0xfea5,0x4684,0x4685,0x4686,0x4687,0x4688,
                                   0x17fd,0x17fe,0x1801,0x1803,0x1804,0x468b,0x468f};
        uint32_t updated=ticks+1;
        if((updated&0xffff)==0) pcs.push_back(0x4691);
        pcs.insert(pcs.end(),{0x4695,0x469a});
        if((updated>>16)==0x18) {
            pcs.insert(pcs.end(),{0x469c,0x46a2});
            if((updated&0xffff)==0xb0) pcs.insert(pcs.end(),{0x46a4,0x46a6,0x46a9,0x46ac});
        }
        pcs.insert(pcs.end(),{0x46b1,0x46b5});
        if(motor==1) pcs.insert(pcs.end(),{0x46b7,0x46bc,0x46be,0x46c1});
        pcs.insert(pcs.end(),{0x46c2,0xff53,0x46c4,0x46c6,0x46c8,0x46c9,0x46ca,0x46cb});
        for(unsigned i=0;i<pcs.size();++i) {
            const bool last=i+1==pcs.size();
            b.step(0xf0000+pcs[i],rom[pcs[i]],last?0:0xf000,last?0x1013:pcs[i+1]);
            ++handler_states;
        }
        const bool midnight=updated==0x1800b0;
        if(midnight) updated=0;
        for(unsigned i=0;i<4;++i) check(b.memory[0x46c+i]==uint8_t(updated>>(i*8)),"original timer counter result");
        check(b.memory[0x470]==unsigned(midnight) && b.memory[0x440]==motor-1,"original timer midnight/motor count");
        check(b.memory[0x43f]==(motor==1?0xf0:0xff),"original timer motor flags");
        check(b.ports[0x20]==0x20 && (motor==1 ? b.ports[0x3f2]==0x0c : !b.ports.count(0x3f2)),"original timer hardware outputs");
        check(b.reg(0)==0x1234 && b.reg(2)==0x5678 && b.reg(3)==0x3456 && b.reg(4)==0x8000 &&
              uint16_t(b.d.segs_o>>48)==0x1111 && b.d.flags_o==0x202,"original timer failed to restore context");
        check(b.acknowledgements==1,"original timer duplicate hardware acknowledgement");
        for(unsigned i=0;i<rom.size();++i) check(b.memory[0xf0000+i]==rom[i],"original timer ROM modified");
        b.step(0x1013,0x43,0,0x1014); b.step(0x1014,0xf4,0,0x1015);
        check(b.reg(3)==0x3457,"original timer return successor"); ++cases;
    }
    std::cout<<"PASS: "<<cases<<" unchanged IBM AT IRQ8 timer cases, "<<handler_states
             <<" exact original handler states, nested INT 1C/IRET, BDA rollover and hardware outputs\n";
}

static void reference_routing_contracts() {
    unsigned cases=0;
    struct Ref { bool segmented; unsigned role,kind,offset,size; bool write,io; };
    for (bool wait:{false,true}) {
        Bench b; b.put(0xfffff0,{0xea,0,1,0,0xf0});
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100,wait);
        uint16_t pc=0x100;
        auto verify=[&](std::initializer_list<Ref> references) {
            unsigned index=0;
            for (const auto& ref:references) for (unsigned byte=0;byte<ref.size;++byte) {
                check(index<b.data_transfers.size(),"missing routed reference byte");
                const auto& transfer=b.data_transfers[index++];
                const unsigned address=ref.segmented ? 0xf0000+ref.offset+byte :
                    ref.io ? uint16_t(ref.offset+byte) : ref.offset+byte;
                check(transfer.segmented==ref.segmented && transfer.address==address &&
                      transfer.write==ref.write && transfer.io==ref.io &&
                      transfer.kind==ref.kind && transfer.size==ref.size,
                      "reference bus space/direction/permission/span mismatch");
                if (ref.segmented) check(transfer.role==ref.role && transfer.offset==ref.offset+byte,
                                         "aliased cache lost explicit role/offset");
            }
            check(index==b.data_transfers.size(),"unexpected routed reference byte");
            ++cases;
        };
        auto run=[&](std::initializer_list<uint8_t> bytes,uint8_t opcode,
                     std::initializer_list<Ref> references=std::initializer_list<Ref>{}) {
            const uint16_t at=pc;
            for (auto byte:bytes) b.memory[0xf0000+pc++]=byte;
            b.data_transfers.clear(); b.step(0xf0000+at,opcode,0xf000,pc,wait); verify(references);
        };
        // All four bases alias. Expected roles come from instruction encodings,
        // never from the physical address or the DUT's selected role.
        run({0xb8,0,0xf0},0xb8); run({0x8e,0xc0},0x8e);
        run({0x8e,0xd0},0x8e); run({0x8e,0xd8},0x8e);
        run({0xbc,0,0x80},0xbc); run({0xbd,0,0x22},0xbd);
        run({0xbb,0,0x21},0xbb); run({0xba,0x40,0},0xba);
        run({0xb8,0xa5,0x5a},0xb8);
        b.put(0xf2200,{0xcd,0xab}); b.put(0xf2100,{0xe1,0xb2});
        run({0xa3,0,0x20},0xa3,{{true,3,1,0x2000,2,true,false}});
        run({0x26,0xa1,0,0x20},0xa1,{{true,0,0,0x2000,2,false,false}});
        run({0x2e,0xa1,0,0x20},0xa1,{{true,1,0,0x2000,2,false,false}});
        run({0x36,0xc7,6,0x20,0x20,0x78,0x56},0xc7,{{true,2,1,0x2020,2,true,false}});
        run({0x8b,0x46,0},0x8b,{{true,2,0,0x2200,2,false,false}});
        run({0x8b,7},0x8b,{{true,3,0,0x2100,2,false,false}});
        run({0x83,6,0,0x20,1},0x83,
            {{true,3,3,0x2000,2,false,false},{true,3,1,0x2000,2,true,false}});
        run({0x83,0x3e,0,0x20,1},0x83,{{true,3,0,0x2000,2,false,false}});
        run({0x87,6,0,0x20},0x87,
            {{true,3,3,0x2000,2,false,false},{true,3,1,0x2000,2,true,false}});
        run({0xd1,0x26,0,0x20},0xd1,
            {{true,3,3,0x2000,2,false,false},{true,3,1,0x2000,2,true,false}});
        run({0xf7,6,0,0x20,0xff,0xff},0xf7,{{true,3,0,0x2000,2,false,false}});
        run({0xf7,0x16,0,0x20},0xf7,
            {{true,3,3,0x2000,2,false,false},{true,3,1,0x2000,2,true,false}});
        run({0xf7,0x1e,0,0x20},0xf7,
            {{true,3,3,0x2000,2,false,false},{true,3,1,0x2000,2,true,false}});
        run({0x50},0x50,{{true,2,1,0x7ffe,2,true,false}});
        run({0x5b},0x5b,{{true,2,0,0x7ffe,2,false,false}});
        run({0x0f,1,6,0,0x40},0x0f,{{true,3,1,0x4000,6,true,false}});
        run({0x0f,1,0x16,0,0x40},0x0f,{{true,3,0,0x4000,6,false,false}});
        run({0xbe,0,0x20},0xbe); run({0xbf,0,0x30},0xbf);
        run({0xa5},0xa5,{{true,3,0,0x2000,2,false,false},{true,0,1,0x3000,2,true,false}});
        run({0xbe,0,0x20},0xbe); run({0xbf,0,0x30},0xbf);
        run({0xa7},0xa7,{{true,0,0,0x3000,2,false,false},{true,3,0,0x2000,2,false,false}});
        run({0xbf,0,0x30},0xbf);
        run({0xaf},0xaf,{{true,0,0,0x3000,2,false,false}});
        run({0xbe,0,0x20},0xbe); run({0xad},0xad,{{true,3,0,0x2000,2,false,false}});
        run({0xbf,0,0x30},0xbf); run({0xab},0xab,{{true,0,1,0x3000,2,true,false}});
        run({0xbf,0,0x30},0xbf);
        run({0x6d},0x6d,{{false,0,0,0x40,2,false,true},{true,0,1,0x3000,2,true,false}});
        run({0xbe,0,0x20},0xbe);
        run({0x6f},0x6f,{{true,3,0,0x2000,2,false,false},{false,0,1,0x40,2,true,true}});
        run({0xbb,0,0x20},0xbb); run({0xb8,1,0},0xb8);
        run({0xd7},0xd7,{{true,3,0,0x2001,1,false,false}});
        run({0xba,0xff,0xff},0xba);
        run({0xed},0xed,{{false,0,0,0xffff,2,false,true}});
        b.put(12,{0,0x70,0,0xf0}); b.put(0xf7000,{0xcf});
        b.memory[0xf0000+pc]=0xcc; b.data_transfers.clear();
        b.step(0xf0000+pc,0xcc,0xf000,0x7000,wait); ++pc;
        verify({{false,0,0,12,4,false,false},{true,2,1,0x7ffe,2,true,false},
                {true,2,1,0x7ffc,2,true,false},{true,2,1,0x7ffa,2,true,false}});
        b.data_transfers.clear(); b.step(0xf7000,0xcf,0xf000,pc,wait);
        verify({{true,2,0,0x7ffa,6,false,false}});
        run({0x90},0x90); run({0xf4},0xf4);
    }
    std::cout<<"PASS: "<<cases<<" aliased-role reference cases, RMW intent, table/stack/string paths and exact successors\n";
}

static void cache_state_contracts() {
    unsigned cases=0;
    // Intel real selector/base rules; A14's raw attributes are independently
    // sourced from pinned MAME reset/data_descriptor/far-transfer behavior.
    for (bool wait: {false,true}) for (unsigned target: {0u,2u,3u})
        for (unsigned selector: {0u,1u,3u,0x100u,0x1234u,0x8000u,0xf000u,0xffffu})
            for (unsigned form=0;form<3;++form) {
        if (form==2 && target==2) continue; // LDS/LES cannot load SS.
        Bench b; b.put(0xfffff0,{0xea,0,1,0,0xf0});
        struct Ins { uint16_t at,next; uint8_t op; };
        std::vector<Ins> program; uint16_t pc=0x100;
        auto emit=[&](std::initializer_list<uint8_t> bytes,uint8_t opcode) {
            const uint16_t at=pc;
            for (auto v:bytes) b.memory[0xf0000+pc++]=v;
            program.push_back({at,pc,opcode});
        };
        emit({0xbc,0,0x80},0xbc);
        emit({0xb8,uint8_t(selector),uint8_t(selector>>8)},0xb8);
        if (form==0) emit({0x8e,uint8_t(0xc0+(target<<3))},0x8e);
        else if (form==1) {
            const uint8_t opcode=target==0?0x07:target==2?0x17:0x1f;
            emit({opcode},opcode); b.put(0x8000,{uint8_t(selector),uint8_t(selector>>8)});
        } else {
            const uint8_t opcode=target==0?0xc4:0xc5;
            emit({opcode,6,0,0x30},opcode); b.put(0x3000,{0x34,0x12,uint8_t(selector),uint8_t(selector>>8)});
        }
        emit({0xb8,0xa5,0x5a},0xb8);
        const uint8_t prefix=target==0?0x26:target==2?0x36:0x3e;
        emit({prefix,0xa3,0,0x20},0xa3);
        emit({prefix,0x8b,0x1e,0,0x20},0x8b);
        emit({0x50},0x50); emit({0x59},0x59); emit({0x90},0x90); emit({0xf4},0xf4);
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100,wait);
        for (unsigned i=0;i<3;++i) b.step(0xf0000+program[i].at,program[i].op,0xf000,program[i].next,wait);
        check(uint16_t(b.d.segs_o>>(target*16))==selector && b.cache_base(target)==selector*16,
              "MOV/POP/LDS/LES cache commit");
        if (form) {
            const unsigned count=form==1?2:4,address=form==1?0x8000:0x3000;
            check(b.data_transfers.size()==count,"segment-load operand count");
            for (unsigned i=0;i<count;++i) check(!b.data_transfers[i].write && b.data_transfers[i].address==address+i,
                                                "segment-load source used new cache prematurely");
        }
        const uint16_t sp=b.reg(4); b.data_transfers.clear();
        for (unsigned i=3;i<program.size();++i) b.step(0xf0000+program[i].at,program[i].op,0xf000,program[i].next,wait);
        check(b.reg(0)==0x5aa5 && b.reg(3)==0x5aa5 && b.reg(1)==0x5aa5 && b.reg(4)==sp,
              "cache-addressed data/stack successor result");
        const uint32_t operand=selector*16+0x2000;
        const uint32_t stack=(target==2?selector*16:0)+uint16_t(sp-2);
        check(b.data_transfers.size()==8,"cache-addressed data/stack transfer count");
        for (unsigned i=0;i<8;++i) {
            const auto& transfer=b.data_transfers[i];
            check(!transfer.io && transfer.address==(i<4?operand:stack)+(i&1) &&
                  transfer.write==(i<2 || (i>=4 && i<6)) && transfer.value==(i&1?0x5a:0xa5),
                  "cache-addressed data/stack exact transfer");
        }
        ++cases;
    }
    std::cout<<"PASS: "<<cases<<" real-cache MOV/POP/LDS/LES cases, exact operand/stack addresses, commits and successors\n";
    unsigned reset_cases=0;
    for (bool wait: {false,true}) for (unsigned target: {0u,2u,3u}) for (unsigned form=0;form<3;++form) {
        if (form==2 && target==2) continue;
        struct Ins { uint16_t at,next; uint8_t op; };
        std::vector<Ins> setup;
        uint16_t operand_pc=0,successor_pc=0;
        uint8_t operand_op=0;
        auto prepare=[&](Bench& b) {
            b.put(0xfffff0,{0xea,0,1,0,0xf0});
            setup.clear(); uint16_t pc=0x100;
            auto emit=[&](std::initializer_list<uint8_t> bytes) {
                const auto at=pc;
                for (auto byte:bytes) b.memory[0xf0000+pc++]=byte;
                setup.push_back({at,pc,*bytes.begin()});
            };
            emit({0xb8,0x11,0x11}); emit({0x8e,0xc0});
            emit({0xb8,0x22,0x22}); emit({0x8e,0xd0});
            emit({0xb8,0x33,0x33}); emit({0x8e,0xd8});
            emit({0xbc,0,0x80}); emit({0xb8,0x3c,0x5a});
            operand_pc=pc;
            if (form==0) emit({0x8e,uint8_t(0xc0+(target<<3))});
            else if (form==1) emit({uint8_t(target==0?0x07:target==2?0x17:0x1f)});
            else emit({uint8_t(target==0?0xc4:0xc5),0x1e,0,0x30}); // BX receives the offset.
            operand_op=setup.back().op; successor_pc=pc; setup.pop_back();
            b.put(0xf0000+pc,{0x90,0xf4});
            b.put(0x22220+0x8000,{0x3c,0x5a});
            b.put(0x33330+0x3000,{0x34,0x12,0x3c,0x5a});
            b.reset(); b.step(0xfffff0,0xea,0xf000,0x100,wait);
            for (const auto& ins:setup) b.step(0xf0000+ins.at,ins.op,0xf000,ins.next,wait);
            b.data_transfers.clear();
        };
        Bench baseline; prepare(baseline); const auto start=baseline.cycles;
        baseline.step(0xf0000+operand_pc,operand_op,0xf000,successor_pc,wait);
        const unsigned duration=baseline.cycles-start;
        for (unsigned cut=0;cut<duration;++cut) {
            Bench b; prepare(b);
            const auto old_selectors=b.d.segs_o;
            for (unsigned n=0;n<cut;++n) {
                b.tick(wait);
                check(!b.d.retire_o && !b.d.fault_o,"cache reset cut crossed commit");
                check(b.d.segs_o==old_selectors && b.reg(4)==0x8000 && b.reg(3)==0,
                      "segment instruction published partial selector/SP/destination before reset");
            }
            b.reset();
            check(b.d.segs_o==0xf0000000ULL && b.reg(3)==0 && b.reg(4)==0,
                  "cache reset failed to cancel segment-load architectural state");
            b.step(0xfffff0,0xea,0xf000,0x100,wait);
            for (const auto& ins:setup) b.step(0xf0000+ins.at,ins.op,0xf000,ins.next,wait);
            b.data_transfers.clear();
            b.step(0xf0000+operand_pc,operand_op,0xf000,successor_pc,wait);
            check(uint16_t(b.d.segs_o>>(target*16))==0x5a3c && b.cache_base(target)==0x5a3c0 &&
                  b.reg(4)==(form==1?0x8002:0x8000) && b.reg(3)==(form==2?0x1234:0),
                  "cache reload after reset used stale operand/selector/stack state");
            const unsigned count=form==0?0:form==1?2:4;
            check(b.data_transfers.size()==count,"reset replay leaked a segment operand request");
            for (unsigned i=0;i<count;++i) check(!b.data_transfers[i].write && !b.data_transfers[i].io &&
                b.data_transfers[i].address==(form==1?0x2a220u:0x36330u)+i,
                "reset replay used stale segment source address");
            b.step(0xf0000+successor_pc,0x90,0xf000,uint16_t(successor_pc+1),wait);
            b.step(0xf0000+successor_pc+1,0xf4,0xf000,uint16_t(successor_pc+2),wait);
            ++reset_cases;
        }
    }
    std::cout<<"PASS: "<<reset_cases<<" real-cache reset cuts, old metadata/operands until commit and exact restarted successors\n";
}

// Expected contracts: Intel 210498-005 system instructions and the pinned
// 86Box 286 group-0F01 implementation cited in system_register_execution.md.
// In particular the sixth stored byte is FF; a modern x86 oracle differs.
static void system_register_contracts() {
    unsigned cases=0;
    for (unsigned r=0;r<8;++r) for (unsigned low=0;low<16;low+=2) {
        Bench b; const unsigned dst=r^3;
        b.put(0xfffff0,{0xea,0,1,0,0xf0});
        b.put(0xf0100,{0xf9,0xfd,uint8_t(0xb8+r),uint8_t(0xa0|low),0x5a,
                      0x0f,1,uint8_t(0xf0|r),0x0f,1,uint8_t(0xe0|dst),
                      0x0f,6,0x0f,1,0x26,0,0x22,0x90,0xf4});
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100);
        b.step(0xf0100,0xf9,0xf000,0x101); b.step(0xf0101,0xfd,0xf000,0x102);
        b.step(0xf0102,uint8_t(0xb8+r),0xf000,0x105);
        b.step(0xf0105,0x0f,0xf000,0x108);
        check(b.d.msw_o==(0xfff0|low),"LMSW reserved/high-bit policy");
        b.step(0xf0108,0x0f,0xf000,0x10b);
        check(b.reg(dst)==(0xfff0|low) && b.reg(r)==(0x5aa0|low),"SMSW register alias/preservation");
        b.step(0xf010b,0x0f,0xf000,0x10d);
        check(b.d.msw_o==((0xfff0|low)&~8u),"CLTS must clear TS only");
        b.data_transfers.clear(); b.step(0xf010d,0x0f,0xf000,0x112);
        check(b.data_transfers.size()==2,"SMSW memory store must not read");
        for (unsigned i=0;i<2;++i) check(b.data_transfers[i].write &&
            b.data_transfers[i].address==0x2200+i &&
            b.data_transfers[i].value==uint8_t(b.d.msw_o>>(8*i)),"SMSW memory byte");
        check(b.d.flags_o==0x403,"system instruction flag preservation");
        b.step(0xf0112,0x90,0xf000,0x113); b.step(0xf0113,0xf4,0xf000,0x114); ++cases;
    }
    for (unsigned low=0;low<16;++low) {
        Bench b; b.put(0xfffff0,{0xea,0,1,0,0xf0});
        b.put(0xf0100,{0x0f,1,0x36,0,0x20,0x90,0xf4}); b.put(0x2000,{uint8_t(0xf0|low),0xa5});
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100); b.data_transfers.clear();
        b.step(0xf0100,0x0f,0xf000,0x105);
        check(b.d.msw_o==(0xfff0|low),"memory LMSW low bits and PE entry");
        b.step(0xf0105,0x90,0xf000,0x106); b.step(0xf0106,0xf4,0xf000,0x107);
        check(b.data_transfers.size()==2 && !b.data_transfers[0].write && !b.data_transfers[1].write &&
            b.data_transfers[0].address==0x2000 && b.data_transfers[1].address==0x2001,"LMSW source traffic"); ++cases;
    }
    for (unsigned table=0;table<2;++table) for (uint32_t base: {0u,1u,0x123456u,0xffffffu})
        for (unsigned limit: {0u,3u,0x3ffu,0xffffu}) for (unsigned unused: {0u,0x55u,0xa5u,0xffu}) {
        Bench b; b.put(0xfffff0,{0xea,0,1,0,0xf0});
        b.put(0xf0100,{0x0f,1,uint8_t(0x16+8*table),0,0x20,
                      0x0f,1,uint8_t(0x06+8*table),0,0x30,0x90,0xf4});
        const uint8_t image[]={uint8_t(limit),uint8_t(limit>>8),uint8_t(base),uint8_t(base>>8),uint8_t(base>>16),uint8_t(unused)};
        for (unsigned i=0;i<6;++i) b.memory[0x2000+i]=image[i];
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100); b.data_transfers.clear();
        b.step(0xf0100,0x0f,0xf000,0x105); b.step(0xf0105,0x0f,0xf000,0x10a);
        check(b.data_transfers.size()==12,"table image transfer count");
        for (unsigned i=0;i<12;++i) { const auto& t=b.data_transfers[i];
            check(!t.io && t.write==(i>=6) && t.address==(i<6?0x2000+i:0x3000+i-6) &&
                  t.value==(i==11?0xff:image[i%6]),"table image address/order/value"); }
        for (unsigned r=0;r<8;++r) check(b.reg(r)==0,"table operation changed GPR");
        check(b.d.flags_o==2,"table operation changed FLAGS");
        b.step(0xf010a,0x90,0xf000,0x10b); b.step(0xf010b,0xf4,0xf000,0x10c); ++cases;
    }
    // Independent Intel 16-bit EA table, with negative 8/16-bit displacements.
    for (unsigned mod=0;mod<3;++mod) for (unsigned rm=0;rm<8;++rm)
        for (uint8_t prefix: {uint8_t(0),uint8_t(0x26),uint8_t(0x2e),uint8_t(0x36),uint8_t(0x3e)}) {
        Bench b; b.put(0xfffff0,{0xea,0,1,0,0xf0}); uint16_t pc=0x100;
        struct Ins { uint16_t at,next; uint8_t op; }; std::vector<Ins> setup;
        auto emit=[&](std::initializer_list<uint8_t> bytes) { const auto at=pc;
            for (auto v:bytes) b.memory[0xf0000+pc++]=v;
            setup.push_back({at,pc,*bytes.begin()}); };
        emit({0xb8,0,0x10}); emit({0x8e,0xd8}); emit({0xb8,0,0x20}); emit({0x8e,0xd0});
        emit({0xb8,0,0x30}); emit({0x8e,0xc0}); emit({0xbb,0,0x11}); emit({0xbd,0,0x22});
        emit({0xbe,0x33,0}); emit({0xbf,0x44,0});
        const unsigned ea_table[]={0x1133,0x1144,0x2233,0x2244,0x33,0x44,0x2200,0x1100};
        const bool direct=mod==0 && rm==6;
        const uint16_t ea=direct?0x5a00:uint16_t(ea_table[rm]+(mod==1?-17:mod==2?-0x1234:0));
        const bool bp=rm==2 || rm==3 || (rm==6 && !direct);
        const uint32_t segment=prefix==0x26?0x30000:prefix==0x2e?0xf0000:prefix==0x36?0x20000:
            prefix==0x3e?0x10000:bp?0x20000:0x10000;
        const uint32_t operand=segment+ea; const uint8_t image[]={0xcd,0xab,0x56,0x34,0x12,0x5a};
        for (unsigned i=0;i<6;++i) b.memory[operand+i]=image[i];
        auto sys=[&](unsigned group) { const uint16_t at=pc;
            if (prefix) b.memory[0xf0000+pc++]=prefix;
            b.memory[0xf0000+pc++]=0x0f; b.memory[0xf0000+pc++]=1;
            b.memory[0xf0000+pc++]=uint8_t((mod<<6)|(group<<3)|rm);
            if (direct) { b.memory[0xf0000+pc++]=0; b.memory[0xf0000+pc++]=0x5a; }
            else if (mod==1) b.memory[0xf0000+pc++]=0xef;
            else if (mod==2) { b.memory[0xf0000+pc++]=0xcc; b.memory[0xf0000+pc++]=0xed; }
            return Ins{at,pc,0x0f}; };
        const auto load=sys(2),store=sys(0); const uint16_t nop=pc; emit({0x90}); emit({0xf4});
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100);
        for (unsigned i=0;i+2<setup.size();++i) b.step(0xf0000+setup[i].at,setup[i].op,0xf000,setup[i].next);
        b.data_transfers.clear(); b.step(0xf0000+load.at,0x0f,0xf000,load.next);
        b.step(0xf0000+store.at,0x0f,0xf000,store.next);
        check(b.data_transfers.size()==12,"system EA transfer count");
        for (unsigned i=0;i<12;++i) check(b.data_transfers[i].address==operand+i%6 &&
            b.data_transfers[i].write==(i>=6) && b.data_transfers[i].value==(i==11?0xff:image[i%6]),"system EA/segment override");
        b.step(0xf0000+nop,0x90,0xf000,nop+1); b.step(0xf0001+nop,0xf4,0xf000,nop+2); ++cases;
    }
    for (unsigned group=0;group<4;++group) for (unsigned offset=0xfffa;offset<=0xffff;++offset) {
        Bench b; b.put(0xfffff0,{0xea,0,1,0,0xf0});
        b.put(0xf0100,{0x0f,1,uint8_t(6+8*group),uint8_t(offset),0xff,0x90,0xf4});
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100); b.data_transfers.clear();
        if (offset>0xfffa) b.processor_fault(13,0x100);
        else { b.step(0xf0100,0x0f,0xf000,0x105); check(b.data_transfers.size()==6,"FFFA operand rejected");
               b.step(0xf0105,0x90,0xf000,0x106); b.step(0xf0106,0xf4,0xf000,0x107); } ++cases;
    }
    for (unsigned prefixes: {8u,9u}) {
        Bench b; b.put(0xfffff0,{0xea,0,1,0,0xf0});
        for (unsigned i=0;i<prefixes;++i) b.memory[0xf0100+i]=0x3e;
        b.put(0xf0100+prefixes,{0x0f,6,0x90,0xf4}); b.reset(); b.step(0xfffff0,0xea,0xf000,0x100); b.accepted.clear();
        if (prefixes==8) { b.step(0xf0100,0x0f,0xf000,0x10a); check(b.accepted.size()==10,"ten-byte system fetch count");
            b.step(0xf010a,0x90,0xf000,0x10b); b.step(0xf010b,0xf4,0xf000,0x10c); }
        else { b.processor_fault(13,0x100); check(b.accepted.size()==10,"overlong instruction fetched extension"); } ++cases;
    }
    for (bool invalid_limit: {false,true}) {
        Bench b; b.put(0xfffff0,{0xea,0,1,0,0xf0});
        b.put(0xf0100,{0xbc,0,0x80,0x0f,1,0x1e,0,0x20,0xcd,0x20,0x43,0xf4});
        b.put(0x2000,{uint8_t(invalid_limit?0x82:0x83),0,0,0,6,0xa5});
        b.put(0x60080,{0,1,0,0x20}); b.put(0x80,{0,1,0,0x30}); b.put(0x20100,{0x43,0xcf});
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100); b.step(0xf0100,0xbc,0xf000,0x103);
        b.step(0xf0103,0x0f,0xf000,0x108); b.data_transfers.clear();
        if (invalid_limit) b.processor_fault(8,0x108,true,0x60000);
        else { b.step(0xf0108,0xcd,0x2000,0x100);
            check(b.data_transfers.size()==10,"redirected INT transfer count");
            for (unsigned i=0;i<4;++i) check(b.data_transfers[i].address==0x60080+i && !b.data_transfers[i].write,"INT ignored loaded IDTR base");
            b.step(0x20100,0x43,0x2000,0x101); b.step(0x20101,0xcf,0xf000,0x10a);
            b.step(0xf010a,0x43,0xf000,0x10b); b.step(0xf010b,0xf4,0xf000,0x10c);
            check(b.reg(3)==2 && b.reg(4)==0x8000,"redirected handler/IRET context"); } ++cases;
    }
    for (unsigned group=0;group<4;++group) for (unsigned cut=0;cut<=6;++cut) {
        Bench b; b.put(0xfffff0,{0xea,0,1,0,0xf0});
        b.put(0xf0100,{0x0f,1,uint8_t(6+8*group),0,0x20,0x90,0xf4});
        for (unsigned i=0;i<6;++i) b.memory[0x2000+i]=uint8_t(0xa0+i);
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100); b.data_transfers.clear();
        unsigned ticks=0;
        while (!(b.d.bus_req_o && !b.d.bus_fetch_o) && ++ticks<200) b.tick();
        check(ticks<200,"reset-cut operand was never requested");
        ticks=0; while (b.data_transfers.size()<cut && ++ticks<200) b.tick();
        check(ticks<200 && !b.d.retire_o,"table transaction retired before reset cut");
        b.reset();
        for (unsigned i=0;i<6;++i) {
            const uint8_t stored=group==1 && i<2?uint8_t(0x3ff>>(8*i)):i==5?0xff:0;
            check(b.memory[0x2000+i]==(group<2 && i<cut?stored:uint8_t(0xa0+i)),"reset lost/created accepted table write");
        }
        b.put(0xf0100,{0x0f,1,6,0,0x30,0x0f,1,0x0e,0,0x40,0x90,0xf4});
        b.step(0xfffff0,0xea,0xf000,0x100); b.step(0xf0100,0x0f,0xf000,0x105);
        b.step(0xf0105,0x0f,0xf000,0x10a);
        const uint8_t gdtr[]={0,0,0,0,0,0xff},idtr[]={0xff,3,0,0,0,0xff};
        for (unsigned i=0;i<6;++i) check(b.memory[0x3000+i]==gdtr[i] && b.memory[0x4000+i]==idtr[i],"reset did not restore table-register policy");
        b.step(0xf010a,0x90,0xf000,0x10b); b.step(0xf010b,0xf4,0xf000,0x10c); ++cases;
    }
    for (unsigned r=0;r<8;++r) {
        Bench b; b.put(0xfffff0,{0xea,0,1,0,0xf0});
        b.put(0xf0100,{uint8_t(0xb8+r),0xff,0xff,0x0f,1,uint8_t(0xf0+r),0x90});
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100); b.step(0xf0100,uint8_t(0xb8+r),0xf000,0x103);
        b.step(0xf0103,0x0f,0xf000,0x106);
        if (b.d.msw_o!=0xffff) std::cerr<<"register LMSW r="<<r<<" MSW="<<std::hex<<b.d.msw_o
                                             <<" source="<<b.reg(r)<<std::dec<<'\n';
        check(b.d.msw_o==0xffff,"register LMSW did not set requested low MSW bits");
        check(b.reg(r)==0xffff,"register LMSW changed its source register"); ++cases;
    }
    for (unsigned encoding: {0xc0u,0xc8u,0xd0u,0xd8u,0xe8u,0xf8u}) {
        Bench b; b.put(0xfffff0,{0xea,0,1,0,0xf0}); b.put(0xf0100,{0x0f,1,uint8_t(encoding)});
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100); b.data_transfers.clear();
        b.ud_fault(0x100); ++cases;
    }
    for (uint16_t offset: {uint16_t(0xfffe),uint16_t(0xffff)}) {
        Bench b; b.put(0xfffff0,{0xea,uint8_t(offset),0xff,0,0xf0}); b.put(0xf0000+offset,{0x0f,6});
        b.put(0xf0000,{0x90,0xf4}); b.reset(); b.step(0xfffff0,0xea,0xf000,offset); b.accepted.clear();
        if (offset==0xfffe) { b.step(0xffffe,0x0f,0xf000,0); check(b.accepted.size()==2,"legal extension wrap fetch count");
            b.step(0xf0000,0x90,0xf000,1); b.step(0xf0001,0xf4,0xf000,2); }
        else { b.stop(2,0xffff); check(b.accepted.size()==1,"extension fetched beyond code limit"); } ++cases;
    }
    for (bool invalid_limit: {false,true}) {
        Bench b; b.put(0xfffff0,{0xea,0,1,0,0xf0});
        b.put(0xf0100,{0xbc,0,0x80,0x0f,1,0x1e,0,0x20,0xfb,0x90,0x43,0xf4});
        b.put(0x2000,{uint8_t(invalid_limit?0x82:0x83),0,0,0,6,0}); b.put(0x60080,{0,1,0,0x20});
        b.put(0x80,{0,1,0,0x30}); b.put(0x20100,{0x43,0xcf});
        b.reset(); b.step(0xfffff0,0xea,0xf000,0x100); b.step(0xf0100,0xbc,0xf000,0x103);
        b.step(0xf0103,0x0f,0xf000,0x108); b.step(0xf0108,0xfb,0xf000,0x109);
        b.d.intr_i=1; b.acknowledge=true; b.interrupt_vector=0x20; b.step(0xf0109,0x90,0xf000,0x10a);
        b.data_transfers.clear();
        if (invalid_limit) b.processor_fault(8,0x10a,true,0x60000,1);
        else { interrupt_entry(b,0x20,0x10a,0x202); b.d.intr_i=0;
            for (unsigned i=0;i<4;++i) check(b.data_transfers[i].address==0x60080+i,"INTR ignored loaded IDTR");
            b.step(0x20100,0x43,0x2000,0x101); b.step(0x20101,0xcf,0xf000,0x10a);
            b.step(0xf010a,0x43,0xf000,0x10b); b.step(0xf010b,0xf4,0xf000,0x10c); }
        check(b.acknowledgements==1,"relocated INTR acknowledgement count"); ++cases;
    }
    std::cout<<"PASS: "<<cases<<" system-register cases, exact successors, six-byte bus images, reset cuts and relocated IDT\n";
}

static void bios_system_registers(const char* path) {
    std::ifstream input(path,std::ios::binary); check(bool(input),"system BIOS ROM missing");
    std::vector<uint8_t> rom((std::istreambuf_iterator<char>(input)),{}); check(rom.size()==65536,"system BIOS ROM size");
    // Original IBM AT table-register self-test, F000:064F..0688. Four original
    // byte-repeated patterns make its overlapping five-word comparison valid.
    // Entry/return state is a RAM fixture; every tested body byte is original.
    unsigned states=0;
    for (uint16_t pattern: {uint16_t(0),uint16_t(0xffff),uint16_t(0x5555),uint16_t(0xaaaa)}) {
        Bench b; for (unsigned i=0;i<rom.size();++i) b.memory[0xf0000+i]=rom[i];
        b.put(0xfffff0,{0xea,0,0x10,0,0});
        b.put(0x1000,{0xbc,0,0x80,0xb8,uint8_t(pattern),uint8_t(pattern>>8),0xbf,0xa0,0xd0,0xea,0x4f,6,0,0xf0});
        b.put(0x8000,{0x24,0x02});
        b.reset(); b.step(0xfffff0,0xea,0,0x1000); b.step(0x1000,0xbc,0,0x1003);
        b.step(0x1003,0xb8,0,0x1006); b.step(0x1006,0xbf,0,0x1009); b.step(0x1009,0xea,0xf000,0x64f);
        auto step=[&](uint16_t pc,uint8_t op,uint16_t next) { b.step(0xf0000+pc,op,0xf000,next); ++states; };
        step(0x64f,0xb9,0x652); step(0x652,0xab,0x654);
        for (const auto& pair: {std::pair<unsigned,unsigned>{0x654,0x657},{0x65c,0x65f},{0x664,0x667},{0x66c,0x66f}}) {
            step(pair.first,0xbd,pair.second); step(pair.second,0x0f,pair.second+5); }
        step(0x674,0xbf,0x677); step(0x677,0x8b,0x679); step(0x679,0xb9,0x67c); step(0x67c,0xbe,0x67f);
        for (unsigned i=0;i<5;++i) {
            step(0x67f,0x3b,0x682); check(b.d.flags_o&0x40,"original BIOS system-table comparison failed");
            step(0x682,0x75,0x684); step(0x684,0x46,0x685); step(0x685,0x46,0x686);
            step(0x686,0xe2,i==4?0x688:0x67f);
        }
        b.step(0xf0688,0xc3,0xf000,0x224); ++states;
        b.step(0xf0224,0xf4,0xf000,0x225); ++states;
        check(b.reg(4)==0x8002 && b.reg(1)==0,"original BIOS table self-test return context");
        for (unsigned i=0;i<rom.size();++i) check(b.memory[0xf0000+i]==rom[i],"system fixture modified original BIOS image");
    }
    std::cout<<"PASS: original IBM AT system-register self-test, 4 patterns, "<<states<<" exact original instruction states\n";
}

static void vectors(const char* path, bool firmware=false, bool routines=false) {
    std::ifstream input(path);
    check(bool(input), "independent vector file missing");
    std::unique_ptr<Bench> b;
    std::string token, label;
    unsigned cases=0, states=0;
    uint32_t current_pc=0;
    unsigned transfer_cursor=0;
    try {
        while (input>>token) {
            if (token=="ROM") {
                std::string rom_path; input>>label>>rom_path;
                std::ifstream rom_file(rom_path,std::ios::binary);
                check(bool(rom_file),"firmware trace ROM missing");
                std::vector<uint8_t> rom((std::istreambuf_iterator<char>(rom_file)),{});
                check(rom.size()==65536,"firmware trace ROM size");
                b=std::make_unique<Bench>();
                for (unsigned i=0;i<rom.size();++i) b->memory[0xf0000+i]=b->memory[0xff0000+i]=rom[i];
                b->reset(); ++cases;
            } else if (token=="CASE") {
                std::string code; input>>label>>code;
                b=std::make_unique<Bench>();
                b->put(0xfffff0,{0xea,0x00,0x10,0x00,0x00});
                for (unsigned i=0;i<code.size();i+=2)
                    b->memory[0x1000+i/2]=uint8_t(std::stoul(code.substr(i,2),nullptr,16));
                b->reset(); b->step(0xfffff0,0xea,0,0x1000);
                ++cases;
            } else if (token=="MEM") {
                uint32_t address; std::string bytes; input>>std::hex>>address>>std::dec>>bytes;
                for (unsigned i=0;i<bytes.size();i+=2)
                    b->memory[address+i/2]=uint8_t(std::stoul(bytes.substr(i,2),nullptr,16));
            } else if (token=="PORT") {
                uint32_t address,value; input>>std::hex>>address>>value>>std::dec;
                b->ports[uint16_t(address)]=uint8_t(value);
            } else if (token=="STEP") {
                uint32_t op,next,flags,mask,ax_mask;
                uint64_t segs;
                input>>std::hex>>current_pc>>op>>next>>flags>>mask>>segs>>ax_mask>>std::dec;
                check(bool(input) && bool(b), "malformed oracle STEP");
                b->accepted.clear(); b->data_transfers.clear(); transfer_cursor=0;
                b->step(current_pc,uint8_t(op),uint16_t(segs>>16),uint16_t(next),cases%2);
                if (((b->d.flags_o^flags)&mask)!=0) {
                    std::cerr<<std::hex<<"FLAGS actual="<<b->d.flags_o<<" expected="<<flags<<" mask="<<mask<<'\n';
                    throw std::runtime_error("independent flag mismatch");
                }
                check(b->d.segs_o==segs, "independent segment-register mismatch");
                for (unsigned r=0;r<8;++r) {
                    uint32_t expected; input>>std::hex>>expected>>std::dec;
                    if (((b->reg(r)^expected)&(r==0?ax_mask:0xffff))!=0) {
                        std::cerr<<std::hex<<"register "<<r<<" actual="<<b->reg(r)<<" expected="<<expected<<'\n';
                        throw std::runtime_error("independent register mismatch");
                    }
                }
                check(bool(input), "truncated oracle STEP");
                ++states;
            } else if (token=="FETCH") {
                uint32_t address; unsigned size; input>>std::hex>>address>>size>>std::dec;
                check(b->accepted.size()==size,"independent fetch byte count");
                for (unsigned i=0;i<size;++i) check(b->accepted[i]==address+i,"independent fetch address");
            } else if (token=="BUS" || token=="BUS_ANY") {
                uint32_t address,value,write,io; input>>std::hex>>address>>value>>write>>io>>std::dec;
                check(transfer_cursor<b->data_transfers.size(),"missing data transaction");
                if (token=="BUS_ANY") {
                    auto found=std::find_if(b->data_transfers.begin()+transfer_cursor,b->data_transfers.end(),[&](const auto& t){
                        return t.address==address && t.value==value && t.write==bool(write) && t.io==bool(io); });
                    check(found!=b->data_transfers.end(),"missing unordered oracle memory effect");
                    std::iter_swap(b->data_transfers.begin()+transfer_cursor,found);
                }
                const auto& transfer=b->data_transfers[transfer_cursor++];
                if (!(transfer.address==address && transfer.value==value && transfer.write==bool(write) && transfer.io==bool(io))) {
                    std::cerr<<std::hex<<"bus actual="<<transfer.address<<":"<<unsigned(transfer.value)
                             <<" expected="<<address<<":"<<value<<'\n';
                    throw std::runtime_error("independent bus side-effect mismatch");
                }
            } else if (token=="CHECK") check(transfer_cursor==b->data_transfers.size(),"unexpected data transaction");
            else if (token=="STOP") {
                unsigned code,ip; input>>std::hex>>code>>ip>>std::dec; b->stop(code,uint16_t(ip));
            } else if (token=="END") {
                if (firmware) check(b && b->cs()==0xf000 && b->d.ip_o==0x0225 && states==196846,
                                    "original BIOS did not reach required checksum-success checkpoint");
                b.reset();
            }
            else throw std::runtime_error("malformed oracle record");
        }
        check(!b,"truncated oracle case");
        check(firmware ? cases==1 && states==196846 : routines ? cases==16 && states==464 : cases>=99650 && states>=1715162, "independent vector suite incomplete");
    } catch (...) {
        std::cerr<<"oracle case "<<label<<" PC="<<std::hex<<current_pc<<std::dec<<'\n'; throw;
    }
    std::cout<<"PASS: "<<cases<<" independent Unicorn cases, "<<states<<" exact instruction states\n";
}

static void protected_mode_segment_integration() {
    using namespace protected_mode_fixture;
    Bench sticky;
    sticky.put(kResetVector,{0xea,0x00,0x01,0x00,0xf0});
    sticky.put(kRealCodeBase+0x0100,{0xb8,0x01,0x00,0x0f,0x01,0xf0,
                                    0xb8,0x00,0x00,0x0f,0x01,0xf0,0x90,0xf4});
    sticky.reset();
    sticky.step(kResetVector,0xea,0xf000,0x0100);
    sticky.step(kRealCodeBase+0x0100,0xb8,0xf000,0x0103);
    sticky.step(kRealCodeBase+0x0103,0x0f,0xf000,0x0106);
    check(sticky.d.msw_o==0xfff1,"LMSW failed to set PE");
    sticky.step(kRealCodeBase+0x0106,0xb8,0xf000,0x0109);
    sticky.step(kRealCodeBase+0x0109,0x0f,0xf000,0x010c);
    if (!(sticky.d.msw_o==0xfff1 && sticky.d.cs_base_o==kRealCodeBase && sticky.d.seg_valid_o==0x0f)) {
        std::cerr<<"sticky LMSW state MSW="<<std::hex<<sticky.d.msw_o
                 <<" CSbase="<<sticky.d.cs_base_o<<" valid="<<unsigned(sticky.d.seg_valid_o)<<std::dec<<'\n';
        throw std::runtime_error("LMSW cleared sticky PE or changed inherited caches");
    }
    sticky.step(kRealCodeBase+0x010c,0x90,0xf000,0x010d);
    sticky.step(kRealCodeBase+0x010d,0xf4,0xf000,0x010e);

    for (bool wait : {false,true}) {
    Bench b;
    b.wait_mode=wait;
    auto place=[&](uint32_t address,const uint8_t* bytes,std::size_t count) {
        for (std::size_t i=0;i<count;++i) b.memory[address+uint32_t(i)]=bytes[i];
    };
    place(kResetVector,kResetJump,sizeof(kResetJump));
    place(kRealCodeBase+0x0100,kRealModeProgram,sizeof(kRealModeProgram));
    place(0x00000040,kGdtrImage,sizeof(kGdtrImage));
    place(0x00000046,kIdtrImage,sizeof(kIdtrImage));
    place(kGdtBase,kGdtImage,sizeof(kGdtImage));
    place(kIdtBase+uint32_t(kFaultVector)*8,kVector13Gate,sizeof(kVector13Gate));
    place(kCodeBase+0x0200,kProtectedProgram,sizeof(kProtectedProgram));
    place(kHandlerBase+kHandlerIp,kVector13Handler,sizeof(kVector13Handler));
    place(kNarrowDataBase+2,kNarrowDataSeed,sizeof(kNarrowDataSeed));
    place(kWideDataBase+0x000f,kWideRetryWord,sizeof(kWideRetryWord));

    auto check_descriptor_transaction=[&](std::size_t start,uint32_t address,uint8_t access) {
        check(start+9<=b.data_transfers.size(),"descriptor transaction byte count");
        for (unsigned i=0;i<8;++i) {
            const auto& t=b.data_transfers[start+i];
            check(t.address==address+i && !t.write && !t.io && !t.segmented &&
                  t.role==0 && t.kind==3 && t.offset==((address+i)&0xffff) && t.size==1,
                  "descriptor read address/order/context");
            const uint8_t expected_byte=i==5 ? access : b.memory[address+i];
            check(t.value==expected_byte,"descriptor read byte value");
        }
        const auto& write=b.data_transfers[start+8];
        check(write.address==address+5 && write.write && !write.io && !write.segmented &&
              write.role==0 && write.kind==3 && write.offset==((address+5)&0xffff) &&
              write.size==1 && write.value==uint8_t(access|1),
              "descriptor accessed-byte write/order/context");
    };
    auto descriptor_transaction=[&](uint32_t address,uint8_t access) {
        check(b.data_transfers.size()==9,"descriptor transaction byte count");
        check_descriptor_transaction(0,address,access);
        b.data_transfers.clear();
    };

    auto restart_to_fault=[&]() {
        b.reset();
        b.data_transfers.clear();
        b.step(kResetVector,0xea,0xf000,0x0100);
        b.step(kRealCodeBase+0x0100,0x0f,0xf000,0x0105);
        b.step(kRealCodeBase+0x0105,0x0f,0xf000,0x010a);
        b.step(kRealCodeBase+0x010a,0xf9,0xf000,0x010b);
        b.step(kRealCodeBase+0x010b,0xfd,0xf000,0x010c);
        b.step(kRealCodeBase+0x010c,0xfb,0xf000,0x010d);
        b.step(kRealCodeBase+0x010d,0xb8,0xf000,0x0110);
        b.step(kRealCodeBase+0x0110,0x0f,0xf000,0x0113);
        b.step(kRealCodeBase+0x0113,0xeb,0xf000,0x0115);
        b.step(kRealCodeBase+0x0115,0xea,kCodeSelector,0x0200);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205);
        b.step(kCodeBase+0x0205,0xb8,kCodeSelector,0x0208);
        b.step(kCodeBase+0x0208,0x8e,kCodeSelector,0x020a);
        b.step(kCodeBase+0x020a,0xb8,kCodeSelector,0x020d);
        b.step(kCodeBase+0x020d,0x8e,kCodeSelector,0x020f);
        b.step(kCodeBase+0x020f,0xbc,kCodeSelector,0x0212);
        b.step(kCodeBase+0x0212,0xa1,kCodeSelector,0x0215);
        b.step(kCodeBase+0x0215,0xa3,kCodeSelector,0x0218);
        b.step(kCodeBase+0x0218,0xa3,kCodeSelector,0x021c);
        b.step(kCodeBase+0x021c,0x50,kCodeSelector,0x021d);
        b.step(kCodeBase+0x021d,0x5b,kCodeSelector,0x021e);
        b.step(kCodeBase+0x021e,0xb8,kCodeSelector,kFaultIp);
        b.data_transfers.clear();
    };

    b.reset();
    b.step(kResetVector,0xea,0xf000,0x0100);
    b.step(kRealCodeBase+0x0100,0x0f,0xf000,0x0105);
    b.step(kRealCodeBase+0x0105,0x0f,0xf000,0x010a);
    b.step(kRealCodeBase+0x010a,0xf9,0xf000,0x010b);
    b.step(kRealCodeBase+0x010b,0xfd,0xf000,0x010c);
    b.step(kRealCodeBase+0x010c,0xfb,0xf000,0x010d);
    b.step(kRealCodeBase+0x010d,0xb8,0xf000,0x0110);
    b.step(kRealCodeBase+0x0110,0x0f,0xf000,0x0113);
    check(b.d.msw_o==0xfff1,"LMSW did not set PE");
    b.step(kRealCodeBase+0x0113,0xeb,0xf000,0x0115);
    b.data_transfers.clear();
    b.step(kRealCodeBase+0x0115,0xea,kCodeSelector,0x0200);
    if (!(b.cs()==kCodeSelector && b.d.cs_base_o==kCodeBase &&
          ((b.d.seg_limits_o>>16)&0xffff)==0x0fff &&
          ((b.d.seg_access_o>>8)&0xff)==0x9a && (b.d.seg_valid_o&2))) {
        std::cerr<<"protected CS result selector="<<std::hex<<b.cs()<<" base="<<b.d.cs_base_o
                 <<" limit="<<((b.d.seg_limits_o>>16)&0xffff)<<" access="<<((b.d.seg_access_o>>8)&0xff)
                 <<" valid="<<unsigned(b.d.seg_valid_o)<<" transfers="<<std::dec<<b.data_transfers.size()<<'\n';
        throw std::runtime_error("protected far JMP did not commit the validated CS cache");
    }
    descriptor_transaction(kGdtBase+8,0x9a);

    b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203);
    b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205);
    check(b.cs()==kCodeSelector && b.cache_base(3)==kNarrowDataBase &&
          ((b.d.seg_limits_o>>48)&0xffff)==0x000f &&
          ((b.d.seg_access_o>>24)&0xff)==0x92 && (b.d.seg_valid_o&8),
          "protected MOV DS did not commit its descriptor cache");
    descriptor_transaction(kGdtBase+24,0x92);

    b.step(kCodeBase+0x0205,0xb8,kCodeSelector,0x0208);
    b.step(kCodeBase+0x0208,0x8e,kCodeSelector,0x020a);
    check(b.cache_base(0)==kEsDataBase && ((b.d.seg_limits_o)&0xffff)==0x00ff &&
          ((b.d.seg_access_o)&0xff)==0x92 && (b.d.seg_valid_o&1),
          "protected MOV ES did not commit its descriptor cache");
    descriptor_transaction(kGdtBase+32,0x92);

    b.step(kCodeBase+0x020a,0xb8,kCodeSelector,0x020d);
    b.step(kCodeBase+0x020d,0x8e,kCodeSelector,0x020f);
    check(b.cache_base(2)==kStackBase && ((b.d.seg_limits_o>>32)&0xffff)==0x00ff &&
          ((b.d.seg_access_o>>16)&0xff)==0x92 && (b.d.seg_valid_o&4),
          "protected MOV SS did not commit its descriptor cache");
    descriptor_transaction(kGdtBase+40,0x92);

    b.step(kCodeBase+0x020f,0xbc,kCodeSelector,0x0212);
    b.step(kCodeBase+0x0212,0xa1,kCodeSelector,0x0215);
    check(b.reg(0)==0x1234,"protected DS read used the wrong cached base");
    b.step(kCodeBase+0x0215,0xa3,kCodeSelector,0x0218);
    check(b.memory[kNarrowDataBase+4]==0x34 && b.memory[kNarrowDataBase+5]==0x12,
          "protected DS write used the wrong cached base");
    b.step(kCodeBase+0x0218,0xa3,kCodeSelector,0x021c);
    check(b.memory[kEsDataBase+6]==0x34 && b.memory[kEsDataBase+7]==0x12,
          "protected ES write used the wrong cached base");
    b.step(kCodeBase+0x021c,0x50,kCodeSelector,0x021d);
    b.step(kCodeBase+0x021d,0x5b,kCodeSelector,0x021e);
    b.step(kCodeBase+0x021e,0xb8,kCodeSelector,kFaultIp);
    check(b.reg(0)==0xcafe && b.reg(3)==0x1234 && b.d.flags_o==kSavedFlags,
          "protected fixture state before the scoped limit fault");

    b.data_transfers.clear();
    for (unsigned n=0;n<100000 && !b.d.event_o && !b.d.fault_o;++n) b.tick(wait);
    check(!b.d.fault_o && b.d.event_o && b.cs()==kHandlerSelector &&
          b.d.cs_base_o==kHandlerBase && b.d.ip_o==kHandlerIp,
          "protected #GP did not enter its configured IDT handler");
    check(b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
          b.d.event_packet_error_valid_o && b.d.event_packet_restartable_o &&
          b.d.event_vector_o==kFaultVector && b.d.event_packet_error_code_o==kFaultError &&
          b.d.event_packet_saved_cs_o==kCodeSelector && b.d.event_packet_saved_ip_o==kFaultIp &&
          b.d.event_packet_saved_flags_o==kSavedFlags && b.d.event_packet_saved_sp_o==kInitialSp,
          "protected #GP packet lost its exact architectural context");
    check(b.reg(0)==kAxAtHandler && b.d.flags_o==kLiveFlagsAtHandler &&
          b.reg(4)==kInitialSp-8 && !b.d.bus_req_o,
          "protected event entry committed the wrong registers, SP or FLAGS");
    check(b.data_transfers.size()==25,"protected event transaction count");
    for (unsigned i=0;i<8;++i) {
        const auto& t=b.data_transfers[i];
        check(t.address==kIdtBase+uint32_t(kFaultVector)*8+i && !t.write && !t.io &&
              !t.segmented && t.value==kVector13Gate[i] && t.size==(i<6?6:2),
              "IDT interrupt-gate read address/order/value");
    }
    check_descriptor_transaction(8,kGdtBase+0x30,0x9a);
    for (unsigned i=0;i<8;++i) {
        const auto& t=b.data_transfers[17+i];
        check(t.address==kFaultFrameWrites[i].address && t.value==kFaultFrameWrites[i].value &&
              t.write && !t.io && t.segmented && t.role==2 && t.kind==1 && t.size==2,
              "protected error frame write address/order/value");
    }
    check(b.memory[kWideDataBase+0x000f]==0xef && b.memory[kWideDataBase+0x0010]==0xbe,
          "wide retry seed changed before the handler");
    b.data_transfers.clear();

    b.step(kHandlerBase+kHandlerIp,0x83,kHandlerSelector,kHandlerIp+3);
    check(b.reg(4)==0x007a && b.data_transfers.empty(),"handler did not discard exactly the error word");
    b.step(kHandlerBase+kHandlerIp+3,0x50,kHandlerSelector,kHandlerIp+4);
    check(b.data_transfers.size()==2 && b.data_transfers[0].address==kStackBase+0x78 &&
          b.data_transfers[0].write && b.data_transfers[0].value==0xfe &&
          b.data_transfers[1].address==kStackBase+0x79 && b.data_transfers[1].write &&
          b.data_transfers[1].value==0xca,"handler AX save did not overwrite only the discarded error word");
    b.data_transfers.clear();
    b.step(kHandlerBase+kHandlerIp+4,0xb8,kHandlerSelector,kHandlerIp+7);
    b.step(kHandlerBase+kHandlerIp+7,0x8e,kHandlerSelector,kHandlerIp+9);
    check(b.cache_base(3)==kWideDataBase && ((b.d.seg_limits_o>>48)&0xffff)==0x00ff &&
          b.reg(0)==0x0010,"handler did not commit the wider DS descriptor");
    descriptor_transaction(kGdtBase+16,0x92);
    b.step(kHandlerBase+kHandlerIp+9,0x58,kHandlerSelector,kHandlerIp+10);
    check(b.reg(0)==kAxAtHandler && b.reg(4)==0x007a && b.data_transfers.size()==2 &&
          !b.data_transfers[0].write && b.data_transfers[0].address==kStackBase+0x78 &&
          b.data_transfers[0].value==0xfe && !b.data_transfers[1].write &&
          b.data_transfers[1].address==kStackBase+0x79 && b.data_transfers[1].value==0xca,
          "handler POP AX did not restore AX and SP");
    b.data_transfers.clear();
    b.step(kHandlerBase+kHandlerIp+10,0xcf,kCodeSelector,kFaultIp);
    check(b.reg(4)==kInitialSp && b.d.flags_o==kSavedFlags && b.cs()==kCodeSelector &&
          b.d.ip_o==kFaultIp && b.cache_base(3)==kWideDataBase,
          "protected IRET did not atomically restore the exact fault context");
    check(b.data_transfers.size()==15,"protected IRET stack/descriptor transaction count");
    const uint8_t iret_frame[]={0x21,0x02,0x08,0x00,0x03,0x06};
    for (unsigned i=0;i<6;++i) {
        const auto& t=b.data_transfers[i];
        check(t.address==kStackBase+0x7a+i && !t.write && !t.io && t.segmented &&
              t.role==2 && t.kind==0 && t.value==iret_frame[i] && t.size==6,
              "IRET stack frame read address/order/value");
    }
    check_descriptor_transaction(6,kGdtBase+8,0x9b);
    b.data_transfers.clear();
    b.step(kCodeBase+kFaultIp,0xa1,kCodeSelector,kFaultSuccessorIp);
    check(b.reg(0)==kAxAfterRetry && b.d.flags_o==kSavedFlags && b.data_transfers.size()==2 &&
          b.data_transfers[0].address==kRetryReadFirst && !b.data_transfers[0].write &&
          b.data_transfers[0].value==0xef && b.data_transfers[1].address==kRetryReadLast &&
          !b.data_transfers[1].write && b.data_transfers[1].value==0xbe,
          "faulting instruction did not retry through the widened cache");
    b.data_transfers.clear();
    b.step(kCodeBase+kFaultSuccessorIp,0x45,kCodeSelector,kFaultSuccessorIp+1);
    check(b.reg(5)==kBpAfterSuccessor,"exact post-retry successor did not execute");
    b.step(kCodeBase+kFaultSuccessorIp+1,0xf4,kCodeSelector,kFaultSuccessorIp+2);
    check(b.d.halted_o && b.reg(4)==kInitialSp && b.memory[kStackBase+0x78]==0xfe &&
          b.memory[kStackBase+0x79]==0xca && b.data_transfers.empty(),
          "protected recovery did not reach its exact HLT/checkpoint");
    check(b.memory[kDeniedReadFirst]==0 && b.memory[kDeniedReadLast]==0,
          "denied narrow DS span touched physical memory");

    // Repeat from reset with cuts inside each irreversible delivery phase.
    // Accepted external writes survive reset; CS:IP, FLAGS and SP do not move
    // until the event or return commit boundary.
    for (unsigned cut : {3u,12u,17u,19u}) {
        restart_to_fault();
        for (unsigned n=0;n<100000 && b.data_transfers.size()<cut;++n) b.tick(wait);
        check(b.data_transfers.size()==cut && !b.d.event_o && !b.d.fault_o,
              "protected reset cut missed its gate/descriptor/frame transfer");
        check(b.cs()==kCodeSelector && b.d.cs_base_o==kCodeBase && b.reg(4)==kInitialSp &&
              b.d.flags_o==kSavedFlags && b.reg(0)==kAxAtHandler,
              "protected event published architecture before complete frame delivery");
        b.reset();
        check(b.memory[kGdtBase+0x35]==(cut>=17?0x9b:b.memory[kGdtBase+0x35]),
              "reset rolled back an accepted handler descriptor accessed write");
        if (cut>=19)
            check(b.memory[kStackBase+0x7e]==0x03 && b.memory[kStackBase+0x7f]==0x06,
                  "reset rolled back accepted protected frame bytes");
    }

    restart_to_fault();
    for (unsigned n=0;n<100000 && !b.d.event_o && !b.d.fault_o;++n) b.tick(wait);
    check(b.d.event_o && !b.d.fault_o,"reset-cut preparation failed to reach handler");
    b.data_transfers.clear();
    b.step(kHandlerBase+kHandlerIp,0x83,kHandlerSelector,kHandlerIp+3);
    b.step(kHandlerBase+kHandlerIp+3,0x50,kHandlerSelector,kHandlerIp+4);
    b.data_transfers.clear();
    b.step(kHandlerBase+kHandlerIp+4,0xb8,kHandlerSelector,kHandlerIp+7);
    b.step(kHandlerBase+kHandlerIp+7,0x8e,kHandlerSelector,kHandlerIp+9);
    b.data_transfers.clear();
    b.step(kHandlerBase+kHandlerIp+9,0x58,kHandlerSelector,kHandlerIp+10);
    b.data_transfers.clear();
    for (unsigned n=0;n<100000 && b.data_transfers.size()<15;++n) b.tick(wait);
    if (!(b.data_transfers.size()==15 && !b.d.fault_o && !b.d.event_o && !b.d.retire_o &&
          b.cs()==kHandlerSelector && b.d.cs_base_o==kHandlerBase && b.reg(4)==0x007a &&
          b.d.flags_o==0x0402))
        std::cerr<<"IRET cut wait="<<wait<<" transfers="<<b.data_transfers.size()<<" fault="<<b.d.fault_o
                 <<" event="<<b.d.event_o<<" retire="<<b.d.retire_o<<" CS="<<std::hex<<b.cs()
                 <<" base="<<b.d.cs_base_o<<" SP="<<b.reg(4)<<" FLAGS="<<b.d.flags_o<<std::dec<<'\n';
    check(b.data_transfers.size()==15 && !b.d.fault_o && !b.d.event_o && !b.d.retire_o &&
          b.cs()==kHandlerSelector && b.d.cs_base_o==kHandlerBase && b.reg(4)==0x007a &&
          b.d.flags_o==0x0402,
          "IRET commit reset cut did not stop after validation and before architectural commit");
    b.tick(wait);
    check(b.cs()==kHandlerSelector && b.d.cs_base_o==kHandlerBase && b.reg(4)==0x007a &&
          b.d.flags_o==0x0402 && !b.d.retire_o,
          "validated IRET exposed return state before its commit edge");
    b.reset();
    check(!b.d.event_packet_valid_o && !b.d.bus_req_o && b.cs()==0xf000 && b.d.ip_o==0xfff0,
          "reset failed to cancel a validated protected IRET");
    }
    std::cout<<"PASS: both wait modes complete protected #GP recovery and reset cuts across gate, descriptor, frame and IRET commit\n";
}

static void protected_arpl_contracts() {
    using namespace protected_mode_fixture;
    for (bool wait : {false,true}) {
        Bench b;
        b.wait_mode=wait;
        auto place=[&](uint32_t address,const uint8_t* bytes,std::size_t count) {
            for (std::size_t i=0;i<count;++i) b.memory[address+uint32_t(i)]=bytes[i];
        };
        place(kResetVector,kResetJump,sizeof(kResetJump));
        place(kRealCodeBase+0x0100,kRealModeProgram,sizeof(kRealModeProgram));
        place(0x00000040,kGdtrImage,sizeof(kGdtrImage));
        place(0x00000046,kIdtrImage,sizeof(kIdtrImage));
        place(kGdtBase,kGdtImage,sizeof(kGdtImage));
        place(kIdtBase+uint32_t(kFaultVector)*8,kVector13Gate,sizeof(kVector13Gate));
        place(kHandlerBase+kHandlerIp,kVector13Handler,sizeof(kVector13Handler));
        const uint8_t protected_program[]={
            0xb8,0x10,0x00, 0x8e,0xd8,             // 0200 MOV DS,0010
            0xb8,0x09,0x00, 0xb9,0x0b,0x00,       // 0205 AX=0009, CX=000B
            0x63,0xc8,                            // 020B ARPL AX,CX: adjust and set ZF
            0xb8,0x0a,0x00, 0xb9,0x09,0x00,       // 020D AX=000A, CX=0009
            0x63,0xc8,                            // 0213 ARPL AX,CX: unchanged and clear ZF
            0xb9,0x0b,0x00, 0x63,0x0e,0x00,0x00, // 0215 CX=000B; ARPL [0000],CX
            0xb9,0x09,0x00, 0x63,0x0e,0x02,0x00, // 021C CX=0009; ARPL [0002],CX
            0xf4                                   // 0223 HLT
        };
        place(kCodeBase+0x0200,protected_program,sizeof(protected_program));
        b.memory[kWideDataBase+0]=0x11; b.memory[kWideDataBase+1]=0x00;
        b.memory[kWideDataBase+2]=0x12; b.memory[kWideDataBase+3]=0x00;

        b.reset();
        b.step(kResetVector,0xea,0xf000,0x0100);
        b.step(kRealCodeBase+0x0100,0x0f,0xf000,0x0105);
        b.step(kRealCodeBase+0x0105,0x0f,0xf000,0x010a);
        b.step(kRealCodeBase+0x010a,0xf9,0xf000,0x010b);
        b.step(kRealCodeBase+0x010b,0xfd,0xf000,0x010c);
        b.step(kRealCodeBase+0x010c,0xfb,0xf000,0x010d);
        b.step(kRealCodeBase+0x010d,0xb8,0xf000,0x0110);
        b.step(kRealCodeBase+0x0110,0x0f,0xf000,0x0113);
        b.step(kRealCodeBase+0x0113,0xeb,0xf000,0x0115);
        b.step(kRealCodeBase+0x0115,0xea,kCodeSelector,0x0200);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205);
        b.data_transfers.clear();
        b.step(kCodeBase+0x0205,0xb8,kCodeSelector,0x0208);
        b.step(kCodeBase+0x0208,0xb9,kCodeSelector,0x020b);
        b.step(kCodeBase+0x020b,0x63,kCodeSelector,0x020d);
        check(b.reg(0)==0x000b && (b.d.flags_o&0x0040),
              "ARPL register form did not raise destination RPL and set ZF");
        b.step(kCodeBase+0x020d,0xb8,kCodeSelector,0x0210);
        b.step(kCodeBase+0x0210,0xb9,kCodeSelector,0x0213);
        b.step(kCodeBase+0x0213,0x63,kCodeSelector,0x0215);
        check(b.reg(0)==0x000a && !(b.d.flags_o&0x0040),
              "ARPL register form changed a higher destination RPL or left ZF set");
        b.step(kCodeBase+0x0215,0xb9,kCodeSelector,0x0218);
        b.step(kCodeBase+0x0218,0x63,kCodeSelector,0x021c);
        check(b.memory[kWideDataBase]==0x13 && b.memory[kWideDataBase+1]==0x00 &&
              (b.d.flags_o&0x0040) && b.data_transfers.size()==4,
              "ARPL memory form did not update selector bytes and ZF");
        check(b.data_transfers[0].address==kWideDataBase && !b.data_transfers[0].write &&
              b.data_transfers[0].kind==3 && b.data_transfers[1].address==kWideDataBase+1 &&
              !b.data_transfers[1].write && b.data_transfers[1].kind==3 &&
              b.data_transfers[2].address==kWideDataBase && b.data_transfers[2].write &&
              b.data_transfers[2].value==0x13 && b.data_transfers[2].kind==1 &&
              b.data_transfers[3].address==kWideDataBase+1 && b.data_transfers[3].write &&
              b.data_transfers[3].value==0x00 && b.data_transfers[3].kind==1,
              "ARPL memory form did not issue exact protected RMW traffic");
        b.data_transfers.clear();
        b.step(kCodeBase+0x021c,0xb9,kCodeSelector,0x021f);
        b.step(kCodeBase+0x021f,0x63,kCodeSelector,0x0223);
        check(b.memory[kWideDataBase+2]==0x12 && b.memory[kWideDataBase+3]==0x00 &&
              !(b.d.flags_o&0x0040) && b.data_transfers.size()==2 &&
              !b.data_transfers[0].write && !b.data_transfers[1].write,
              "unchanged ARPL memory operand performed a write or left ZF set");
        b.step(kCodeBase+0x0223,0xf4,kCodeSelector,0x0224);
        check(b.d.halted_o,"protected ARPL sequence did not reach exact HLT");
    }

    // The Intel B-2/B-3 information sheet says all 286 steppings fault when
    // the ARPL source selector is null; the fault packet must retain the
    // original instruction PC and suppress both register and FLAGS updates.
    Bench b;
    b.put(kResetVector,{0xea,0x00,0x01,0x00,0xf0});
    // Set up the descriptor tables and PE entry with the production fixture.
    b.put(kResetVector,{0xea,0x00,0x01,0x00,0xf0});
    for (unsigned i=0;i<sizeof(kRealModeProgram);++i) b.memory[kRealCodeBase+0x0100+i]=kRealModeProgram[i];
    for (unsigned i=0;i<sizeof(kGdtrImage);++i) b.memory[0x40+i]=kGdtrImage[i];
    for (unsigned i=0;i<sizeof(kIdtrImage);++i) b.memory[0x46+i]=kIdtrImage[i];
    for (unsigned i=0;i<sizeof(kGdtImage);++i) b.memory[kGdtBase+i]=kGdtImage[i];
    for (unsigned i=0;i<sizeof(kVector13Gate);++i) b.memory[kIdtBase+kFaultVector*8+i]=kVector13Gate[i];
    const uint8_t null_source_program[]={
        0xb8,0x10,0x00, 0x8e,0xd8,             // MOV DS,0010
        0xb8,0x28,0x00, 0x8e,0xd0,             // MOV SS,0028
        0xbc,0x80,0x00,                        // MOV SP,0080
        0xb8,0x09,0x00, 0xb9,0x03,0x00,       // AX=0009, CX=null selector 0003
        0x63,0x0e,0x00,0x00, 0xf4             // ARPL [DS:0000],CX; HLT
    };
    for (unsigned i=0;i<sizeof(null_source_program);++i) b.memory[kCodeBase+0x0200+i]=null_source_program[i];
    b.memory[kWideDataBase]=0x11; b.memory[kWideDataBase+1]=0x00;
    b.reset();
    b.step(kResetVector,0xea,0xf000,0x0100);
    b.step(kRealCodeBase+0x0100,0x0f,0xf000,0x0105);
    b.step(kRealCodeBase+0x0105,0x0f,0xf000,0x010a);
    b.step(kRealCodeBase+0x010a,0xf9,0xf000,0x010b);
    b.step(kRealCodeBase+0x010b,0xfd,0xf000,0x010c);
    b.step(kRealCodeBase+0x010c,0xfb,0xf000,0x010d);
    b.step(kRealCodeBase+0x010d,0xb8,0xf000,0x0110);
    b.step(kRealCodeBase+0x0110,0x0f,0xf000,0x0113);
    b.step(kRealCodeBase+0x0113,0xeb,0xf000,0x0115);
    b.step(kRealCodeBase+0x0115,0xea,kCodeSelector,0x0200);
    b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203);
    b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205);
    b.step(kCodeBase+0x0205,0xb8,kCodeSelector,0x0208);
    b.step(kCodeBase+0x0208,0x8e,kCodeSelector,0x020a);
    b.step(kCodeBase+0x020a,0xbc,kCodeSelector,0x020d);
    b.step(kCodeBase+0x020d,0xb8,kCodeSelector,0x0210);
    b.step(kCodeBase+0x0210,0xb9,kCodeSelector,0x0213);
    b.data_transfers.clear();
    const auto retired_before=b.retired;
    for (unsigned n=0;n<100000 && !b.d.event_o && !b.d.fault_o;++n) b.tick();
    check(!b.d.fault_o && b.d.event_o && b.d.event_vector_o==13 &&
          b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
          b.d.event_packet_error_valid_o && b.d.event_packet_error_code_o==0 &&
          b.d.event_packet_saved_cs_o==kCodeSelector && b.d.event_packet_saved_ip_o==0x0213 &&
          b.d.event_packet_saved_flags_o==kSavedFlags && b.d.event_packet_saved_sp_o==kInitialSp &&
          b.reg(0)==0x0009 && b.reg(1)==0x0003 && b.retired==retired_before &&
          b.memory[kWideDataBase]==0x11 && b.memory[kWideDataBase+1]==0x00 &&
          std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
              return t.address==kWideDataBase || t.address==kWideDataBase+1;
          }),
          "null-source ARPL did not raise restartable protected #GP before architectural updates");
    std::cout<<"PASS: protected ARPL register/memory RPL, ZF, conditional RMW, stalls and null-source #GP\n";
}

static void protected_mode_boot(Bench& b, bool wait);
static void place_selector_fixture(Bench& b, const uint8_t* program, std::size_t program_size);

static void protected_arpl_reachable_privilege_matrix() {
    using namespace protected_mode_fixture;
    struct Level {
        unsigned cpl;
        uint16_t code_selector, stack_selector;
        uint32_t code_base, stack_base;
        uint8_t code_access, stack_access;
    };
    const Level levels[]={
        {1,0x0049,0x0051,0x00081000,0x00080000,0xba,0xb2},
        {2,0x005a,0x0062,0x00083000,0x00082000,0xda,0xd2},
        {3,0x006b,0x0073,0x00085000,0x00084000,0xfa,0xf2}
    };
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00, 0x8e,0xd0, 0xbc,0x80,0x00, 0xcf, 0xf4
    };
    constexpr uint16_t target_ip=0x0409;
    auto put_descriptor=[](Bench& b,uint32_t address,uint16_t limit,
                           uint32_t base,uint8_t access) {
        b.memory[address+0]=uint8_t(limit);
        b.memory[address+1]=uint8_t(limit>>8);
        b.memory[address+2]=uint8_t(base);
        b.memory[address+3]=uint8_t(base>>8);
        b.memory[address+4]=uint8_t(base>>16);
        b.memory[address+5]=access;
        b.memory[address+6]=0;
        b.memory[address+7]=0;
    };

    unsigned executions=0;
    for (const auto& level:levels)
        for (unsigned source_rpl=0;source_rpl<4;++source_rpl)
            for (unsigned destination_rpl=0;destination_rpl<4;++destination_rpl)
                for (bool memory_destination:{false,true})
                    for (bool prior_zf:{false,true})
                        for (bool wait:{false,true}) {
        const uint16_t source=uint16_t(0x0008|source_rpl);
        const uint16_t original_destination=uint16_t(0xa5b0|destination_rpl);
        const bool adjusted=destination_rpl<source_rpl;
        const uint16_t expected_destination=adjusted ?
            uint16_t((original_destination&0xfffc)|source_rpl) : original_destination;
        const uint16_t saved_flags=uint16_t(kSavedFlags|(prior_zf?0x0040:0));
        const uint16_t successor=uint16_t(target_ip+(memory_destination?3:2));
        std::vector<uint8_t> target_program={
            0xbd,0x20,0x00,                         // MOV BP,0020 (SS-based memory operand)
            0xb9,uint8_t(source),uint8_t(source>>8), // MOV CX,non-null source selector
            0xb8,uint8_t(original_destination),uint8_t(original_destination>>8),
            0x63,uint8_t(memory_destination?0x4e:0xc8)
        };
        if (memory_destination) target_program.push_back(0x00); // ARPL word ptr SS:[BP+0],CX
        target_program.push_back(0x90);
        target_program.push_back(0x90);
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x40]=0x77; // Extend the GDT through the CPL-3 code and stack descriptors.
        put_descriptor(b,kGdtBase+(level.code_selector&0xfff8u),0x0fff,
                       level.code_base,level.code_access);
        put_descriptor(b,kGdtBase+(level.stack_selector&0xfff8u),0x0fff,
                       level.stack_base,level.stack_access);
        for (std::size_t i=0;i<target_program.size();++i)
            b.memory[level.code_base+0x0400+uint32_t(i)]=target_program[i];
        b.memory[level.stack_base+0x0020]=uint8_t(original_destination);
        b.memory[level.stack_base+0x0021]=uint8_t(original_destination>>8);
        b.put(kStackBase+0x0080,{0x00,0x04,uint8_t(level.code_selector),
            uint8_t(level.code_selector>>8),uint8_t(saved_flags),uint8_t(saved_flags>>8),
            0x00,0x01,uint8_t(level.stack_selector),uint8_t(level.stack_selector>>8)});

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.data_transfers.clear();
        b.step(kCodeBase+0x0208,0xcf,level.code_selector,0x0400,wait);
        check((b.cs()&3)==level.cpl && b.cs()==level.code_selector &&
              uint16_t(b.d.segs_o>>32)==level.stack_selector &&
              b.cache_base(1)==level.code_base && b.cache_base(2)==level.stack_base &&
              b.reg(4)==0x0100 && b.d.flags_o==saved_flags,
              "outer IRET did not establish the requested reachable ARPL privilege state");
        b.step(level.code_base+0x0400,0xbd,level.code_selector,0x0403,wait);
        b.step(level.code_base+0x0403,0xb9,level.code_selector,0x0406,wait);
        b.step(level.code_base+0x0406,0xb8,level.code_selector,target_ip,wait);
        check(b.reg(5)==0x0020 && b.reg(1)==source && b.reg(0)==original_destination,
              "ARPL privilege fixture loaded incorrect operands");

        const uint16_t flags_before=b.d.flags_o;
        const unsigned retired_before=b.retired;
        b.accepted.clear();
        b.data_transfers.clear();
        b.step(level.code_base+target_ip,0x63,level.code_selector,successor,wait);
        check(b.retired==retired_before+1 && !b.d.event_o &&
              !b.d.event_packet_valid_o && !b.d.fault_o,
              "reachable ARPL did not retire exactly once without a fault");
        check(b.d.flags_o==uint16_t((flags_before&0xffbf)|(adjusted?0x0040:0)),
              "reachable ARPL did not update only ZF from its RPL comparison");
        check(b.reg(1)==source &&
              b.reg(0)==(memory_destination?original_destination:expected_destination),
              "reachable ARPL register result or source preservation is incorrect");
        check(b.accepted.size()==(memory_destination?3u:2u) &&
              b.accepted[0]==level.code_base+target_ip &&
              b.accepted[1]==level.code_base+target_ip+1 &&
              (!memory_destination || b.accepted[2]==level.code_base+target_ip+2),
              "reachable ARPL fetched bytes outside its exact encoding");
        if (!memory_destination) {
            check(b.data_transfers.empty(),"register ARPL performed an unexpected data transfer");
        } else {
            const unsigned expected_transfers=adjusted?4:2;
            check(b.data_transfers.size()==expected_transfers &&
                  b.memory[level.stack_base+0x0020]==uint8_t(expected_destination) &&
                  b.memory[level.stack_base+0x0021]==uint8_t(expected_destination>>8),
                  "reachable ARPL memory result or conditional write count is incorrect");
            for (unsigned i=0;i<2;++i) {
                const auto& transfer=b.data_transfers[i];
                check(transfer.address==level.stack_base+0x0020+i &&
                      transfer.value==uint8_t(original_destination>>(8*i)) &&
                      !transfer.write && !transfer.io && transfer.segmented &&
                      transfer.role==2 && transfer.kind==3 &&
                      transfer.offset==0x0020+i && transfer.size==2,
                      "reachable ARPL memory form did not read the exact SS word first");
            }
            if (adjusted) for (unsigned i=0;i<2;++i) {
                const auto& transfer=b.data_transfers[2+i];
                check(transfer.address==level.stack_base+0x0020+i &&
                      transfer.value==uint8_t(expected_destination>>(8*i)) &&
                      transfer.write && !transfer.io && transfer.segmented &&
                      transfer.role==2 && transfer.kind==1 &&
                      transfer.offset==0x0020+i && transfer.size==2,
                      "adjusting ARPL memory form did not write the exact SS word");
            }
        }
        b.step(level.code_base+successor,0x90,level.code_selector,successor+1,wait);
        b.step(level.code_base+successor+1,0x90,level.code_selector,successor+2,wait);
        check(!b.d.halted_o && !b.d.event_o && !b.d.fault_o && b.d.ip_o==successor+2,
              "reachable ARPL missed its exact unprivileged NOP successors");
        ++executions;
    }
    check(executions==384,
          "reachable ARPL matrix missed a CPL, source/destination RPL, form, prior ZF or READY policy");
    std::cout<<"PASS: "<<executions
             <<" reachable CPL1/CPL2/CPL3 ARPL cases cover all source/destination RPL pairs, register/SS memory forms, both prior ZF values and both READY policies\n";
}

static void protected_selector_opcode_decode() {
    using namespace protected_mode_fixture;
    struct DecodeCase {
        const char* label;
        std::vector<uint8_t> bytes;
        bool invalid_group;
    };
    const std::vector<DecodeCase> cases={
        {"selector invalid /6",{0x0f,0x00,0xf0},true},
        {"selector invalid /7",{0x0f,0x00,0xf8},true},
    };

    unsigned runs=0;
    for (bool wait:{false,true}) for (const auto& test:cases) {
        try {
            Bench b;
            b.wait_mode=wait;
            auto place=[&](uint32_t address,const uint8_t* bytes,std::size_t count) {
                for (std::size_t i=0;i<count;++i) b.memory[address+uint32_t(i)]=bytes[i];
            };
            place(kResetVector,kResetJump,sizeof(kResetJump));
            place(kRealCodeBase+0x0100,kRealModeProgram,sizeof(kRealModeProgram));
            place(0x00000040,kGdtrImage,sizeof(kGdtrImage));
            place(0x00000046,kIdtrImage,sizeof(kIdtrImage));
            place(kGdtBase,kGdtImage,sizeof(kGdtImage));
            place(kCodeBase+0x0200,test.bytes.data(),test.bytes.size());

            b.reset();
            b.step(kResetVector,0xea,0xf000,0x0100,wait);
            b.step(kRealCodeBase+0x0100,0x0f,0xf000,0x0105,wait);
            b.step(kRealCodeBase+0x0105,0x0f,0xf000,0x010a,wait);
            b.step(kRealCodeBase+0x010a,0xf9,0xf000,0x010b,wait);
            b.step(kRealCodeBase+0x010b,0xfd,0xf000,0x010c,wait);
            b.step(kRealCodeBase+0x010c,0xfb,0xf000,0x010d,wait);
            b.step(kRealCodeBase+0x010d,0xb8,0xf000,0x0110,wait);
            b.step(kRealCodeBase+0x0110,0x0f,0xf000,0x0113,wait);
            b.step(kRealCodeBase+0x0113,0xeb,0xf000,0x0115,wait);
            b.step(kRealCodeBase+0x0115,0xea,kCodeSelector,0x0200,wait);

            b.accepted.clear();
            b.data_transfers.clear();
            const unsigned retired_before=b.retired;
            for (unsigned cycle=0;cycle<10000 && !b.d.fault_o;++cycle) b.tick(wait);
            check(b.d.fault_o && b.d.fault_code_o==3 && b.d.ip_o==0x0200 && !b.d.retire_o,
                  "selector opcode did not stop visibly at its first byte");
            check(b.retired==retired_before && b.data_transfers.size()==8,
                  "selector opcode retired or did not read exactly its invalid protected #UD gate");
            for (unsigned i=0;i<8;++i)
                check(!b.data_transfers[i].write &&
                      b.data_transfers[i].address==kIdtBase+6*8+i,
                      "invalid protected #UD delivery accessed an operand or another descriptor");
            check(b.accepted.size()==test.bytes.size(),
                  "selector opcode did not fetch its complete ModR/M/displacement encoding");
            for (std::size_t i=0;i<test.bytes.size();++i)
                check(b.accepted[i]==kCodeBase+0x0200+uint32_t(i),
                      "selector opcode fetched an unexpected byte/address");
            if (test.invalid_group) {
                check(b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
                      b.d.event_vector_o==6,
                      "invalid SLDT group did not enter the protected #UD diagnostic path");
            } else {
                check(!b.d.event_packet_valid_o,
                      "valid unimplemented selector instruction was misclassified as #UD");
            }
            ++runs;
        } catch (const std::exception& error) {
            throw std::runtime_error(std::string("80286 protected selector decode ")+test.label+": "+error.what());
        }
    }
    std::cout<<"PASS: "<<runs<<" invalid protected selector-group encodings raise #UD\n";
}

static void protected_mode_boot(Bench& b, bool wait) {
    using namespace protected_mode_fixture;
    b.wait_mode=wait;
    b.reset();
    b.step(kResetVector,0xea,0xf000,0x0100,wait);
    b.step(kRealCodeBase+0x0100,0x0f,0xf000,0x0105,wait);
    b.step(kRealCodeBase+0x0105,0x0f,0xf000,0x010a,wait);
    b.step(kRealCodeBase+0x010a,0xf9,0xf000,0x010b,wait);
    b.step(kRealCodeBase+0x010b,0xfd,0xf000,0x010c,wait);
    b.step(kRealCodeBase+0x010c,0xfb,0xf000,0x010d,wait);
    b.step(kRealCodeBase+0x010d,0xb8,0xf000,0x0110,wait);
    b.step(kRealCodeBase+0x0110,0x0f,0xf000,0x0113,wait);
    b.step(kRealCodeBase+0x0113,0xeb,0xf000,0x0115,wait);
    b.step(kRealCodeBase+0x0115,0xea,kCodeSelector,0x0200,wait);
}

static void place_selector_fixture(Bench& b, const uint8_t* program, std::size_t program_size);

static void protected_outer_iret() {
    using namespace protected_mode_fixture;
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00,             // 0200 MOV AX, ring-0 SS
        0x8e,0xd0,                   // 0203 MOV SS,AX
        0xbc,0x80,0x00,             // 0205 MOV SP,0080
        0xcf,                       // 0208 IRET to outer privilege
        0xf4                        // 0209 must not execute
    };
    const uint8_t ring3_code[]={0x90};
    const uint8_t ring3_cs[]={0xff,0x0f,0x00,0x00,0x06,0xfa,0x00,0x00};
    const uint8_t ring3_ss[]={0xff,0x00,0x00,0x00,0x07,0xf2,0x00,0x00};
    unsigned executions=0;
    for (bool wait:{false,true}) {
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.put(kGdtBase+0x38,{ring3_cs[0],ring3_cs[1],ring3_cs[2],ring3_cs[3],
                              ring3_cs[4],ring3_cs[5],ring3_cs[6],ring3_cs[7]});
        b.put(kGdtBase+0x40,{ring3_ss[0],ring3_ss[1],ring3_ss[2],ring3_ss[3],
                              ring3_ss[4],ring3_ss[5],ring3_ss[6],ring3_ss[7]});
        b.put(0x00060000+0x0400,{ring3_code[0]});
        b.put(kStackBase+0x0080,{0x00,0x04,0x3b,0x00,0x02,0x02,
                                 0x00,0x01,0x43,0x00});
        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.data_transfers.clear();
        b.step(kCodeBase+0x0208,0xcf,0x003b,0x0400,wait);
        check(uint16_t(b.d.segs_o>>32)==0x0043 && b.reg(4)==0x0100 &&
              b.cache_base(2)==0x070000 && (b.d.seg_valid_o&4),
              "outer IRET did not atomically load the ring-3 stack selector/cache/SP");
        check(!(b.d.seg_valid_o&0x09) && uint16_t(b.d.segs_o)==0 &&
              uint16_t(b.d.segs_o>>48)==0,
              "outer IRET did not invalidate ring-0 ES/DS caches");
        check(b.d.flags_o==0x0202,"outer IRET did not restore the requested FLAGS");
        check(std::count_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && t.address>=kStackBase+0x80 && t.address<kStackBase+0x8a;
              })==10,"outer IRET did not read the complete five-word return frame");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                  return !t.write && t.address==kGdtBase+0x38;
              }) && std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && t.address==kGdtBase+0x40;
              }),"outer IRET did not read both target descriptors");
        const auto code_read=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
            return !t.write && t.address==kGdtBase+0x38;
        });
        const auto outer_sp_read=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
            return !t.write && t.address==kStackBase+0x86;
        });
        const auto stack_read=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
            return !t.write && t.address==kStackBase+0x88;
        });
        const auto stack_descriptor_read=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
            return !t.write && t.address==kGdtBase+0x40;
        });
        check(code_read<outer_sp_read && outer_sp_read<stack_read && stack_read<stack_descriptor_read,
              "outer IRET violated Intel's CS-check then outer SS:SP check order");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                  return t.write && t.address==kGdtBase+0x3d && t.value==0xfb;
              }) && std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return t.write && t.address==kGdtBase+0x45 && t.value==0xf3;
              }),"outer IRET did not write both descriptor accessed bits before commit");
        b.step(0x00060400,0x90,0x003b,0x0401,wait);
        check(!b.d.halted_o && b.cs()==0x003b && b.d.ip_o==0x0401,
              "ring-3 return target did not execute its unprivileged successor");
        ++executions;
    }
    check(executions==2,"outer IRET did not cover both READY modes");
    std::cout<<"PASS: outer-level protected IRET validates and commits ring-3 CS/SS/SP/FLAGS in both READY modes\n";
}

static void protected_outer_iret_faults() {
    using namespace protected_mode_fixture;
    struct FaultCase {
        const char* label;
        uint16_t rejected_cs, error_code;
        uint8_t vector;
        bool system_descriptor, descriptor_lookup, code_limit_fault;
    };
    const FaultCase cases[]={
        {"null code selector",0x0003,0x0000,13,false,false,false},
        {"non-present code segment",0x004b,0x0048,11,false,true,false},
        {"system descriptor in CS slot",0x0053,0x0050,13,true,true,false},
        {"return IP beyond code limit",0x004b,0x0000,13,false,true,true}
    };
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00,             // 0200 MOV AX, ring-0 SS
        0x8e,0xd0,                   // 0203 MOV SS,AX
        0xbc,0x80,0x00,             // 0205 MOV SP,0080
        0xcf,                       // 0208 IRET; handler repairs its source frame
        0xf4
    };
    const uint8_t ring3_cs[]={0xff,0x0f,0x00,0x00,0x06,0xfa,0x00,0x00};
    const uint8_t ring3_ss[]={0xff,0x00,0x00,0x00,0x07,0xf2,0x00,0x00};
    const uint8_t ring3_cs_not_present[]={0xff,0x0f,0x00,0x00,0x06,0x7a,0x00,0x00};
    const uint8_t ring3_cs_short_limit[]={0xff,0x03,0x00,0x00,0x06,0xfa,0x00,0x00};
    const uint8_t ring3_system_descriptor[]={0x17,0x00,0x00,0x06,0x00,0x82,0x00,0x00};
    const uint8_t repair_handler[]={
        0x83,0xc4,0x02,             // 0300 discard the exception error code
        0xb8,0x28,0x00,             // 0303 MOV AX, ring-0 SS
        0x8e,0xd8,                   // 0306 MOV DS,AX
        0xb8,0x3b,0x00,             // 0308 MOV AX, valid ring-3 CS
        0xa3,0x82,0x00,             // 030B repair original outer-IRET CS slot
        0xcf                        // 030E IRET to retry the original IRET
    };
    unsigned executions=0;
    for (const auto& fault:cases) for (bool wait:{false,true}) {
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.put(kGdtBase+0x38,{ring3_cs[0],ring3_cs[1],ring3_cs[2],ring3_cs[3],
                              ring3_cs[4],ring3_cs[5],ring3_cs[6],ring3_cs[7]});
        b.put(kGdtBase+0x40,{ring3_ss[0],ring3_ss[1],ring3_ss[2],ring3_ss[3],
                              ring3_ss[4],ring3_ss[5],ring3_ss[6],ring3_ss[7]});
        const uint32_t rejected_descriptor=kGdtBase+(fault.rejected_cs&0xfff8);
        const uint8_t* rejected_bytes=fault.system_descriptor ? ring3_system_descriptor :
            fault.code_limit_fault ? ring3_cs_short_limit : ring3_cs_not_present;
        if (fault.descriptor_lookup)
            b.put(rejected_descriptor,{rejected_bytes[0],rejected_bytes[1],rejected_bytes[2],
                                       rejected_bytes[3],rejected_bytes[4],rejected_bytes[5],
                                       rejected_bytes[6],rejected_bytes[7]});
        for (std::size_t i=0;i<sizeof(repair_handler);++i)
            b.memory[kHandlerBase+kHandlerIp+uint32_t(i)]=repair_handler[i];
        b.put(0x00060000+0x0400,{0x90});
        b.put(kStackBase+0x0080,{0x00,0x04,
                                 uint8_t(fault.rejected_cs),uint8_t(fault.rejected_cs>>8),
                                 0x02,0x02,0x00,0x01,0x43,0x00});
        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.data_transfers.clear();
        const unsigned retired_before_iret=b.retired;
        for (unsigned n=0;n<100000 && !b.d.event_o && !b.d.fault_o;++n) b.tick(wait);
        check(!b.d.fault_o && b.d.event_o && b.cs()==kHandlerSelector &&
              b.d.cs_base_o==kHandlerBase && b.d.ip_o==kHandlerIp,
              "invalid protected IRET CS did not enter its IDT handler");
        check(b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_error_valid_o && b.d.event_packet_restartable_o &&
              b.d.event_vector_o==fault.vector &&
              b.d.event_packet_error_code_o==fault.error_code &&
              b.d.event_packet_saved_cs_o==kCodeSelector &&
              b.d.event_packet_saved_ip_o==0x0208 &&
              b.d.event_packet_saved_flags_o==kSavedFlags &&
              b.d.event_packet_saved_sp_o==kInitialSp,
              "invalid protected IRET lost its restartable exception context");
        check(b.retired==retired_before_iret && b.reg(4)==0x0078 &&
              b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp,
              "faulting protected IRET retired or changed its source stack");
        check(b.memory[kStackBase+0x78]==uint8_t(fault.error_code) &&
              b.memory[kStackBase+0x79]==uint8_t(fault.error_code>>8) &&
              b.memory[kStackBase+0x7a]==0x08 && b.memory[kStackBase+0x7b]==0x02 &&
              b.memory[kStackBase+0x7c]==0x08 && b.memory[kStackBase+0x7d]==0x00 &&
              b.memory[kStackBase+0x7e]==0x03 && b.memory[kStackBase+0x7f]==0x06,
              "IRET descriptor fault did not push the exact error and restart frame");
        const uint8_t original_outer_frame[]={0x00,0x04,
            uint8_t(fault.rejected_cs),uint8_t(fault.rejected_cs>>8),
            0x02,0x02,0x00,0x01,0x43,0x00};
        for (unsigned i=0;i<sizeof(original_outer_frame);++i)
            check(b.memory[kStackBase+0x80+i]==original_outer_frame[i],
                  "IRET fault modified its original five-word return frame");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return t.write && t.address>=kStackBase+0x80 && t.address<kStackBase+0x8a;
              }),"IRET fault wrote into its original outer-return frame");
        check(std::count_if(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                  return !t.write && t.address>=rejected_descriptor &&
                         t.address<rejected_descriptor+8;
              })==(fault.descriptor_lookup ? 8 : 0) &&
              std::count_if(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                  return t.write && t.address==rejected_descriptor+5 && t.value==0xfb;
              })==(fault.code_limit_fault ? 1 : 0) &&
              std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                  return t.write && t.address==rejected_descriptor+5 && t.value!=0xfb;
              }),
              "IRET CS validation performed incorrect descriptor traffic or accessed-bit update");
        if (fault.descriptor_lookup) {
            for (unsigned i=0;i<8;++i) {
                const auto read=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                    return !t.write && t.address==rejected_descriptor+i;
                });
                check(read!=b.data_transfers.end() && read->value==rejected_bytes[i],
                      "IRET fault used the wrong return-CS descriptor bytes");
            }
        }

        b.data_transfers.clear();
        b.step(kHandlerBase+kHandlerIp,0x83,kHandlerSelector,kHandlerIp+3,wait);
        check(b.reg(4)==0x007a,"IRET fault handler did not discard one error word");
        b.step(kHandlerBase+kHandlerIp+3,0xb8,kHandlerSelector,kHandlerIp+6,wait);
        b.step(kHandlerBase+kHandlerIp+6,0x8e,kHandlerSelector,kHandlerIp+8,wait);
        check(b.cache_base(3)==kStackBase,"IRET fault handler did not map DS to its repair stack");
        b.step(kHandlerBase+kHandlerIp+8,0xb8,kHandlerSelector,kHandlerIp+11,wait);
        b.step(kHandlerBase+kHandlerIp+11,0xa3,kHandlerSelector,kHandlerIp+14,wait);
        check(b.memory[kStackBase+0x82]==0x3b && b.memory[kStackBase+0x83]==0x00 &&
              std::count_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return t.write && (t.address==kStackBase+0x82 || t.address==kStackBase+0x83);
              })==2,
              "IRET fault handler did not repair only the original CS slot");
        b.step(kHandlerBase+kHandlerIp+14,0xcf,kCodeSelector,0x0208,wait);
        check(b.reg(4)==kInitialSp && b.cs()==kCodeSelector && b.d.ip_o==0x0208 &&
              b.d.flags_o==kSavedFlags,
              "same-level handler IRET did not return to the faulting outer IRET");
        b.step(kCodeBase+0x0208,0xcf,0x003b,0x0400,wait);
        check(uint16_t(b.d.segs_o>>16)==0x003b &&
              uint16_t(b.d.segs_o>>32)==0x0043 && b.reg(4)==0x0100 &&
              b.cache_base(1)==0x00060000 && b.cache_base(2)==0x00070000 &&
              b.d.flags_o==0x0202,
              "repaired outer IRET did not commit the complete ring-3 return context");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return t.write && t.address==kGdtBase+0x3d && t.value==0xfb;
              }) && std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return t.write && t.address==kGdtBase+0x45 && t.value==0xf3;
              }),"repaired IRET did not set the accepted CS/SS accessed bits");
        b.step(0x00060400,0x90,0x003b,0x0401,wait);
        check(!b.d.halted_o && b.cs()==0x003b && b.d.ip_o==0x0401,
              "repaired IRET did not execute its exact ring-3 successor");
        ++executions;
        std::cout<<"PASS: protected outer IRET repaired "<<fault.label
                 <<" in "<<(wait?"wait":"no-wait")<<" mode\n";
    }
    check(executions==8,"protected outer IRET fault matrix did not cover all four faults and READY modes");
}

static void protected_outer_iret_inward_faults() {
    using namespace protected_mode_fixture;
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00,             // 0200 MOV AX, ring-0 SS
        0x8e,0xd0,                   // 0203 MOV SS,AX
        0xbc,0x80,0x00,             // 0205 MOV SP,0080
        0xcf                        // 0208 IRET to ring 3
    };
    const uint8_t ring3_cs[]={0xff,0x0f,0x00,0x00,0x01,0xfa,0x00,0x00};
    const uint8_t ring3_ss[]={0xff,0x0f,0x00,0x00,0x05,0xf2,0x00,0x00};
    const uint8_t ring3_gp_gate[]={0x00,0x06,0x3b,0x00,0x00,0x86,0x00,0x00};
    const uint8_t ring3_handler[]={
        0x83,0xc4,0x02,             // 0600 discard #GP(selector)
        0xb8,0x43,0x00,             // 0603 MOV AX, ring-3 SS/data
        0x8e,0xd8,                   // 0606 MOV DS,AX
        0xb8,0x3b,0x00,             // 0608 MOV AX, valid ring-3 CS
        0xa3,0x02,0x01,             // 060B repair original IRET CS slot
        0xcf                        // 060E IRET to retry the faulting IRET
    };
    unsigned executions=0;
    for (bool wait:{false,true}) {
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.put(kGdtBase+0x38,{ring3_cs[0],ring3_cs[1],ring3_cs[2],ring3_cs[3],
                              ring3_cs[4],ring3_cs[5],ring3_cs[6],ring3_cs[7]});
        b.put(kGdtBase+0x40,{ring3_ss[0],ring3_ss[1],ring3_ss[2],ring3_ss[3],
                              ring3_ss[4],ring3_ss[5],ring3_ss[6],ring3_ss[7]});
        b.put(kIdtBase+13*8,{ring3_gp_gate[0],ring3_gp_gate[1],ring3_gp_gate[2],
                              ring3_gp_gate[3],ring3_gp_gate[4],ring3_gp_gate[5],
                              ring3_gp_gate[6],ring3_gp_gate[7]});
        for (std::size_t i=0;i<sizeof(ring3_handler);++i)
            b.memory[kCodeBase+0x0600+uint32_t(i)]=ring3_handler[i];
        b.put(kCodeBase+0x0400,{0xcf}); // Faulting ring-3 IRET.
        b.put(kCodeBase+0x0500,{0x90}); // Exact successor after the repaired IRET.
        b.put(kStackBase+0x0080,{0x00,0x04,0x3b,0x00,0x02,0x00,
                                  0x00,0x01,0x43,0x00});
        b.put(kStackBase+0x0100,{0x00,0x05,0x08,0x00,0x02,0x00});

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xcf,0x003b,0x0400,wait);
        check(b.cs()==0x003b && uint16_t(b.d.segs_o>>32)==0x0043 &&
              b.reg(4)==0x0100 && b.cache_base(1)==kCodeBase &&
              b.cache_base(2)==kStackBase,
              "outer IRET did not establish the ring-3 inward-return fixture");

        b.data_transfers.clear();
        const unsigned retired_before_iret=b.retired;
        for (unsigned n=0;n<100000 && !b.d.event_o && !b.d.fault_o;++n) b.tick(wait);
        check(!b.d.fault_o && b.d.event_o && b.d.event_packet_valid_o &&
              b.d.event_packet_protected_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_restartable_o && b.d.event_vector_o==13 &&
              b.d.event_packet_error_code_o==0x0008 &&
              b.d.event_packet_saved_cs_o==0x003b &&
              b.d.event_packet_saved_ip_o==0x0400 &&
              b.d.event_packet_saved_flags_o==0x0002 &&
              b.d.event_packet_saved_sp_o==0x0100 && b.retired==retired_before_iret &&
              b.cs()==0x003b && b.d.cs_base_o==kCodeBase &&
              b.d.ip_o==0x0600 && b.reg(4)==0x00f8,
              "inward protected IRET did not deliver restartable #GP(0008) in ring 3");
        const uint8_t expected_frame[]={0x08,0x00,0x00,0x04,0x3b,0x00,0x02,0x00};
        for (unsigned i=0;i<sizeof(expected_frame);++i)
            check(b.memory[kStackBase+0x00f8+i]==expected_frame[i],
                  "inward IRET #GP frame bytes/order are incorrect");
        const uint8_t original_frame[]={0x00,0x05,0x08,0x00,0x02,0x00};
        for (unsigned i=0;i<sizeof(original_frame);++i)
            check(b.memory[kStackBase+0x0100+i]==original_frame[i],
                  "inward IRET fault modified its original return frame");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return (t.address>=kStackBase+0x0100 && t.address<kStackBase+0x0106 && t.write) ||
                         (t.address>=kGdtBase+0x0008 && t.address<kGdtBase+0x0010);
              }),"inward IRET wrote its source frame or looked up the rejected inner CS descriptor");

        b.data_transfers.clear();
        b.step(kCodeBase+0x0600,0x83,0x003b,0x0603,wait);
        check(b.reg(4)==0x00fa,"ring-3 #GP handler did not discard the selector error word");
        b.step(kCodeBase+0x0603,0xb8,0x003b,0x0606,wait);
        b.step(kCodeBase+0x0606,0x8e,0x003b,0x0608,wait);
        check(b.cache_base(3)==kStackBase,
              "ring-3 #GP handler did not map DS to the repair stack");
        b.step(kCodeBase+0x0608,0xb8,0x003b,0x060b,wait);
        b.step(kCodeBase+0x060b,0xa3,0x003b,0x060e,wait);
        check(b.memory[kStackBase+0x0102]==0x3b && b.memory[kStackBase+0x0103]==0x00 &&
              std::count_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return t.write && (t.address==kStackBase+0x0102 ||
                                     t.address==kStackBase+0x0103);
              })==2,
              "ring-3 #GP handler did not repair only the original CS slot");
        b.step(kCodeBase+0x060e,0xcf,0x003b,0x0400,wait);
        check(b.reg(4)==0x0100 && b.cs()==0x003b && b.d.ip_o==0x0400,
              "ring-3 #GP handler did not retry the original IRET");
        b.step(kCodeBase+0x0400,0xcf,0x003b,0x0500,wait);
        check(b.reg(4)==0x0106 && b.cs()==0x003b && b.d.ip_o==0x0500,
              "repaired same-level IRET did not land on the exact successor");
        b.step(kCodeBase+0x0500,0x90,0x003b,0x0501,wait);
        check(b.reg(4)==0x0106 && b.d.ip_o==0x0501 && !b.d.halted_o,
              "repaired inward-return frame did not execute its exact successor");
        ++executions;
    }
    check(executions==2,"inward IRET fault test missed a READY mode");
    std::cout<<"PASS: inward protected IRET raises restartable #GP(selector) before descriptor lookup, repairs/retries in ring 3, and reaches the exact successor in both READY modes\n";
}

static void protected_outer_iret_ss_faults() {
    using namespace protected_mode_fixture;
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00,             // 0200 MOV AX, ring-0 SS
        0x8e,0xd0,                   // 0203 MOV SS,AX
        0xbc,0x80,0x00,             // 0205 MOV SP,0080
        0xcf                        // 0208 IRET to ring 3
    };
    const uint8_t ring3_cs[]={0xff,0x0f,0x00,0x00,0x01,0xfa,0x00,0x00};
    const uint8_t ring3_ss[]={0xff,0x0f,0x00,0x00,0x05,0xf2,0x00,0x00};
    const uint8_t ring3_ss_not_present[]={0xff,0x0f,0x00,0x00,0x05,0x72,0x00,0x00};
    const uint8_t ring3_ss_wrong_dpl[]={0xff,0x0f,0x00,0x00,0x05,0xd2,0x00,0x00};
    const uint8_t ring3_code_descriptor[]={0xff,0x0f,0x00,0x00,0x01,0xfa,0x00,0x00};
    struct FaultCase {
        const char* label;
        uint16_t selector, error_code;
        const uint8_t* descriptor;
    };
    const FaultCase cases[]={
        {"null SS selector",0x0003,0x0000,nullptr},
        {"non-present SS descriptor",0x0043,0x0040,ring3_ss_not_present},
        {"code descriptor in SS slot",0x004b,0x0048,ring3_code_descriptor},
        {"SS selector RPL mismatch",0x0042,0x0040,ring3_ss_wrong_dpl},
        {"SS selector beyond GDT limit",0x00c3,0x00c0,nullptr}
    };
    const uint8_t repair_handler[]={
        0x83,0xc4,0x02,             // 0300 discard #SS(selector)
        0xb8,0x28,0x00,             // 0303 MOV AX, ring-0 SS
        0x8e,0xd8,                   // 0306 MOV DS,AX
        0xb8,0x53,0x00,             // 0308 MOV AX, valid ring-3 SS
        0xa3,0x88,0x00,             // 030B repair original outer-IRET SS slot
        0xcf                        // 030E IRET to retry the original IRET
    };
    unsigned executions=0;
    for (const auto& fault:cases) for (bool wait:{false,true}) {
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.put(kGdtBase+0x38,{ring3_cs[0],ring3_cs[1],ring3_cs[2],ring3_cs[3],
                              ring3_cs[4],ring3_cs[5],ring3_cs[6],ring3_cs[7]});
        b.put(kGdtBase+0x50,{ring3_ss[0],ring3_ss[1],ring3_ss[2],ring3_ss[3],
                              ring3_ss[4],ring3_ss[5],ring3_ss[6],ring3_ss[7]});
        if (fault.descriptor) {
            const uint32_t address=kGdtBase+(fault.selector&0xfff8);
            b.put(address,{fault.descriptor[0],fault.descriptor[1],fault.descriptor[2],
                           fault.descriptor[3],fault.descriptor[4],fault.descriptor[5],
                           fault.descriptor[6],fault.descriptor[7]});
        }
        for (unsigned i=0;i<8;++i)
            b.memory[kIdtBase+12*8+i]=kVector13Gate[i];
        for (std::size_t i=0;i<sizeof(repair_handler);++i)
            b.memory[kHandlerBase+kHandlerIp+uint32_t(i)]=repair_handler[i];
        b.put(kCodeBase+0x0400,{0x90});
        const uint8_t saved_frame[]={0x00,0x04,0x3b,0x00,
            uint8_t(kSavedFlags),uint8_t(kSavedFlags>>8),
            0x00,0x01,uint8_t(fault.selector),uint8_t(fault.selector>>8)};
        b.put(kStackBase+0x0080,{saved_frame[0],saved_frame[1],saved_frame[2],saved_frame[3],
                                 saved_frame[4],saved_frame[5],saved_frame[6],saved_frame[7],
                                 saved_frame[8],saved_frame[9]});

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.data_transfers.clear();
        const unsigned retired_before_iret=b.retired;
        for (unsigned n=0;n<100000 && !b.d.event_o && !b.d.fault_o;++n) b.tick(wait);
        check(!b.d.fault_o && b.d.event_o && b.d.event_packet_valid_o &&
              b.d.event_packet_protected_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_restartable_o && b.d.event_vector_o==12 &&
              b.d.event_packet_error_code_o==fault.error_code &&
              b.d.event_packet_saved_cs_o==kCodeSelector &&
              b.d.event_packet_saved_ip_o==0x0208 &&
              b.d.event_packet_saved_flags_o==kSavedFlags &&
              b.d.event_packet_saved_sp_o==kInitialSp && b.retired==retired_before_iret &&
              b.cs()==kHandlerSelector && b.d.cs_base_o==kHandlerBase &&
              b.d.ip_o==kHandlerIp && b.reg(4)==0x0078,
              (std::string("outer IRET ")+fault.label+
               " did not deliver restartable #SS(selector)").c_str());
        const uint8_t expected_error_frame[]={uint8_t(fault.error_code),
            uint8_t(fault.error_code>>8),0x08,0x02,0x08,0x00,
            uint8_t(kSavedFlags),uint8_t(kSavedFlags>>8)};
        for (unsigned i=0;i<sizeof(expected_error_frame);++i)
            check(b.memory[kStackBase+0x78+i]==expected_error_frame[i],
                  "outer IRET #SS frame bytes/order are incorrect");
        for (unsigned i=0;i<sizeof(saved_frame);++i)
            check(b.memory[kStackBase+0x80+i]==saved_frame[i],
                  "outer IRET #SS modified its original five-word return frame");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return t.write && t.address>=kStackBase+0x80 && t.address<kStackBase+0x8a;
              }),"outer IRET #SS wrote into its original return frame");
        const uint32_t rejected_descriptor=kGdtBase+(fault.selector&0xfff8);
        const unsigned descriptor_reads=std::count_if(b.data_transfers.begin(),b.data_transfers.end(),
            [&](const auto& t) {
                return !t.write && t.address>=rejected_descriptor &&
                       t.address<rejected_descriptor+8;
            });
        check(descriptor_reads==(fault.descriptor ? 8u : 0u) &&
              std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                  return t.write && t.address==rejected_descriptor+5;
              }),
              "outer IRET #SS performed an unexpected rejected-SS descriptor access");

        b.data_transfers.clear();
        b.step(kHandlerBase+kHandlerIp,0x83,kHandlerSelector,kHandlerIp+3,wait);
        b.step(kHandlerBase+kHandlerIp+3,0xb8,kHandlerSelector,kHandlerIp+6,wait);
        b.step(kHandlerBase+kHandlerIp+6,0x8e,kHandlerSelector,kHandlerIp+8,wait);
        b.step(kHandlerBase+kHandlerIp+8,0xb8,kHandlerSelector,kHandlerIp+11,wait);
        b.step(kHandlerBase+kHandlerIp+11,0xa3,kHandlerSelector,kHandlerIp+14,wait);
        check(b.memory[kStackBase+0x88]==0x53 && b.memory[kStackBase+0x89]==0x00 &&
              std::count_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return t.write && (t.address==kStackBase+0x88 ||
                                     t.address==kStackBase+0x89);
              })==2,
              "#SS handler did not repair only the original outer SS slot");
        b.step(kHandlerBase+kHandlerIp+14,0xcf,kCodeSelector,0x0208,wait);
        check(b.reg(4)==kInitialSp && b.d.ip_o==0x0208 && b.cs()==kCodeSelector,
              "same-level #SS IRET did not return to the original outer IRET");
        b.step(kCodeBase+0x0208,0xcf,0x003b,0x0400,wait);
        check(b.cs()==0x003b && uint16_t(b.d.segs_o>>32)==0x0053 &&
              b.reg(4)==0x0100 && b.cache_base(1)==kCodeBase &&
              b.cache_base(2)==kStackBase,
              "repaired outer IRET did not commit the valid ring-3 SS:SP");
        b.step(kCodeBase+0x0400,0x90,0x003b,0x0401,wait);
        check(b.d.ip_o==0x0401 && b.reg(4)==0x0100,
              "repaired outer IRET did not execute the exact ring-3 successor");
        ++executions;
    }
    check(executions==10,"outer IRET SS fault matrix missed a fault or READY mode");
    std::cout<<"PASS: null, absent, wrong-type, wrong-RPL and out-of-limit outer SS faults raise #SS(selector), repair/retry, and reach the exact successor in both READY modes\n";
}

static void protected_outer_iret_frame_faults() {
    using namespace protected_mode_fixture;
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00,             // 0200 MOV AX, short-limit ring-0 SS
        0x8e,0xd0,                   // 0203 MOV SS,AX
        0xbc,0x00,0x00,             // 0205 MOV SP, fault-specific value
        0xcf                        // 0208 IRET to ring 3
    };
    const uint8_t ring3_cs[]={0xff,0x0f,0x00,0x00,0x06,0xfa,0x00,0x00};
    const uint8_t ring3_ss[]={0xff,0x00,0x00,0x00,0x07,0xf2,0x00,0x00};
    const uint8_t wide_ring0_ss[]={0xff,0x0f,0x00,0x00,0x05,0x92,0x00,0x00};
    struct FrameFault {
        const char* label;
        uint16_t initial_sp, current_ss_limit, source_frame_reads;
    };
    const FrameFault cases[]={
        {"starting SP beyond the current SS limit",0x0090,0x008f,0},
        {"five-word frame crossing the current SS limit",0x0080,0x0087,6}
    };
    const uint8_t repair_handler[]={
        0x83,0xc4,0x02,             // 0300 discard #SS(0)
        0xb8,0x68,0x00,             // 0303 MOV AX, wide ring-0 SS
        0x8e,0xd0,                   // 0306 MOV SS,AX
        0xcf                        // 0308 IRET to retry the outer IRET
    };
    unsigned executions=0;
    for (const auto& fault:cases) for (bool wait:{false,true}) {
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x40]=0x6f; // Include the alternate SS descriptor at selector 0068.
        b.memory[kCodeBase+0x0206]=uint8_t(fault.initial_sp);
        b.memory[kCodeBase+0x0207]=uint8_t(fault.initial_sp>>8);
        b.put(kGdtBase+0x28,{uint8_t(fault.current_ss_limit),
                              uint8_t(fault.current_ss_limit>>8),
                              0x00,0x00,0x05,0x92,0x00,0x00});
        b.put(kGdtBase+0x38,{ring3_cs[0],ring3_cs[1],ring3_cs[2],ring3_cs[3],
                              ring3_cs[4],ring3_cs[5],ring3_cs[6],ring3_cs[7]});
        b.put(kGdtBase+0x40,{ring3_ss[0],ring3_ss[1],ring3_ss[2],ring3_ss[3],
                              ring3_ss[4],ring3_ss[5],ring3_ss[6],ring3_ss[7]});
        b.put(kGdtBase+0x68,{wide_ring0_ss[0],wide_ring0_ss[1],wide_ring0_ss[2],
                              wide_ring0_ss[3],wide_ring0_ss[4],wide_ring0_ss[5],
                              wide_ring0_ss[6],wide_ring0_ss[7]});
        b.put(kIdtBase+12*8,{kVector13Gate[0],kVector13Gate[1],kVector13Gate[2],
                              kVector13Gate[3],kVector13Gate[4],kVector13Gate[5],
                              kVector13Gate[6],kVector13Gate[7]});
        for (std::size_t i=0;i<sizeof(repair_handler);++i)
            b.memory[kHandlerBase+kHandlerIp+uint32_t(i)]=repair_handler[i];
        b.put(0x00060000+0x0400,{0x90,0x90,0x90,0x90,0x90,0x90,0x90,0x90});
        const uint8_t outer_frame[]={0x00,0x04,0x3b,0x00,0x02,0x02,
                                     0x00,0x01,0x43,0x00};
        for (unsigned i=0;i<sizeof(outer_frame);++i)
            b.memory[kStackBase+fault.initial_sp+i]=outer_frame[i];

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        check(b.reg(4)==fault.initial_sp,
              "outer IRET stack-bound fixture loaded the wrong initial SP");
        b.data_transfers.clear();
        const unsigned retired_before_iret=b.retired;
        for (unsigned n=0;n<100000 && !b.d.event_o && !b.d.fault_o;++n) b.tick(wait);
        const uint16_t handler_sp=fault.initial_sp-8;
        check(!b.d.fault_o && b.d.event_o && b.d.event_packet_valid_o &&
              b.d.event_packet_protected_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_restartable_o && b.d.event_vector_o==12 &&
              b.d.event_packet_error_code_o==0 &&
              b.d.event_packet_saved_cs_o==kCodeSelector &&
              b.d.event_packet_saved_ip_o==0x0208 &&
              b.d.event_packet_saved_flags_o==kSavedFlags &&
              b.d.event_packet_saved_sp_o==fault.initial_sp &&
              b.retired==retired_before_iret && b.cs()==kHandlerSelector &&
              b.d.ip_o==kHandlerIp && b.reg(4)==handler_sp,
              (std::string("outer IRET ")+fault.label+
               " did not raise restartable #SS(0): event="+std::to_string(b.d.event_o)+
               ", fault="+std::to_string(b.d.fault_o)+
               ", stop="+std::to_string(b.d.fault_code_o)+
               ", vector="+std::to_string(b.d.event_vector_o)+
               ", SP="+std::to_string(b.reg(4))+
               ", IP="+std::to_string(b.d.ip_o)).c_str());
        const uint8_t expected_error_frame[]={0x00,0x00,0x08,0x02,0x08,0x00,
                                               uint8_t(kSavedFlags),uint8_t(kSavedFlags>>8)};
        for (unsigned i=0;i<sizeof(expected_error_frame);++i)
            check(b.memory[kStackBase+handler_sp+i]==expected_error_frame[i],
                  "outer IRET stack-bound fault pushed the wrong #SS(0) frame");
        for (unsigned i=0;i<sizeof(outer_frame);++i)
            check(b.memory[kStackBase+fault.initial_sp+i]==outer_frame[i],
                  "outer IRET stack-bound fault changed its five-word source frame");
        check(std::count_if(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                  return !t.write && t.address>=kStackBase+fault.initial_sp &&
                         t.address<kStackBase+fault.initial_sp+sizeof(outer_frame);
              })==fault.source_frame_reads &&
              std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && t.address>=kGdtBase+0x38 && t.address<kGdtBase+0x48;
              }) &&
              std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                  return t.write && t.address>=kStackBase+fault.initial_sp &&
                         t.address<kStackBase+fault.initial_sp+sizeof(outer_frame);
              }),
              "outer IRET stack-bound fault read too much, read a target descriptor, or wrote its source frame");

        b.step(kHandlerBase+kHandlerIp,0x83,kHandlerSelector,kHandlerIp+3,wait);
        b.step(kHandlerBase+kHandlerIp+3,0xb8,kHandlerSelector,kHandlerIp+6,wait);
        b.step(kHandlerBase+kHandlerIp+6,0x8e,kHandlerSelector,kHandlerIp+8,wait);
        check(uint16_t(b.d.segs_o>>32)==0x0068 && b.cache_base(2)==kStackBase &&
              b.reg(4)==fault.initial_sp-6,
              "#SS handler did not reload the valid wider ring-0 stack descriptor");
        b.step(kHandlerBase+kHandlerIp+8,0xcf,kCodeSelector,0x0208,wait);
        check(b.reg(4)==fault.initial_sp && uint16_t(b.d.segs_o>>32)==0x0068 &&
              b.d.ip_o==0x0208,
              "same-level #SS handler IRET did not retry the original IRET");
        b.step(kCodeBase+0x0208,0xcf,0x003b,0x0400,wait);
        check(b.cs()==0x003b && uint16_t(b.d.segs_o>>32)==0x0043 &&
              b.reg(4)==0x0100 && b.cache_base(1)==0x00060000 &&
              b.cache_base(2)==0x00070000,
              "repaired stack bounds did not allow the exact outer IRET commit");
        b.step(0x00060000+0x0400,0x90,0x003b,0x0401,wait);
        check(b.d.ip_o==0x0401 && b.reg(4)==0x0100,
              "repaired stack-bounds IRET did not execute its exact successor");
        ++executions;
    }
    check(executions==4,"outer IRET frame-boundary matrix missed a case or READY mode");
    std::cout<<"PASS: outer IRET checks starting SP and full five-word frame bounds with #SS(0), handler stack repair and exact-successor retry in both READY modes\n";
}

static void protected_outer_iret_fault_priorities() {
    using namespace protected_mode_fixture;
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00,             // 0200 MOV AX, ring-0 SS
        0x8e,0xd0,                   // 0203 MOV SS,AX
        0xbc,0x00,0x00,             // 0205 MOV SP, priority-case value
        0xcf                        // 0208 IRET to outer privilege
    };
    const uint8_t ring3_cs[]={0xff,0x0f,0x00,0x00,0x06,0xfa,0x00,0x00};
    const uint8_t ring3_ss[]={0xff,0x00,0x00,0x00,0x07,0xf2,0x00,0x00};
    const uint8_t nonpresent_ring3_ss[]={0xff,0x00,0x00,0x00,0x07,0x72,0x00,0x00};
    const uint8_t nonpresent_ring3_cs[]={0xff,0x0f,0x00,0x00,0x06,0x7a,0x00,0x00};
    const uint8_t short_limit_ring3_cs[]={0xff,0x03,0x00,0x00,0x06,0xfa,0x00,0x00};
    struct PriorityCase {
        const char* label;
        uint16_t initial_sp, current_ss_limit, return_cs, outer_ss, return_ip;
        uint8_t vector;
        bool nonpresent_cs, short_limit_cs, nonpresent_outer_ss;
        uint16_t error_code, source_frame_reads, return_cs_descriptor_reads,
                 outer_ss_descriptor_reads;
        uint16_t return_cs_accessed_writes;
    };
    const PriorityCase cases[]={
        {"starting-SP #SS before null return-CS #GP",0x0090,0x008f,0x0003,0x0000,0x0400,12,false,false,false,0,0,0,0,0},
        {"full-frame #SS before null return-CS #GP",0x0080,0x0087,0x0003,0x0000,0x0400,12,false,false,false,0,6,0,0,0},
        {"null return-CS #GP before null outer-SS #SS",0x0080,0x008f,0x0003,0x0000,0x0400,13,false,false,false,0,6,0,0,0},
        {"non-present return-CS #NP before null outer-SS #SS",0x0080,0x008f,0x004b,0x0000,0x0400,11,true,false,false,0x0048,6,8,0,0},
        {"null outer-SS #SS before over-limit return-IP #GP(0)",0x0080,0x008f,0x004b,0x0000,0x0400,12,false,true,false,0,10,8,0,1},
        {"non-present outer-SS #SS before over-limit return-IP #GP(0)",0x0080,0x008f,0x004b,0x0043,0x0400,12,false,true,true,0x0040,10,8,8,1}
    };
    unsigned executions=0;
    for (const auto& fault:cases) for (bool wait:{false,true}) {
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x40]=0x6f; // Include GDT entries for both outer-return descriptors.
        b.memory[kCodeBase+0x0206]=uint8_t(fault.initial_sp);
        b.memory[kCodeBase+0x0207]=uint8_t(fault.initial_sp>>8);
        b.put(kGdtBase+0x28,{uint8_t(fault.current_ss_limit),
                              uint8_t(fault.current_ss_limit>>8),
                              0x00,0x00,0x05,0x92,0x00,0x00});
        b.put(kGdtBase+0x38,{ring3_cs[0],ring3_cs[1],ring3_cs[2],ring3_cs[3],
                              ring3_cs[4],ring3_cs[5],ring3_cs[6],ring3_cs[7]});
        b.put(kGdtBase+0x40,{ring3_ss[0],ring3_ss[1],ring3_ss[2],ring3_ss[3],
                              ring3_ss[4],ring3_ss[5],ring3_ss[6],ring3_ss[7]});
        if (fault.nonpresent_outer_ss)
            b.put(kGdtBase+0x40,{nonpresent_ring3_ss[0],nonpresent_ring3_ss[1],
                                  nonpresent_ring3_ss[2],nonpresent_ring3_ss[3],
                                  nonpresent_ring3_ss[4],nonpresent_ring3_ss[5],
                                  nonpresent_ring3_ss[6],nonpresent_ring3_ss[7]});
        if (fault.nonpresent_cs)
            b.put(kGdtBase+(fault.return_cs&0xfff8),{
                nonpresent_ring3_cs[0],nonpresent_ring3_cs[1],nonpresent_ring3_cs[2],
                nonpresent_ring3_cs[3],nonpresent_ring3_cs[4],nonpresent_ring3_cs[5],
                nonpresent_ring3_cs[6],nonpresent_ring3_cs[7]});
        else if (fault.short_limit_cs)
            b.put(kGdtBase+(fault.return_cs&0xfff8),{
                short_limit_ring3_cs[0],short_limit_ring3_cs[1],short_limit_ring3_cs[2],
                short_limit_ring3_cs[3],short_limit_ring3_cs[4],short_limit_ring3_cs[5],
                short_limit_ring3_cs[6],short_limit_ring3_cs[7]});
        b.put(kIdtBase+12*8,{kVector13Gate[0],kVector13Gate[1],kVector13Gate[2],
                              kVector13Gate[3],kVector13Gate[4],kVector13Gate[5],
                              kVector13Gate[6],kVector13Gate[7]});
        const uint8_t outer_frame[]={uint8_t(fault.return_ip),uint8_t(fault.return_ip>>8),
            uint8_t(fault.return_cs),uint8_t(fault.return_cs>>8),
            0x02,0x02,0x00,0x01,
            uint8_t(fault.outer_ss),uint8_t(fault.outer_ss>>8)};
        for (unsigned i=0;i<sizeof(outer_frame);++i)
            b.memory[kStackBase+fault.initial_sp+i]=outer_frame[i];

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.data_transfers.clear();
        const unsigned retired_before_iret=b.retired;
        for (unsigned n=0;n<100000 && !b.d.event_o && !b.d.fault_o;++n) b.tick(wait);

        const uint16_t handler_sp=fault.initial_sp-8;
        check(!b.d.fault_o && b.d.event_o && b.d.event_packet_valid_o &&
              b.d.event_packet_protected_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_restartable_o && b.d.event_vector_o==fault.vector &&
              b.d.event_packet_error_code_o==fault.error_code &&
              b.d.event_packet_saved_cs_o==kCodeSelector &&
              b.d.event_packet_saved_ip_o==0x0208 &&
              b.d.event_packet_saved_flags_o==kSavedFlags &&
              b.d.event_packet_saved_sp_o==fault.initial_sp &&
              b.retired==retired_before_iret && b.cs()==kHandlerSelector &&
              b.d.ip_o==kHandlerIp && b.reg(4)==handler_sp,
              (std::string("outer IRET priority case ")+fault.label+
               " raised the wrong first fault, stop="+std::to_string(b.d.fault_code_o)+
               ", vector="+std::to_string(b.d.event_vector_o)).c_str());

        const uint8_t expected_error_frame[]={uint8_t(fault.error_code),
            uint8_t(fault.error_code>>8),0x08,0x02,0x08,0x00,
            uint8_t(kSavedFlags),uint8_t(kSavedFlags>>8)};
        for (unsigned i=0;i<sizeof(expected_error_frame);++i)
            check(b.memory[kStackBase+handler_sp+i]==expected_error_frame[i],
                  "outer IRET priority case pushed the wrong restart frame");
        for (unsigned i=0;i<sizeof(outer_frame);++i)
            check(b.memory[kStackBase+fault.initial_sp+i]==outer_frame[i],
                  "outer IRET priority fault modified its source frame");
        const uint32_t return_cs_descriptor=kGdtBase+(fault.return_cs&0xfff8);
        check(std::count_if(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                  return !t.write && t.address>=kStackBase+fault.initial_sp &&
                         t.address<kStackBase+fault.initial_sp+sizeof(outer_frame);
              })==fault.source_frame_reads &&
              std::count_if(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                  return !t.write && t.address>=return_cs_descriptor &&
                         t.address<return_cs_descriptor+8;
              })==fault.return_cs_descriptor_reads &&
              std::count_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && t.address>=kGdtBase+0x40 && t.address<kGdtBase+0x48;
              })==fault.outer_ss_descriptor_reads &&
              std::count_if(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                  return t.write && t.address==return_cs_descriptor+5 && t.value==0xfb;
              })==fault.return_cs_accessed_writes &&
              std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                  return t.write && t.address==return_cs_descriptor+5 && t.value!=0xfb;
              }) &&
              std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                  return t.write && t.address>=kStackBase+fault.initial_sp &&
                         t.address<kStackBase+fault.initial_sp+sizeof(outer_frame);
              }),
              "outer IRET priority case read past the first fault or changed its source frame");
        if (fault.nonpresent_outer_ss) {
            for (unsigned i=0;i<8;++i) {
                const auto read=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                    return !t.write && t.address==kGdtBase+0x40+i;
                });
                check(read!=b.data_transfers.end() && read->value==nonpresent_ring3_ss[i],
                      "outer IRET priority case used the wrong outer-SS descriptor bytes");
            }
        }
        ++executions;
    }
    check(executions==12,"outer IRET fault-priority matrix missed a case or READY mode");
    std::cout<<"PASS: outer IRET prioritizes current-stack, return-CS, outer-SS and return-IP faults in Intel Table 7-4 order in both READY modes\n";
}

static void protected_call_gate_same_level() {
    using namespace protected_mode_fixture;
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00,             // 0200 MOV AX, ring-0 SS
        0x8e,0xd0,                   // 0203 MOV SS,AX
        0xbc,0x80,0x00,             // 0205 MOV SP,0080
        0xcf,                       // 0208 IRET to outer privilege
        0xf4
    };
    const uint8_t ring3_program[]={
        0x9a,0x00,0x00,0x6b,0x00,  // 0400 CALL far through GDT call gate; supplied offset ignored
        0x90
    };
    const uint8_t ring3_code[]={0x90};
    const uint8_t ring3_cs[]={0xff,0x0f,0x00,0x00,0x06,0xfa,0x00,0x00};
    const uint8_t ring3_ss[]={0xff,0x00,0x00,0x00,0x07,0xf2,0x00,0x00};
    const uint8_t call_gate[]={0x00,0x05,0x3b,0x00,0x00,0xe4,0x00,0x00};
    unsigned executions=0;
    for (bool wait:{false,true}) {
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x41]=0x00; b.memory[0x40]=0x6f; // Extend GDT through selector 0068.
        b.put(kGdtBase+0x38,{ring3_cs[0],ring3_cs[1],ring3_cs[2],ring3_cs[3],
                              ring3_cs[4],ring3_cs[5],ring3_cs[6],ring3_cs[7]});
        b.put(kGdtBase+0x40,{ring3_ss[0],ring3_ss[1],ring3_ss[2],ring3_ss[3],
                              ring3_ss[4],ring3_ss[5],ring3_ss[6],ring3_ss[7]});
        b.put(kGdtBase+0x68,{call_gate[0],call_gate[1],call_gate[2],call_gate[3],
                              call_gate[4],call_gate[5],call_gate[6],call_gate[7]});
        b.put(0x00060000+0x0400,{ring3_program[0],ring3_program[1],ring3_program[2],
                                  ring3_program[3],ring3_program[4],ring3_program[5]});
        b.put(0x00060000+0x0500,{ring3_code[0]});
        b.put(kStackBase+0x0080,{0x00,0x04,0x3b,0x00,0x02,0x02,
                                 0x00,0x01,0x43,0x00});
        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xcf,0x003b,0x0400,wait);
        b.data_transfers.clear();
        b.step(0x00060400,0x9a,0x003b,0x0500,wait);
        check(uint16_t(b.d.segs_o>>32)==0x0043 && b.reg(4)==0x00fc,
              "same-level call gate changed CPL, SS or the expected frame SP");
        check(b.memory[0x000700fc]==0x05 && b.memory[0x000700fd]==0x04 &&
              b.memory[0x000700fe]==0x3b && b.memory[0x000700ff]==0x00,
              "same-level call gate did not push the exact successor IP and old CS");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && t.address==kGdtBase+0x68;
              }) && std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && t.address==kGdtBase+0x38;
              }),"same-level call gate did not read both gate and target code descriptors");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return t.write && t.address==0x000700fe && t.value==0x3b;
              }) && std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return t.write && t.address==0x000700fc && t.value==0x05;
              }),"same-level call gate did not issue its link-frame writes");
        b.step(0x00060500,0x90,0x003b,0x0501,wait);
        check(!b.d.halted_o && b.d.ip_o==0x0501,
              "same-level call gate target did not execute its unprivileged instruction");
        ++executions;
    }
    check(executions==2,"same-level call gate did not cover both READY modes");
    std::cout<<"PASS: protected same-level CALL gate resolves the target, pushes the exact link and reaches its gate offset in both READY modes\n";
}

static void protected_call_gate_access_faults() {
    using namespace protected_mode_fixture;
    struct FaultCase {
        uint16_t selector;
        uint8_t access;
        uint8_t vector;
        uint16_t error_code;
        bool gate_read;
    };
    const FaultCase cases[]={
        {0x006b,0x84,13,0x0068,true}, // RPL 3 exceeds the DPL-0 gate.
        {0x0068,0x04,11,0x0068,true}, // Accessible gate with P clear.
        {0x0068,0x83,13,0x0068,true}, // A present busy-TSS descriptor is not a call gate.
        {0x0068,0x82,13,0x0068,true}, // A present LDT descriptor is not a call gate.
        {0x0068,0x80,13,0x0068,true}, // A reserved system descriptor is not a call gate.
        {0x0068,0x86,13,0x0068,true}, // A present interrupt gate is not a call gate.
        {0x0068,0x87,13,0x0068,true}, // A present trap gate is not a call gate.
        {0x0068,0x88,13,0x0068,true}, // Reserved system descriptor type 8.
        {0x0068,0x89,13,0x0068,true}, // Reserved system descriptor type 9.
        {0x0068,0x8a,13,0x0068,true}, // Reserved system descriptor type A.
        {0x0068,0x8b,13,0x0068,true}, // Reserved system descriptor type B.
        {0x0068,0x8c,13,0x0068,true}, // Reserved system descriptor type C.
        {0x0068,0x8d,13,0x0068,true}, // Reserved system descriptor type D.
        {0x0068,0x8e,13,0x0068,true}, // Reserved system descriptor type E.
        {0x0068,0x8f,13,0x0068,true}, // Reserved system descriptor type F.
        {0x0068,0x92,13,0x0068,true}, // A present writable data descriptor is not a call gate.
        {0x0000,0x84,13,0x0000,false}, // Null gate selector.
        {0x0098,0x84,13,0x0098,false} // Non-null selector beyond the GDT limit.
    };
    unsigned executions=0;
    for (bool wait:{false,true}) for (const auto& test:cases) {
        const uint8_t program[]={
            0xb8,0x28,0x00,             // 0200 MOV AX, ring-0 SS
            0x8e,0xd0,                   // 0203 MOV SS,AX
            0xbc,0x80,0x00,             // 0205 MOV SP,0080
            0x9a,0x00,0x05,uint8_t(test.selector),uint8_t(test.selector>>8),
                                        // 0208 CALL through the selected gate
            0xf4
        };
        const uint8_t gate[]={0x00,0x05,0x08,0x00,0x00,test.access,0x00,0x00};
        Bench b;
        place_selector_fixture(b,program,sizeof(program));
        b.memory[0x41]=0x00; b.memory[0x40]=0x6f; // Extend GDT through the gate descriptor.
        b.put(kGdtBase+0x68,{gate[0],gate[1],gate[2],gate[3],
                              gate[4],gate[5],gate[6],gate[7]});
        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        const uint16_t saved_flags=b.d.flags_o;
        const unsigned retired_before=b.retired;
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<30000 && !b.d.event_o && !b.d.fault_o;++cycle) b.tick(wait);
        check(b.d.event_o && !b.d.fault_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_error_valid_o && b.d.event_packet_restartable_o &&
              b.d.event_vector_o==test.vector && b.d.event_packet_error_code_o==test.error_code &&
              b.d.event_packet_saved_cs_o==kCodeSelector &&
              b.d.event_packet_saved_ip_o==0x0208 &&
              b.d.event_packet_saved_flags_o==saved_flags &&
              b.d.event_packet_saved_sp_o==kInitialSp &&
              b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp &&
              uint16_t(b.d.segs_o>>32)==kSsSelector &&
              b.cache_base(2)==kStackBase && b.reg(4)==kInitialSp-8 &&
              b.reg(0)==kSsSelector && b.retired==retired_before,
              "CALL-gate DPL/presence check did not deliver its exact restartable fault packet");
        const uint8_t expected_values[]={
            uint8_t(saved_flags),uint8_t(saved_flags>>8),
            uint8_t(kCodeSelector),uint8_t(kCodeSelector>>8),
            0x08,0x02,uint8_t(test.error_code),uint8_t(test.error_code>>8)
        };
        const uint32_t expected_addresses[]={
            kStackBase+kInitialSp-2,kStackBase+kInitialSp-1,
            kStackBase+kInitialSp-4,kStackBase+kInitialSp-3,
            kStackBase+kInitialSp-6,kStackBase+kInitialSp-5,
            kStackBase+kInitialSp-8,kStackBase+kInitialSp-7
        };
        std::vector<Bench::Transfer> frame_writes;
        for (const auto& transfer:b.data_transfers)
            if (transfer.write && transfer.address>=kStackBase+kInitialSp-8 &&
                transfer.address<kStackBase+kInitialSp)
                frame_writes.push_back(transfer);
        check(frame_writes.size()==8,
              "rejected CALL gate partially wrote a call frame before the exception frame");
        for (unsigned i=0;i<8;++i)
            check(frame_writes[i].address==expected_addresses[i] &&
                  frame_writes[i].value==expected_values[i],
                  "CALL-gate exception frame bus order/value mismatch");
        const bool gate_read=std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& transfer) {
            return !transfer.write && transfer.address==kGdtBase+0x68;
        });
        check(gate_read==test.gate_read,
              "CALL-gate selector rejection performed an unexpected gate descriptor read");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& transfer) {
                  return !transfer.write && transfer.address>=kGdtBase+8 &&
                         transfer.address<kGdtBase+0x10;
              }),"CALL-gate rejection read the target code descriptor before gate validation");
        check(b.memory[kGdtBase+0x6d]==test.access,
              "rejected CALL gate modified its descriptor");
        const uint8_t expected_frame[]={
            uint8_t(test.error_code),uint8_t(test.error_code>>8),0x08,0x02,0x08,0x00,
            uint8_t(saved_flags),uint8_t(saved_flags>>8)
        };
        for (unsigned i=0;i<8;++i)
            check(b.memory.at(kStackBase+kInitialSp-8+i)==expected_frame[i],
                  "CALL-gate exception stack image mismatch");
        ++executions;
    }
    check(executions==36,"CALL-gate selector/type/access faults did not cover every case and READY mode");
    std::cout<<"PASS: null/out-of-limit selectors, all 13 invalid system types and a data descriptor, plus DPL/presence rejection, report exact #GP/#NP frames before target lookup or CALL-frame writes in both READY modes\n";
}

static void protected_call_gate_target_faults() {
    using namespace protected_mode_fixture;
    struct FaultCase {
        uint16_t target_selector;
        uint8_t target_access;
        uint8_t vector;
        bool target_descriptor_read;
    };
    const FaultCase cases[]={
        {0x0000,0x00,13,false}, // A null target selector raises #GP(0).
        {0x00a0,0x00,13,false}, // An out-of-limit target selector raises #GP(selector).
        {0x0010,0x92,13,true},  // A present data descriptor is not a code target.
        {0x0038,0xfa,13,true},  // A DPL-3 nonconforming target is too unprivileged for CPL 0.
        {0x0098,0x1a,11,true}   // A non-present code target raises #NP(selector).
    };
    unsigned executions=0;
    for (bool wait:{false,true}) for (const auto& test:cases) {
        const uint8_t program[]={
            0xb8,0x28,0x00,             // 0200 MOV AX, ring-0 SS
            0x8e,0xd0,                   // 0203 MOV SS,AX
            0xbc,0x80,0x00,             // 0205 MOV SP,0080
            0x9a,0x00,0x05,0x68,0x00,  // 0208 CALL through the present DPL-0 gate
            0xf4
        };
        const uint8_t gate[]={0x00,0x05,uint8_t(test.target_selector),
                              uint8_t(test.target_selector>>8),0x00,0x84,0x00,0x00};
        const uint8_t nonpresent_code[]={0xff,0x0f,0x00,0x00,0x06,test.target_access,0x00,0x00};
        const uint8_t dpl3_code[]={0xff,0x0f,0x00,0x00,0x06,test.target_access,0x00,0x00};
        Bench b;
        place_selector_fixture(b,program,sizeof(program));
        b.memory[0x40]=0x9f; b.memory[0x41]=0x00; // Include the non-present target descriptor.
        b.put(kGdtBase+0x68,{gate[0],gate[1],gate[2],gate[3],
                              gate[4],gate[5],gate[6],gate[7]});
        if (test.target_selector==0x0098)
            b.put(kGdtBase+0x98,{nonpresent_code[0],nonpresent_code[1],
                                  nonpresent_code[2],nonpresent_code[3],
                                  nonpresent_code[4],nonpresent_code[5],
                                  nonpresent_code[6],nonpresent_code[7]});
        else if (test.target_selector==0x0038)
            b.put(kGdtBase+0x38,{dpl3_code[0],dpl3_code[1],dpl3_code[2],dpl3_code[3],
                                  dpl3_code[4],dpl3_code[5],dpl3_code[6],dpl3_code[7]});
        const uint32_t target_address=kGdtBase+(test.target_selector&0xfff8);
        if (!test.target_descriptor_read) b.memory[target_address+5]=0x5a;
        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        const uint16_t saved_flags=b.d.flags_o;
        const unsigned retired_before=b.retired;
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<30000 && !b.d.event_o && !b.d.fault_o;++cycle) b.tick(wait);
        const uint16_t expected_error=test.target_selector&0xfffc;
        check(b.d.event_o && !b.d.fault_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_error_valid_o && b.d.event_packet_restartable_o &&
              b.d.event_vector_o==test.vector &&
              b.d.event_packet_error_code_o==expected_error &&
              b.d.event_packet_saved_cs_o==kCodeSelector &&
              b.d.event_packet_saved_ip_o==0x0208 &&
              b.d.event_packet_saved_flags_o==saved_flags &&
              b.d.event_packet_saved_sp_o==kInitialSp &&
              b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp &&
              uint16_t(b.d.segs_o>>32)==kSsSelector &&
              b.cache_base(2)==kStackBase && b.reg(4)==kInitialSp-8 &&
              b.reg(0)==kSsSelector && b.retired==retired_before,
              "CALL-gate target type/privilege/presence check did not deliver its exact restartable fault packet");

        const uint8_t expected_values[]={
            uint8_t(saved_flags),uint8_t(saved_flags>>8),
            uint8_t(kCodeSelector),uint8_t(kCodeSelector>>8),
            0x08,0x02,uint8_t(expected_error),uint8_t(expected_error>>8)
        };
        const uint32_t expected_addresses[]={
            kStackBase+kInitialSp-2,kStackBase+kInitialSp-1,
            kStackBase+kInitialSp-4,kStackBase+kInitialSp-3,
            kStackBase+kInitialSp-6,kStackBase+kInitialSp-5,
            kStackBase+kInitialSp-8,kStackBase+kInitialSp-7
        };
        std::vector<Bench::Transfer> frame_writes;
        for (const auto& transfer:b.data_transfers)
            if (transfer.write && transfer.address>=kStackBase+kInitialSp-8 &&
                transfer.address<kStackBase+kInitialSp)
                frame_writes.push_back(transfer);
        check(frame_writes.size()==8,
              "invalid CALL-gate target partially wrote a call frame before the exception frame");
        for (unsigned i=0;i<8;++i)
            check(frame_writes[i].address==expected_addresses[i] &&
                  frame_writes[i].value==expected_values[i],
                  "CALL-gate target exception frame bus order/value mismatch");

        std::vector<uint32_t> target_reads;
        for (const auto& transfer:b.data_transfers)
            if (!transfer.write && !transfer.io && transfer.address>=target_address &&
                transfer.address<target_address+8)
                target_reads.push_back(transfer.address);
        check(target_reads.size()==(test.target_descriptor_read ? 8u : 0u),
              "CALL-gate null/out-of-limit target selector issued an incorrect target descriptor read");
        for (unsigned i=0;i<8;++i)
            if (test.target_descriptor_read) check(target_reads[i]==target_address+i,
                  "CALL-gate target descriptor bytes were read out of order");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& transfer) {
                  return !transfer.write && transfer.address==0x00000702;
              }),"CALL-gate target fault read the TSS before target validation");
        check(b.memory[target_address+5]==(test.target_descriptor_read ? test.target_access : 0x5a),
              "rejected CALL-gate target descriptor/sentinel was modified");
        const uint8_t expected_frame[]={
            uint8_t(expected_error),uint8_t(expected_error>>8),0x08,0x02,0x08,0x00,
            uint8_t(saved_flags),uint8_t(saved_flags>>8)
        };
        for (unsigned i=0;i<8;++i)
            check(b.memory.at(kStackBase+kInitialSp-8+i)==expected_frame[i],
                  "CALL-gate target exception stack image mismatch");
        ++executions;
    }
    check(executions==10,"CALL-gate target faults did not cover all cases and READY modes");
    std::cout<<"PASS: CALL-gate null, out-of-limit, invalid-type, privilege and presence checks report exact #GP/#NP before TSS access or CALL-frame writes in both READY modes\n";
}

static void protected_call_gate_ldt_target_faults() {
    using namespace protected_mode_fixture;
    struct FaultCase {
        const char* name;
        bool load_ldt;
        uint16_t ldt_limit;
        uint8_t target_access;
        uint8_t vector;
        uint16_t error_code;
        bool target_descriptor_read;
    };
    const FaultCase cases[]={
        {"invalid LDTR",false,0x0007,0x00,13,0x000c,false},
        {"LDT limit",true,0x0007,0x00,13,0x000c,false},
        {"present data target",true,0x000f,0x92,13,0x000c,true},
        {"non-present code target",true,0x000f,0x1a,11,0x000c,true}
    };
    unsigned executions=0;
    for (bool wait:{false,true}) for (const auto& test:cases) {
        std::vector<uint8_t> program={
            0xb8,0x28,0x00,             // MOV AX, ring-0 SS
            0x8e,0xd0,                   // MOV SS,AX
            0xbc,0x80,0x00              // MOV SP,0080
        };
        if (test.load_ldt) {
            program.insert(program.end(),{0xb8,0x38,0x00,0x0f,0x00,0xd0}); // LLDT AX
        }
        const uint16_t call_ip=uint16_t(0x0200+program.size());
        program.insert(program.end(),{0x9a,0x00,0x05,0x68,0x00,0xf4});

        Bench b;
        place_selector_fixture(b,program.data(),program.size());
        b.memory[0x40]=0x6f; b.memory[0x41]=0x00; // Include the LDT and gate descriptors.
        b.put(kGdtBase+0x38,{uint8_t(test.ldt_limit),uint8_t(test.ldt_limit>>8),
                              0x00,0x06,0x00,0x82,0x00,0x00}); // LDT base=0600.
        b.put(kGdtBase+0x68,{0x00,0x05,0x0c,0x00,0x00,0x84,0x00,0x00}); // Target LDT selector 000C.
        const uint8_t target_descriptor[]={0xff,0x0f,0x00,0x00,0x01,
                                            test.target_access,0x00,0x00};
        for (unsigned i=0;i<8;++i)
            b.memory[0x00000608+i]=test.target_descriptor_read ? target_descriptor[i] : uint8_t(0xa0+i);

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        if (test.load_ldt) {
            b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
            b.step(kCodeBase+0x020b,0x0f,kCodeSelector,call_ip,wait);
        }
        const uint16_t saved_flags=b.d.flags_o;
        const unsigned retired_before=b.retired;
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<30000 && !b.d.event_o && !b.d.fault_o;++cycle) b.tick(wait);
        check(b.d.event_o && !b.d.fault_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_error_valid_o && b.d.event_packet_restartable_o &&
              b.d.event_vector_o==test.vector && b.d.event_packet_error_code_o==test.error_code &&
              b.d.event_packet_saved_cs_o==kCodeSelector &&
              b.d.event_packet_saved_ip_o==call_ip &&
              b.d.event_packet_saved_flags_o==saved_flags &&
              b.d.event_packet_saved_sp_o==kInitialSp &&
              b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp &&
              uint16_t(b.d.segs_o>>32)==kSsSelector &&
              b.cache_base(2)==kStackBase && b.reg(4)==kInitialSp-8 &&
              b.retired==retired_before,
              (std::string("CALL-gate ")+test.name+" did not deliver its exact selector fault").c_str());

        const auto target_reads=std::count_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& transfer) {
            return !transfer.write && !transfer.io && transfer.address>=0x00000608 &&
                transfer.address<0x00000610;
        });
        check(target_reads==(test.target_descriptor_read ? 8u : 0u),
              (std::string("CALL-gate ")+test.name+" performed an unexpected LDT target read").c_str());
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& transfer) {
                  return !transfer.write && transfer.address==0x00000702;
              }),(std::string("CALL-gate ")+test.name+" read the TSS before target validation").c_str());

        const uint8_t expected_values[]={
            uint8_t(saved_flags),uint8_t(saved_flags>>8),
            uint8_t(kCodeSelector),uint8_t(kCodeSelector>>8),
            uint8_t(call_ip),uint8_t(call_ip>>8),uint8_t(test.error_code),uint8_t(test.error_code>>8)
        };
        const uint32_t expected_addresses[]={
            kStackBase+kInitialSp-2,kStackBase+kInitialSp-1,
            kStackBase+kInitialSp-4,kStackBase+kInitialSp-3,
            kStackBase+kInitialSp-6,kStackBase+kInitialSp-5,
            kStackBase+kInitialSp-8,kStackBase+kInitialSp-7
        };
        std::vector<Bench::Transfer> frame_writes;
        for (const auto& transfer:b.data_transfers)
            if (transfer.write && transfer.address>=kStackBase+kInitialSp-8 &&
                transfer.address<kStackBase+kInitialSp)
                frame_writes.push_back(transfer);
        check(frame_writes.size()==8,
              (std::string("CALL-gate ")+test.name+" did not isolate its exact exception frame").c_str());
        for (unsigned i=0;i<8;++i)
            check(frame_writes[i].address==expected_addresses[i] &&
                  frame_writes[i].value==expected_values[i],
                  (std::string("CALL-gate ")+test.name+" exception-frame bus order/value mismatch").c_str());
        for (unsigned i=0;i<8;++i) if (test.target_descriptor_read)
            check(b.memory[0x00000608+i]==target_descriptor[i],
                  (std::string("CALL-gate ")+test.name+" changed the rejected LDT target descriptor").c_str());
        ++executions;
    }
    check(executions==8,"CALL-gate invalid LDT target matrix did not cover every case and READY mode");
    std::cout<<"PASS: CALL-gate LDT targets with invalid LDTR, out-of-limit, wrong-type or non-present descriptors deliver exact #GP/#NP before TSS access or CALL-frame writes in both READY modes\n";
}

static void protected_call_gate_tss_stack_faults() {
    using namespace protected_mode_fixture;
    struct FaultCase {
        const char* name;
        uint16_t tss_limit;
        uint16_t stack_pointer;
        uint16_t stack_selector;
        uint16_t stack_limit;
        uint8_t stack_access;
        uint8_t vector;
        uint16_t error_code;
        bool tss_pair_read;
        bool stack_descriptor_read;
    };
    const FaultCase cases[]={
        {"TSS limit",0x0001,0x0100,0x0028,0x00ff,0x93,10,0x0058,false,false},
        {"null SS0",0x002b,0x0100,0x0000,0x00ff,0x93,10,0x0000,true,false},
        {"SS0 outside GDT",0x002b,0x0100,0x0070,0x00ff,0x93,10,0x0070,true,false},
        {"code SS0",0x002b,0x0100,0x0030,0x00ff,0x93,10,0x0030,true,true},
        {"SS0 RPL mismatch",0x002b,0x0100,0x002b,0x00ff,0x93,10,0x0028,true,true},
        {"SS0 DPL mismatch",0x002b,0x0100,0x0040,0x00ff,0x93,10,0x0040,true,true},
        {"SS0 not present",0x002b,0x0100,0x0028,0x00ff,0x12,12,0x0028,true,true},
        {"SP0 underflow",0x002b,0x0007,0x0028,0x00ff,0x93,12,0x0000,true,true},
        {"SS0 limit",0x002b,0x0008,0x0028,0x0006,0x93,12,0x0000,true,true}
    };
    const uint8_t ring0_program[]={
        0xb8,0x48,0x00,             // 0200 MOV AX, dedicated ring-0 setup SS
        0x8e,0xd0,                   // 0203 MOV SS,AX
        0xbc,0x80,0x00,             // 0205 MOV SP,0080
        0xb8,0x58,0x00,             // 0208 MOV AX, TSS selector
        0x0f,0x00,0xd8,             // 020B LTR AX
        0xcf,                       // 020E IRET to ring 3
        0xf4
    };
    const uint8_t ring3_program[]={0x9a,0x00,0x00,0x6b,0x00,0xf4};
    const uint8_t ring3_cs[]={0xff,0x0f,0x00,0x00,0x06,0xfa,0x00,0x00};
    const uint8_t ring3_ss[]={0xff,0x01,0x00,0x00,0x07,0xf2,0x00,0x00};
    unsigned executions=0;
    for (bool wait:{false,true}) for (const auto& test:cases) {
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x41]=0x00; b.memory[0x40]=0x6f; // Include TSS and CALL-gate descriptors.
        b.put(kGdtBase+0x38,{ring3_cs[0],ring3_cs[1],ring3_cs[2],ring3_cs[3],
                              ring3_cs[4],ring3_cs[5],ring3_cs[6],ring3_cs[7]});
        b.put(kGdtBase+0x40,{ring3_ss[0],ring3_ss[1],ring3_ss[2],ring3_ss[3],
                              ring3_ss[4],ring3_ss[5],ring3_ss[6],ring3_ss[7]});
        b.put(kGdtBase+0x48,{0xff,0x00,0x00,0x00,0x05,0x93,0x00,0x00});
        b.put(kGdtBase+0x28,{uint8_t(test.stack_limit),uint8_t(test.stack_limit>>8),
                              0x00,0x00,0x05,test.stack_access,0x00,0x00});
        b.put(kGdtBase+0x58,{uint8_t(test.tss_limit),uint8_t(test.tss_limit>>8),
                              0x00,0x07,0x00,0x81,0x00,0x00});
        b.put(kGdtBase+0x68,{0x00,0x05,0x08,0x00,0x00,0xe4,0x00,0x00});
        b.put(0x00000702,{uint8_t(test.stack_pointer),uint8_t(test.stack_pointer>>8),
                           uint8_t(test.stack_selector),uint8_t(test.stack_selector>>8)});
        b.put(kIdtBase+10*8,{0x00,0x03,0x3b,0x00,0x00,0x86,0x00,0x00});
        b.put(kIdtBase+12*8,{0x00,0x03,0x3b,0x00,0x00,0x86,0x00,0x00});
        b.put(0x00060000+0x0400,{ring3_program[0],ring3_program[1],ring3_program[2],
                                  ring3_program[3],ring3_program[4],ring3_program[5]});
        b.put(0x00060000+0x0300,{0xf4});
        b.put(kStackBase+0x0080,{0x00,0x04,0x3b,0x00,0x02,0x02,
                                 0x00,0x01,0x43,0x00});

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
        b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x020e,wait);
        check(b.memory[kGdtBase+0x5d]==0x83,
              "LTR did not mark the TSS busy for the call-gate fault fixture");
        b.step(kCodeBase+0x020e,0xcf,0x003b,0x0400,wait);
        check(b.reg(4)==0x0100 && uint16_t(b.d.segs_o>>32)==0x0043,
              "outer IRET did not prepare the ring-3 caller stack");
        const uint16_t saved_flags=b.d.flags_o;
        const unsigned retired_before=b.retired;
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<30000 && !b.d.event_o && !b.d.fault_o;++cycle) b.tick(wait);
        check(b.d.event_o && !b.d.fault_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_error_valid_o && b.d.event_packet_restartable_o &&
              b.d.event_vector_o==test.vector &&
              b.d.event_packet_error_code_o==test.error_code &&
              b.d.event_packet_saved_cs_o==0x003b &&
              b.d.event_packet_saved_ip_o==0x0400 &&
              b.d.event_packet_saved_flags_o==saved_flags &&
              b.d.event_packet_saved_sp_o==0x0100 &&
              b.cs()==0x003b && b.d.ip_o==0x0300 &&
              uint16_t(b.d.segs_o>>32)==0x0043 && b.cache_base(2)==0x00070000 &&
              b.reg(4)==0x00f8 && b.retired==retired_before,
              (std::string("CALL-gate ")+test.name+" did not deliver its exact same-level fault packet").c_str());

        const uint8_t expected_values[]={
            uint8_t(saved_flags),uint8_t(saved_flags>>8),0x3b,0x00,
            0x00,0x04,uint8_t(test.error_code),uint8_t(test.error_code>>8)
        };
        const uint32_t expected_addresses[]={
            0x000700fe,0x000700ff,0x000700fc,0x000700fd,
            0x000700fa,0x000700fb,0x000700f8,0x000700f9
        };
        std::vector<Bench::Transfer> ring3_frame_writes;
        std::vector<Bench::Transfer> ring0_stack_writes;
        for (const auto& transfer:b.data_transfers) if (transfer.write) {
            if (transfer.address>=0x000700f8 && transfer.address<0x00070100)
                ring3_frame_writes.push_back(transfer);
            if (transfer.address>=kStackBase+0x00f0 && transfer.address<kStackBase+0x0100)
                ring0_stack_writes.push_back(transfer);
        }
        check(ring3_frame_writes.size()==8 && ring0_stack_writes.empty(),
              (std::string("CALL-gate ")+test.name+" wrote a partial CALL frame or missed its exception frame").c_str());
        for (unsigned i=0;i<8;++i)
            check(ring3_frame_writes[i].address==expected_addresses[i] &&
                  ring3_frame_writes[i].value==expected_values[i],
                  (std::string("CALL-gate ")+test.name+" exception-frame byte order/value mismatch").c_str());

        const auto tss_reads=std::count_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
            return !t.write && t.address>=0x00000702 && t.address<0x00000706;
        });
        check(tss_reads==(test.tss_pair_read ? 4u : 0u),
              (std::string("CALL-gate ")+test.name+" performed an unexpected TSS stack-pair read").c_str());
        const uint32_t ss_address=kGdtBase+(test.stack_selector&0xfff8);
        const auto ss_reads=std::count_if(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
            return !t.write && t.address>=ss_address && t.address<ss_address+8;
        });
        check(ss_reads==(test.stack_descriptor_read ? 8u : 0u),
              (std::string("CALL-gate ")+test.name+" performed an unexpected SS descriptor read").c_str());
        const uint8_t expected_frame[]={
            uint8_t(test.error_code),uint8_t(test.error_code>>8),0x00,0x04,0x3b,0x00,
            uint8_t(saved_flags),uint8_t(saved_flags>>8)
        };
        for (unsigned i=0;i<8;++i)
            check(b.memory.at(0x000700f8+i)==expected_frame[i],
                  (std::string("CALL-gate ")+test.name+" exception stack image mismatch").c_str());
        ++executions;
    }
    check(executions==18,"CALL-gate TSS/stack fault matrix did not cover every case and READY mode");
    std::cout<<"PASS: CALL-gate TSS bounds, SS0 selector/type/privilege/presence and stack-span failures deliver exact #TS/#SS frames without partial privilege-switch writes in both READY modes\n";
}

static void protected_call_gate_outer_level() {
    using namespace protected_mode_fixture;
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00,             // 0200 MOV AX, ring-0 SS
        0x8e,0xd0,                   // 0203 MOV SS,AX
        0xbc,0x80,0x00,             // 0205 MOV SP,0080
        0xb8,0x58,0x00,             // 0208 MOV AX, ring-0 TSS
        0x0f,0x00,0xd8,             // 020B LTR AX
        0xcf,                       // 020E IRET to outer privilege
        0xf4
    };
    const uint8_t ring3_program[]={
        0x9a,0x00,0x00,0x6b,0x00,  // 0400 CALL through DPL-3 gate to DPL-0 code
        0x90
    };
    const uint8_t ring3_cs[]={0xff,0x0f,0x00,0x00,0x06,0xfa,0x00,0x00};
    const uint8_t ring3_ss[]={0xff,0x01,0x00,0x00,0x07,0xf2,0x00,0x00};
    const uint8_t tss[]={0x2b,0x00,0x00,0x07,0x00,0x81,0x00,0x00};
    unsigned executions=0;
    for (unsigned parameter_count:{0u,1u,31u}) for (bool wait:{false,true}) {
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x41]=0x00; b.memory[0x40]=0x6f; // Include TSS and gate descriptors.
        b.put(kGdtBase+0x38,{ring3_cs[0],ring3_cs[1],ring3_cs[2],ring3_cs[3],
                              ring3_cs[4],ring3_cs[5],ring3_cs[6],ring3_cs[7]});
        b.put(kGdtBase+0x40,{ring3_ss[0],ring3_ss[1],ring3_ss[2],ring3_ss[3],
                              ring3_ss[4],ring3_ss[5],ring3_ss[6],ring3_ss[7]});
        b.put(kGdtBase+0x58,{tss[0],tss[1],tss[2],tss[3],tss[4],tss[5],tss[6],tss[7]});
        b.put(kGdtBase+0x68,{0x00,0x05,0x08,0x00,uint8_t(parameter_count),0xe4,0x00,0x00});
        b.put(0x00000702,{0x00,0x01,0x28,0x00}); // TSS base=0700; SP0=0100, SS0=0028.
        b.put(0x00060000+0x0400,{ring3_program[0],ring3_program[1],ring3_program[2],
                                  ring3_program[3],ring3_program[4],ring3_program[5]});
        const unsigned return_adjust=parameter_count*2;
        if (parameter_count==0) b.put(kCodeBase+0x0500,{0xcb});
        else b.put(kCodeBase+0x0500,{0xca,uint8_t(return_adjust),uint8_t(return_adjust>>8)});
        for (unsigned i=0;i<parameter_count;++i) {
            const uint16_t value=uint16_t(0x1000+i);
            b.put(0x00070100+2*i,{uint8_t(value),uint8_t(value>>8)});
        }
        b.put(kStackBase+0x0080,{0x00,0x04,0x3b,0x00,0x02,0x02,
                                 0x00,0x01,0x43,0x00});
        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
        b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x020e,wait);
        check(b.memory[kGdtBase+0x5d]==0x83,"LTR did not mark the TSS busy before the privilege call");
        b.step(kCodeBase+0x020e,0xcf,0x003b,0x0400,wait);
        b.data_transfers.clear();
        b.step(0x00060400,0x9a,kCodeSelector,0x0500,wait);
        const uint16_t final_sp=uint16_t(0x0100-(8+2*parameter_count));
        check(uint16_t(b.d.segs_o>>32)==kSsSelector && b.reg(4)==final_sp,
              "call gate did not atomically install the TSS ring-0 SS:SP");
        check(b.cs()==kCodeSelector && b.cache_base(2)==kStackBase,
              "call gate did not install the ring-0 code and stack caches");
        check(b.memory[kStackBase+final_sp]==0x05 && b.memory[kStackBase+final_sp+1]==0x04 &&
              b.memory[kStackBase+final_sp+2]==0x3b && b.memory[kStackBase+final_sp+3]==0x00 &&
              b.memory[kStackBase+0x00fc]==0x00 && b.memory[kStackBase+0x00fd]==0x01 &&
              b.memory[kStackBase+0x00fe]==0x43 && b.memory[kStackBase+0x00ff]==0x00,
              "inter-level call gate built the return link or outer stack pointer incorrectly");
        for (unsigned i=0;i<parameter_count;++i) {
            const uint16_t expected=uint16_t(0x1000+i);
            const unsigned dest=kStackBase+final_sp+4+2*i;
            check(b.memory[dest]==uint8_t(expected) && b.memory[dest+1]==uint8_t(expected>>8),
                  "inter-level call gate copied a parameter to the wrong new-stack position");
        }
        const auto tss_read=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
            return !t.write && t.address==0x00000702;
        });
        const auto ss_descriptor=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
            return !t.write && t.address==kGdtBase+0x28;
        });
        const auto first_frame_write=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
            return t.write && t.address==0x000500fe;
        });
        check(tss_read<ss_descriptor && ss_descriptor<first_frame_write,
              "call gate accessed or wrote the new stack before reading TSS and validating SS0");
        auto previous_parameter_write=b.data_transfers.end();
        for (unsigned i=0;i<parameter_count;++i) {
            const uint32_t source=0x00070100+2*i;
            const uint32_t destination=kStackBase+final_sp+4+2*i;
            const auto parameter_read=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                return !t.write && t.address==source;
            });
            const auto parameter_write=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                return t.write && t.address==destination;
            });
            check(parameter_read!=b.data_transfers.end() && parameter_write!=b.data_transfers.end() &&
                  parameter_read<parameter_write &&
                  (previous_parameter_write==b.data_transfers.end() || previous_parameter_write<parameter_read),
                  "call gate did not copy each caller parameter to its new-stack position in order");
            previous_parameter_write=parameter_write;
        }
        b.step(kCodeBase+0x0500,parameter_count==0 ? 0xcb : 0xca,0x003b,0x0405,wait);
        check(uint16_t(b.d.segs_o>>32)==0x0043 && b.reg(4)==0x0100+return_adjust,
              "outer RETF did not restore the caller SS:SP and apply its immediate adjustment");
        b.step(0x00060405,0x90,0x003b,0x0406,wait);
        check(!b.d.halted_o && b.d.ip_o==0x0406,
              "inter-level call and outer RETF did not resume the ring-3 caller");
        ++executions;
    }
    check(executions==6,"inter-level call gate did not cover zero, one and 31 parameters in both READY modes");
    std::cout<<"PASS: protected ring-3 CALL gates copy 0, 1 and 31 parameters, switch through TSS, and return across privilege levels in both READY modes\n";
}

static void protected_call_gate_ring1_ring2() {
    using namespace protected_mode_fixture;
    struct LevelCase {
        unsigned cpl;
        uint16_t code_selector, stack_selector, initial_sp, tss_offset;
        uint32_t code_base, stack_base, code_descriptor, stack_descriptor;
        uint8_t code_access, stack_access;
    };
    const LevelCase levels[]={
        {1,0x0049,0x0061,0x0140,0x0006,0x00081000,0x00080000,
         0x00000348,0x00000360,0xba,0xb3},
        {2,0x0052,0x0072,0x0180,0x000a,0x00083000,0x00082000,
         0x00000350,0x00000370,0xda,0xd3}
    };
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00,             // 0200 MOV AX, ring-0 SS
        0x8e,0xd0,                   // 0203 MOV SS,AX
        0xbc,0x80,0x00,             // 0205 MOV SP,0080
        0xb8,0x58,0x00,             // 0208 MOV AX, ring-0 TSS
        0x0f,0x00,0xd8,             // 020B LTR AX
        0xcf,                       // 020E IRET to outer privilege
        0xf4
    };
    const uint8_t ring3_program[]={
        0x9a,0x00,0x00,0x6b,0x00,  // 0400 CALL through DPL-3 gate
        0x90
    };
    const uint8_t ring3_cs[]={0xff,0x0f,0x00,0x00,0x06,0xfa,0x00,0x00};
    const uint8_t ring3_ss[]={0xff,0x01,0x00,0x00,0x07,0xf2,0x00,0x00};
    const uint8_t tss_descriptor[]={0x2b,0x00,0x00,0x07,0x00,0x81,0x00,0x00};
    unsigned executions=0;
    for (const auto& level:levels) for (bool wait:{false,true}) {
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x40]=0x77; b.memory[0x41]=0x00;
        b.put(kGdtBase+0x38,{ring3_cs[0],ring3_cs[1],ring3_cs[2],ring3_cs[3],
                              ring3_cs[4],ring3_cs[5],ring3_cs[6],ring3_cs[7]});
        b.put(kGdtBase+0x40,{ring3_ss[0],ring3_ss[1],ring3_ss[2],ring3_ss[3],
                              ring3_ss[4],ring3_ss[5],ring3_ss[6],ring3_ss[7]});
        b.put(kGdtBase+0x48,{0xff,0x0f,0x00,0x10,0x08,level.code_access,0x00,0x00});
        b.put(kGdtBase+0x50,{0xff,0x0f,0x00,0x30,0x08,0xda,0x00,0x00});
        b.put(kGdtBase+0x58,{tss_descriptor[0],tss_descriptor[1],tss_descriptor[2],tss_descriptor[3],
                              tss_descriptor[4],tss_descriptor[5],tss_descriptor[6],tss_descriptor[7]});
        b.put(kGdtBase+0x60,{0xff,0x01,0x00,0x00,0x08,0xb3,0x00,0x00});
        b.put(kGdtBase+0x68,{0x00,0x05,uint8_t(level.code_selector),
                              uint8_t(level.code_selector>>8),0x02,0xe4,0x00,0x00});
        b.put(kGdtBase+0x70,{0xff,0x01,0x00,0x20,0x08,0xd3,0x00,0x00});
        b.put(0x00000702,{0x00,0x01,0x28,0x00,  // SP0:SS0
                          0x40,0x01,0x61,0x00,  // SP1:SS1
                          0x80,0x01,0x72,0x00}); // SP2:SS2
        b.put(0x00060400,{ring3_program[0],ring3_program[1],ring3_program[2],
                           ring3_program[3],ring3_program[4],ring3_program[5]});
        b.put(level.code_base+0x0500,{0xca,0x04,0x00}); // RETF 4
        b.put(kStackBase+0x0080,{0x00,0x04,0x3b,0x00,0x02,0x02,
                                  0x00,0x01,0x43,0x00});
        b.put(0x00070100,{0x34,0x12,0x78,0x56});

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
        b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x020e,wait);
        b.step(kCodeBase+0x020e,0xcf,0x003b,0x0400,wait);
        check(b.cs()==0x003b && uint16_t(b.d.segs_o>>32)==0x0043 && b.reg(4)==0x0100,
              "outer IRET did not reach the ring-3 CALL-gate caller");
        check(b.memory[kGdtBase+0x5d]==0x83,"LTR did not mark the TSS busy for ring-1/2 CALL");

        b.data_transfers.clear();
        const uint16_t final_sp=uint16_t(level.initial_sp-12);
        b.step(0x00060400,0x9a,level.code_selector,0x0500,wait);
        check(b.cs()==level.code_selector && uint16_t(b.d.segs_o>>32)==level.stack_selector &&
              b.cache_base(1)==level.code_base && b.cache_base(2)==level.stack_base &&
              b.reg(4)==final_sp,
              "CALL gate did not install the selected ring-1/2 CS:SS:SP caches");
        const uint32_t frame=level.stack_base+final_sp;
        check(b.memory[frame+0]==0x05 && b.memory[frame+1]==0x04 &&
              b.memory[frame+2]==0x3b && b.memory[frame+3]==0x00 &&
              b.memory[frame+4]==0x34 && b.memory[frame+5]==0x12 &&
              b.memory[frame+6]==0x78 && b.memory[frame+7]==0x56 &&
              b.memory[frame+8]==0x00 && b.memory[frame+9]==0x01 &&
              b.memory[frame+10]==0x43 && b.memory[frame+11]==0x00,
              "ring-1/2 CALL frame, copied parameters, or old SS:SP link is incorrect");

        const auto tss_pair=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
            return !t.write && t.address==0x00000700+level.tss_offset && t.size==4;
        });
        const auto ss_read=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
            return !t.write && t.address==level.stack_descriptor;
        });
        const auto first_stack_write=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
            return t.write && t.address==level.stack_base+level.initial_sp-2;
        });
        check(tss_pair!=b.data_transfers.end() && ss_read!=b.data_transfers.end() &&
              first_stack_write!=b.data_transfers.end() && tss_pair<ss_read && ss_read<first_stack_write,
              "ring-1/2 CALL did not read the target CPL TSS pair and validate SS before stack writes");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                  return t.write && t.address==level.code_descriptor+5 &&
                         t.value==uint8_t(level.code_access|1);
              }),"ring-1/2 target CS accessed-byte write is missing");

        b.step(level.code_base+0x0500,0xca,0x003b,0x0405,wait);
        check(b.cs()==0x003b && uint16_t(b.d.segs_o>>32)==0x0043 &&
              b.cache_base(1)==0x00060000 && b.cache_base(2)==0x00070000 &&
              b.reg(4)==0x0104,
              "outer RETF did not restore the ring-3 caller from ring 1/2");
        b.step(0x00060405,0x90,0x003b,0x0406,wait);
        check(!b.d.halted_o && b.d.ip_o==0x0406,
              "ring-1/2 CALL-gate return missed the exact ring-3 successor");
        ++executions;
    }
    check(executions==4,"ring-1/2 CALL-gate coverage missed a privilege or READY mode");
    std::cout<<"PASS: ring-3 CALL gates select SP1:SS1 and SP2:SS2, validate each new stack, copy parameters, and return exactly in both READY modes\n";
}

static void protected_call_gate_conforming_target() {
    using namespace protected_mode_fixture;
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00,             // 0200 MOV AX, ring-0 SS
        0x8e,0xd0,                   // 0203 MOV SS,AX
        0xbc,0x80,0x00,             // 0205 MOV SP,0080
        0xb8,0x58,0x00,             // 0208 MOV AX, ring-0 TSS
        0x0f,0x00,0xd8,             // 020B LTR AX
        0xcf,                       // 020E IRET to outer privilege
        0xf4
    };
    const uint8_t ring3_program[]={
        0x9a,0x00,0x00,0x6b,0x00,  // 0400 CALL through DPL-3 gate
        0x90
    };
    const uint8_t ring3_cs[]={0xff,0x0f,0x00,0x00,0x06,0xfa,0x00,0x00};
    const uint8_t ring3_ss[]={0xff,0x01,0x00,0x00,0x07,0xf2,0x00,0x00};
    const uint8_t tss_descriptor[]={0x2b,0x00,0x00,0x07,0x00,0x81,0x00,0x00};
    unsigned executions=0;
    for (bool wait:{false,true}) {
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x40]=0x6f; b.memory[0x41]=0x00;
        b.put(kGdtBase+0x38,{ring3_cs[0],ring3_cs[1],ring3_cs[2],ring3_cs[3],
                              ring3_cs[4],ring3_cs[5],ring3_cs[6],ring3_cs[7]});
        b.put(kGdtBase+0x40,{ring3_ss[0],ring3_ss[1],ring3_ss[2],ring3_ss[3],
                              ring3_ss[4],ring3_ss[5],ring3_ss[6],ring3_ss[7]});
        b.put(kGdtBase+0x48,{0xff,0x0f,0x00,0x40,0x08,0xbe,0x00,0x00});
        b.put(kGdtBase+0x58,{tss_descriptor[0],tss_descriptor[1],tss_descriptor[2],tss_descriptor[3],
                              tss_descriptor[4],tss_descriptor[5],tss_descriptor[6],tss_descriptor[7]});
        b.put(kGdtBase+0x68,{0x00,0x05,0x49,0x00,0x02,0xe4,0x00,0x00});
        b.put(0x00000702,{0x00,0x01,0x28,0x00});
        b.put(0x00060400,{ring3_program[0],ring3_program[1],ring3_program[2],
                           ring3_program[3],ring3_program[4],ring3_program[5]});
        b.put(0x00084000+0x0500,{0xcb}); // RETF
        b.put(kStackBase+0x0080,{0x00,0x04,0x3b,0x00,0x02,0x02,
                                  0x00,0x01,0x43,0x00});
        b.put(0x00070100,{0x34,0x12,0x78,0x56});

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
        b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x020e,wait);
        b.step(kCodeBase+0x020e,0xcf,0x003b,0x0400,wait);
        check(b.cs()==0x003b && uint16_t(b.d.segs_o>>32)==0x0043 && b.reg(4)==0x0100,
              "outer IRET did not reach the ring-3 conforming-gate caller");

        b.data_transfers.clear();
        b.step(0x00060400,0x9a,0x004b,0x0500,wait);
        check(b.cs()==0x004b && uint16_t(b.d.segs_o>>32)==0x0043 && b.reg(4)==0x00fc &&
              b.cache_base(1)==0x00084000 && b.cache_base(2)==0x00070000,
              "conforming gate target changed CPL or selected a different stack");
        check(b.memory[0x000700fc]==0x05 && b.memory[0x000700fd]==0x04 &&
              b.memory[0x000700fe]==0x3b && b.memory[0x000700ff]==0x00,
              "conforming call gate did not push the normal same-level return link");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return (!t.write && t.address>=0x00000700 && t.address<0x00000710) ||
                         (t.write && t.address>=0x00084000);
              }),"conforming call gate read a TSS pair or wrote a new-level stack");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && t.address==0x00070100;
              }),"same-level conforming call gate copied inter-level parameters");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return t.write && t.address==0x0000034d && t.value==0xbf;
              }),"conforming target did not perform its accessed-byte write");

        b.step(0x00084500,0xcb,0x003b,0x0405,wait);
        check(b.cs()==0x003b && uint16_t(b.d.segs_o>>32)==0x0043 && b.reg(4)==0x0100,
              "same-level RETF from conforming code did not restore ring-3 CS:SS:SP");
        b.step(0x00060405,0x90,0x003b,0x0406,wait);
        check(!b.d.halted_o && b.d.ip_o==0x0406,
              "conforming call-gate return missed the exact ring-3 successor");
        ++executions;
    }
    check(executions==2,"conforming target test did not cover both READY modes");
    std::cout<<"PASS: conforming DPL-1 CALL-gate targets preserve CPL 3 and caller stack, skip TSS/parameter copying, and return exactly in both READY modes\n";
}

static void protected_call_gate_outer_return_faults() {
    using namespace protected_mode_fixture;
    struct FaultCase {
        const char* name;
        uint16_t return_ip;
        uint16_t return_cs;
        uint16_t return_ss;
        uint8_t vector;
        uint16_t error_code;
        bool cs_descriptor_read;
        bool ss_descriptor_read;
        uint16_t mutate_selector;
        uint8_t mutate_access;
    };
    const FaultCase cases[]={
        {"null CS",0x0405,0x0000,0x0043,13,0x0000,false,false,0,0},
        {"CS outside GDT",0x0405,0x00a0,0x0043,13,0x00a0,false,false,0,0},
        {"data CS",0x0405,0x0013,0x0043,13,0x0010,true,false,0,0},
        {"CS DPL mismatch",0x0405,0x003b,0x0043,13,0x0038,true,false,0x0038,0xda},
        {"non-present CS",0x0405,0x009b,0x0043,11,0x0098,true,false,0,0},
        {"null SS",0x0405,0x003b,0x0000,13,0x0000,true,false,0,0},
        {"SS outside GDT",0x0405,0x003b,0x00a0,13,0x00a0,true,false,0,0},
        {"code SS",0x0405,0x003b,0x009b,13,0x0098,true,true,0,0},
        {"SS RPL mismatch",0x0405,0x003b,0x0028,13,0x0028,true,true,0,0},
        {"SS DPL mismatch",0x0405,0x003b,0x004b,13,0x0048,true,true,0x0048,0xd2},
        {"non-present SS",0x0405,0x003b,0x004b,12,0x0048,true,true,0x0048,0x72},
        {"invalid SS precedes bad return IP",0x1000,0x003b,0x0028,13,0x0028,true,true,0,0},
        {"bad return IP after valid SS",0x1000,0x003b,0x0043,13,0x0000,true,true,0,0}
    };
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00,             // 0200 MOV AX, ring-0 SS
        0x8e,0xd0,                   // 0203 MOV SS,AX
        0xbc,0x80,0x00,             // 0205 MOV SP,0080
        0xb8,0x58,0x00,             // 0208 MOV AX, ring-0 TSS
        0x0f,0x00,0xd8,             // 020B LTR AX
        0xcf,                       // 020E IRET to outer privilege
        0xf4
    };
    const uint8_t ring3_program[]={0x9a,0x00,0x00,0x6b,0x00,0xf4};
    const uint8_t ring3_cs[]={0xff,0x0f,0x00,0x00,0x06,0xfa,0x00,0x00};
    const uint8_t ring3_ss[]={0xff,0x01,0x00,0x00,0x07,0xf2,0x00,0x00};
    const uint8_t tss[]={0x2b,0x00,0x00,0x07,0x00,0x81,0x00,0x00};
    unsigned executions=0;
    for (bool wait:{false,true}) for (const auto& test:cases) {
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x41]=0x00; b.memory[0x40]=0x9f; // Include TSS, gate and return-CS test descriptor.
        b.put(kGdtBase+0x38,{ring3_cs[0],ring3_cs[1],ring3_cs[2],ring3_cs[3],
                              ring3_cs[4],ring3_cs[5],ring3_cs[6],ring3_cs[7]});
        b.put(kGdtBase+0x40,{ring3_ss[0],ring3_ss[1],ring3_ss[2],ring3_ss[3],
                              ring3_ss[4],ring3_ss[5],ring3_ss[6],ring3_ss[7]});
        b.put(kGdtBase+0x48,{0xff,0x0f,0x00,0x00,0x07,0x72,0x00,0x00}); // Absent writable DPL-3 stack.
        b.put(kGdtBase+0x58,{tss[0],tss[1],tss[2],tss[3],tss[4],tss[5],tss[6],tss[7]});
        b.put(kGdtBase+0x68,{0x00,0x05,0x08,0x00,0x00,0xe4,0x00,0x00});
        b.put(0x00000702,{0x00,0x01,0x28,0x00}); // TSS base=0700; SP0=0100, SS0=0028.
        b.put(0x00060000+0x0400,{ring3_program[0],ring3_program[1],ring3_program[2],
                                  ring3_program[3],ring3_program[4],ring3_program[5]});
        b.put(kCodeBase+0x0500,{0xcb});
        b.put(kGdtBase+0x98,{0xff,0x0f,0x00,0x00,0x06,0x7a,0x00,0x00}); // Non-present DPL-3 code.
        b.put(kIdtBase+12*8,{0x00,0x03,0x30,0x00,0x00,0x86,0x00,0x00}); // Same-level #SS handler.
        b.put(kStackBase+0x0080,{0x00,0x04,0x3b,0x00,0x02,0x02,
                                  0x00,0x01,0x43,0x00});

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
        b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x020e,wait);
        b.step(kCodeBase+0x020e,0xcf,0x003b,0x0400,wait);
        b.step(0x00060400,0x9a,kCodeSelector,0x0500,wait);
        check(b.cs()==kCodeSelector && uint16_t(b.d.segs_o>>32)==kSsSelector && b.reg(4)==0x00f8,
              "outer RETF fault fixture did not reach the inner ring-0 call frame");

        // Corrupt only the architectural return frame after reaching it through
        // the real gate path; CPL, caches and current SS:SP remain reachable.
        b.put(kStackBase+0x00f8,{uint8_t(test.return_ip),uint8_t(test.return_ip>>8),
                                  uint8_t(test.return_cs),uint8_t(test.return_cs>>8),
                                  0x00,0x01,uint8_t(test.return_ss),uint8_t(test.return_ss>>8)});
        if (test.mutate_selector) b.memory[kGdtBase+(test.mutate_selector&0xfff8)+5]=test.mutate_access;
        const uint16_t saved_flags=b.d.flags_o;
        const unsigned retired_before=b.retired;
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<30000 && !b.d.event_o && !b.d.fault_o;++cycle) b.tick(wait);
        if (std::string(test.name)=="non-present SS" &&
            !(b.d.event_o && !b.d.fault_o && b.d.event_packet_valid_o &&
              b.d.event_packet_protected_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_restartable_o && b.d.event_vector_o==test.vector &&
              b.d.event_packet_error_code_o==test.error_code)) {
            std::cerr<<"RETF SS diagnostic: event="<<unsigned(b.d.event_o)
                     <<" fault="<<unsigned(b.d.fault_o)
                     <<" vector="<<unsigned(b.d.event_vector_o)
                     <<" packet="<<unsigned(b.d.event_packet_valid_o)
                     <<" error-valid="<<unsigned(b.d.event_packet_error_valid_o)
                     <<" error="<<std::hex<<b.d.event_packet_error_code_o
                     <<" SS descriptor access="<<unsigned(b.memory[kGdtBase+0x4d])
                     <<" fault-code="<<unsigned(b.d.fault_code_o)<<std::dec<<'\n';
            for (const auto& transfer:b.data_transfers)
                if (transfer.address>=kGdtBase+0x48 && transfer.address<kGdtBase+0x50)
                    std::cerr<<"SS descriptor transfer "<<(transfer.write?"W":"R")<<' '
                             <<std::hex<<transfer.address<<" = "<<unsigned(transfer.value)<<std::dec<<'\n';
        }
        check(b.d.event_o && !b.d.fault_o && b.d.event_packet_valid_o &&
              b.d.event_packet_protected_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_restartable_o && b.d.event_vector_o==test.vector &&
              b.d.event_packet_error_code_o==test.error_code &&
              b.d.event_packet_saved_cs_o==kCodeSelector &&
              b.d.event_packet_saved_ip_o==0x0500 &&
              b.d.event_packet_saved_flags_o==saved_flags &&
              b.d.event_packet_saved_sp_o==0x00f8 &&
              b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp &&
              uint16_t(b.d.segs_o>>32)==kSsSelector && b.cache_base(2)==kStackBase &&
              b.reg(4)==0x00f0 && b.retired==retired_before,
              (std::string("outer RETF ")+test.name+" did not deliver its exact restartable fault").c_str());

        const uint32_t cs_address=kGdtBase+(test.return_cs&0xfff8);
        const uint32_t ss_address=kGdtBase+(test.return_ss&0xfff8);
        const auto descriptor_read_count=[&](uint32_t address) {
            return std::count_if(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                return !t.write && !t.io && t.address>=address && t.address<address+8;
            });
        };
        check(descriptor_read_count(cs_address)==(test.cs_descriptor_read ? 8 : 0),
              (std::string("outer RETF ")+test.name+" read the return-CS descriptor incorrectly").c_str());
        const int actual_ss_reads=descriptor_read_count(ss_address);
        check(actual_ss_reads==(test.ss_descriptor_read ? 8 : 0),
              (std::string("outer RETF ")+test.name+" read the return-SS descriptor incorrectly ("+
               std::to_string(actual_ss_reads)+" bytes)").c_str());
        if (test.ss_descriptor_read) {
            const auto cs_read=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                return !t.write && t.address>=cs_address && t.address<cs_address+8;
            });
            const auto ss_read=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                return !t.write && t.address>=ss_address && t.address<ss_address+8;
            });
            check(cs_read<ss_read,"outer RETF read the saved SS descriptor before validating return CS");
        }

        const uint8_t expected_values[]={
            uint8_t(saved_flags),uint8_t(saved_flags>>8),uint8_t(kCodeSelector),uint8_t(kCodeSelector>>8),
            0x00,0x05,uint8_t(test.error_code),uint8_t(test.error_code>>8)
        };
        const uint32_t expected_addresses[]={
            kStackBase+0x00f6,kStackBase+0x00f7,kStackBase+0x00f4,kStackBase+0x00f5,
            kStackBase+0x00f2,kStackBase+0x00f3,kStackBase+0x00f0,kStackBase+0x00f1
        };
        std::vector<Bench::Transfer> exception_writes;
        for (const auto& transfer:b.data_transfers)
            if (transfer.write && transfer.address>=kStackBase+0x00f0 && transfer.address<kStackBase+0x00f8)
                exception_writes.push_back(transfer);
        check(exception_writes.size()==8,(std::string("outer RETF ")+test.name+" wrote an incomplete exception frame").c_str());
        for (unsigned i=0;i<8;++i)
            check(exception_writes[i].address==expected_addresses[i] && exception_writes[i].value==expected_values[i],
                  (std::string("outer RETF ")+test.name+" exception frame byte order/value mismatch").c_str());
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return t.write && t.address>=kStackBase+0x00f8 && t.address<kStackBase+0x0100;
              }),"outer RETF fault modified the saved return frame instead of only pushing its exception frame");
        const uint8_t saved_frame[]={uint8_t(test.return_ip),uint8_t(test.return_ip>>8),
            uint8_t(test.return_cs),uint8_t(test.return_cs>>8),0x00,0x01,
            uint8_t(test.return_ss),uint8_t(test.return_ss>>8)};
        for (unsigned i=0;i<8;++i)
            check(b.memory.at(kStackBase+0x00f8+i)==saved_frame[i],
                  (std::string("outer RETF ")+test.name+" changed the rejected return frame").c_str());
        ++executions;
    }
    check(executions==26,"outer RETF fault cases did not cover every descriptor failure and READY mode");

    {
    unsigned recoveries=0;
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00,0x8e,0xd0,0xbc,0x80,0x00,
        0xb8,0x58,0x00,0x0f,0x00,0xd8,0xcf,0xf4
    };
    const uint8_t ring3_program[]={0x9a,0x00,0x00,0x6b,0x00,0xf4};
    const uint8_t ring3_cs[]={0xff,0x0f,0x00,0x00,0x06,0xfa,0x00,0x00};
    const uint8_t ring3_ss[]={0xff,0x01,0x00,0x00,0x07,0xf2,0x00,0x00};
    const uint8_t tss[]={0x2b,0x00,0x00,0x07,0x00,0x81,0x00,0x00};
    const uint8_t repair_handler[]={
        0x83,0xc4,0x02,             // discard #GP error word
        0x89,0xe5,                   // MOV BP,SP
        0xc7,0x46,0x0c,0x43,0x00,   // repair saved outer SS at SS:[BP+0C]
        0xcf                         // IRET to retry RETF
    };
    for (bool wait:{false,true}) {
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x41]=0x00; b.memory[0x40]=0x6f;
        b.put(kGdtBase+0x38,{ring3_cs[0],ring3_cs[1],ring3_cs[2],ring3_cs[3],
                              ring3_cs[4],ring3_cs[5],ring3_cs[6],ring3_cs[7]});
        b.put(kGdtBase+0x40,{ring3_ss[0],ring3_ss[1],ring3_ss[2],ring3_ss[3],
                              ring3_ss[4],ring3_ss[5],ring3_ss[6],ring3_ss[7]});
        b.put(kGdtBase+0x58,{tss[0],tss[1],tss[2],tss[3],tss[4],tss[5],tss[6],tss[7]});
        b.put(kGdtBase+0x68,{0x00,0x05,0x08,0x00,0x00,0xe4,0x00,0x00});
        b.put(0x00000702,{0x00,0x01,0x28,0x00});
        b.put(0x00060000+0x0400,{ring3_program[0],ring3_program[1],ring3_program[2],
                                  ring3_program[3],ring3_program[4],ring3_program[5]});
        b.put(kCodeBase+0x0500,{0xcb});
        b.put(kHandlerBase+kHandlerIp,{repair_handler[0],repair_handler[1],repair_handler[2],
                                        repair_handler[3],repair_handler[4],repair_handler[5],
                                        repair_handler[6],repair_handler[7],repair_handler[8],
                                        repair_handler[9],repair_handler[10]});
        b.put(kStackBase+0x0080,{0x00,0x04,0x3b,0x00,0x02,0x02,
                                  0x00,0x01,0x43,0x00});
        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
        b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x020e,wait);
        b.step(kCodeBase+0x020e,0xcf,0x003b,0x0400,wait);
        b.step(0x00060400,0x9a,kCodeSelector,0x0500,wait);
        b.put(kStackBase+0x00f8,{0x05,0x04,0x3b,0x00,0x00,0x01,0x28,0x00});
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<30000 && !b.d.event_o && !b.d.fault_o;++cycle) b.tick(wait);
        check(b.d.event_o && !b.d.fault_o && b.d.event_vector_o==13 &&
              b.d.event_packet_error_code_o==0x0028 && b.d.event_packet_saved_ip_o==0x0500 &&
              b.d.event_packet_saved_sp_o==0x00f8 && b.cs()==kHandlerSelector &&
              b.d.ip_o==kHandlerIp && b.reg(4)==0x00f0,
              "repairable outer RETF SS fault did not reach the ring-0 #GP handler");
        check(b.memory[kStackBase+0x00fe]==0x28 && b.memory[kStackBase+0x00ff]==0x00,
              "outer return SS changed before the #GP handler repaired it");
        b.step(kHandlerBase+kHandlerIp,0x83,kHandlerSelector,kHandlerIp+3,wait);
        b.step(kHandlerBase+kHandlerIp+3,0x89,kHandlerSelector,kHandlerIp+5,wait);
        b.step(kHandlerBase+kHandlerIp+5,0xc7,kHandlerSelector,kHandlerIp+10,wait);
        check(b.memory[kStackBase+0x00fe]==0x43 && b.memory[kStackBase+0x00ff]==0x00,
              "#GP handler did not repair the saved outer SS selector");
        b.step(kHandlerBase+kHandlerIp+10,0xcf,kCodeSelector,0x0500,wait);
        check(b.cs()==kCodeSelector && uint16_t(b.d.segs_o>>32)==kSsSelector && b.reg(4)==0x00f8,
              "same-level IRET did not restore the inner RETF retry frame");
        b.step(kCodeBase+0x0500,0xcb,0x003b,0x0405,wait);
        check(b.cs()==0x003b && uint16_t(b.d.segs_o>>32)==0x0043 && b.reg(4)==0x0100 &&
              b.cache_base(1)==0x00060000 && b.cache_base(2)==0x00070000,
              "repaired outer RETF did not resume ring 3 with the exact saved SS:SP");
        b.memory[0x00060405]=0x90;
        b.step(0x00060405,0x90,0x003b,0x0406,wait);
        check(!b.d.halted_o && b.d.ip_o==0x0406,
              "repaired outer RETF did not execute the exact unprivileged successor");
        ++recoveries;
    }
    check(recoveries==2,"outer RETF handler repair did not cover both READY modes");
    }

    {
    unsigned precheck_recoveries=0;
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00,0x8e,0xd0,0xbc,0x80,0x00,
        0xb8,0x58,0x00,0x0f,0x00,0xd8,0xcf,0xf4
    };
    const uint8_t narrow_stack_retf[]={
        0xb8,0x70,0x00,             // 0500 MOV AX, narrow ring-0 SS
        0x8e,0xd0,                   // 0503 MOV SS,AX
        0xcb,                       // 0505 RETF; outer frame-span check faults
        0xf4
    };
    const uint8_t ring3_program[]={0x9a,0x00,0x00,0x6b,0x00,0xf4};
    const uint8_t ring3_cs[]={0xff,0x0f,0x00,0x00,0x06,0xfa,0x00,0x00};
    const uint8_t ring3_ss[]={0xff,0x01,0x00,0x00,0x07,0xf2,0x00,0x00};
    const uint8_t tss[]={0x2b,0x00,0x00,0x07,0x00,0x81,0x00,0x00};
    const uint8_t repair_handler[]={
        0x83,0xc4,0x02,             // discard #SS error word
        0xb8,0x28,0x00,             // MOV AX, wide ring-0 SS
        0x8e,0xd0,                   // MOV SS,AX
        0xcf                         // IRET to retry RETF
    };
    for (bool wait:{false,true}) {
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x40]=0x9f; b.memory[0x41]=0x00;
        b.put(kGdtBase+0x38,{ring3_cs[0],ring3_cs[1],ring3_cs[2],ring3_cs[3],
                              ring3_cs[4],ring3_cs[5],ring3_cs[6],ring3_cs[7]});
        b.put(kGdtBase+0x40,{ring3_ss[0],ring3_ss[1],ring3_ss[2],ring3_ss[3],
                              ring3_ss[4],ring3_ss[5],ring3_ss[6],ring3_ss[7]});
        b.put(kGdtBase+0x58,{tss[0],tss[1],tss[2],tss[3],tss[4],tss[5],tss[6],tss[7]});
        b.put(kGdtBase+0x68,{0x00,0x05,0x08,0x00,0x00,0xe4,0x00,0x00});
        b.put(kGdtBase+0x70,{0xfb,0x00,0x00,0x00,0x05,0x92,0x00,0x00}); // Same base; limit FB.
        b.put(0x00000702,{0x00,0x01,0x28,0x00});
        b.put(kIdtBase+12*8,{0x00,0x03,0x30,0x00,0x00,0x86,0x00,0x00}); // Same-level #SS handler.
        b.put(0x00060000+0x0400,{ring3_program[0],ring3_program[1],ring3_program[2],
                                  ring3_program[3],ring3_program[4],ring3_program[5]});
        b.put(kCodeBase+0x0500,{narrow_stack_retf[0],narrow_stack_retf[1],narrow_stack_retf[2],
                                  narrow_stack_retf[3],narrow_stack_retf[4],narrow_stack_retf[5],
                                  narrow_stack_retf[6]});
        b.put(kHandlerBase+kHandlerIp,{repair_handler[0],repair_handler[1],repair_handler[2],
                                        repair_handler[3],repair_handler[4],repair_handler[5],
                                        repair_handler[6],repair_handler[7],repair_handler[8]});
        b.put(kStackBase+0x0080,{0x00,0x04,0x3b,0x00,0x02,0x02,
                                  0x00,0x01,0x43,0x00});

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
        b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x020e,wait);
        b.step(kCodeBase+0x020e,0xcf,0x003b,0x0400,wait);
        b.step(0x00060400,0x9a,kCodeSelector,0x0500,wait);
        check(b.cs()==kCodeSelector && uint16_t(b.d.segs_o>>32)==kSsSelector && b.reg(4)==0x00f8,
              "outer RETF span-fault fixture did not reach the ring-0 call frame");

        const uint16_t saved_flags=b.d.flags_o;
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<30000 && !b.d.event_o && !b.d.fault_o;++cycle) b.tick(wait);
        if (!(b.d.event_o && !b.d.fault_o && b.d.event_packet_valid_o &&
              b.d.event_packet_protected_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_restartable_o && b.d.event_vector_o==12 &&
              b.d.event_packet_error_code_o==0 && b.d.event_packet_saved_ip_o==0x0505 &&
              b.d.event_packet_saved_cs_o==kCodeSelector &&
              b.d.event_packet_saved_flags_o==saved_flags && b.d.event_packet_saved_sp_o==0x00f8 &&
              b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp &&
              uint16_t(b.d.segs_o>>32)==0x0070 && b.cache_base(2)==kStackBase && b.reg(4)==0x00f0))
            std::cerr<<"outer RETF span diagnostic: event="<<unsigned(b.d.event_o)
                     <<" fault="<<unsigned(b.d.fault_o)<<" vector="<<unsigned(b.d.event_vector_o)
                     <<" packet="<<unsigned(b.d.event_packet_valid_o)
                     <<" error-valid="<<unsigned(b.d.event_packet_error_valid_o)
                     <<" error="<<std::hex<<b.d.event_packet_error_code_o
                     <<" saved="<<b.d.event_packet_saved_cs_o<<":"<<b.d.event_packet_saved_ip_o
                     <<" saved-SP="<<b.d.event_packet_saved_sp_o
                     <<" live="<<b.cs()<<":"<<b.d.ip_o
                     <<" SS:SP="<<uint16_t(b.d.segs_o>>32)<<":"<<b.reg(4)
                     <<" flags="<<b.d.event_packet_saved_flags_o<<std::dec<<'\n';
        check(b.d.event_o && !b.d.fault_o && b.d.event_packet_valid_o &&
              b.d.event_packet_protected_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_restartable_o && b.d.event_vector_o==12 &&
              b.d.event_packet_error_code_o==0 && b.d.event_packet_saved_ip_o==0x0505 &&
              b.d.event_packet_saved_cs_o==kCodeSelector &&
              b.d.event_packet_saved_flags_o==saved_flags && b.d.event_packet_saved_sp_o==0x00f8 &&
              b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp &&
              uint16_t(b.d.segs_o>>32)==0x0070 && b.cache_base(2)==kStackBase && b.reg(4)==0x00f0,
              "outer RETF span precheck did not deliver an exact restartable #SS(0)");
        const uint8_t saved_call_frame[]={0x05,0x04,0x3b,0x00,0x00,0x01,0x43,0x00};
        for (unsigned i=0;i<8;++i)
            check(b.memory.at(kStackBase+0x00f8+i)==saved_call_frame[i],
              "outer RETF span fault changed the saved return frame");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return (t.write && t.address>=kStackBase+0x00f8 && t.address<kStackBase+0x0100) ||
                         (!t.write && t.address>=kStackBase+0x00fc && t.address<kStackBase+0x0100);
              }),"outer RETF span precheck accessed bytes beyond the current SS limit");
        const uint8_t exception_values[]={
            uint8_t(saved_flags),uint8_t(saved_flags>>8),uint8_t(kCodeSelector),uint8_t(kCodeSelector>>8),
            0x05,0x05,0x00,0x00
        };
        const uint32_t exception_addresses[]={
            kStackBase+0x00f6,kStackBase+0x00f7,kStackBase+0x00f4,kStackBase+0x00f5,
            kStackBase+0x00f2,kStackBase+0x00f3,kStackBase+0x00f0,kStackBase+0x00f1
        };
        std::vector<Bench::Transfer> exception_writes;
        for (const auto& transfer:b.data_transfers)
            if (transfer.write && transfer.address>=kStackBase+0x00f0 && transfer.address<kStackBase+0x00f8)
                exception_writes.push_back(transfer);
        check(exception_writes.size()==8,"outer RETF span fault wrote an incomplete #SS frame");
        for (unsigned i=0;i<8;++i)
            check(exception_writes[i].address==exception_addresses[i] && exception_writes[i].value==exception_values[i],
                  "outer RETF span fault wrote an incorrect #SS frame");
        b.step(kHandlerBase+kHandlerIp,0x83,kHandlerSelector,kHandlerIp+3,wait);
        b.step(kHandlerBase+kHandlerIp+3,0xb8,kHandlerSelector,kHandlerIp+6,wait);
        b.step(kHandlerBase+kHandlerIp+6,0x8e,kHandlerSelector,kHandlerIp+8,wait);
        check(uint16_t(b.d.segs_o>>32)==kSsSelector && b.reg(4)==0x00f2,
              "#SS handler did not widen SS before retrying outer RETF");
        b.step(kHandlerBase+kHandlerIp+8,0xcf,kCodeSelector,0x0505,wait);
        check(b.cs()==kCodeSelector && uint16_t(b.d.segs_o>>32)==kSsSelector && b.reg(4)==0x00f8,
              "same-level IRET did not restore the exact outer RETF retry state");
        b.step(kCodeBase+0x0505,0xcb,0x003b,0x0405,wait);
        check(b.cs()==0x003b && uint16_t(b.d.segs_o>>32)==0x0043 && b.reg(4)==0x0100,
              "repaired outer RETF span did not restore the exact caller SS:SP");
        b.memory[0x00060405]=0x90;
        b.step(0x00060405,0x90,0x003b,0x0406,wait);
        check(!b.d.halted_o && b.d.ip_o==0x0406,
              "repaired outer RETF span did not execute the exact unprivileged successor");
        ++precheck_recoveries;
    }
    check(precheck_recoveries==2,"outer RETF span-fault recovery did not cover both READY modes");
    }
    std::cout<<"PASS: outer RETF CS/SS and span faults preserve the inner frame, deliver exact restartable exception packets, check SS before invalid IP, and recover by handler repair plus IRET in both READY modes\n";
}

static void protected_call_gate_ldt() {
    using namespace protected_mode_fixture;
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00,             // 0200 MOV AX, ring-0 SS
        0x8e,0xd0,                   // 0203 MOV SS,AX
        0xbc,0x80,0x00,             // 0205 MOV SP,0080
        0xb8,0x38,0x00,             // 0208 MOV AX, LDT descriptor selector
        0x0f,0x00,0xd0,             // 020B LLDT AX
        0xb8,0x40,0x00,             // 020E MOV AX, TSS selector
        0x0f,0x00,0xd8,             // 0211 LTR AX
        0xcf,                       // 0214 IRET to LDT-backed ring-3 CS:SS
        0xf4
    };
    const uint8_t ring3_program[]={
        0x9a,0x00,0x00,0x1f,0x00,  // 0400 CALL through LDT gate selector 001F
        0xf4
    };
    const uint8_t ldt_code[]={0xff,0x0f,0x00,0x00,0x06,0xfa,0x00,0x00};
    const uint8_t ldt_stack[]={0xff,0x00,0x00,0x00,0x07,0xf2,0x00,0x00};
    const uint8_t ldt_gate[]={0x00,0x05,0x08,0x00,0x00,0xe4,0x00,0x00};
    unsigned executions=0;
    for (bool wait:{false,true}) {
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x40]=0x47; b.memory[0x41]=0x00; // Include the LDT and TSS descriptors.
        b.memory[kGdtBase+0x38]=0x1f;             // LDT entries 0 through 3, including the gate.
        b.put(0x00000608,{ldt_code[0],ldt_code[1],ldt_code[2],ldt_code[3],
                           ldt_code[4],ldt_code[5],ldt_code[6],ldt_code[7]});
        b.put(0x00000610,{ldt_stack[0],ldt_stack[1],ldt_stack[2],ldt_stack[3],
                           ldt_stack[4],ldt_stack[5],ldt_stack[6],ldt_stack[7]});
        b.put(0x00000618,{ldt_gate[0],ldt_gate[1],ldt_gate[2],ldt_gate[3],
                           ldt_gate[4],ldt_gate[5],ldt_gate[6],ldt_gate[7]});
        b.put(0x00000702,{0x00,0x01,0x28,0x00}); // TSS base=0700; SP0=0100, SS0=0028.
        b.put(0x00060400,{ring3_program[0],ring3_program[1],ring3_program[2],
                           ring3_program[3],ring3_program[4],ring3_program[5]});
        b.put(kCodeBase+0x0500,{0xcb});
        b.put(kStackBase+0x0080,{0x00,0x04,0x0f,0x00,0x02,0x02,
                                  0x00,0x01,0x17,0x00});

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
        b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x020e,wait);
        b.step(kCodeBase+0x020e,0xb8,kCodeSelector,0x0211,wait);
        b.step(kCodeBase+0x0211,0x0f,kCodeSelector,0x0214,wait);
        check(b.memory[kGdtBase+0x45]==0x83,"LTR did not mark the fixture TSS busy");
        b.step(kCodeBase+0x0214,0xcf,0x000f,0x0400,wait);
        check(b.cs()==0x000f && uint16_t(b.d.segs_o>>32)==0x0017 &&
              b.cache_base(1)==0x00060000 && b.cache_base(2)==0x00070000 && b.reg(4)==0x0100,
              "outer IRET did not load LDT-backed ring-3 CS and SS caches");

        b.data_transfers.clear();
        b.step(0x00060400,0x9a,kCodeSelector,0x0500,wait);
        check(uint16_t(b.d.segs_o>>32)==kSsSelector && b.reg(4)==0x00f8 &&
              b.cs()==kCodeSelector && b.cache_base(2)==kStackBase,
              "LDT call gate did not switch to the TSS ring-0 stack and target code");
        check(b.memory[kStackBase+0x00f8]==0x05 && b.memory[kStackBase+0x00f9]==0x04 &&
              b.memory[kStackBase+0x00fa]==0x0f && b.memory[kStackBase+0x00fb]==0x00 &&
              b.memory[kStackBase+0x00fc]==0x00 && b.memory[kStackBase+0x00fd]==0x01 &&
              b.memory[kStackBase+0x00fe]==0x17 && b.memory[kStackBase+0x00ff]==0x00,
              "LDT call gate did not preserve the exact outer CS:IP and SS:SP link");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && t.address==0x00000618;
              }) && std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && t.address==kGdtBase+0x08;
              }),"LDT call gate did not read its gate from the LDT and target code from the GDT");
        const auto tss_read=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
            return !t.write && t.address==0x00000702;
        });
        const auto stack_read=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
            return !t.write && t.address==kGdtBase+0x28;
        });
        const auto frame_write=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
            return t.write && t.address==kStackBase+0x00fe;
        });
        check(tss_read<stack_read && stack_read<frame_write,
              "LDT call gate touched the new frame before reading TSS and validating SS0");
        b.step(kCodeBase+0x0500,0xcb,0x000f,0x0405,wait);
        check(b.cs()==0x000f && uint16_t(b.d.segs_o>>32)==0x0017 &&
              b.reg(4)==0x0100 && b.cache_base(1)==0x00060000 && b.cache_base(2)==0x00070000,
              "outer RETF did not restore the LDT-backed ring-3 CS:SS:SP");
        b.memory[0x00060405]=0x90;
        b.step(0x00060405,0x90,0x000f,0x0406,wait);
        check(!b.d.halted_o && b.d.ip_o==0x0406,
              "LDT call-gate return did not resume the ring-3 caller");
        ++executions;
    }
    check(executions==2,"LDT call gate did not cover both READY modes");
    std::cout<<"PASS: protected LDT call gate resolves its GDT code target, switches through TSS, and returns to LDT-backed ring 3 in both READY modes\n";
}

static void place_selector_fixture(Bench& b, const uint8_t* program, std::size_t program_size) {
    using namespace protected_mode_fixture;
    auto place=[&](uint32_t address,const uint8_t* bytes,std::size_t count) {
        for (std::size_t i=0;i<count;++i) b.memory[address+uint32_t(i)]=bytes[i];
    };
    place(kResetVector,kResetJump,sizeof(kResetJump));
    place(kRealCodeBase+0x0100,kRealModeProgram,sizeof(kRealModeProgram));
    place(0x00000040,kGdtrImage,sizeof(kGdtrImage));
    b.memory[0x40]=0x67; // Include GDT entries 7 through 12 used by this fixture.
    place(0x00000046,kIdtrImage,sizeof(kIdtrImage));
    place(kGdtBase,kGdtImage,sizeof(kGdtImage));
    const uint8_t ldt_descriptor[]={0x17,0x00,0x00,0x06,0x00,0x82,0x00,0x00};
    const uint8_t tss_a[]={0x2b,0x00,0x00,0x07,0x00,0x81,0x00,0x00};
    const uint8_t tss_b[]={0x2b,0x00,0x40,0x07,0x00,0x81,0x00,0x00};
    const uint8_t tss_not_present[]={0x2b,0x00,0x20,0x07,0x00,0x01,0x00,0x00};
    const uint8_t tss_busy[]={0x2b,0x00,0x60,0x07,0x00,0x83,0x00,0x00};
    const uint8_t ldt_data[]={0xff,0x00,0x00,0x00,0x06,0x92,0x00,0x00};
    place(kGdtBase+0x38,ldt_descriptor,sizeof(ldt_descriptor));
    place(kGdtBase+0x40,tss_a,sizeof(tss_a));
    place(kGdtBase+0x50,tss_b,sizeof(tss_b));
    place(kGdtBase+0x58,tss_not_present,sizeof(tss_not_present));
    place(kGdtBase+0x60,tss_busy,sizeof(tss_busy));
    place(0x00000608,ldt_data,sizeof(ldt_data));
    const uint8_t gate[]={0x00,0x03,0x30,0x00,0x00,0x86,0x00,0x00};
    place(kIdtBase+11*8,gate,sizeof(gate));
    place(kIdtBase+13*8,gate,sizeof(gate));
    place(kHandlerBase+kHandlerIp,kVector13Handler,sizeof(kVector13Handler));
    place(kCodeBase+0x0200,program,program_size);
}

static void protected_selector_state_execution() {
    using namespace protected_mode_fixture;
    const uint8_t program[]={
        0xb8,0x10,0x00, 0x8e,0xd8,             // 0200 MOV AX,10 / MOV DS,AX
        0xb8,0x38,0x00,                       // 0205 MOV AX, LDT descriptor selector
        0x0f,0x00,0xd0,                       // 0208 LLDT AX
        0x0f,0x00,0x16,0x10,0x00,             // 020B LLDT [0010]
        0x0f,0x00,0xc0,                       // 0210 SLDT AX
        0x0f,0x00,0x06,0x00,0x00,             // 0213 SLDT [0000]
        0xb8,0x40,0x00,                       // 0218 MOV AX, first TSS selector
        0x0f,0x00,0xd8,                       // 021B LTR AX
        0x0f,0x00,0xc8,                       // 021E STR AX
        0x0f,0x00,0x1e,0x12,0x00,             // 0221 LTR [0012]
        0x0f,0x00,0x0e,0x16,0x00,             // 0226 STR [0016]
        0x0f,0x00,0xc8,                       // 022B STR AX
        0xb8,0x0c,0x00, 0x8e,0xd8,             // 022E load DS from LDT
        0xa1,0x04,0x00, 0xf4                 // 0233 read LDT data, HLT
    };
    const uint8_t ldt_payload[]={0x38,0x00,0x50,0x00,0xef,0xbe};
    unsigned executions=0;
    for (bool wait:{false,true}) {
        Bench b;
        place_selector_fixture(b,program,sizeof(program));
        for (std::size_t i=0;i<sizeof(ldt_payload);++i)
            b.memory[kWideDataBase+0x10+uint32_t(i)]=ldt_payload[i];
        b.memory[0x00060004]=0xef; b.memory[0x00060005]=0xbe;
        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.data_transfers.clear();
        const uint16_t unchanged_flags=b.d.flags_o;
        b.step(kCodeBase+0x0205,0xb8,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0x0f,kCodeSelector,0x020b,wait);
        check(b.reg(0)==0x0038,"LLDT register form changed the wrong state");
        b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x0210,wait);
        b.step(kCodeBase+0x0210,0x0f,kCodeSelector,0x0213,wait);
        check(b.reg(0)==0x0038,"SLDT did not return the visible LDTR selector");
        b.step(kCodeBase+0x0213,0x0f,kCodeSelector,0x0218,wait);
        check(b.memory[kWideDataBase]==0x38 && b.memory[kWideDataBase+1]==0,
              "SLDT memory form stored the wrong selector bytes");
        b.step(kCodeBase+0x0218,0xb8,kCodeSelector,0x021b,wait);
        b.step(kCodeBase+0x021b,0x0f,kCodeSelector,0x021e,wait);
        check(b.memory[kGdtBase+0x45]==0x83,
              "LTR did not set the available TSS descriptor busy bit");
        b.step(kCodeBase+0x021e,0x0f,kCodeSelector,0x0221,wait);
        check(b.reg(0)==0x0040,"STR did not return the visible task selector");
        b.step(kCodeBase+0x0221,0x0f,kCodeSelector,0x0226,wait);
        check(b.memory[kGdtBase+0x55]==0x83,
              "LTR memory form did not set the new TSS busy bit");
        b.step(kCodeBase+0x0226,0x0f,kCodeSelector,0x022b,wait);
        check(b.memory[kWideDataBase+0x16]==0x50 && b.memory[kWideDataBase+0x17]==0,
              "STR memory form stored the wrong selector bytes");
        b.step(kCodeBase+0x022b,0x0f,kCodeSelector,0x022e,wait);
        check(b.reg(0)==0x0050,"LTR memory form did not commit the visible TR selector");
        b.step(kCodeBase+0x022e,0xb8,kCodeSelector,0x0231,wait);
        b.step(kCodeBase+0x0231,0x8e,kCodeSelector,0x0233,wait);
        check(uint16_t(b.d.segs_o>>48)==0x000c,"segment load did not select the loaded LDT");
        b.step(kCodeBase+0x0233,0xa1,kCodeSelector,0x0236,wait);
        check(b.reg(0)==0xbeef,"LDT descriptor cache did not route the data read");
        b.step(kCodeBase+0x0236,0xf4,kCodeSelector,0x0237,wait);
        check(b.d.flags_o==unchanged_flags,"selector instructions modified FLAGS");
        check(!wait || b.stalls>0,"selector execution did not exercise READY stalls");

        std::vector<uint32_t> table_reads;
        for (const auto& transfer:b.data_transfers)
            if (!transfer.write && !transfer.io &&
                ((transfer.address>=kGdtBase+0x38 && transfer.address<kGdtBase+0x40) ||
                 (transfer.address>=kGdtBase+0x40 && transfer.address<kGdtBase+0x48) ||
                 (transfer.address>=kGdtBase+0x50 && transfer.address<kGdtBase+0x58) ||
                 (transfer.address>=0x00000608 && transfer.address<0x00000610)))
                table_reads.push_back(transfer.address);
        std::vector<uint32_t> expected_reads;
        for (uint32_t base:{kGdtBase+0x38,kGdtBase+0x38,kGdtBase+0x40,
                            kGdtBase+0x50,0x00000608u})
            for (uint32_t byte=0;byte<8;++byte) expected_reads.push_back(base+byte);
        check(table_reads==expected_reads,
              "selector loads read the wrong GDT/LDT descriptor bytes or order");
        check(b.memory[0x0000060d]==0x93,
              "loading an LDT data descriptor did not set its accessed bit");
        check(b.d.flags_o==unchanged_flags,"selector transfer changed architectural flags");
        ++executions;
    }
    std::cout<<"PASS: "<<executions
             <<" protected SLDT/STR/LLDT/LTR executions, GDT/LDT loads, TSS busy writes and READY stalls\n";
}

static void protected_selector_query_execution() {
    using namespace protected_mode_fixture;
    enum class Query : uint8_t { Verr, Verw, Lar, Lsl };
    struct QueryCase {
        const char* label;
        Query query;
        uint16_t selector;
        uint8_t access;
        uint16_t limit;
        bool success;
        bool descriptor_read;
        bool memory_source;
        bool es_override;
        bool load_ldt;
        bool prior_zf;
    };
    const std::vector<QueryCase> cases={
        {"VERR readable ring-0 data",Query::Verr,0x0010,0x92,0x0002,true,true,false,false,true,false},
        {"VERR writable ring-3 data",Query::Verr,0x0068,0xf2,0x5678,true,true,false,false,true,true},
        {"VERR conforming readable code",Query::Verr,0x008b,0xfe,0xcdef,true,true,false,false,true,false},
        {"VERR execute-only code",Query::Verr,0x0070,0x98,0x7654,false,true,false,false,true,true},
        {"VERR system TSS",Query::Verr,0x0040,0x81,0x002b,false,true,false,false,true,true},
        {"VERR RPL exceeds DPL",Query::Verr,0x0013,0x92,0x0002,false,true,false,false,true,true},
        {"VERR not-present data",Query::Verr,0x0098,0x12,0xabcd,true,true,false,false,true,false},
        {"VERR null selector",Query::Verr,0x0003,0x00,0x0000,false,false,false,false,true,true},
        {"VERR GDT limit",Query::Verr,0x00c8,0x00,0x0000,false,false,false,false,true,true},
        {"VERR memory source with ES override",Query::Verr,0x0010,0x92,0x0002,true,true,true,true,true,false},
        {"VERW writable data",Query::Verw,0x0010,0x92,0x0002,true,true,false,false,true,false},
        {"VERW read-only data",Query::Verw,0x0078,0x90,0x4567,false,true,false,false,true,true},
        {"VERW code segment",Query::Verw,0x0008,0x9a,0x0fff,false,true,false,false,true,true},
        {"VERW RPL exceeds DPL",Query::Verw,0x0013,0x92,0x0002,false,true,false,false,true,true},
        {"VERW not-present writable data",Query::Verw,0x0098,0x12,0xabcd,true,true,false,false,true,false},
        {"VERW memory source",Query::Verw,0x0010,0x92,0x0002,true,true,true,false,true,false},
        {"LAR data access byte",Query::Lar,0x0010,0x93,0x0002,true,true,false,false,true,false},
        {"LAR conforming code access byte",Query::Lar,0x008b,0xfe,0xcdef,true,true,false,false,true,false},
        {"LAR TSS access byte",Query::Lar,0x0040,0x81,0x002b,true,true,false,false,true,false},
        {"LAR LDT access byte",Query::Lar,0x0038,0x82,0x0017,true,true,false,false,true,false},
        {"LAR busy TSS access byte",Query::Lar,0x0060,0x83,0x002b,true,true,false,false,true,false},
        {"LAR call-gate access byte",Query::Lar,0x0090,0x84,0x7777,true,true,false,false,true,false},
        {"LAR task-gate access byte",Query::Lar,0x00a8,0x85,0x0000,true,true,false,false,true,false},
        {"LAR interrupt-gate access byte",Query::Lar,0x00b0,0x86,0x1234,true,true,false,false,true,false},
        {"LAR trap-gate access byte",Query::Lar,0x00b8,0x87,0x5678,true,true,false,false,true,false},
        {"LAR reserved system type",Query::Lar,0x00a0,0x80,0x1111,false,true,false,false,true,true},
        {"LAR not-present access byte",Query::Lar,0x0098,0x12,0xabcd,true,true,false,false,true,false},
        {"LAR memory source",Query::Lar,0x0010,0x93,0x0002,true,true,true,false,true,false},
        {"LAR null selector",Query::Lar,0x0003,0x00,0x0000,false,false,false,false,true,true},
        {"LSL TSS limit",Query::Lsl,0x0040,0x81,0x002b,true,true,false,false,true,false},
        {"LSL LDT descriptor limit",Query::Lsl,0x0038,0x82,0x0017,true,true,false,false,true,false},
        {"LSL busy TSS limit",Query::Lsl,0x0060,0x83,0x002b,true,true,false,false,true,false},
        {"LSL conforming code limit",Query::Lsl,0x008b,0xfe,0xcdef,true,true,false,false,true,false},
        {"LSL call gate excluded",Query::Lsl,0x0090,0x84,0x7777,false,true,false,false,true,true},
        {"LSL reserved system type",Query::Lsl,0x00a0,0x80,0x1111,false,true,false,false,true,true},
        {"LSL LDT data limit",Query::Lsl,0x0014,0x92,0x1357,true,true,false,false,true,false},
        {"LSL LDT entry zero is not a null selector",Query::Lsl,0x0004,0x00,0x0000,false,true,false,false,true,true},
        {"LSL LDT limit boundary",Query::Lsl,0x001c,0x00,0x0000,false,false,false,false,true,true},
        {"LSL null LDTR",Query::Lsl,0x000c,0x00,0x0000,false,false,false,false,false,true},
        {"LSL memory source",Query::Lsl,0x0014,0x92,0x1357,true,true,true,false,true,false},
        {"LSL null selector",Query::Lsl,0x0003,0x00,0x0000,false,false,false,false,true,true},
    };

    auto put_descriptor=[](Bench& b,uint32_t address,uint16_t limit,
                           uint32_t base,uint8_t access) {
        b.memory[address+0]=uint8_t(limit);
        b.memory[address+1]=uint8_t(limit>>8);
        b.memory[address+2]=uint8_t(base);
        b.memory[address+3]=uint8_t(base>>8);
        b.memory[address+4]=uint8_t(base>>16);
        b.memory[address+5]=access;
        b.memory[address+6]=0;
        b.memory[address+7]=0;
    };

    unsigned executions=0;
    for (bool wait:{false,true}) for (const auto& test:cases) {
        try {
            std::vector<uint8_t> program={
                0xb8,0x10,0x00, 0x8e,0xd8,                         // MOV DS,0010
                0xb8,uint8_t(test.load_ldt?0x38:0x00),0x00,
                0x0f,0x00,0xd0,                                   // LLDT AX or null LLDT
                0xb8,0x20,0x00, 0x8e,0xc0,                         // MOV ES,0020
                0xbb,uint8_t(test.selector),uint8_t(test.selector>>8),
                0xb8,0xfe,0xca,                                   // AX sentinel
                0x39,uint8_t(test.prior_zf?0xc0:0xd8)             // CMP AX,AX sets ZF; CMP AX,BX clears it
            };
            std::vector<uint8_t> query_bytes;
            uint8_t second_opcode=0x00;
            switch (test.query) {
                case Query::Verr: second_opcode=0x00; break;
                case Query::Verw: second_opcode=0x00; break;
                case Query::Lar: second_opcode=0x02; break;
                case Query::Lsl: second_opcode=0x03; break;
            }
            if (test.es_override) query_bytes.push_back(0x26);
            query_bytes.push_back(0x0f);
            query_bytes.push_back(second_opcode);
            if (test.memory_source) {
                const uint8_t modrm=test.query==Query::Verr ? 0x26 :
                                    test.query==Query::Verw ? 0x2e : 0x06;
                query_bytes.push_back(modrm);
                query_bytes.push_back(0x20);
                query_bytes.push_back(0x00);
            } else {
                const uint8_t modrm=test.query==Query::Verr ? 0xe3 :
                                    test.query==Query::Verw ? 0xeb : 0xc3;
                query_bytes.push_back(modrm);
            }
            program.insert(program.end(),query_bytes.begin(),query_bytes.end());
            program.push_back(0xf4);

            Bench b;
            b.wait_mode=wait;
            place_selector_fixture(b,program.data(),program.size());
            b.memory[0x40]=0xc7; // GDT entries through offset C7 fit in the table.
            put_descriptor(b,kGdtBase+0x68,0x5678,0x012345,0xf2); // Ring-3 writable data.
            put_descriptor(b,kGdtBase+0x70,0x7654,0x023456,0x98); // Execute-only code.
            put_descriptor(b,kGdtBase+0x78,0x4567,0x034567,0x90); // Read-only data.
            put_descriptor(b,kGdtBase+0x80,0x89ab,0x045678,0xfa); // Ring-3 readable code.
            put_descriptor(b,kGdtBase+0x88,0xcdef,0x056789,0xfe); // Ring-3 conforming/readable code.
            put_descriptor(b,kGdtBase+0x90,0x7777,0x06789a,0x84); // Call gate.
            put_descriptor(b,kGdtBase+0x98,0xabcd,0x0789ab,0x12); // Not-present writable data.
            put_descriptor(b,kGdtBase+0xa0,0x1111,0x089abc,0x80); // Reserved system type.
            put_descriptor(b,kGdtBase+0xa8,0x0000,0x000000,0x85); // Task gate.
            put_descriptor(b,kGdtBase+0xb0,0x1234,0x000000,0x86); // Interrupt gate.
            put_descriptor(b,kGdtBase+0xb8,0x5678,0x000000,0x87); // Trap gate.
            put_descriptor(b,0x00000610,0x1357,0x000000,0x92); // LDT entry selector 0014.
            if (test.memory_source) {
                const uint32_t source_base=test.es_override?kEsDataBase:kWideDataBase;
                b.memory[source_base+0x20]=uint8_t(test.selector);
                b.memory[source_base+0x21]=uint8_t(test.selector>>8);
            }
            protected_mode_boot(b,wait);
            b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
            b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
            b.step(kCodeBase+0x0205,0xb8,kCodeSelector,0x0208,wait);
            b.step(kCodeBase+0x0208,0x0f,kCodeSelector,0x020b,wait);
            b.step(kCodeBase+0x020b,0xb8,kCodeSelector,0x020e,wait);
            b.step(kCodeBase+0x020e,0x8e,kCodeSelector,0x0210,wait);
            b.step(kCodeBase+0x0210,0xbb,kCodeSelector,0x0213,wait);
            b.step(kCodeBase+0x0213,0xb8,kCodeSelector,0x0216,wait);
            b.step(kCodeBase+0x0216,0x39,kCodeSelector,0x0218,wait);

            const uint16_t flags_before=b.d.flags_o;
            const uint16_t ax_before=b.reg(0);
            const uint16_t bx_before=b.reg(3);
            const unsigned retired_before=b.retired;
            const uint16_t query_ip=0x0218;
            const uint16_t next_ip=uint16_t(query_ip+query_bytes.size());
            const uint32_t descriptor_address=(test.selector&4) ?
                0x00000600u+(test.selector&0xfff8u) :
                kGdtBase+(test.selector&0xfff8u);
            const bool null_gdt=((test.selector&0xfffcu)==0 && !(test.selector&4));
            const bool table_bounds=(test.selector&4) ?
                test.load_ldt && uint32_t(test.selector&0xfff8u)+7u<=0x17u :
                uint32_t(test.selector&0xfff8u)+7u<=0xc7u;
            const bool should_read=test.descriptor_read && !null_gdt && table_bounds;
            const uint8_t original_access=should_read?b.memory[descriptor_address+5]:0;
            b.accepted.clear();
            b.data_transfers.clear();
            b.step(kCodeBase+query_ip,0x0f,kCodeSelector,next_ip,wait);
            check(b.retired==retired_before+1,"selector query did not retire exactly once");
            check(!b.d.event_o && !b.d.event_packet_valid_o && !b.d.fault_o,
                  "selector query raised a selector event or diagnostic stop");
            check((b.d.flags_o&0xffbf)==(flags_before&0xffbf),
                  "selector query changed FLAGS other than ZF");
            check(bool(b.d.flags_o&0x0040)==test.success,
                  "selector query returned the wrong ZF result");
            uint16_t expected_ax=ax_before;
            if (test.success && test.query==Query::Lar) expected_ax=uint16_t(test.access)<<8;
            if (test.success && test.query==Query::Lsl) expected_ax=test.limit;
            check(b.reg(0)==expected_ax,"LAR/LSL result or failed-query destination preservation");
            check(b.reg(3)==bx_before,"selector query changed its source register");
            check(b.accepted.size()==query_bytes.size(),"selector query fetched the wrong number of bytes");
            for (std::size_t i=0;i<query_bytes.size();++i)
                check(b.accepted[i]==kCodeBase+query_ip+uint32_t(i),
                      "selector query fetched an unexpected instruction byte");

            std::vector<Bench::Transfer> expected_data;
            if (test.memory_source) {
                const uint32_t source_base=test.es_override?kEsDataBase:kWideDataBase;
                const unsigned source_segment=test.es_override?0:3;
                expected_data.push_back({source_base+0x20,uint8_t(test.selector),false,false,true,
                                         source_segment,0,0x20,2});
                expected_data.push_back({source_base+0x21,uint8_t(test.selector>>8),false,false,true,
                                         source_segment,0,0x21,2});
            }
            if (should_read) {
                for (unsigned i=0;i<8;++i)
                    expected_data.push_back({descriptor_address+i,b.memory[descriptor_address+i],
                                             false,false,false,0,0,i<6?i:i-6,i<6?6u:2u});
            }
            check(b.data_transfers.size()==expected_data.size(),
                  "selector query issued an unexpected descriptor or operand transfer count");
            for (std::size_t i=0;i<expected_data.size();++i) {
                const auto& actual=b.data_transfers[i];
                const auto& expected=expected_data[i];
                check(actual.address==expected.address && actual.value==expected.value &&
                      actual.write==expected.write && actual.io==expected.io &&
                      actual.segmented==expected.segmented && actual.role==expected.role &&
                      actual.kind==expected.kind && actual.offset==expected.offset &&
                      actual.size==expected.size,
                      "selector query issued incorrect operand/descriptor bus traffic");
            }
            check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),
                               [](const auto& transfer){return transfer.write;}),
                  "read-only selector query modified a descriptor or operand");
            if (should_read)
                check(b.memory[descriptor_address+5]==original_access,
                      "selector query modified the descriptor access byte");
            ++executions;
        } catch (const std::exception& error) {
            throw std::runtime_error(std::string("80286 selector query ")+test.label+": "+error.what());
        }
    }
    check(executions==cases.size()*2,"selector query did not cover both READY modes");
    std::cout<<"PASS: "<<executions
             <<" protected VERR/VERW/LAR/LSL cases cover GDT/LDT, type/privilege rules, memory operands and READY stalls\n";
}

static void protected_selector_query_ring3_execution() {
    using namespace protected_mode_fixture;
    enum class Query : uint8_t { Verr, Verw, Lar, Lsl };
    struct QueryCase {
        const char* label;
        Query query;
        uint16_t selector;
        uint8_t access;
        uint16_t limit;
        bool success;
        bool prior_zf;
        bool memory_source=false;
        bool descriptor_read=true;
    };
    const QueryCase cases[]={
        {"VERR CPL3 writable data",Query::Verr,0x006b,0xf2,0x5678,true,false},
        {"VERR CPL3 read-only data",Query::Verr,0x0073,0xf0,0x2468,true,true},
        {"VERR CPL0 data denied at CPL3",Query::Verr,0x0013,0x92,0x0002,false,true},
        {"VERW CPL3 writable data",Query::Verw,0x006b,0xf2,0x5678,true,false},
        {"VERW CPL3 read-only data",Query::Verw,0x0073,0xf0,0x2468,false,true},
        {"LAR CPL3 data access byte",Query::Lar,0x006b,0xf2,0x5678,true,false},
        {"LAR CPL0 data denied at CPL3",Query::Lar,0x0013,0x92,0x0002,false,true},
        {"LSL CPL3 data limit",Query::Lsl,0x006b,0xf2,0x5678,true,false},
        {"LSL CPL0 data denied at CPL3",Query::Lsl,0x0013,0x92,0x0002,false,true},
        {"VERR CPL3 writable memory",Query::Verr,0x006b,0xf2,0x5678,true,false,true},
        {"VERR CPL0 data memory denied at CPL3",Query::Verr,0x0013,0x92,0x0002,false,true,true},
        {"VERW CPL3 writable memory",Query::Verw,0x006b,0xf2,0x5678,true,false,true},
        {"VERW CPL3 read-only memory",Query::Verw,0x0073,0xf0,0x2468,false,true,true},
        {"LAR CPL3 memory access byte",Query::Lar,0x006b,0xf2,0x5678,true,false,true},
        {"LAR CPL0 data memory denied at CPL3",Query::Lar,0x0013,0x92,0x0002,false,true,true},
        {"LSL CPL3 memory limit",Query::Lsl,0x006b,0xf2,0x5678,true,false,true},
        {"LSL CPL0 data memory denied at CPL3",Query::Lsl,0x0013,0x92,0x0002,false,true,true},
        {"VERR CPL3 LDT data",Query::Verr,0x000f,0xf2,0x3456,true,false},
        {"VERW CPL3 LDT data",Query::Verw,0x000f,0xf2,0x3456,true,false},
        {"LAR CPL3 LDT data",Query::Lar,0x000f,0xf2,0x3456,true,false},
        {"LSL CPL3 LDT data",Query::Lsl,0x000f,0xf2,0x3456,true,false},
        {"VERR CPL3 LDT memory",Query::Verr,0x000f,0xf2,0x3456,true,false,true},
        {"VERW CPL3 LDT memory",Query::Verw,0x000f,0xf2,0x3456,true,false,true},
        {"LAR CPL3 LDT memory",Query::Lar,0x000f,0xf2,0x3456,true,false,true},
        {"LSL CPL3 LDT memory",Query::Lsl,0x000f,0xf2,0x3456,true,false,true},
        {"VERR CPL3 conforming code RPL0",Query::Verr,0x0078,0x9e,0x89ab,true,false},
        {"VERR CPL3 conforming code RPL3",Query::Verr,0x007b,0x9e,0x89ab,true,true},
        {"VERR CPL3 conforming code memory",Query::Verr,0x007b,0x9e,0x89ab,true,false,true},
        {"VERW CPL3 conforming code",Query::Verw,0x007b,0x9e,0x89ab,false,true},
        {"VERW CPL3 conforming code memory",Query::Verw,0x007b,0x9e,0x89ab,false,true,true},
        {"LAR CPL3 conforming code RPL0",Query::Lar,0x0078,0x9e,0x89ab,true,false},
        {"LAR CPL3 conforming code memory",Query::Lar,0x007b,0x9e,0x89ab,true,false,true},
        {"LSL CPL3 conforming code RPL0",Query::Lsl,0x0078,0x9e,0x89ab,true,false},
        {"LSL CPL3 conforming code memory",Query::Lsl,0x007b,0x9e,0x89ab,true,false,true},
        {"VERR CPL3 available TSS",Query::Verr,0x0093,0xe1,0x1101,false,false},
        {"VERW CPL3 available TSS",Query::Verw,0x0093,0xe1,0x1101,false,true},
        {"LAR CPL3 available TSS",Query::Lar,0x0093,0xe1,0x1101,true,false},
        {"LSL CPL3 available TSS",Query::Lsl,0x0093,0xe1,0x1101,true,true},
        {"LAR CPL3 LDT descriptor",Query::Lar,0x009b,0xe2,0x1102,true,false},
        {"LSL CPL3 LDT descriptor",Query::Lsl,0x009b,0xe2,0x1102,true,true},
        {"LAR CPL3 busy TSS",Query::Lar,0x00a3,0xe3,0x1103,true,false},
        {"LSL CPL3 busy TSS",Query::Lsl,0x00a3,0xe3,0x1103,true,true},
        {"VERR CPL3 call gate",Query::Verr,0x00ab,0xe4,0x1104,false,false},
        {"VERW CPL3 call gate",Query::Verw,0x00ab,0xe4,0x1104,false,true},
        {"LAR CPL3 call gate",Query::Lar,0x00ab,0xe4,0x1104,true,false},
        {"LSL CPL3 call gate",Query::Lsl,0x00ab,0xe4,0x1104,false,true},
        {"LAR CPL3 task gate",Query::Lar,0x00b3,0xe5,0x1105,true,false},
        {"LSL CPL3 task gate",Query::Lsl,0x00b3,0xe5,0x1105,false,true},
        {"LAR CPL3 interrupt gate",Query::Lar,0x00bb,0xe6,0x1106,true,false},
        {"LSL CPL3 interrupt gate",Query::Lsl,0x00bb,0xe6,0x1106,false,true},
        {"LAR CPL3 trap gate",Query::Lar,0x00c3,0xe7,0x1107,true,false},
        {"LSL CPL3 trap gate",Query::Lsl,0x00c3,0xe7,0x1107,false,true},
        {"VERR CPL3 TSS memory",Query::Verr,0x0093,0xe1,0x1101,false,false,true},
        {"VERW CPL3 TSS memory",Query::Verw,0x0093,0xe1,0x1101,false,true,true},
        {"LAR CPL3 TSS memory",Query::Lar,0x0093,0xe1,0x1101,true,false,true},
        {"LSL CPL3 TSS memory",Query::Lsl,0x0093,0xe1,0x1101,true,true,true},
        {"LAR CPL3 call gate memory",Query::Lar,0x00ab,0xe4,0x1104,true,false,true},
        {"LSL CPL3 call gate memory",Query::Lsl,0x00ab,0xe4,0x1104,false,true,true},
        {"LAR CPL3 DPL0 TSS denied",Query::Lar,0x00c8,0x81,0x2222,false,true},
        {"LSL CPL3 DPL0 TSS denied",Query::Lsl,0x00c8,0x81,0x2222,false,false},
        {"VERR CPL3 non-present data",Query::Verr,0x0083,0x72,0x1234,true,false},
        {"VERW CPL3 non-present writable data",Query::Verw,0x0083,0x72,0x1234,true,true},
        {"LAR CPL3 non-present data",Query::Lar,0x0083,0x72,0x1234,true,false},
        {"LSL CPL3 non-present data",Query::Lsl,0x0083,0x72,0x1234,true,true},
        {"LAR CPL3 non-present data memory",Query::Lar,0x0083,0x72,0x1234,true,false,true},
        {"VERR CPL3 null GDT selector",Query::Verr,0x0003,0xf2,0x3131,false,true,false,false},
        {"VERW CPL3 null GDT selector",Query::Verw,0x0003,0xf2,0x3131,false,false,false,false},
        {"LAR CPL3 null GDT selector",Query::Lar,0x0003,0xf2,0x3131,false,true,false,false},
        {"LSL CPL3 null GDT selector",Query::Lsl,0x0003,0xf2,0x3131,false,false,false,false},
        {"LAR CPL3 null GDT selector memory",Query::Lar,0x0003,0xf2,0x3131,false,true,true,false},
        {"VERR CPL3 GDT descriptor beyond limit",Query::Verr,0x00d3,0xf2,0x3232,false,true,false,false},
        {"VERW CPL3 GDT descriptor beyond limit",Query::Verw,0x00d3,0xf2,0x3232,false,false,false,false},
        {"LAR CPL3 GDT descriptor beyond limit",Query::Lar,0x00d3,0xf2,0x3232,false,true,false,false},
        {"LSL CPL3 GDT descriptor beyond limit",Query::Lsl,0x00d3,0xf2,0x3232,false,false,false,false},
        {"LAR CPL3 GDT over-limit descriptor memory",Query::Lar,0x00d3,0xf2,0x3232,false,true,true,false},
        {"VERR CPL3 LDT descriptor beyond limit",Query::Verr,0x0027,0xf2,0x3333,false,true,false,false},
        {"VERW CPL3 LDT descriptor beyond limit",Query::Verw,0x0027,0xf2,0x3333,false,false,false,false},
        {"LAR CPL3 LDT descriptor beyond limit",Query::Lar,0x0027,0xf2,0x3333,false,true,false,false},
        {"LSL CPL3 LDT descriptor beyond limit",Query::Lsl,0x0027,0xf2,0x3333,false,false,false,false},
        {"LAR CPL3 LDT over-limit descriptor memory",Query::Lar,0x0027,0xf2,0x3333,false,true,true,false},
    };
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00, 0x8e,0xd0,       // MOV SS, ring-0 stack
        0xbc,0x80,0x00,                   // MOV SP,0080
        0xb8,0x48,0x00,                   // LLDT the fixture LDT
        0x0f,0x00,0xd0,
        0xb8,0x50,0x00,                   // Load the fixture TSS before outer IRET
        0x0f,0x00,0xd8,
        0xcf,
        0xf4
    };
    const uint8_t ring3_code[]={0xff,0x0f,0x00,0x00,0x06,0xfa,0x00,0x00};
    const uint8_t ring3_stack[]={0xff,0x0f,0x00,0x00,0x07,0xf2,0x00,0x00};
    const uint8_t ring3_data[]={0xff,0x00,0x00,0x20,0x07,0xf2,0x00,0x00};
    const uint8_t ldt_descriptor[]={0x17,0x00,0x00,0x00,0x08,0x82,0x00,0x00};
    constexpr uint32_t ring3_code_base=0x00060000;
    constexpr uint32_t ring3_stack_base=0x00070000;
    constexpr uint32_t ring3_data_base=0x00072000;
    constexpr uint32_t ldt_base=0x00080000;
    constexpr uint16_t ring3_code_selector=0x003b;
    constexpr uint16_t ring3_stack_selector=0x0043;
    constexpr uint16_t ring3_data_selector=0x0063;
    constexpr uint16_t query_ip=0x040d;
    unsigned executions=0;

    auto put_descriptor=[](Bench& b,uint32_t address,uint16_t limit,
                           uint32_t base,uint8_t access) {
        b.memory[address+0]=uint8_t(limit);
        b.memory[address+1]=uint8_t(limit>>8);
        b.memory[address+2]=uint8_t(base);
        b.memory[address+3]=uint8_t(base>>8);
        b.memory[address+4]=uint8_t(base>>16);
        b.memory[address+5]=access;
        b.memory[address+6]=0;
        b.memory[address+7]=0;
    };

    for (bool wait:{false,true}) for (const auto& test:cases) {
        try {
            uint8_t second_opcode=0x00;
            uint8_t query_modrm=0xe3; // VERR BX
            uint8_t memory_modrm=0x26; // VERR word ptr DS:[0020]
            switch (test.query) {
                case Query::Verr: second_opcode=0x00; query_modrm=0xe3; memory_modrm=0x26; break;
                case Query::Verw: second_opcode=0x00; query_modrm=0xeb; memory_modrm=0x2e; break;
                case Query::Lar: second_opcode=0x02; query_modrm=0xc3; memory_modrm=0x06; break;
                case Query::Lsl: second_opcode=0x03; query_modrm=0xc3; memory_modrm=0x06; break;
            }
            const uint8_t compare_modrm=test.prior_zf ? 0xc0 : 0xd8;
            std::vector<uint8_t> ring3_program={
                0xb8,uint8_t(ring3_data_selector),uint8_t(ring3_data_selector>>8),
                0x8e,0xd8,
                0xbb,uint8_t(test.selector),uint8_t(test.selector>>8),
                0xb8,0xfe,0xca,
                0x39,compare_modrm
            };
            const uint16_t query_length=test.memory_source?5:3;
            const uint16_t next_ip=uint16_t(query_ip+query_length);
            if (test.memory_source)
                ring3_program.insert(ring3_program.end(),
                    {0x0f,second_opcode,memory_modrm,0x20,0x00});
            else
                ring3_program.insert(ring3_program.end(),{0x0f,second_opcode,query_modrm});
            ring3_program.push_back(0x90);
            Bench b;
            place_selector_fixture(b,ring0_program,sizeof(ring0_program));
            b.memory[0x40]=0xcf; // Include query descriptors through the DPL-0 TSS at C8h.
            b.put(kGdtBase+0x38,{ring3_code[0],ring3_code[1],ring3_code[2],ring3_code[3],
                                  ring3_code[4],ring3_code[5],ring3_code[6],ring3_code[7]});
            b.put(kGdtBase+0x40,{ring3_stack[0],ring3_stack[1],ring3_stack[2],ring3_stack[3],
                                  ring3_stack[4],ring3_stack[5],ring3_stack[6],ring3_stack[7]});
            b.put(kGdtBase+0x48,{ldt_descriptor[0],ldt_descriptor[1],ldt_descriptor[2],
                                  ldt_descriptor[3],ldt_descriptor[4],ldt_descriptor[5],
                                  ldt_descriptor[6],ldt_descriptor[7]});
            b.put(kGdtBase+0x60,{ring3_data[0],ring3_data[1],ring3_data[2],ring3_data[3],
                                  ring3_data[4],ring3_data[5],ring3_data[6],ring3_data[7]});
            put_descriptor(b,kGdtBase+0x68,0x5678,0x012345,0xf2);
            put_descriptor(b,kGdtBase+0x70,0x2468,0x023456,0xf0);
            put_descriptor(b,kGdtBase+0x78,0x89ab,0x045678,0x9e);
            put_descriptor(b,kGdtBase+0x80,0x1234,0x06789a,0x72); // Non-present but visible writable data.
            put_descriptor(b,kGdtBase,0x3131,0x010203,0xf2); // Poison null selector: it must still cause no read.
            for (unsigned type=1;type<=7;++type)
                put_descriptor(b,kGdtBase+0x88+type*8,0x1100+type,
                               0x0a0000+type*0x100,uint8_t(0xe0|type));
            put_descriptor(b,kGdtBase+0xc8,0x2222,0x012345,0x81);
            put_descriptor(b,kGdtBase+0xd0,0x3232,0x020304,0xf2); // Inaccessible beyond GDTR.limit.
            put_descriptor(b,ldt_base+0x08,0x3456,0x034567,0xf2);
            put_descriptor(b,ldt_base+0x20,0x3333,0x030405,0xf2); // Inaccessible beyond LDTR.limit.
            if (test.memory_source)
                b.put(ring3_data_base+0x20,{uint8_t(test.selector),uint8_t(test.selector>>8)});
            b.put(ring3_code_base+0x0400,{ring3_program[0],ring3_program[1],ring3_program[2],
                                          ring3_program[3],ring3_program[4],ring3_program[5],
                                          ring3_program[6],ring3_program[7]});
            for (std::size_t i=8;i<ring3_program.size();++i)
                b.memory[ring3_code_base+0x0400+uint32_t(i)]=ring3_program[i];
            b.put(kStackBase+0x0080,{0x00,0x04,uint8_t(ring3_code_selector),
                uint8_t(ring3_code_selector>>8),0x02,0x02,0x00,0x01,
                uint8_t(ring3_stack_selector),uint8_t(ring3_stack_selector>>8)});

            protected_mode_boot(b,wait);
            b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
            b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
            b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
            b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
            b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x020e,wait);
            b.step(kCodeBase+0x020e,0xb8,kCodeSelector,0x0211,wait);
            b.step(kCodeBase+0x0211,0x0f,kCodeSelector,0x0214,wait);
            check(b.memory[kGdtBase+0x55]==0x83,
                  "ring-0 setup did not load TR before ring-3 selector queries");
            check(b.memory[kGdtBase+0x4d]==0x82,
                  "ring-0 setup changed the LDT descriptor access byte");
            b.step(kCodeBase+0x0214,0xcf,ring3_code_selector,0x0400,wait);
            check(b.cs()==ring3_code_selector &&
                  uint16_t(b.d.segs_o>>32)==ring3_stack_selector &&
                  b.cache_base(2)==ring3_stack_base && b.reg(4)==0x0100 &&
                  b.cache_base(1)==ring3_code_base,
                  "outer IRET did not establish reachable CPL3 selector-query state");
            b.step(ring3_code_base+0x0400,0xb8,ring3_code_selector,0x0403,wait);
            b.step(ring3_code_base+0x0403,0x8e,ring3_code_selector,0x0405,wait);
            b.step(ring3_code_base+0x0405,0xbb,ring3_code_selector,0x0408,wait);
            b.step(ring3_code_base+0x0408,0xb8,ring3_code_selector,0x040b,wait);
            b.step(ring3_code_base+0x040b,0x39,ring3_code_selector,query_ip,wait);
            check((b.d.flags_o&0x0040)==(test.prior_zf?0x0040:0),
                  "ring-3 query fixture did not establish its incoming ZF");

            const uint16_t flags_before=b.d.flags_o;
            const uint16_t ax_before=b.reg(0);
            const unsigned retired_before=b.retired;
            const uint32_t descriptor_address=(test.selector&4) ?
                ldt_base+(test.selector&0xfff8u) : kGdtBase+(test.selector&0xfff8u);
            const uint8_t original_access=b.memory.at(descriptor_address+5);
            check(original_access==test.access,
                  "ring-3 query fixture descriptor access byte differs from its case");
            b.accepted.clear();
            b.data_transfers.clear();
            b.step(ring3_code_base+query_ip,0x0f,ring3_code_selector,next_ip,wait);
            check(b.retired==retired_before+1,
                  "ring-3 selector query did not retire exactly once");
            check(!b.d.event_o && !b.d.event_packet_valid_o && !b.d.fault_o,
                  "ring-3 selector query raised a fault or diagnostic stop");
            check((b.d.flags_o&0xffbf)==(flags_before&0xffbf) &&
                  bool(b.d.flags_o&0x0040)==test.success,
                  "ring-3 query changed flags other than ZF or returned the wrong eligibility");
            uint16_t expected_ax=ax_before;
            if (test.success && test.query==Query::Lar)
                expected_ax=uint16_t(test.access)<<8;
            if (test.success && test.query==Query::Lsl) expected_ax=test.limit;
            check(b.reg(0)==expected_ax && b.reg(3)==test.selector,
                  "ring-3 LAR/LSL result, failed destination preservation, or BX changed");
            check(b.accepted.size()==query_length,
                  "ring-3 query fetched the wrong number of encoding bytes");
            for (unsigned i=0;i<query_length;++i)
                check(b.accepted[i]==ring3_code_base+query_ip+i,
                      "ring-3 query fetched bytes outside its exact encoding");
            std::size_t descriptor_transfer_index=0;
            if (test.memory_source) {
                const std::size_t expected_operand_transfers=2+(test.descriptor_read?8:0);
                check(b.data_transfers.size()==expected_operand_transfers &&
                      b.data_transfers[0].address==ring3_data_base+0x20 &&
                      b.data_transfers[0].value==uint8_t(test.selector) &&
                      !b.data_transfers[0].write && !b.data_transfers[0].io &&
                      b.data_transfers[0].segmented && b.data_transfers[0].role==3 &&
                      b.data_transfers[0].kind==0 && b.data_transfers[0].offset==0x20 &&
                      b.data_transfers[0].size==2 &&
                      b.data_transfers[1].address==ring3_data_base+0x21 &&
                      b.data_transfers[1].value==uint8_t(test.selector>>8) &&
                      !b.data_transfers[1].write && !b.data_transfers[1].io &&
                      b.data_transfers[1].segmented && b.data_transfers[1].role==3 &&
                      b.data_transfers[1].kind==0 && b.data_transfers[1].offset==0x21 &&
                      b.data_transfers[1].size==2,
                      "ring-3 query did not read its selector through DS:[0020]");
                descriptor_transfer_index=2;
            }
            check(b.data_transfers.size()==descriptor_transfer_index+
                  (test.descriptor_read?8:0),
                  "ring-3 query issued an unexpected descriptor-transfer count");
            if (test.descriptor_read) {
                for (unsigned i=0;i<8;++i) {
                    const auto& transfer=b.data_transfers[descriptor_transfer_index+i];
                    check(transfer.address==descriptor_address+i &&
                          transfer.value==b.memory.at(descriptor_address+i) &&
                          !transfer.write && !transfer.io && !transfer.segmented,
                          "ring-3 query descriptor read address/order/value mismatch");
                }
            }
            check(b.memory.at(descriptor_address+5)==original_access,
                  "read-only ring-3 selector query modified its descriptor");
            b.step(ring3_code_base+next_ip,0x90,ring3_code_selector,next_ip+1,wait);
            check(!b.d.halted_o && b.cs()==ring3_code_selector && b.reg(4)==0x0100,
                  "ring-3 query did not reach its exact unprivileged successor");
            ++executions;
        } catch (const std::exception& error) {
            throw std::runtime_error(std::string("80286 ")+test.label+
                " reachable ring-3 execution: "+error.what());
        }
    }
    check(executions==sizeof(cases)/sizeof(cases[0])*2,
          "ring-3 selector query matrix did not cover both READY modes");
    std::cout<<"PASS: "<<executions
             <<" reachable CPL3 register/memory VERR/VERW/LAR/LSL queries verify DPL visibility, conforming code, system/gate types, non-present descriptors, table bounds, null selectors, ZF, result preservation and READY stalls\n";
}

static void protected_selector_query_ring12_matrix() {
    using namespace protected_mode_fixture;
    enum class Query : uint8_t { Verr, Verw, Lar, Lsl };
    struct QueryEncoding { Query query; uint8_t second_opcode, modrm; };
    struct Level {
        unsigned cpl;
        uint16_t code_selector, stack_selector;
        uint32_t code_base, stack_base;
        uint8_t code_access, stack_access;
    };
    struct DescriptorClass {
        const char* label;
        uint8_t type;
        bool code;
        bool conforming;
    };
    const QueryEncoding operations[]={
        {Query::Verr,0x00,0xe3}, // VERR BX
        {Query::Verw,0x00,0xeb}, // VERW BX
        {Query::Lar, 0x02,0xc3}, // LAR AX,BX
        {Query::Lsl, 0x03,0xc3}  // LSL AX,BX
    };
    const Level levels[]={
        {1,0x0049,0x0051,0x00081000,0x00080000,0xba,0xb2},
        {2,0x005a,0x0062,0x00083000,0x00082000,0xda,0xd2}
    };
    const DescriptorClass descriptor_classes[]={
        {"writable data",0x02,false,false},
        {"readable nonconforming code",0x0a,true,false},
        {"readable conforming code",0x0e,true,true}
    };
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00, 0x8e,0xd0, 0xbc,0x80,0x00, 0xcf, 0xf4
    };
    constexpr uint16_t selector_index=0x0070;
    constexpr uint16_t query_ip=0x0406;
    constexpr uint16_t query_successor=0x0409;
    constexpr uint32_t descriptor_address=kGdtBase+selector_index;
    unsigned executions=0;

    auto put_descriptor=[](Bench& b,uint32_t address,uint16_t limit,
                           uint32_t base,uint8_t access) {
        b.memory[address+0]=uint8_t(limit);
        b.memory[address+1]=uint8_t(limit>>8);
        b.memory[address+2]=uint8_t(base);
        b.memory[address+3]=uint8_t(base>>8);
        b.memory[address+4]=uint8_t(base>>16);
        b.memory[address+5]=access;
        b.memory[address+6]=0;
        b.memory[address+7]=0;
    };

    for (const auto& level:levels)
        for (const auto& descriptor_class:descriptor_classes)
            for (unsigned dpl=0;dpl<4;++dpl)
                for (unsigned rpl=0;rpl<4;++rpl)
                    for (const auto& operation:operations)
                        for (bool wait:{false,true}) {
        const uint8_t access=uint8_t(0x80 | (dpl<<5) | 0x10 | descriptor_class.type);
        const uint16_t limit=uint16_t(0x3100+dpl*0x111);
        const uint16_t selector=uint16_t(selector_index|rpl);
        const bool privilege_visible=descriptor_class.conforming ||
            (dpl>=level.cpl && dpl>=rpl);
        const bool expected_success=operation.query==Query::Verw ?
            (!descriptor_class.code && privilege_visible) : privilege_visible;
        uint8_t ring_code[10]={
            0xbb,uint8_t(selector),uint8_t(selector>>8),
            0xb8,0xfe,0xca,
            0x0f,operation.second_opcode,operation.modrm,
            0x90
        };
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x40]=0x77; // The complete query descriptor ends at GDT limit 0077h.
        put_descriptor(b,kGdtBase+(level.code_selector&0xfff8u),0x0fff,
                       level.code_base,level.code_access);
        put_descriptor(b,kGdtBase+(level.stack_selector&0xfff8u),0x0fff,
                       level.stack_base,level.stack_access);
        put_descriptor(b,descriptor_address,limit,0x012345,access);
        b.put(level.code_base+0x0400,
              {ring_code[0],ring_code[1],ring_code[2],ring_code[3],ring_code[4],
               ring_code[5],ring_code[6],ring_code[7],ring_code[8],ring_code[9]});
        b.put(kStackBase+0x0080,{0x00,0x04,uint8_t(level.code_selector),
            uint8_t(level.code_selector>>8),0x02,0x02,0x00,0x01,
            uint8_t(level.stack_selector),uint8_t(level.stack_selector>>8)});

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xcf,level.code_selector,0x0400,wait);
        check(b.cs()==level.code_selector &&
              uint16_t(b.d.segs_o>>32)==level.stack_selector &&
              b.cache_base(1)==level.code_base && b.cache_base(2)==level.stack_base &&
              b.reg(4)==0x0100,
              "outer IRET did not establish reachable ring-1/ring-2 query state");
        b.step(level.code_base+0x0400,0xbb,level.code_selector,0x0403,wait);
        b.step(level.code_base+0x0403,0xb8,level.code_selector,query_ip,wait);

        const uint16_t flags_before=b.d.flags_o;
        const uint16_t ax_before=b.reg(0);
        const unsigned retired_before=b.retired;
        b.accepted.clear();
        b.data_transfers.clear();
        try {
            b.step(level.code_base+query_ip,0x0f,level.code_selector,query_successor,wait);
            check(b.retired==retired_before+1,
                  "ring-1/ring-2 selector query did not retire exactly once");
            check(!b.d.event_o && !b.d.event_packet_valid_o && !b.d.fault_o,
                  "ring-1/ring-2 selector query faulted or stopped diagnostically");
            check((b.d.flags_o&0xffbf)==(flags_before&0xffbf) &&
                  bool(b.d.flags_o&0x0040)==expected_success,
                  "ring-1/ring-2 selector query changed non-ZF flags or returned wrong visibility");
            uint16_t expected_ax=ax_before;
            if (expected_success && operation.query==Query::Lar)
                expected_ax=uint16_t(access)<<8;
            if (expected_success && operation.query==Query::Lsl) expected_ax=limit;
            check(b.reg(0)==expected_ax && b.reg(3)==selector,
                  "ring-1/ring-2 query result, failed destination preservation, or BX changed");
            check(b.accepted.size()==3,
                  "ring-1/ring-2 query fetched the wrong encoding length");
            for (unsigned i=0;i<3;++i)
                check(b.accepted[i]==level.code_base+query_ip+i,
                      "ring-1/ring-2 query fetched bytes outside its exact encoding");
            check(b.data_transfers.size()==8,
                  "ring-1/ring-2 query did not read exactly one full descriptor");
            for (unsigned i=0;i<8;++i) {
                const auto& transfer=b.data_transfers[i];
                check(transfer.address==descriptor_address+i &&
                      transfer.value==b.memory.at(descriptor_address+i) &&
                      !transfer.write && !transfer.io && !transfer.segmented,
                      "ring-1/ring-2 query descriptor read address/order/value mismatch");
            }
            check(b.memory.at(descriptor_address+5)==access,
                  "ring-1/ring-2 query modified its descriptor");
            b.step(level.code_base+query_successor,0x90,level.code_selector,
                   query_successor+1,wait);
            check(!b.d.halted_o && b.cs()==level.code_selector &&
                  b.reg(4)==0x0100 && b.d.ip_o==query_successor+1,
                  "ring-1/ring-2 query missed its exact successor");
        } catch (const std::exception& error) {
            const char* operation_name=operation.query==Query::Verr ? "VERR" :
                operation.query==Query::Verw ? "VERW" :
                operation.query==Query::Lar ? "LAR" : "LSL";
            const char* type_name=descriptor_class.label;
            std::ostringstream message;
            message<<"CPL"<<level.cpl<<" "<<operation_name<<" "<<type_name
                   <<" DPL"<<dpl<<" RPL"<<rpl<<" READY="<<wait<<": "<<error.what();
            throw std::runtime_error(message.str());
        }
        ++executions;
    }

    check(executions==768,
          "ring-1/ring-2 selector visibility matrix missed a type, DPL, RPL, operation or READY policy");
    std::cout<<"PASS: "<<executions
             <<" reachable CPL1/CPL2 VERR/VERW/LAR/LSL queries cover writable data, readable nonconforming code and conforming code for every DPL/RPL pair in both READY modes\n";
}

static void protected_selector_descriptor_faults() {
    using namespace protected_mode_fixture;
    struct FaultCase {
        uint16_t selector;
        uint8_t group;
        uint8_t vector;
        uint16_t error;
        bool expect_descriptor_read;
    };
    const FaultCase cases[]={
        {0x0008,3,13,0x0008,true}, // LTR rejects a code descriptor.
        {0x0058,3,11,0x0058,true}, // LTR reports an absent available TSS.
        {0x0060,3,13,0x0060,true}, // LTR rejects an already-busy TSS.
        {0x0008,2,13,0x0008,true}, // LLDT rejects a code descriptor.
        {0x0004,2,13,0x0004,false} // TI=1 with index zero is not a null selector.
    };
    const uint8_t repair_handler[]={
        0x83,0xc4,0x02,  // discard the selector exception error word
        0x58,             // pop the saved fault IP
        0x83,0xc0,0x03,  // skip the three-byte LLDT/LTR instruction
        0x50,             // push the repaired saved IP
        0xcf              // IRET to the exact successor
    };
    unsigned executions=0;
    for (bool wait:{false,true}) for (const auto& test:cases) {
        const uint8_t program[]={
            0xb8,0x10,0x00, 0x8e,0xd8,
            0xb8,0x28,0x00, 0x8e,0xd0, 0xbc,0x80,0x00,
            0xb8,uint8_t(test.selector),uint8_t(test.selector>>8),
            0x0f,0x00,uint8_t(test.group==2 ? 0xd0 : 0xd8),
            0xf4
        };
        Bench b;
        place_selector_fixture(b,program,sizeof(program));
        for (std::size_t i=0;i<sizeof(repair_handler);++i)
            b.memory[kHandlerBase+kHandlerIp+uint32_t(i)]=repair_handler[i];
        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xb8,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0x8e,kCodeSelector,0x020a,wait);
        b.step(kCodeBase+0x020a,0xbc,kCodeSelector,0x020d,wait);
        b.step(kCodeBase+0x020d,0xb8,kCodeSelector,0x0210,wait);
        const uint16_t saved_flags=b.d.flags_o;
        const unsigned retired_before=b.retired;
        b.data_transfers.clear();
        const uint32_t descriptor_base=kGdtBase+(test.selector & 0xfff8);
        check(b.memory.count(descriptor_base+5),"selector fixture descriptor is absent before test");
        const uint8_t original_access=b.memory[descriptor_base+5];
        for (unsigned cycle=0;cycle<30000 && !b.d.event_o && !b.d.fault_o;++cycle) b.tick(wait);
        if (!(b.d.event_o && !b.d.fault_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_error_valid_o && b.d.event_packet_restartable_o &&
              b.d.event_vector_o==test.vector &&
              b.d.event_packet_error_code_o==test.error &&
              b.d.event_packet_saved_cs_o==kCodeSelector &&
              b.d.event_packet_saved_ip_o==0x0210 &&
              b.d.event_packet_saved_flags_o==saved_flags &&
              b.d.event_packet_saved_sp_o==kInitialSp &&
              b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp &&
              b.reg(4)==kInitialSp-8 && b.retired==retired_before))
            throw std::runtime_error("selector " + std::to_string(test.selector) +
                " did not deliver its exact protected fault packet to the IDT handler");
        check(b.memory.count(descriptor_base+5) &&
              b.memory[descriptor_base+5]==original_access,
              "rejected selector descriptor was modified");
        const bool descriptor_was_read=std::any_of(
            b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& transfer) {
                return !transfer.write && !transfer.io &&
                       transfer.address>=descriptor_base && transfer.address<descriptor_base+8;
            });
        check(descriptor_was_read==test.expect_descriptor_read,
              "selector validation read a forbidden descriptor or skipped a required descriptor");
        const uint8_t expected_frame[]={
            uint8_t(test.error),uint8_t(test.error>>8),
            0x10,0x02,uint8_t(kCodeSelector),uint8_t(kCodeSelector>>8),
            uint8_t(saved_flags),uint8_t(saved_flags>>8)
        };
        const uint32_t expected_write_addresses[]={
            kStackBase+kInitialSp-2,kStackBase+kInitialSp-1,
            kStackBase+kInitialSp-4,kStackBase+kInitialSp-3,
            kStackBase+kInitialSp-6,kStackBase+kInitialSp-5,
            kStackBase+kInitialSp-8,kStackBase+kInitialSp-7
        };
        const uint8_t expected_write_values[]={
            uint8_t(saved_flags),uint8_t(saved_flags>>8),
            uint8_t(kCodeSelector),uint8_t(kCodeSelector>>8),
            0x10,0x02,uint8_t(test.error),uint8_t(test.error>>8)
        };
        std::vector<Bench::Transfer> frame_writes;
        for (const auto& transfer:b.data_transfers)
            if (transfer.write && transfer.address>=kStackBase+kInitialSp-8 &&
                transfer.address<kStackBase+kInitialSp)
                frame_writes.push_back(transfer);
        check(frame_writes.size()==8,"selector exception did not write a complete eight-byte frame");
        for (unsigned i=0;i<8;++i)
            check(frame_writes[i].address==expected_write_addresses[i] &&
                  frame_writes[i].value==expected_write_values[i],
                  "selector exception frame bus order/value mismatch");
        for (unsigned i=0;i<8;++i)
            check(b.memory.at(kStackBase+kInitialSp-8+i)==expected_frame[i],
                  "selector exception stack image mismatch");

        b.data_transfers.clear();
        b.step(kHandlerBase+kHandlerIp,0x83,kHandlerSelector,kHandlerIp+3,wait);
        b.step(kHandlerBase+kHandlerIp+3,0x58,kHandlerSelector,kHandlerIp+4,wait);
        b.step(kHandlerBase+kHandlerIp+4,0x83,kHandlerSelector,kHandlerIp+7,wait);
        b.step(kHandlerBase+kHandlerIp+7,0x50,kHandlerSelector,kHandlerIp+8,wait);
        b.step(kHandlerBase+kHandlerIp+8,0xcf,kCodeSelector,0x0213,wait);
        check(b.reg(4)==kInitialSp && b.cs()==kCodeSelector && b.d.ip_o==0x0213 &&
              b.d.flags_o==saved_flags,
              "handler IRET did not restore the selector-fault frame and exact successor");
        b.step(kCodeBase+0x0213,0xf4,kCodeSelector,0x0214,wait);
        check(b.d.halted_o && b.reg(4)==kInitialSp && b.d.ip_o==0x0214,
              "selector exception handler did not resume at the exact post-fault HLT");
        ++executions;
    }
    std::cout<<"PASS: "<<executions
             <<" selector #GP/#NP cases deliver exact error-code frames, recover through IRET and resume at the exact successor in both READY modes\n";
}

static void protected_selector_privilege_faults() {
    using namespace protected_mode_fixture;
    struct FaultCase {
        const char* name;
        uint8_t group;
        bool memory_operand;
        uint16_t selector;
        uint16_t memory_offset;
        uint8_t modrm;
        uint16_t length;
    };
    const FaultCase cases[]={
        {"LLDT register",2,false,0x0048,0x0020,0xd0,3},
        {"LLDT memory",2,true,0x0048,0x0020,0x16,5},
        {"LTR register",3,false,0x0058,0x0022,0xd8,3},
        {"LTR memory",3,true,0x0058,0x0022,0x1e,5}
    };
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00, 0x8e,0xd0,             // MOV SS, ring-0 stack
        0xbc,0x80,0x00,                         // MOV SP,0080
        0xb8,0x50,0x00,                         // Existing available TSS selector
        0x0f,0x00,0xd8,                         // LTR AX before entering ring 3
        0xcf,                                   // IRET to outer privilege
        0xf4
    };
    const uint8_t ring3_cs[]={0xff,0x0f,0x00,0x00,0x06,0xfa,0x00,0x00};
    const uint8_t ring3_ss[]={0xff,0x0f,0x00,0x00,0x07,0xf2,0x00,0x00};
    const uint8_t ldt_descriptor[]={0x17,0x00,0x00,0x06,0x00,0x82,0x00,0x00};
    const uint8_t target_tss[]={0x2b,0x00,0x80,0x07,0x00,0x81,0x00,0x00};
    const uint8_t ring3_data[]={0xff,0x00,0x00,0x20,0x07,0xf2,0x00,0x00};
    const uint8_t ring3_gate[]={0x00,0x05,0x3b,0x00,0x00,0xe6,0x00,0x00};
    // Preserve AX and adjust only the saved IP. After PUSH AX, [BP+4] is the
    // saved IP; the handler then discards #GP(0) and returns with IRET.
    const uint8_t repair_handler[]={
        0x50,                         // PUSH AX
        0x89,0xe5,                    // MOV BP,SP
        0x83,0x46,0x04,0x03,           // ADD word SS:[BP+4],3 (patched per case)
        0x58,                         // POP AX
        0x83,0xc4,0x02,               // discard #GP error word
        0xcf                          // IRET
    };
    constexpr uint32_t ring3_code_base=0x00060000;
    constexpr uint32_t ring3_data_base=0x00072000;
    constexpr uint32_t ring3_stack_base=0x00070000;
    unsigned executions=0;
    for (bool wait:{false,true}) for (uint8_t cpl=1;cpl<=3;++cpl)
      for (const auto& test:cases) {
        try {
            const uint16_t ring3_code_selector=uint16_t(0x0038|cpl);
            const uint16_t ring3_stack_selector=uint16_t(0x0040|cpl);
            const uint16_t ring3_data_selector=uint16_t(0x0060|cpl);
            Bench b;
            place_selector_fixture(b,ring0_program,sizeof(ring0_program));
            b.put(kGdtBase+0x38,{ring3_cs[0],ring3_cs[1],ring3_cs[2],ring3_cs[3],
                                  ring3_cs[4],uint8_t(0x9a|(cpl<<5)),ring3_cs[6],ring3_cs[7]});
            b.put(kGdtBase+0x40,{ring3_ss[0],ring3_ss[1],ring3_ss[2],ring3_ss[3],
                                  ring3_ss[4],uint8_t(0x92|(cpl<<5)),ring3_ss[6],ring3_ss[7]});
            b.put(kGdtBase+0x48,{ldt_descriptor[0],ldt_descriptor[1],ldt_descriptor[2],ldt_descriptor[3],
                                  ldt_descriptor[4],ldt_descriptor[5],ldt_descriptor[6],ldt_descriptor[7]});
            b.put(kGdtBase+0x58,{target_tss[0],target_tss[1],target_tss[2],target_tss[3],
                                  target_tss[4],target_tss[5],target_tss[6],target_tss[7]});
            b.put(kGdtBase+0x60,{ring3_data[0],ring3_data[1],ring3_data[2],ring3_data[3],
                                  ring3_data[4],uint8_t(0x92|(cpl<<5)),ring3_data[6],ring3_data[7]});
            b.put(kIdtBase+13*8,{ring3_gate[0],ring3_gate[1],uint8_t(ring3_code_selector),
                                  uint8_t(ring3_code_selector>>8),ring3_gate[4],0x86,
                                  ring3_gate[6],ring3_gate[7]});
            std::vector<uint8_t> ring3_program={
                0xb8,uint8_t(ring3_data_selector),uint8_t(ring3_data_selector>>8), // MOV AX, ring-3 DS
                0x8e,0xd8,                                                     // MOV DS,AX
                0xb8,uint8_t(test.selector),uint8_t(test.selector>>8)          // AX sentinel/selector
            };
            if (test.memory_operand)
                ring3_program.insert(ring3_program.end(),{0x0f,0x00,test.modrm,
                    uint8_t(test.memory_offset),uint8_t(test.memory_offset>>8)});
            else
                ring3_program.insert(ring3_program.end(),{0x0f,0x00,test.modrm});
            ring3_program.insert(ring3_program.end(),{0x0f,0x00,0xc3, // SLDT BX
                                                      0x0f,0x00,0xc9, // STR CX
                                                      0x90});
            const uint16_t fault_ip=0x0408;
            const uint16_t successor_ip=fault_ip+test.length;
            b.put(ring3_code_base+0x0400,{ring3_program[0],ring3_program[1],ring3_program[2],
                                          ring3_program[3],ring3_program[4],ring3_program[5],
                                          ring3_program[6],ring3_program[7]});
            for (std::size_t i=8;i<ring3_program.size();++i)
                b.memory[ring3_code_base+0x0400+uint32_t(i)]=ring3_program[i];
            for (std::size_t i=0;i<sizeof(repair_handler);++i)
                b.memory[ring3_code_base+0x0500+uint32_t(i)]=repair_handler[i];
            b.memory[ring3_code_base+0x0500+6]=uint8_t(test.length); // ADD immediate in repair handler.
            b.put(ring3_data_base+0x20,{0x48,0x00});
            b.put(ring3_data_base+0x22,{0x58,0x00});
            b.put(kStackBase+0x0080,{0x00,0x04,uint8_t(ring3_code_selector),uint8_t(ring3_code_selector>>8),
                                      0x02,0x02,0x00,0x01,uint8_t(ring3_stack_selector),
                                      uint8_t(ring3_stack_selector>>8)});

            protected_mode_boot(b,wait);
            b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
            b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
            b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
            b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
            b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x020e,wait);
            check(b.memory[kGdtBase+0x55]==0x83,
                  "ring-0 setup did not load the original TR before the ring-3 test");
            b.step(kCodeBase+0x020e,0xcf,ring3_code_selector,0x0400,wait);
            check(b.cs()==ring3_code_selector && uint16_t(b.d.segs_o>>32)==ring3_stack_selector &&
                  b.cache_base(2)==ring3_stack_base && b.reg(4)==0x0100,
                  "outer IRET did not establish reachable ring-3 CS:SS:SP");
            b.step(ring3_code_base+0x0400,0xb8,ring3_code_selector,0x0403,wait);
            b.step(ring3_code_base+0x0403,0x8e,ring3_code_selector,0x0405,wait);
            b.step(ring3_code_base+0x0405,0xb8,ring3_code_selector,fault_ip,wait);
            const uint16_t saved_flags=b.d.flags_o;
            const unsigned retired_before=b.retired;
            b.data_transfers.clear();
            for (unsigned cycle=0;cycle<50000 && !b.d.event_o && !b.d.fault_o &&
                 b.retired==retired_before;++cycle) b.tick(wait);
            if (!(b.d.event_o && !b.d.fault_o && b.d.event_packet_valid_o &&
                  b.d.event_packet_protected_o && b.d.event_packet_error_valid_o &&
                  b.d.event_packet_restartable_o && b.d.event_vector_o==13 &&
                  b.d.event_packet_error_code_o==0 &&
                  b.d.event_packet_saved_cs_o==ring3_code_selector &&
                  b.d.event_packet_saved_ip_o==fault_ip &&
                  b.d.event_packet_saved_flags_o==saved_flags &&
                  b.d.event_packet_saved_sp_o==0x0100 && b.retired==retired_before &&
                  b.cs()==ring3_code_selector && b.d.ip_o==0x0500 && b.reg(4)==0x00f8))
                throw std::runtime_error(std::string(test.name)+
                    " did not raise reachable ring-3 #GP(0) before retirement");
            check(b.reg(0)==test.selector,
                  "privileged selector fault changed its AX operand before handler execution");
            const uint8_t expected_frame[]={0x00,0x00,uint8_t(fault_ip),uint8_t(fault_ip>>8),
                uint8_t(ring3_code_selector),uint8_t(ring3_code_selector>>8),
                uint8_t(saved_flags),uint8_t(saved_flags>>8)};
            for (unsigned i=0;i<8;++i)
                check(b.memory.at(ring3_stack_base+0x00f8+i)==expected_frame[i],
                      "ring-3 privileged-instruction #GP frame contents mismatch");
            const uint32_t expected_write_addresses[]={
                ring3_stack_base+0x00fe,ring3_stack_base+0x00ff,
                ring3_stack_base+0x00fc,ring3_stack_base+0x00fd,
                ring3_stack_base+0x00fa,ring3_stack_base+0x00fb,
                ring3_stack_base+0x00f8,ring3_stack_base+0x00f9};
            const uint8_t expected_write_values[]={
                uint8_t(saved_flags),uint8_t(saved_flags>>8),uint8_t(ring3_code_selector),
                uint8_t(ring3_code_selector>>8),uint8_t(fault_ip),uint8_t(fault_ip>>8),0,0};
            std::vector<Bench::Transfer> frame_writes;
            for (const auto& transfer:b.data_transfers)
                if (transfer.write && transfer.address>=ring3_stack_base+0x00f8 &&
                    transfer.address<ring3_stack_base+0x0100) frame_writes.push_back(transfer);
            check(frame_writes.size()==8,
                  "ring-3 privileged-instruction #GP did not write exactly one complete frame");
            for (unsigned i=0;i<8;++i)
                check(frame_writes[i].address==expected_write_addresses[i] &&
                      frame_writes[i].value==expected_write_values[i],
                      "ring-3 privileged-instruction #GP frame bus order/value mismatch");
            const uint32_t operand_address=ring3_data_base+test.memory_offset;
            check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                      return !t.write && t.address>=operand_address && t.address<operand_address+2;
                  }),"privilege fault read the memory selector operand before #GP(0)");
            check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                      return (t.address>=kGdtBase+0x48 && t.address<kGdtBase+0x50) ||
                             (t.address>=kGdtBase+0x58 && t.address<kGdtBase+0x60) ||
                             (t.address>=0x00074000 && t.address<0x00074030) ||
                             (t.address>=0x00078000 && t.address<0x00078030);
                  }),"privilege fault accessed its LDT/TSS operand descriptor or TSS image");
            check(b.memory[kGdtBase+0x4d]==0x82 && b.memory[kGdtBase+0x55]==0x83 &&
                  b.memory[kGdtBase+0x5d]==0x81,
                  "privilege fault changed the existing/new LDT or TSS busy state");

            b.step(ring3_code_base+0x0500,0x50,ring3_code_selector,0x0501,wait);
            b.step(ring3_code_base+0x0501,0x89,ring3_code_selector,0x0503,wait);
            b.step(ring3_code_base+0x0503,0x83,ring3_code_selector,0x0507,wait);
            b.step(ring3_code_base+0x0507,0x58,ring3_code_selector,0x0508,wait);
            b.step(ring3_code_base+0x0508,0x83,ring3_code_selector,0x050b,wait);
            b.step(ring3_code_base+0x050b,0xcf,ring3_code_selector,successor_ip,wait);
            // The same-CPL ring-3 interrupt gate clears IF. Since CPL 3 is
            // above IOPL 0, IRET must leave that handler IF value unchanged.
            check(b.reg(0)==test.selector && b.reg(4)==0x0100 &&
                  b.d.flags_o==(saved_flags&0xfdff),
                  "ring-3 #GP handler/IRET changed AX, SP, or restricted IF");
            b.step(ring3_code_base+successor_ip,0x0f,ring3_code_selector,successor_ip+3,wait);
            b.step(ring3_code_base+successor_ip+3,0x0f,ring3_code_selector,successor_ip+6,wait);
            check(b.reg(3)==0 && b.reg(1)==0x0050,
                  "ring-3 SLDT/STR observed LDTR/TR changes from rejected LLDT/LTR");
            b.step(ring3_code_base+successor_ip+6,0x90,ring3_code_selector,successor_ip+7,wait);
            check(!b.d.halted_o && b.cs()==ring3_code_selector && b.reg(4)==0x0100,
                  "ring-3 selector privilege test missed its exact unprivileged successor");
            ++executions;
        } catch (const std::exception& error) {
            throw std::runtime_error(std::string("80286 ")+test.name+" CPL "+
                std::to_string(cpl)+" privilege fault: "+error.what());
        }
    }
    check(executions==24,"CPL 1-3 LLDT/LTR did not cover operands and both READY modes");
    std::cout<<"PASS: "<<executions
             <<" reachable CPL 1-3 LLDT/LTR register/memory faults raise #GP(0), suppress operand/descriptor/TSS traffic, preserve LDTR/TR, and IRET to exact successors in both READY modes\n";
}

static void protected_event_outer_delivery() {
    using namespace protected_mode_fixture;
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00, 0x8e,0xd0,       // Install ring-0 SS.
        0xbc,0x80,0x00,                   // Install ring-0 SP.
        0xb8,0x58,0x00, 0x0f,0x00,0xd8, // LTR ring-0 TSS.
        0xcf, 0xf4
    };
    const uint8_t ring3_fault_program[]={0xb8,0x00,0x00,0x0f,0x00,0xd0,0x90};
    const uint8_t ring3_cs[]={0xff,0x0f,0x00,0x00,0x06,0xfa,0x00,0x00};
    const uint8_t ring3_ss[]={0xff,0x0f,0x00,0x00,0x07,0xf2,0x00,0x00};
    const uint8_t tss[]={0x2b,0x00,0x00,0x07,0x00,0x81,0x00,0x00};
    const uint8_t return_handler[]={
        0x83,0xc4,0x02,       // Discard #GP error code.
        0x55,                 // Preserve BP.
        0x89,0xe5,             // BP = SP.
        0x83,0x46,0x02,0x03,  // Patched to skip LLDT or INT after the error word.
        0x5d, 0xcf
    };
    const uint16_t ring3_cs_selector=0x003b;
    const uint16_t ring3_ss_selector=0x0043;
    constexpr uint32_t ring3_code_base=0x00060000;
    constexpr uint32_t ring3_stack_base=0x00070000;
    struct EventCase { uint8_t gate_type; bool software_interrupt; };
    unsigned executions=0;
    for (const auto& scenario:{EventCase{6,false},EventCase{7,false},
                               EventCase{6,true},EventCase{7,true}})
      for (bool wait:{false,true}) {
        const uint8_t gate_type=scenario.gate_type;
        const bool software_interrupt=scenario.software_interrupt;
        const std::vector<uint8_t> ring3_program=software_interrupt ?
            std::vector<uint8_t>{0xcd,0x0d,0x90} :
            std::vector<uint8_t>(std::begin(ring3_fault_program),std::end(ring3_fault_program));
        const uint16_t fault_ip=software_interrupt ? 0x0400 : 0x0403;
        const uint16_t fault_error=software_interrupt ? 0x006a : 0x0000;
        const uint8_t fault_length=software_interrupt ? 2 : 3;
        const uint16_t successor_ip=fault_ip+fault_length;
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x40]=0x6f; b.memory[0x41]=0x00; // Include the busy TSS descriptor.
        b.put(kGdtBase+0x38,{ring3_cs[0],ring3_cs[1],ring3_cs[2],ring3_cs[3],
                              ring3_cs[4],ring3_cs[5],ring3_cs[6],ring3_cs[7]});
        b.put(kGdtBase+0x40,{ring3_ss[0],ring3_ss[1],ring3_ss[2],ring3_ss[3],
                              ring3_ss[4],ring3_ss[5],ring3_ss[6],ring3_ss[7]});
        b.put(kGdtBase+0x58,{tss[0],tss[1],tss[2],tss[3],tss[4],tss[5],tss[6],tss[7]});
        b.put(kIdtBase+13*8,{0x00,0x03,0x30,0x00,0x00,uint8_t(0x80|gate_type),0x00,0x00});
        b.put(0x00000702,{0x00,0x01,0x28,0x00}); // SP0:SS0 = 0100:0028.
        for (std::size_t i=0;i<ring3_program.size();++i)
            b.memory[ring3_code_base+0x0400+uint32_t(i)]=ring3_program[i];
        for (std::size_t i=0;i<sizeof(return_handler);++i)
            b.memory[kHandlerBase+kHandlerIp+uint32_t(i)]=return_handler[i];
        b.memory[kHandlerBase+kHandlerIp+9]=fault_length;
        b.put(kStackBase+0x0080,{0x00,0x04,uint8_t(ring3_cs_selector),uint8_t(ring3_cs_selector>>8),
                                  0x02,0x02,0x00,0x01,uint8_t(ring3_ss_selector),
                                  uint8_t(ring3_ss_selector>>8)});

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
        b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x020e,wait);
        check(b.memory[kGdtBase+0x5d]==0x83,"event fixture LTR did not mark TR busy");
        b.step(kCodeBase+0x020e,0xcf,ring3_cs_selector,0x0400,wait);
        if (!software_interrupt)
            b.step(ring3_code_base+0x0400,0xb8,ring3_cs_selector,fault_ip,wait);
        const uint16_t saved_flags=b.d.flags_o;
        const unsigned retired_before=b.retired;
        b.data_transfers.clear();
        bool event_seen=false,handler_entered=false;
        for (unsigned cycle=0;cycle<50000 && !b.d.fault_o &&
             b.retired==retired_before;++cycle) {
            b.tick(wait);
            event_seen=event_seen || b.d.event_o;
            if (b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp) {
                handler_entered=true;
                break;
            }
        }
        const bool event_committed=event_seen && handler_entered && !b.d.fault_o && b.d.event_packet_valid_o &&
              b.d.event_packet_protected_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_restartable_o && b.d.event_vector_o==13 &&
              b.d.event_packet_error_code_o==fault_error &&
              b.d.event_packet_saved_cs_o==ring3_cs_selector &&
              b.d.event_packet_saved_ip_o==fault_ip &&
              b.d.event_packet_saved_flags_o==saved_flags &&
              b.d.event_packet_saved_sp_o==0x0100 && b.retired==retired_before &&
              b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp &&
              uint16_t(b.d.segs_o>>32)==kSsSelector && b.reg(4)==0x00f4;
        if (!event_committed) {
            std::cerr<<"outer-event gate="<<unsigned(gate_type)<<" event-seen="<<unsigned(event_seen)
                     <<" handler-entered="<<unsigned(handler_entered)<<" event="<<unsigned(b.d.event_o)
                     <<" fault="<<unsigned(b.d.fault_o)<<" fault_code="<<unsigned(b.d.fault_code_o)
                     <<" vector="<<unsigned(b.d.event_vector_o)<<" packet="<<unsigned(b.d.event_packet_valid_o)
                     <<" error="<<unsigned(b.d.event_packet_error_valid_o)<<":"<<std::hex
                     <<b.d.event_packet_error_code_o<<" expected-error="<<fault_error
                     <<" saved="<<b.d.event_packet_saved_cs_o<<":"
                     <<b.d.event_packet_saved_ip_o<<" SP="<<b.reg(4)<<" CS:IP="<<b.cs()<<":"
                     <<b.d.ip_o<<" SS="<<uint16_t(b.d.segs_o>>32)<<" retired="<<std::dec
                     <<b.retired<<" expected-retired="<<retired_before<<" transfers="
                     <<b.data_transfers.size()<<'\n';
            for (const auto& transfer:b.data_transfers)
                std::cerr<<(transfer.write?'W':'R')<<" 0x"<<std::hex<<transfer.address
                         <<" size="<<std::dec<<unsigned(transfer.size)<<'\n';
            throw std::runtime_error("ring-3 #GP did not switch to the TSS ring-0 stack and commit its event frame");
        }
        const uint8_t expected_frame[]={
            uint8_t(fault_error),uint8_t(fault_error>>8),uint8_t(fault_ip),uint8_t(fault_ip>>8),
            uint8_t(ring3_cs_selector),uint8_t(ring3_cs_selector>>8),
            uint8_t(saved_flags),uint8_t(saved_flags>>8),
            0x00,0x01,uint8_t(ring3_ss_selector),uint8_t(ring3_ss_selector>>8)
        };
        for (unsigned i=0;i<sizeof(expected_frame);++i)
            check(b.memory.at(kStackBase+0x00f4+i)==expected_frame[i],
                  "privilege-changing event frame bytes/order are incorrect");
        check(b.d.flags_o==(gate_type==6 ? uint16_t(saved_flags&0xfcff) :
                                             uint16_t(saved_flags&0xfeff)),
              "interrupt/trap gate IF/TF handling mismatch");
        const auto tss_pair=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
            return !t.write && t.address==0x00000702 && t.size==4;
        });
        const auto stack_descriptor=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
            return !t.write && t.address==kGdtBase+0x28;
        });
        const auto first_frame_write=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
            return t.write && t.address==kStackBase+0x00fe;
        });
        check(tss_pair!=b.data_transfers.end() && stack_descriptor!=b.data_transfers.end() &&
              first_frame_write!=b.data_transfers.end() &&
              tss_pair<stack_descriptor && stack_descriptor<first_frame_write,
              "event delivery wrote the new stack before reading TSS and validating SS0");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return t.write && t.address>=ring3_stack_base && t.address<ring3_stack_base+0x100;
              }),"privilege-changing event wrote to the old ring-3 stack");

        b.step(kHandlerBase+kHandlerIp,0x83,kHandlerSelector,kHandlerIp+3,wait);
        b.step(kHandlerBase+kHandlerIp+3,0x55,kHandlerSelector,kHandlerIp+4,wait);
        b.step(kHandlerBase+kHandlerIp+4,0x89,kHandlerSelector,kHandlerIp+6,wait);
        b.step(kHandlerBase+kHandlerIp+6,0x83,kHandlerSelector,kHandlerIp+10,wait);
        b.step(kHandlerBase+kHandlerIp+10,0x5d,kHandlerSelector,kHandlerIp+11,wait);
        b.step(kHandlerBase+kHandlerIp+11,0xcf,ring3_cs_selector,successor_ip,wait);
        check(b.cs()==ring3_cs_selector && uint16_t(b.d.segs_o>>32)==ring3_ss_selector &&
              b.reg(4)==0x0100 && b.d.flags_o==saved_flags,
              "outer IRET did not restore the interrupted ring-3 state after event delivery");
        b.step(ring3_code_base+successor_ip,0x90,ring3_cs_selector,successor_ip+1,wait);
        check(!b.d.halted_o && b.d.ip_o==successor_ip+1,
              "ring-3 handler return missed its exact unprivileged successor");
        ++executions;
    }
    check(executions==8,"protected event delivery did not cover gate types, software DPL faults and READY modes");
    std::cout<<"PASS: protected interrupt/trap gates switch ring-3 faults to the TSS ring-0 stack, enforce software INT gate DPL, build exact frames, and outer-IRET to exact successors in both READY modes\n";
}

static void protected_event_ring12_delivery() {
    using namespace protected_mode_fixture;
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00, 0x8e,0xd0,       // Install ring-0 SS.
        0xbc,0x80,0x00,                   // Install ring-0 SP.
        0xb8,0x68,0x00, 0x0f,0x00,0xd8, // LTR ring-0 TSS.
        0xcf, 0xf4
    };
    struct Level {
        unsigned cpl;
        uint16_t code_selector, stack_selector;
        uint32_t code_base, stack_base;
        uint32_t code_descriptor, stack_descriptor;
        uint8_t code_access, stack_access;
    };
    const Level levels[]={
        {1,0x0049,0x0051,0x00081000,0x00080000,0x48,0x50,0xba,0xb2},
        {2,0x005a,0x0062,0x00083000,0x00082000,0x58,0x60,0xda,0xd2}
    };
    constexpr uint16_t fault_ip=0x0400;
    constexpr uint16_t successor_ip=0x0402;
    constexpr uint16_t ring_level_sp=0x0100;
    constexpr uint16_t saved_flags=0x0202;
    constexpr uint16_t idt_error=0x006a;
    constexpr uint32_t tss_base=0x00000700;
    const uint8_t repair_handler[]={
        0x83,0xc4,0x02,       // Discard #GP error code.
        0x55,                 // Preserve BP.
        0x89,0xe5,             // BP = SP.
        0x83,0x46,0x02,0x02,  // Skip the rejected two-byte INT instruction.
        0x5d,0xcf
    };
    auto put_descriptor=[](Bench& b,uint32_t address,uint16_t limit,
                           uint32_t base,uint8_t access) {
        b.put(address,{uint8_t(limit),uint8_t(limit>>8),uint8_t(base),
                       uint8_t(base>>8),uint8_t(base>>16),access,0,0});
    };
    unsigned executions=0;
    for (const auto& level:levels)
      for (uint8_t gate_type:{uint8_t(6),uint8_t(7)})
        for (bool software_int_allowed:{false,true})
          for (bool wait:{false,true}) {
        const unsigned gate_dpl=software_int_allowed ? level.cpl : level.cpl-1;
        const bool denied=!software_int_allowed;
        const uint16_t expected_saved_ip=denied ? fault_ip : successor_ip;
        const uint16_t expected_stack_pointer=uint16_t(0x0100-(denied ? 12 : 10));
        const uint16_t expected_retired_delta=denied ? 0 : 1;
        const uint8_t ring_program[]={0xcd,0x0d,0x90}; // INT 13h; exact successor.
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x40]=0x77; // Extend GDT through ring-2 code/stack and the TSS.
        for (const auto& descriptor_level:levels) {
            put_descriptor(b,kGdtBase+descriptor_level.code_descriptor,0x0fff,
                           descriptor_level.code_base,descriptor_level.code_access);
            put_descriptor(b,kGdtBase+descriptor_level.stack_descriptor,0x0fff,
                           descriptor_level.stack_base,descriptor_level.stack_access);
        }
        b.put(kGdtBase+0x68,{0x2b,0x00,0x00,0x07,0x00,0x81,0x00,0x00});
        b.put(kIdtBase+13*8,{0x00,0x03,0x30,0x00,0x00,
                             uint8_t(0x80|(gate_dpl<<5)|gate_type),0x00,0x00});
        b.put(tss_base+2,{0x00,0x01,0x28,0x00}); // SP0:SS0 = 0100:0028.
        for (std::size_t i=0;i<sizeof(ring_program);++i)
            b.memory[level.code_base+fault_ip+uint32_t(i)]=ring_program[i];
        b.memory[kHandlerBase+kHandlerIp]=0xcf; // Successful INT returns directly.
        if (denied)
            for (std::size_t i=0;i<sizeof(repair_handler);++i)
                b.memory[kHandlerBase+kHandlerIp+uint32_t(i)]=repair_handler[i];
        for (uint32_t offset=0x00f0;offset<0x0110;++offset)
            b.memory[level.stack_base+offset]=0xa5;

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
        b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x020e,wait);
        check(b.memory[kGdtBase+0x6d]==0x83,
              "ring-1/2 event fixture LTR did not mark the TSS busy");
        b.put(kStackBase+0x0080,{uint8_t(fault_ip),uint8_t(fault_ip>>8),
                                  uint8_t(level.code_selector),uint8_t(level.code_selector>>8),
                                  uint8_t(saved_flags),uint8_t(saved_flags>>8),
                                  0x00,0x01,uint8_t(level.stack_selector),
                                  uint8_t(level.stack_selector>>8)});
        b.step(kCodeBase+0x020e,0xcf,level.code_selector,fault_ip,wait);
        check(uint16_t(b.d.segs_o>>32)==level.stack_selector &&
              b.reg(4)==ring_level_sp && b.d.flags_o==saved_flags,
              "initial outer IRET did not establish the requested ring-1/2 context");

        const unsigned retired_before=b.retired;
        b.data_transfers.clear();
        bool event_seen=false,handler_entered=false;
        for (unsigned cycle=0;cycle<50000 && !b.d.fault_o &&
             b.retired==retired_before;++cycle) {
            b.tick(wait);
            event_seen=event_seen || b.d.event_o;
            if (b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp) {
                handler_entered=true;
                break;
            }
        }
        const bool event_committed=event_seen && handler_entered && !b.d.fault_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              bool(b.d.event_packet_error_valid_o)==denied &&
              bool(b.d.event_packet_restartable_o)==denied &&
              b.d.event_vector_o==13 &&
              b.d.event_packet_error_code_o==(denied ? idt_error : 0) &&
              b.d.event_packet_saved_cs_o==level.code_selector &&
              b.d.event_packet_saved_ip_o==expected_saved_ip &&
              b.d.event_packet_saved_flags_o==saved_flags &&
              b.d.event_packet_saved_sp_o==ring_level_sp &&
              b.retired==retired_before+expected_retired_delta &&
              b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp &&
              uint16_t(b.d.segs_o>>32)==kSsSelector &&
              b.reg(4)==expected_stack_pointer;
        if (!event_committed) {
            std::cerr<<"ring-"<<level.cpl<<" INT gate="<<unsigned(gate_type)
                     <<" gate-DPL="<<gate_dpl<<" allowed="<<unsigned(software_int_allowed)
                     <<" wait="<<unsigned(wait)<<" event-seen="<<unsigned(event_seen)
                     <<" handler-entered="<<unsigned(handler_entered)
                     <<" fault="<<unsigned(b.d.fault_o)<<":"<<unsigned(b.d.fault_code_o)
                     <<" vector="
                     <<unsigned(b.d.event_vector_o)<<" packet="
                     <<unsigned(b.d.event_packet_valid_o)<<" error="
                     <<unsigned(b.d.event_packet_error_valid_o)<<":"<<std::hex
                     <<b.d.event_packet_error_code_o<<" saved="
                     <<b.d.event_packet_saved_cs_o<<":"<<b.d.event_packet_saved_ip_o
                     <<" SP="<<b.reg(4)<<" CS:IP="<<b.cs()<<":"<<b.d.ip_o
                     <<" retired="<<std::dec<<b.retired<<" expected-retired="
                     <<retired_before+expected_retired_delta<<" transfers="
                     <<b.data_transfers.size()<<" TSS.SP0:SS0="<<std::hex
                     <<unsigned(b.memory[tss_base+2])+(unsigned(b.memory[tss_base+3])<<8)
                     <<":"<<unsigned(b.memory[tss_base+4])+(unsigned(b.memory[tss_base+5])<<8)<<'\n';
            for (const auto& transfer:b.data_transfers)
                std::cerr<<(transfer.write?'W':'R')<<" 0x"<<std::hex<<transfer.address
                         <<" value=0x"<<unsigned(transfer.value)
                         <<" size="<<std::dec<<unsigned(transfer.size)<<'\n';
            throw std::runtime_error("ring-1/2 software INT gate delivery did not commit the expected privilege transition");
        }

        std::vector<uint8_t> expected_frame;
        auto append_word=[&expected_frame](uint16_t word) {
            expected_frame.push_back(uint8_t(word));
            expected_frame.push_back(uint8_t(word>>8));
        };
        if (denied) append_word(idt_error);
        append_word(expected_saved_ip);
        append_word(level.code_selector);
        append_word(saved_flags);
        append_word(ring_level_sp);
        append_word(level.stack_selector);
        for (std::size_t i=0;i<expected_frame.size();++i)
            check(b.memory.at(kStackBase+expected_stack_pointer+uint32_t(i))==expected_frame[i],
                  "ring-1/2 event frame bytes/order are incorrect");
        check(b.d.flags_o==(gate_type==6 ? uint16_t(saved_flags&0xfcff) :
                                                   uint16_t(saved_flags&0xfeff)),
              "ring-1/2 interrupt/trap gate IF/TF handling mismatch");
        const auto tss_pair=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),
            [tss_base](const auto& t) {
                return !t.write && t.address==tss_base+2 && t.size==4;
            });
        const auto stack_descriptor=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),
            [](const auto& t) { return !t.write && t.address==kGdtBase+0x28; });
        const auto first_frame_write=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),
            [](const auto& t) { return t.write && t.address==kStackBase+0x00fe; });
        check(tss_pair!=b.data_transfers.end() && stack_descriptor!=b.data_transfers.end() &&
              first_frame_write!=b.data_transfers.end() &&
              tss_pair<stack_descriptor && stack_descriptor<first_frame_write,
              "ring-1/2 event wrote the new stack before reading TSS and validating SS0");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),
                  [&level](const auto& t) {
                      return t.write && t.address>=level.stack_base+0x00f0 &&
                             t.address<level.stack_base+0x0110;
                  }),"ring-1/2 event wrote to the interrupted stack");
        for (uint32_t offset=0x00f0;offset<0x0110;++offset)
            check(b.memory.at(level.stack_base+offset)==0xa5,
                  "ring-1/2 interrupted stack contents changed during event entry");

        if (denied) {
            b.step(kHandlerBase+kHandlerIp,0x83,kHandlerSelector,kHandlerIp+3,wait);
            b.step(kHandlerBase+kHandlerIp+3,0x55,kHandlerSelector,kHandlerIp+4,wait);
            b.step(kHandlerBase+kHandlerIp+4,0x89,kHandlerSelector,kHandlerIp+6,wait);
            b.step(kHandlerBase+kHandlerIp+6,0x83,kHandlerSelector,kHandlerIp+10,wait);
            b.step(kHandlerBase+kHandlerIp+10,0x5d,kHandlerSelector,kHandlerIp+11,wait);
            b.step(kHandlerBase+kHandlerIp+11,0xcf,level.code_selector,successor_ip,wait);
        } else {
            b.step(kHandlerBase+kHandlerIp,0xcf,level.code_selector,successor_ip,wait);
        }
        check(b.cs()==level.code_selector && uint16_t(b.d.segs_o>>32)==level.stack_selector &&
              b.reg(4)==ring_level_sp && b.d.flags_o==saved_flags,
              "outer IRET did not restore the ring-1/2 state after software INT");
        b.step(level.code_base+successor_ip,0x90,level.code_selector,successor_ip+1,wait);
        check(!b.d.halted_o && b.cs()==level.code_selector &&
              b.d.ip_o==successor_ip+1 && b.reg(4)==ring_level_sp,
              "ring-1/2 handler return missed its exact unprivileged successor");
        ++executions;
    }
    check(executions==16,
          "ring-1/2 event delivery did not cover both privilege levels, gate types, DPL outcomes and READY modes");
    std::cout<<"PASS: 16 reachable CPL1/CPL2 software INT cases verify interrupt/trap gate DPL decisions, #GP(IDT selector), TSS ring-0 stacks, exact outer frames and IRET successors in both READY modes\n";
}

static void protected_event_ring12_exception_delivery() {
    using namespace protected_mode_fixture;
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00, 0x8e,0xd0,
        0xbc,0x80,0x00,
        0xb8,0x68,0x00, 0x0f,0x00,0xd8,
        0xcf,0xf4
    };
    struct Level {
        unsigned cpl;
        uint16_t code_selector, stack_selector;
        uint32_t code_base, stack_base;
        uint32_t code_descriptor, stack_descriptor;
        uint8_t code_access, stack_access;
    };
    const Level levels[]={
        {1,0x0049,0x0051,0x00081000,0x00080000,0x48,0x50,0xba,0xb2},
        {2,0x005a,0x0062,0x00083000,0x00082000,0x58,0x60,0xda,0xd2}
    };
    constexpr uint16_t fault_ip=0x0400;
    constexpr uint16_t fault_length=5; // 0F 01 /3 LIDT m16.
    constexpr uint16_t successor_ip=fault_ip+fault_length;
    constexpr uint16_t ring_level_sp=0x0100;
    constexpr uint16_t saved_flags=0x0202;
    constexpr uint32_t tss_base=0x00000700;
    const uint8_t fault_program[]={0x0f,0x01,0x1e,0x10,0x00,0x90};
    const uint8_t repair_handler[]={
        0x83,0xc4,0x02,       // Discard the #GP error code.
        0x55,
        0x89,0xe5,
        0x83,0x46,0x02,0x05,  // Skip the five-byte privileged LIDT.
        0x5d,0xcf
    };
    auto put_descriptor=[](Bench& b,uint32_t address,uint16_t limit,
                           uint32_t base,uint8_t access) {
        b.put(address,{uint8_t(limit),uint8_t(limit>>8),uint8_t(base),
                       uint8_t(base>>8),uint8_t(base>>16),access,0,0});
    };
    unsigned executions=0;
    for (const auto& level:levels)
      for (uint8_t gate_type:{uint8_t(6),uint8_t(7)})
        for (uint8_t gate_dpl:{uint8_t(0),uint8_t(3)})
          for (bool wait:{false,true}) {
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x40]=0x77;
        for (const auto& descriptor_level:levels) {
            put_descriptor(b,kGdtBase+descriptor_level.code_descriptor,0x0fff,
                           descriptor_level.code_base,descriptor_level.code_access);
            put_descriptor(b,kGdtBase+descriptor_level.stack_descriptor,0x0fff,
                           descriptor_level.stack_base,descriptor_level.stack_access);
        }
        b.put(kGdtBase+0x68,{0x2b,0x00,0x00,0x07,0x00,0x81,0x00,0x00});
        b.put(kIdtBase+13*8,{0x00,0x03,0x30,0x00,0x00,
                             uint8_t(0x80|(gate_dpl<<5)|gate_type),0x00,0x00});
        b.put(tss_base+2,{0x00,0x01,0x28,0x00});
        for (std::size_t i=0;i<sizeof(fault_program);++i)
            b.memory[level.code_base+fault_ip+uint32_t(i)]=fault_program[i];
        for (std::size_t i=0;i<sizeof(repair_handler);++i)
            b.memory[kHandlerBase+kHandlerIp+uint32_t(i)]=repair_handler[i];
        for (uint32_t offset=0x00f0;offset<0x0110;++offset)
            b.memory[level.stack_base+offset]=0xa5;

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
        b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x020e,wait);
        check(b.memory[kGdtBase+0x6d]==0x83,
              "ring-1/2 exception fixture LTR did not mark the TSS busy");
        b.put(kStackBase+0x0080,{uint8_t(fault_ip),uint8_t(fault_ip>>8),
                                  uint8_t(level.code_selector),uint8_t(level.code_selector>>8),
                                  uint8_t(saved_flags),uint8_t(saved_flags>>8),
                                  0x00,0x01,uint8_t(level.stack_selector),
                                  uint8_t(level.stack_selector>>8)});
        b.step(kCodeBase+0x020e,0xcf,level.code_selector,fault_ip,wait);
        check(uint16_t(b.d.segs_o>>32)==level.stack_selector &&
              b.reg(4)==ring_level_sp && b.d.flags_o==saved_flags,
              "initial outer IRET did not establish the exception fixture ring");

        const unsigned retired_before=b.retired;
        b.data_transfers.clear();
        bool event_seen=false,handler_entered=false;
        for (unsigned cycle=0;cycle<50000 && !b.d.fault_o &&
             b.retired==retired_before;++cycle) {
            b.tick(wait);
            event_seen=event_seen || b.d.event_o;
            if (b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp) {
                handler_entered=true;
                break;
            }
        }
        const uint16_t expected_stack_pointer=0x00f4;
        const bool event_committed=event_seen && handler_entered && !b.d.fault_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_error_valid_o && b.d.event_packet_restartable_o &&
              b.d.event_vector_o==13 && b.d.event_packet_error_code_o==0 &&
              b.d.event_packet_saved_cs_o==level.code_selector &&
              b.d.event_packet_saved_ip_o==fault_ip &&
              b.d.event_packet_saved_flags_o==saved_flags &&
              b.d.event_packet_saved_sp_o==ring_level_sp &&
              b.retired==retired_before && b.cs()==kHandlerSelector &&
              b.d.ip_o==kHandlerIp && uint16_t(b.d.segs_o>>32)==kSsSelector &&
              b.reg(4)==expected_stack_pointer;
        if (!event_committed) {
            std::cerr<<"ring-"<<level.cpl<<" LIDT gate="<<unsigned(gate_type)
                     <<" gate-DPL="<<unsigned(gate_dpl)<<" wait="<<unsigned(wait)
                     <<" event-seen="<<unsigned(event_seen)
                     <<" handler-entered="<<unsigned(handler_entered)
                     <<" fault="<<unsigned(b.d.fault_o)<<":"<<unsigned(b.d.fault_code_o)
                     <<" vector="<<unsigned(b.d.event_vector_o)<<" packet="
                     <<unsigned(b.d.event_packet_valid_o)<<" error="
                     <<unsigned(b.d.event_packet_error_valid_o)<<":"<<std::hex
                     <<b.d.event_packet_error_code_o<<" saved="
                     <<b.d.event_packet_saved_cs_o<<":"<<b.d.event_packet_saved_ip_o
                     <<" SP="<<b.reg(4)<<" CS:IP="<<b.cs()<<":"<<b.d.ip_o
                     <<" transfers="<<std::dec<<b.data_transfers.size()<<'\n';
            for (const auto& transfer:b.data_transfers)
                std::cerr<<(transfer.write?'W':'R')<<" 0x"<<std::hex<<transfer.address
                         <<" value=0x"<<unsigned(transfer.value)
                         <<" size="<<std::dec<<unsigned(transfer.size)<<'\n';
            throw std::runtime_error("ring-1/2 privileged-instruction #GP did not enter the ring-0 event gate");
        }

        const uint8_t expected_frame[]={
            0x00,0x00,uint8_t(fault_ip),uint8_t(fault_ip>>8),
            uint8_t(level.code_selector),uint8_t(level.code_selector>>8),
            uint8_t(saved_flags),uint8_t(saved_flags>>8),
            0x00,0x01,uint8_t(level.stack_selector),uint8_t(level.stack_selector>>8)
        };
        for (unsigned i=0;i<sizeof(expected_frame);++i)
            check(b.memory.at(kStackBase+expected_stack_pointer+i)==expected_frame[i],
                  "ring-1/2 #GP event frame bytes/order are incorrect");
        check(b.d.flags_o==(gate_type==6 ? uint16_t(saved_flags&0xfcff) :
                                                   uint16_t(saved_flags&0xfeff)),
              "ring-1/2 exception interrupt/trap gate IF/TF handling mismatch");
        const auto tss_pair=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),
            [tss_base](const auto& t) { return !t.write && t.address==tss_base+2 && t.size==4; });
        const auto stack_descriptor=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),
            [](const auto& t) { return !t.write && t.address==kGdtBase+0x28; });
        const auto first_frame_write=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),
            [](const auto& t) { return t.write && t.address==kStackBase+0x00fe; });
        check(tss_pair!=b.data_transfers.end() && stack_descriptor!=b.data_transfers.end() &&
              first_frame_write!=b.data_transfers.end() &&
              tss_pair<stack_descriptor && stack_descriptor<first_frame_write,
              "exception event wrote the new stack before reading TSS and validating SS0");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && t.address>=0x0010 && t.address<0x0012;
              }),"privilege-denied LIDT read its pseudo-descriptor operand");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),
                  [&level](const auto& t) {
                      return t.write && t.address>=level.stack_base+0x00f0 &&
                             t.address<level.stack_base+0x0110;
                  }),"ring-1/2 exception event wrote to the interrupted stack");
        for (uint32_t offset=0x00f0;offset<0x0110;++offset)
            check(b.memory.at(level.stack_base+offset)==0xa5,
                  "ring-1/2 interrupted stack contents changed during exception entry");

        b.step(kHandlerBase+kHandlerIp,0x83,kHandlerSelector,kHandlerIp+3,wait);
        b.step(kHandlerBase+kHandlerIp+3,0x55,kHandlerSelector,kHandlerIp+4,wait);
        b.step(kHandlerBase+kHandlerIp+4,0x89,kHandlerSelector,kHandlerIp+6,wait);
        b.step(kHandlerBase+kHandlerIp+6,0x83,kHandlerSelector,kHandlerIp+10,wait);
        b.step(kHandlerBase+kHandlerIp+10,0x5d,kHandlerSelector,kHandlerIp+11,wait);
        b.step(kHandlerBase+kHandlerIp+11,0xcf,level.code_selector,successor_ip,wait);
        check(b.cs()==level.code_selector && uint16_t(b.d.segs_o>>32)==level.stack_selector &&
              b.reg(4)==ring_level_sp && b.d.flags_o==saved_flags,
              "outer IRET did not restore the ring-1/2 context after #GP");
        b.step(level.code_base+successor_ip,0x90,level.code_selector,successor_ip+1,wait);
        check(!b.d.halted_o && b.cs()==level.code_selector &&
              b.d.ip_o==successor_ip+1 && b.reg(4)==ring_level_sp,
              "ring-1/2 exception handler missed the exact LIDT successor");
        ++executions;
    }
    check(executions==16,
          "ring-1/2 exception delivery did not cover both levels, gate types, gate DPL extremes and READY modes");
    std::cout<<"PASS: 16 reachable CPL1/CPL2 LIDT #GP cases confirm exception delivery ignores IDT gate DPL, switches through TSS, writes exact frames and outer-IRETs to the exact successor in both READY modes\n";
}

static void protected_event_ring12_async_delivery(bool nmi_mode) {
    using namespace protected_mode_fixture;
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00, 0x8e,0xd0,
        0xbc,0x80,0x00,
        0xb8,0x68,0x00, 0x0f,0x00,0xd8,
        0xcf,0xf4
    };
    struct Level {
        unsigned cpl;
        uint16_t code_selector, stack_selector;
        uint32_t code_base, stack_base;
        uint32_t code_descriptor, stack_descriptor;
        uint8_t code_access, stack_access;
    };
    const Level levels[]={
        {1,0x0049,0x0051,0x00081000,0x00080000,0x48,0x50,0xba,0xb2},
        {2,0x005a,0x0062,0x00083000,0x00082000,0x58,0x60,0xda,0xd2}
    };
    constexpr uint16_t first_ip=0x0400;
    constexpr uint16_t successor_ip=0x0401;
    constexpr uint16_t ring_level_sp=0x0100;
    constexpr uint16_t saved_flags=0x0202;
    const uint8_t vector=nmi_mode ? uint8_t(2) : uint8_t(13);
    const char* source_name=nmi_mode ? "NMI" : "external INTR";
    constexpr uint32_t tss_base=0x00000700;
    auto put_descriptor=[](Bench& b,uint32_t address,uint16_t limit,
                           uint32_t base,uint8_t access) {
        b.put(address,{uint8_t(limit),uint8_t(limit>>8),uint8_t(base),
                       uint8_t(base>>8),uint8_t(base>>16),access,0,0});
    };
    unsigned executions=0;
    for (const auto& level:levels)
      for (uint8_t gate_type:{uint8_t(6),uint8_t(7)})
        for (bool wait:{false,true}) {
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x40]=0x77;
        for (const auto& descriptor_level:levels) {
            put_descriptor(b,kGdtBase+descriptor_level.code_descriptor,0x0fff,
                           descriptor_level.code_base,descriptor_level.code_access);
            put_descriptor(b,kGdtBase+descriptor_level.stack_descriptor,0x0fff,
                           descriptor_level.stack_base,descriptor_level.stack_access);
        }
        b.put(kGdtBase+0x68,{0x2b,0x00,0x00,0x07,0x00,0x81,0x00,0x00});
        b.put(kIdtBase+vector*8,{0x00,0x03,0x30,0x00,0x00,
                                 uint8_t(0x80|gate_type),0x00,0x00}); // DPL=0.
        b.put(tss_base+2,{0x00,0x01,0x28,0x00});
        b.memory[level.code_base+first_ip]=0x90;
        b.memory[level.code_base+successor_ip]=0x90;
        b.memory[kHandlerBase+kHandlerIp]=0xcf;
        for (uint32_t offset=0x00f0;offset<0x0110;++offset)
            b.memory[level.stack_base+offset]=0xa5;

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
        b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x020e,wait);
        check(b.memory[kGdtBase+0x6d]==0x83,
              "ring-1/2 external-event fixture LTR did not mark the TSS busy");
        b.put(kStackBase+0x0080,{uint8_t(first_ip),uint8_t(first_ip>>8),
                                  uint8_t(level.code_selector),uint8_t(level.code_selector>>8),
                                  uint8_t(saved_flags),uint8_t(saved_flags>>8),
                                  0x00,0x01,uint8_t(level.stack_selector),
                                  uint8_t(level.stack_selector>>8)});
        b.step(kCodeBase+0x020e,0xcf,level.code_selector,first_ip,wait);
        check(uint16_t(b.d.segs_o>>32)==level.stack_selector &&
              b.reg(4)==ring_level_sp && b.d.flags_o==saved_flags,
              "initial outer IRET did not establish the external-event ring");

        const unsigned retired_before=b.retired;
        const unsigned acknowledgements_before=b.acknowledgements;
        b.data_transfers.clear();
        if (nmi_mode) b.d.nmi_i=1;
        else {
            b.d.intr_i=1;
            b.acknowledge=true;
            b.interrupt_vector=vector;
        }
        bool event_seen=false,handler_entered=false;
        bool first_nop_retired=false;
        for (unsigned cycle=0;cycle<50000 && !b.d.fault_o &&
             b.cs()!=kHandlerSelector;++cycle) {
            b.tick(wait);
            if (b.d.retire_o) {
                check(!first_nop_retired && b.d.retire_pc_o==level.code_base+first_ip &&
                      b.d.retire_opcode_o==0x90 && b.cs()==level.code_selector &&
                      b.d.ip_o==successor_ip,
                      "external INTR was not sampled after exactly the first ring-level NOP");
                first_nop_retired=true;
            }
            event_seen=event_seen || b.d.event_o;
            if (b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp) {
                handler_entered=true;
                b.d.intr_i=0;
                b.d.nmi_i=0;
                b.acknowledge=false;
                break;
            }
        }
        constexpr uint16_t expected_stack_pointer=0x00f6;
        const bool event_committed=event_seen && handler_entered && !b.d.fault_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              !b.d.event_packet_error_valid_o && !b.d.event_packet_restartable_o &&
              b.d.event_vector_o==vector && b.d.event_packet_error_code_o==0 &&
              b.d.event_packet_saved_cs_o==level.code_selector &&
              b.d.event_packet_saved_ip_o==successor_ip &&
              b.d.event_packet_saved_flags_o==saved_flags &&
              b.d.event_packet_saved_sp_o==ring_level_sp &&
              (nmi_mode ? (b.acknowledgements==acknowledgements_before &&
                           b.d.nmi_blocked_o && !b.d.nmi_pending_o) :
                          b.acknowledgements>acknowledgements_before) &&
              first_nop_retired && b.retired==retired_before+1 &&
              b.cs()==kHandlerSelector &&
              b.d.ip_o==kHandlerIp && uint16_t(b.d.segs_o>>32)==kSsSelector &&
              b.reg(4)==expected_stack_pointer;
        if (!event_committed) {
            b.d.intr_i=0;
            b.d.nmi_i=0;
            b.acknowledge=false;
            std::cerr<<"ring-"<<level.cpl<<" "<<source_name<<" vector="<<unsigned(vector)
                     <<" gate="<<unsigned(gate_type)<<" gate-DPL=0 wait="
                     <<unsigned(wait)<<" event-seen="<<unsigned(event_seen)
                     <<" handler-entered="<<unsigned(handler_entered)
                     <<" ack-count="<<b.acknowledgements<<" fault="
                     <<unsigned(b.d.fault_o)<<":"<<unsigned(b.d.fault_code_o)
                     <<" packet="<<unsigned(b.d.event_packet_valid_o)<<" saved="
                     <<b.d.event_packet_saved_cs_o<<":"<<std::hex
                     <<b.d.event_packet_saved_ip_o<<" SP="<<b.reg(4)
                     <<" CS:IP="<<b.cs()<<":"<<b.d.ip_o<<" transfers="
                     <<std::dec<<b.data_transfers.size()<<'\n';
            for (const auto& transfer:b.data_transfers)
                std::cerr<<(transfer.write?'W':'R')<<" 0x"<<std::hex<<transfer.address
                         <<" value=0x"<<unsigned(transfer.value)
                         <<" size="<<std::dec<<unsigned(transfer.size)<<'\n';
            throw std::runtime_error(std::string("ring-1/2 ")+source_name+
                                     " did not enter the DPL-0 gate");
        }

        const uint8_t expected_frame[]={
            uint8_t(successor_ip),uint8_t(successor_ip>>8),
            uint8_t(level.code_selector),uint8_t(level.code_selector>>8),
            uint8_t(saved_flags),uint8_t(saved_flags>>8),
            0x00,0x01,uint8_t(level.stack_selector),uint8_t(level.stack_selector>>8)
        };
        for (unsigned i=0;i<sizeof(expected_frame);++i)
            check(b.memory.at(kStackBase+expected_stack_pointer+i)==expected_frame[i],
              "ring-1/2 asynchronous-event frame bytes/order are incorrect");
        check(b.d.flags_o==(gate_type==6 ? uint16_t(saved_flags&0xfcff) :
                                                   uint16_t(saved_flags&0xfeff)),
              "ring-1/2 asynchronous interrupt/trap gate IF/TF handling mismatch");
        const auto tss_pair=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),
            [tss_base](const auto& t) { return !t.write && t.address==tss_base+2 && t.size==4; });
        const auto stack_descriptor=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),
            [](const auto& t) { return !t.write && t.address==kGdtBase+0x28; });
        const auto first_frame_write=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),
            [](const auto& t) { return t.write && t.address==kStackBase+0x00fe; });
        check(tss_pair!=b.data_transfers.end() && stack_descriptor!=b.data_transfers.end() &&
              first_frame_write!=b.data_transfers.end() &&
              tss_pair<stack_descriptor && stack_descriptor<first_frame_write,
              "asynchronous event wrote the new stack before reading TSS and validating SS0");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),
                  [&level](const auto& t) {
                      return t.write && t.address>=level.stack_base+0x00f0 &&
                             t.address<level.stack_base+0x0110;
                  }),"asynchronous event wrote to the interrupted ring-1/2 stack");
        for (uint32_t offset=0x00f0;offset<0x0110;++offset)
            check(b.memory.at(level.stack_base+offset)==0xa5,
                  "ring-1/2 stack contents changed during asynchronous event entry");

        b.step(kHandlerBase+kHandlerIp,0xcf,level.code_selector,successor_ip,wait);
        check(b.cs()==level.code_selector && uint16_t(b.d.segs_o>>32)==level.stack_selector &&
              b.reg(4)==ring_level_sp && b.d.flags_o==saved_flags,
              "outer IRET did not restore ring-1/2 state after asynchronous event");
        if (nmi_mode)
            check(!b.d.nmi_blocked_o && !b.d.nmi_pending_o,
                  "outer IRET did not release the serviced ring-1/2 NMI");
        b.step(level.code_base+successor_ip,0x90,level.code_selector,successor_ip+1,wait);
        check(!b.d.halted_o && b.cs()==level.code_selector &&
              b.d.ip_o==successor_ip+1 && b.reg(4)==ring_level_sp,
              "ring-1/2 asynchronous handler missed the exact successor");
        ++executions;
    }
    check(executions==8,
          "ring-1/2 asynchronous-event delivery did not cover levels, gate types and READY modes");
    std::cout<<"PASS: 8 reachable CPL1/CPL2 "<<source_name
             <<" cases ignore DPL-0 gate restrictions, switch through TSS, write exact no-error outer frames and IRET to the exact successor in both READY modes\n";
}

static void protected_event_task_gate_delivery() {
    using namespace protected_mode_fixture;
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00, 0x8e,0xd0,
        0xbc,0x80,0x00,
        0xb8,0x68,0x00, 0x0f,0x00,0xd8,
        0xcf,0xf4
    };
    struct Level {
        unsigned cpl;
        uint16_t code_selector,stack_selector;
        uint32_t code_base,stack_base,code_descriptor,stack_descriptor;
        uint8_t code_access,stack_access;
    };
    const Level levels[]={
        {1,0x0049,0x0051,0x00081000,0x00080000,0x48,0x50,0xba,0xb2},
        {2,0x005a,0x0062,0x00083000,0x00082000,0x58,0x60,0xda,0xd2}
    };
    constexpr uint16_t first_ip=0x0400;
    constexpr uint16_t ring_level_sp=0x0100;
    constexpr uint16_t saved_flags=0x0202;
    constexpr uint16_t current_tss_selector=0x0068;
    constexpr uint16_t task_gate_tss_selector=0x0078;
    constexpr uint32_t current_tss_base=0x00000700;
    constexpr uint32_t task_gate_tss_base=0x000a0000;
    const uint16_t task_words[]={
        0x0500,0x0202,0x0201,0x0202,0x0203,0x0204,0x0080,
        0x0205,0x0206,0x0207,0x0010,0x0030,0x0028,0x0010,0x0000
    };
    enum class EventSource { external_intr, software_int, nmi };
    const EventSource event_sources[]={EventSource::external_intr,
                                        EventSource::software_int,
                                        EventSource::nmi};
    auto put_descriptor=[](Bench& b,uint32_t address,uint16_t limit,
                           uint32_t base,uint8_t access) {
        b.put(address,{uint8_t(limit),uint8_t(limit>>8),uint8_t(base),
                       uint8_t(base>>8),uint8_t(base>>16),access,0,0});
    };
    auto put_word=[](Bench& b,uint32_t address,uint16_t value) {
        b.memory[address]=uint8_t(value);
        b.memory[address+1]=uint8_t(value>>8);
    };
    unsigned cases=0;
    for (const auto& level:levels)
      for (bool wait:{false,true})
       for (EventSource source:event_sources) {
        const bool software_int=source==EventSource::software_int;
        const bool nmi_mode=source==EventSource::nmi;
        const uint8_t vector=nmi_mode ? uint8_t(2) : uint8_t(13);
        const uint16_t successor_ip=uint16_t(first_ip+(software_int ? 2 : 1));
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x40]=0x7f; // Include the running TSS and the task-gate TSS.
        for (const auto& descriptor_level:levels) {
            put_descriptor(b,kGdtBase+descriptor_level.code_descriptor,0x0fff,
                           descriptor_level.code_base,descriptor_level.code_access);
            put_descriptor(b,kGdtBase+descriptor_level.stack_descriptor,0x0fff,
                           descriptor_level.stack_base,descriptor_level.stack_access);
        }
        put_descriptor(b,kGdtBase+current_tss_selector,0x002b,
                       current_tss_base,0x81);
        put_descriptor(b,kGdtBase+task_gate_tss_selector,0x002b,
                       task_gate_tss_base,0x81);
        // Present IDT task gate, DPL 0, target TSS selector 0078.
        b.put(kIdtBase+vector*8,{0x00,0x00,uint8_t(task_gate_tss_selector),
                             uint8_t(task_gate_tss_selector>>8),0x00,0x85,0x00,0x00});
        b.put(current_tss_base+2,{0x00,0x01,0x28,0x00}); // SP0:SS0.
        b.memory[level.code_base+first_ip]=software_int ? 0xcd : 0x90;
        if (software_int) b.memory[level.code_base+first_ip+1]=0x0d;
        b.memory[level.code_base+successor_ip]=0x90;
        b.memory[kHandlerBase+0x0500]=software_int ? 0xf4 : 0xcf;
        for (uint32_t offset=0x0070;offset<0x0090;++offset)
            b.memory[kStackBase+offset]=0xa5;
        for (uint32_t offset=0x00f0;offset<0x0110;++offset)
            b.memory[level.stack_base+offset]=0xa5;
        put_word(b,task_gate_tss_base,0xa55a);
        for (unsigned index=0;index<15;++index)
            put_word(b,task_gate_tss_base+0x000e + 2*index,task_words[index]);

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
        b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x020e,wait);
        check(b.memory[kGdtBase+current_tss_selector+5]==0x83,
              "task-gate event fixture LTR did not mark the current TSS busy");
        b.put(kStackBase+0x0080,{uint8_t(first_ip),uint8_t(first_ip>>8),
                                  uint8_t(level.code_selector),uint8_t(level.code_selector>>8),
                                  uint8_t(saved_flags),uint8_t(saved_flags>>8),
                                  0x00,0x01,uint8_t(level.stack_selector),
                                  uint8_t(level.stack_selector>>8)});
        b.step(kCodeBase+0x020e,0xcf,level.code_selector,first_ip,wait);
        check(uint16_t(b.d.segs_o>>32)==level.stack_selector &&
              b.reg(4)==ring_level_sp && b.d.flags_o==saved_flags,
              "task-gate event fixture did not establish CPL1/CPL2 state");

        const unsigned retired_before=b.retired;
        const unsigned acknowledgements_before=b.acknowledgements;
        b.data_transfers.clear();
        if (!software_int) {
            if (nmi_mode) b.d.nmi_i=1;
            else {
                b.d.intr_i=1;
                b.acknowledge=true;
                b.interrupt_vector=vector;
            }
        }
        bool first_instruction_retired=false;
        bool event_seen=false,task_entered=false;
        bool packet_valid=false,packet_error_valid=false,packet_restartable=false;
        uint8_t packet_vector=0;
        uint16_t packet_error=0,packet_cs=0,packet_ip=0,packet_flags=0,packet_sp=0;
        for (unsigned cycle=0;cycle<100000 && !b.d.fault_o &&
             !(b.cs()==0x0030 && b.d.ip_o==0x0500);++cycle) {
            b.tick(wait);
            if (b.d.retire_o) {
                check(!software_int && !first_instruction_retired &&
                      b.d.retire_pc_o==level.code_base+first_ip &&
                      b.d.retire_opcode_o==0x90 && b.cs()==level.code_selector &&
                      b.d.ip_o==successor_ip,
                      "external task-gate interrupt was not sampled after exactly one NOP");
                first_instruction_retired=true;
            }
            if (b.d.event_o) {
                event_seen=true;
                packet_valid=b.d.event_packet_valid_o;
                packet_error_valid=b.d.event_packet_error_valid_o;
                packet_restartable=b.d.event_packet_restartable_o;
                packet_vector=b.d.event_vector_o;
                packet_error=b.d.event_packet_error_code_o;
                packet_cs=b.d.event_packet_saved_cs_o;
                packet_ip=b.d.event_packet_saved_ip_o;
                packet_flags=b.d.event_packet_saved_flags_o;
                packet_sp=b.d.event_packet_saved_sp_o;
            }
            if (b.cs()==0x0030 && b.d.ip_o==0x0500) {
                task_entered=true;
                b.d.intr_i=0;
                b.d.nmi_i=0;
                b.acknowledge=false;
            }
        }
        const uint16_t expected_packet_ip=software_int ? first_ip : successor_ip;
        const uint16_t expected_error=software_int ? uint16_t(0x006a) : uint16_t(0);
        check(task_entered && event_seen && !b.d.fault_o &&
              b.d.event_packet_valid_o && (b.d.msw_o&0x0008) &&
              packet_valid && packet_vector==vector &&
              packet_error_valid==software_int && packet_error==expected_error &&
              packet_restartable==software_int &&
              packet_cs==level.code_selector && packet_ip==expected_packet_ip &&
              packet_flags==saved_flags && packet_sp==ring_level_sp &&
              (software_int ? (b.acknowledgements==acknowledgements_before &&
                               !first_instruction_retired) :
               nmi_mode ? (b.acknowledgements==acknowledgements_before &&
                           first_instruction_retired && b.d.nmi_blocked_o &&
                           !b.d.nmi_pending_o) :
                          (b.acknowledgements==acknowledgements_before+1 &&
                           first_instruction_retired)) &&
              b.cs()==0x0030 && b.d.ip_o==0x0500 &&
              uint16_t(b.d.segs_o>>32)==0x0028 &&
              b.reg(4)==(software_int ? 0x007e : 0x0080),
              software_int ?
                "software INT did not take #GP through the DPL-0 task gate with its error word" :
                "external INTR did not enter the DPL-0 task gate without an error word");
        check(uint16_t(b.memory[task_gate_tss_base] |
                       (uint16_t(b.memory[task_gate_tss_base+1])<<8))==current_tss_selector &&
              b.memory[kGdtBase+current_tss_selector+5]==0x83 &&
              b.memory[kGdtBase+task_gate_tss_selector+5]==0x83 &&
              (b.d.flags_o&0x4000),
              "nested task-gate event missed the backlink, busy bits or NT flag");
        check(uint16_t(b.memory[current_tss_base+0x000e] |
                       (uint16_t(b.memory[current_tss_base+0x000f])<<8))==expected_packet_ip &&
              uint16_t(b.memory[current_tss_base+0x0010] |
                       (uint16_t(b.memory[current_tss_base+0x0011])<<8))==saved_flags &&
              uint16_t(b.memory[current_tss_base+0x001a] |
                       (uint16_t(b.memory[current_tss_base+0x001b])<<8))==ring_level_sp &&
              uint16_t(b.memory[current_tss_base+0x0024] |
                       (uint16_t(b.memory[current_tss_base+0x0025])<<8))==level.code_selector &&
              uint16_t(b.memory[current_tss_base+0x0026] |
                       (uint16_t(b.memory[current_tss_base+0x0027])<<8))==level.stack_selector,
              "task-gate entry did not save the exact interrupted TSS successor/context");
        for (uint32_t offset=0x00f0;offset<0x0110;++offset)
            check(b.memory[level.stack_base+offset]==0xa5,
                  "task-gate entry wrote to the interrupted CPL1/CPL2 stack");
        if (software_int) {
            check(uint16_t(b.memory[kStackBase+0x007e] |
                           (uint16_t(b.memory[kStackBase+0x007f])<<8))==expected_error &&
                  std::count_if(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                      return t.write && t.address>=kStackBase+0x007e &&
                             t.address<kStackBase+0x0080;
                  })==2,
                  "software INT #GP task-gate delivery did not push its IDT error code once");
            b.step(kHandlerBase+0x0500,0xf4,0x0030,0x0501,wait);
            check(b.d.halted_o && b.retired==retired_before+1,
                  "software INT #GP task did not execute its exact handler HLT");
        } else {
            check(b.memory[kStackBase+0x007e]==0xa5 && b.memory[kStackBase+0x007f]==0xa5 &&
                  std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                      return t.write && t.address>=kStackBase+0x0070 &&
                             t.address<kStackBase+0x0090;
                  }),
                  "external task-gate interrupt pushed an error or wrote the incoming stack");
            b.step(kHandlerBase+0x0500,0xcf,level.code_selector,successor_ip,wait);
            check(b.cs()==level.code_selector &&
                  uint16_t(b.d.segs_o>>32)==level.stack_selector &&
                  b.reg(4)==ring_level_sp && b.d.flags_o==saved_flags &&
                  b.memory[kGdtBase+task_gate_tss_selector+5]==0x81 &&
                  b.memory[kGdtBase+current_tss_selector+5]==0x83,
                  "task IRET did not restore the exact interrupted task or clear the nested task busy bit");
            if (nmi_mode)
                check(!b.d.nmi_blocked_o && !b.d.nmi_pending_o,
                      "task IRET did not release the serviced NMI");
            b.step(level.code_base+successor_ip,0x90,level.code_selector,successor_ip+1,wait);
            check(b.cs()==level.code_selector && b.d.ip_o==successor_ip+1 &&
                  b.reg(4)==ring_level_sp && b.retired==retired_before+3,
                  "task-gate external interrupt missed the exact resumed successor");
        }
        ++cases;
    }
    check(cases==12,
          "IDT task-gate external/software/NMI matrix missed a privilege level or READY policy");
    std::cout<<"PASS: 12 CPL1/CPL2 IDT task-gate external-INTR/software-INT/NMI cases prove external DPL bypass, software #GP error delivery, NMI blocking, exact nested TSS state and task-IRET resumption in both READY modes\n";
}

static void protected_event_task_gate_fault_recovery() {
    using namespace protected_mode_fixture;
    const uint8_t setup_program[]={
        0xb8,0x28,0x00, 0x8e,0xd0,
        0xbc,0x80,0x00,
        0xb8,0x68,0x00, 0x0f,0x00,0xd8,
        0x90,0xf4
    };
    struct Fault {
        const char* name;
        uint8_t vector;
        uint16_t error;
        uint16_t selector_offset;
        uint16_t invalid_selector;
        uint16_t repaired_selector;
    };
    const Fault faults[]={
        {"null CS #TS",10,0x0000,0x0024,0x0000,0x0030},
        {"wrong-type CS #TS",10,0x00c0,0x0024,0x00c0,0x0030},
        {"not-present CS #NP",11,0x00a0,0x0024,0x00a0,0x0030},
        {"null SS #SS",12,0x0000,0x0026,0x0000,0x0028},
        {"not-present SS #SS",12,0x00a8,0x0026,0x00a8,0x0028},
        {"not-present DS #NP",11,0x00b0,0x0028,0x00b0,0x0000},
        {"not-present ES #NP",11,0x00b0,0x0022,0x00b0,0x0000},
        {"wrong-type LDTR #TS",10,0x00b8,0x002a,0x00b8,0x0000}
    };
    constexpr uint16_t current_tss_selector=0x0068;
    constexpr uint16_t fault_tss_selector=0x0078;
    constexpr uint16_t handler_tss_selector=0x0088;
    constexpr uint32_t current_tss_base=0x00000700;
    constexpr uint32_t fault_tss_base=0x000a0000;
    constexpr uint32_t handler_tss_base=0x000b0000;
    auto put_descriptor=[](Bench& b,uint32_t address,uint16_t limit,
                           uint32_t base,uint8_t access) {
        b.put(address,{uint8_t(limit),uint8_t(limit>>8),uint8_t(base),
                       uint8_t(base>>8),uint8_t(base>>16),access,0,0});
    };
    auto put_word=[](Bench& b,uint32_t address,uint16_t value) {
        b.memory[address]=uint8_t(value);
        b.memory[address+1]=uint8_t(value>>8);
    };
    auto read_word=[](Bench& b,uint32_t address) {
        return uint16_t(b.memory[address] |
                        (uint16_t(b.memory[address+1])<<8));
    };
    unsigned cases=0;
    for (bool wait:{false,true}) for (const auto& fault:faults) {
        Bench b;
        place_selector_fixture(b,setup_program,sizeof(setup_program));
        b.memory[0x40]=0xc7; // Include fault descriptors through selector 00c0.
        put_descriptor(b,kGdtBase+current_tss_selector,0x002b,
                       current_tss_base,0x81);
        put_descriptor(b,kGdtBase+fault_tss_selector,0x002b,
                       fault_tss_base,0x81);
        put_descriptor(b,kGdtBase+handler_tss_selector,0x002b,
                       handler_tss_base,0x81);
        put_descriptor(b,kGdtBase+0x0090,0x002b,fault_tss_base,0x92);
        put_descriptor(b,kGdtBase+0x00a0,0x0fff,kHandlerBase,0x1a);
        put_descriptor(b,kGdtBase+0x00a8,0x0fff,kStackBase,0x12);
        put_descriptor(b,kGdtBase+0x00b0,0x0fff,kWideDataBase,0x12);
        put_descriptor(b,kGdtBase+0x00b8,0x0fff,kWideDataBase,0x92);
        put_descriptor(b,kGdtBase+0x00c0,0x0fff,kWideDataBase,0x92);
        b.put(kIdtBase+13*8,{0x00,0x00,uint8_t(fault_tss_selector),
                             uint8_t(fault_tss_selector>>8),0x00,0x85,0x00,0x00});
        b.put(kIdtBase+uint32_t(fault.vector)*8,
              {0x00,0x00,uint8_t(handler_tss_selector),
               uint8_t(handler_tss_selector>>8),0x00,0x85,0x00,0x00});

        uint16_t fault_task_words[]={
            0x0500,0x0202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0030,0x0028,0x0010,0x0000
        };
        const unsigned selector_word=(fault.selector_offset-0x000e)/2;
        check(selector_word<15,"task-gate recovery selector offset is outside the TSS image");
        fault_task_words[selector_word]=fault.invalid_selector;
        const uint16_t expected_saved_cs=fault_task_words[11];
        uint16_t saved_fault_task[15];
        std::copy(std::begin(fault_task_words),std::end(fault_task_words),
                  std::begin(saved_fault_task));
        saved_fault_task[1]=0x4202;
        const uint16_t handler_task_words[]={
            0x0700,0x0202,0x0201,0x0202,0x0203,0x0204,0x0080,
            0x0205,0x0206,0x0207,0x0020,0x0030,0x0028,0x0090,0x0000
        };
        for (unsigned index=0;index<15;++index) {
            put_word(b,fault_tss_base+0x000e + 2*index,fault_task_words[index]);
            put_word(b,handler_tss_base+0x000e + 2*index,handler_task_words[index]);
        }
        put_word(b,current_tss_base+2,0x0080);
        put_word(b,current_tss_base+4,0x0028);
        b.put(kHandlerBase+0x0500,{0x90,0xf4}); // Recovered task successor, then HLT.
        const uint8_t repair_handler[]={
            0xc7,0x06,uint8_t(fault.selector_offset),
            uint8_t(fault.selector_offset>>8),
            uint8_t(fault.repaired_selector),uint8_t(fault.repaired_selector>>8),
            0xcf
        };
        for (unsigned index=0;index<sizeof(repair_handler);++index)
            b.memory[kHandlerBase+0x0700+index]=repair_handler[index];

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
        b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x020e,wait);
        check(b.memory[kGdtBase+current_tss_selector+5]==0x83,
              "task-gate fault fixture did not make the running TSS busy");
        b.step(kCodeBase+0x020e,0x90,kCodeSelector,0x020f,wait);

        const unsigned acks_before=b.acknowledgements;
        b.d.intr_i=1;
        b.acknowledge=true;
        b.interrupt_vector=13;
        std::vector<uint8_t> delivered_vectors;
        bool handler_entered=false;
        for (unsigned cycle=0;cycle<150000 && !b.d.fault_o && !b.d.shutdown_o;
             ++cycle) {
            b.tick(wait);
            if (b.d.event_o) {
                delivered_vectors.push_back(b.d.event_vector_o);
                if (b.d.event_vector_o==13) {
                    b.d.intr_i=0;
                    b.acknowledge=false;
                }
            }
            if (b.cs()==kHandlerSelector && b.d.ip_o==0x0700) {
                handler_entered=true;
                b.d.intr_i=0;
                b.acknowledge=false;
                break;
            }
        }
        if (!handler_entered || b.d.fault_o || b.d.shutdown_o ||
            delivered_vectors!=std::vector<uint8_t>({fault.vector}) ||
            b.acknowledgements!=acks_before+1) {
            std::cerr<<"task-gate repair entry "<<fault.name<<" wait="<<wait
                     <<" entered="<<handler_entered<<" fault/shutdown="
                     <<unsigned(b.d.fault_o)<<"/"<<unsigned(b.d.shutdown_o)
                     <<" cs:ip="<<std::hex<<b.cs()<<":"<<b.d.ip_o
                     <<" last-vector="<<unsigned(b.d.event_vector_o)<<std::dec
                     <<" ack="<<b.acknowledgements-acks_before<<" vectors=";
            for (auto vector:delivered_vectors) std::cerr<<unsigned(vector)<<",";
            std::cerr<<" packet-error="<<std::hex<<b.d.event_packet_error_code_o
                     <<" saved="<<b.d.event_packet_saved_cs_o<<":"
                     <<b.d.event_packet_saved_ip_o<<std::dec<<"\n";
        }
        check(handler_entered && !b.d.fault_o && !b.d.shutdown_o &&
              delivered_vectors==std::vector<uint8_t>({fault.vector}) &&
              b.acknowledgements==acks_before+1,
              (std::string("incoming ")+fault.name+
               " did not follow external task-gate entry with one fault task gate").c_str());
        check(b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==fault.error &&
              b.d.event_packet_saved_cs_o==expected_saved_cs &&
              b.d.event_packet_saved_ip_o==0x0500 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080 &&
              b.cs()==kHandlerSelector && b.d.ip_o==0x0700 &&
              uint16_t(b.d.segs_o>>32)==kSsSelector &&
              uint16_t(b.d.segs_o>>48)==0x0090 &&
              b.cache_base(3)==fault_tss_base && b.reg(4)==0x007e,
              (std::string("incoming ")+fault.name+
               " fault packet did not enter the valid task handler context").c_str());
        for (unsigned index=0;index<15;++index)
            check(read_word(b,fault_tss_base+0x000e + 2*index)==saved_fault_task[index],
                  (std::string("incoming ")+fault.name+
                   " task-gate delivery failed to save the faulting TSS word").c_str());
        check(read_word(b,fault_tss_base)==current_tss_selector &&
              read_word(b,handler_tss_base)==fault_tss_selector &&
              b.memory[kGdtBase+current_tss_selector+5]==0x83 &&
              b.memory[kGdtBase+fault_tss_selector+5]==0x83 &&
              b.memory[kGdtBase+handler_tss_selector+5]==0x83 &&
              read_word(b,kStackBase+0x007e)==fault.error,
              (std::string("incoming ")+fault.name+
               " task-gate entry missed backlinks, busy bits or null error push").c_str());

        b.data_transfers.clear();
        b.step(kHandlerBase+0x0700,0xc7,kHandlerSelector,0x0706,wait);
        check(read_word(b,fault_tss_base+fault.selector_offset)==fault.repaired_selector &&
              b.data_transfers.size()==2 &&
              b.data_transfers[0].write &&
              b.data_transfers[0].address==fault_tss_base+fault.selector_offset &&
              b.data_transfers[1].write &&
              b.data_transfers[1].address==fault_tss_base+fault.selector_offset+1,
              (std::string("incoming ")+fault.name+
               " handler did not repair only the saved selector").c_str());
        b.step(kHandlerBase+0x0706,0xcf,kHandlerSelector,0x0500,wait);
        check(!b.d.fault_o && !b.d.shutdown_o && !b.d.event_o &&
              b.cs()==kHandlerSelector && b.d.ip_o==0x0500 &&
              uint16_t(b.d.segs_o>>32)==kSsSelector &&
              uint16_t(b.d.segs_o)==(fault.selector_offset==0x0022 ? 0x0000 : 0x0020) &&
              uint16_t(b.d.segs_o>>48)==(fault.selector_offset==0x0028 ? 0x0000 : 0x0010) &&
              b.reg(4)==0x0080 && b.d.flags_o==0x4202 &&
              b.memory[kGdtBase+current_tss_selector+5]==0x83 &&
              b.memory[kGdtBase+fault_tss_selector+5]==0x83 &&
              b.memory[kGdtBase+handler_tss_selector+5]==0x81,
              (std::string("incoming ")+fault.name+
               " handler task IRET did not restore the repaired faulting task").c_str());
        b.step(kHandlerBase+0x0500,0x90,kHandlerSelector,0x0501,wait);
        b.step(kHandlerBase+0x0501,0xf4,kHandlerSelector,0x0502,wait);
        check(b.d.halted_o && b.cs()==kHandlerSelector && b.d.ip_o==0x0502 &&
              b.d.event_vector_o==fault.vector,
              (std::string("incoming ")+fault.name+
               " recovery missed the exact resumed-task successor").c_str());
        ++cases;
    }
    check(cases==16,
          "task-gate selector-fault repair-and-IRET matrix missed a READY policy or fault type");
    std::cout<<"PASS: 16 incoming-task #TS/#NP/#SS task-gate deliveries repair saved CS/SS/DS/ES/LDTR selectors, task-IRET to the exact resumed successor, and complete in both READY modes\n";
}

static void protected_event_task_gate_handler_entry_fault() {
    using namespace protected_mode_fixture;
    const uint8_t setup_program[]={
        0xb8,0x28,0x00, 0x8e,0xd0,
        0xbc,0x80,0x00,
        0xb8,0x68,0x00, 0x0f,0x00,0xd8,
        0x90,0xf4
    };
    constexpr uint16_t current_tss_selector=0x0068;
    constexpr uint16_t fault_tss_selector=0x0078;
    constexpr uint16_t unavailable_handler_tss_selector=0x0088;
    constexpr uint16_t double_fault_tss_selector=0x0098;
    constexpr uint16_t handler_code_selector=0x0030;
    constexpr uint32_t current_tss_base=0x00000700;
    constexpr uint32_t fault_tss_base=0x000a0000;
    constexpr uint32_t unavailable_handler_tss_base=0x000b0000;
    constexpr uint32_t double_fault_tss_base=0x000c0000;
    auto put_descriptor=[](Bench& b,uint32_t address,uint16_t limit,
                           uint32_t base,uint8_t access) {
        b.put(address,{uint8_t(limit),uint8_t(limit>>8),uint8_t(base),
                       uint8_t(base>>8),uint8_t(base>>16),access,0,0});
    };
    auto put_word=[](Bench& b,uint32_t address,uint16_t value) {
        b.memory[address]=uint8_t(value);
        b.memory[address+1]=uint8_t(value>>8);
    };
    auto read_word=[](Bench& b,uint32_t address) {
        return uint16_t(b.memory[address] |
                        (uint16_t(b.memory[address+1])<<8));
    };
    unsigned recovery_cases=0,shutdown_cases=0;
    for (bool wait:{false,true}) for (bool fail_double_fault_task:{false,true}) {
        Bench b;
        place_selector_fixture(b,setup_program,sizeof(setup_program));
        b.memory[0x40]=0xc7;
        put_descriptor(b,kGdtBase+current_tss_selector,0x002b,
                       current_tss_base,0x81);
        put_descriptor(b,kGdtBase+fault_tss_selector,0x002b,
                       fault_tss_base,0x81);
        put_descriptor(b,kGdtBase+unavailable_handler_tss_selector,0x002b,
                       unavailable_handler_tss_base,0x01);
        put_descriptor(b,kGdtBase+double_fault_tss_selector,0x002b,
                       double_fault_tss_base,uint8_t(fail_double_fault_task ? 0x01 : 0x81));
        // DS in the double-fault task aliases the first faulting TSS so the
        // handler can repair it before task IRET resumes that task.
        put_descriptor(b,kGdtBase+0x0090,0x002b,fault_tss_base,0x92);
        b.put(kIdtBase+13*8,{0x00,0x00,uint8_t(fault_tss_selector),
                             uint8_t(fault_tss_selector>>8),0x00,0x85,0x00,0x00});
        b.put(kIdtBase+10*8,{0x00,0x00,uint8_t(unavailable_handler_tss_selector),
                             uint8_t(unavailable_handler_tss_selector>>8),0x00,0x85,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,uint8_t(double_fault_tss_selector),
                            uint8_t(double_fault_tss_selector>>8),0x00,0x85,0x00,0x00});

        const uint16_t fault_task_words[]={
            0x0500,0x0202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0000,0x0028,0x0020,0x0000
        };
        const uint16_t double_fault_task_words[]={
            0x0700,0x0202,0x0201,0x0202,0x0203,0x0204,0x0080,
            0x0205,0x0206,0x0207,0x0020,0x0030,0x0028,0x0090,0x0000
        };
        for (unsigned index=0;index<15;++index) {
            put_word(b,fault_tss_base+0x000e + 2*index,fault_task_words[index]);
            put_word(b,double_fault_tss_base+0x000e + 2*index,
                     double_fault_task_words[index]);
        }
        put_word(b,double_fault_tss_base,0x5aa5);
        b.memory[unavailable_handler_tss_base]=0xa5;
        b.memory[unavailable_handler_tss_base+1]=0x5a;
        put_word(b,current_tss_base+2,0x0080);
        put_word(b,current_tss_base+4,0x0028);
        b.put(kHandlerBase+0x0500,{0x90,0xf4});
        b.put(kHandlerBase+0x0700,{0x90,0xc7,0x06,0x24,0x00,0x30,0x00,0xcf});

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
        b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x020e,wait);
        check(b.memory[kGdtBase+current_tss_selector+5]==0x83,
              "task-gate handler-entry fixture did not make the running TSS busy");
        b.step(kCodeBase+0x020e,0x90,kCodeSelector,0x020f,wait);

        const unsigned acknowledgements_before=b.acknowledgements;
        b.d.intr_i=1;
        b.acknowledge=true;
        b.interrupt_vector=13;
        std::vector<uint8_t> delivered_vectors;
        bool double_fault_packet_seen=false;
        bool double_fault_packet_valid=false, double_fault_packet_protected=false;
        bool double_fault_packet_restartable=false, double_fault_error_valid=false;
        uint16_t double_fault_error=0,double_fault_saved_cs=0,double_fault_saved_ip=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.fault_o &&
             !b.d.shutdown_o && !b.d.halted_o;++cycle) {
            b.tick(wait);
            if (b.acknowledgements==acknowledgements_before+1) {
                b.d.intr_i=0;
                b.acknowledge=false;
            }
            if (b.d.event_o) {
                delivered_vectors.push_back(b.d.event_vector_o);
                if (b.d.event_vector_o==8) {
                    double_fault_packet_seen=true;
                    double_fault_packet_valid=b.d.event_packet_valid_o;
                    double_fault_packet_protected=b.d.event_packet_protected_o;
                    double_fault_packet_restartable=b.d.event_packet_restartable_o;
                    double_fault_error_valid=b.d.event_packet_error_valid_o;
                    double_fault_error=b.d.event_packet_error_code_o;
                    double_fault_saved_cs=b.d.event_packet_saved_cs_o;
                    double_fault_saved_ip=b.d.event_packet_saved_ip_o;
                }
                if (b.d.event_vector_o==13) {
                    b.d.intr_i=0;
                    b.acknowledge=false;
                }
            }
        }
        if (!b.d.halted_o || b.d.fault_o ||
            b.d.shutdown_o!=fail_double_fault_task ||
            b.acknowledgements!=acknowledgements_before+1) {
            std::cerr<<"task-gate handler-entry fault wait="<<wait
                     <<" fail-#DF-TSS="<<fail_double_fault_task
                     <<" fault/shutdown="<<unsigned(b.d.fault_o)<<"/"
                     <<unsigned(b.d.shutdown_o)<<" cs:ip="<<std::hex<<b.cs()
                     <<":"<<b.d.ip_o<<" event-vector="<<unsigned(b.d.event_vector_o)
                     <<" packet-error="<<b.d.event_packet_error_code_o
                     <<" saved="<<b.d.event_packet_saved_cs_o<<":"
                     <<b.d.event_packet_saved_ip_o<<std::dec<<" ack="
                     <<b.acknowledgements-acknowledgements_before<<" vectors=";
            for (auto vector:delivered_vectors) std::cerr<<unsigned(vector)<<",";
            std::cerr<<" transfers="<<b.data_transfers.size()<<"\n";
        }
        if (fail_double_fault_task) {
            if (double_fault_packet_seen || !b.d.event_packet_valid_o ||
                !b.d.event_packet_protected_o || !b.d.event_packet_restartable_o ||
                !b.d.event_packet_error_valid_o || b.d.event_packet_error_code_o!=0 ||
                b.d.event_vector_o!=8 || b.d.event_packet_saved_cs_o!=0x0000 ||
                b.d.event_packet_saved_ip_o!=0x0500 ||
                b.d.event_packet_saved_flags_o!=0x4202 ||
                b.d.event_packet_saved_sp_o!=0x0080) {
                std::cerr<<"failed #DF entry packet wait="<<wait
                         <<" event-seen="<<double_fault_packet_seen
                         <<" packet="<<b.d.event_packet_valid_o<<"/"
                         <<b.d.event_packet_protected_o<<"/"
                         <<b.d.event_packet_restartable_o<<"/"
                         <<b.d.event_packet_error_valid_o<<" error="<<std::hex
                         <<b.d.event_packet_error_code_o<<" vector="<<std::dec
                         <<unsigned(b.d.event_vector_o)<<" saved="<<std::hex
                         <<b.d.event_packet_saved_cs_o<<":"
                         <<b.d.event_packet_saved_ip_o<<" flags="
                         <<b.d.event_packet_saved_flags_o<<" sp="
                         <<b.d.event_packet_saved_sp_o<<std::dec<<"\n";
            }
            check(b.d.halted_o && !b.d.fault_o && b.d.shutdown_o &&
                  b.acknowledgements==acknowledgements_before+1,
                  "fault entering the #DF task did not enter protected shutdown");
            check(!double_fault_packet_seen && b.d.event_packet_valid_o &&
                  b.d.event_packet_protected_o && b.d.event_packet_restartable_o &&
                  b.d.event_packet_error_valid_o && b.d.event_packet_error_code_o==0 &&
                  b.d.event_vector_o==8 && b.d.event_packet_saved_cs_o==0x0000 &&
                  b.d.event_packet_saved_ip_o==0x0500 &&
                  b.d.event_packet_saved_flags_o==0x4202 &&
                  b.d.event_packet_saved_sp_o==0x0080,
                  "failed #DF task entry lost the original #TS context or null #DF error");
            check(read_word(b,fault_tss_base)==current_tss_selector &&
                  read_word(b,fault_tss_base+0x0024)==0x0000 &&
                  b.memory[kGdtBase+current_tss_selector+5]==0x83 &&
                  b.memory[kGdtBase+fault_tss_selector+5]==0x83 &&
                  b.memory[kGdtBase+unavailable_handler_tss_selector+5]==0x01 &&
                  b.memory[kGdtBase+double_fault_tss_selector+5]==0x01 &&
                  read_word(b,double_fault_tss_base)==0x5aa5 &&
                  b.memory[unavailable_handler_tss_base]==0xa5 &&
                  b.memory[unavailable_handler_tss_base+1]==0x5a,
                  "failed #DF task entry changed TSS links, busy bits or target memory");
            check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),
                               [&](const auto& transfer) {
                       return !transfer.io && transfer.address>=double_fault_tss_base &&
                              transfer.address<double_fault_tss_base+0x2e;
                   }),
                  "not-present #DF task TSS was read during failed task-gate admission");
            const size_t transfers_at_shutdown=b.data_transfers.size();
            for (unsigned cycle=0;cycle<8;++cycle) b.tick(wait);
            check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o &&
                  b.d.bus_shutdown_cycle_o && !b.d.bus_halt_cycle_o &&
                  !b.d.bus_req_o && b.data_transfers.size()==transfers_at_shutdown,
                  "failed #DF task entry did not remain quiescent in shutdown");
            ++shutdown_cases;
        } else {
            check(b.d.halted_o && !b.d.fault_o && !b.d.shutdown_o &&
                  b.acknowledgements==acknowledgements_before+1,
                  "fault entering the #TS task-gate target did not recover through the #DF task");
            check(double_fault_packet_seen && double_fault_packet_valid &&
                  double_fault_packet_protected && double_fault_packet_restartable &&
                  double_fault_error_valid && double_fault_error==0 &&
                  double_fault_saved_cs==0x0000 && double_fault_saved_ip==0x0500,
                  "double-fault recovery changed the first-fault context or null error");
            if (b.cs()!=handler_code_selector || b.d.ip_o!=0x0502)
                std::cerr<<"double-fault final PC wait="<<wait<<" got="<<std::hex
                         <<b.cs()<<":"<<b.d.ip_o<<" halted="<<b.d.halted_o
                         <<" retired="<<std::dec<<b.retired<<"\n";
            check(b.cs()==handler_code_selector && b.d.ip_o==0x0502,
                  "double-fault recovery did not restore the exact repaired task successor");
            check(uint16_t(b.d.segs_o>>32)==kSsSelector &&
                  uint16_t(b.d.segs_o>>48)==0x0020 &&
                  uint16_t(b.d.segs_o)==0x0020,
                  "double-fault recovery did not restore the repaired task's data selectors");
            check(b.reg(4)==0x0080,
                  "double-fault recovery did not restore the repaired task's stack pointer");
            check(read_word(b,fault_tss_base)==current_tss_selector &&
                  read_word(b,double_fault_tss_base)==fault_tss_selector &&
                  b.memory[kGdtBase+current_tss_selector+5]==0x83 &&
                  b.memory[kGdtBase+fault_tss_selector+5]==0x83 &&
                  b.memory[kGdtBase+unavailable_handler_tss_selector+5]==0x01 &&
                  b.memory[kGdtBase+double_fault_tss_selector+5]==0x81 &&
                  read_word(b,kStackBase+0x007e)==0 &&
                  b.memory[unavailable_handler_tss_base]==0xa5 &&
                  b.memory[unavailable_handler_tss_base+1]==0x5a,
                  "failed #TS handler admission changed its TSS, task links, busy bits, or #DF error word");
            check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),
                               [&](const auto& transfer) {
                       return !transfer.io && transfer.address>=unavailable_handler_tss_base &&
                              transfer.address<unavailable_handler_tss_base+0x2e;
                   }),
                  "not-present #TS handler TSS was read during failed task-gate admission");

            std::vector<Bench::Transfer> selector_repair_writes;
            for (const auto& transfer:b.data_transfers)
                if (transfer.write && !transfer.io &&
                    transfer.address>=fault_tss_base+0x0024 &&
                    transfer.address<=fault_tss_base+0x0025)
                    selector_repair_writes.push_back(transfer);
            check(read_word(b,fault_tss_base+0x0024)==handler_code_selector &&
                  selector_repair_writes.size()>=2 &&
                  selector_repair_writes[selector_repair_writes.size()-2].address==fault_tss_base+0x0024 &&
                  selector_repair_writes[selector_repair_writes.size()-2].value==uint8_t(handler_code_selector) &&
                  selector_repair_writes.back().address==fault_tss_base+0x0025 &&
                  selector_repair_writes.back().value==uint8_t(handler_code_selector>>8),
                  "double-fault handler did not repair only the saved first-fault CS");
            check(b.d.halted_o && b.d.event_vector_o==8 && b.d.flags_o==0x4202 &&
                  b.memory[kGdtBase+fault_tss_selector+5]==0x83 &&
                  b.memory[kGdtBase+double_fault_tss_selector+5]==0x81 &&
                  b.memory[kGdtBase+unavailable_handler_tss_selector+5]==0x01,
                  "double-fault recovery missed the exact resumed-task successor");
            ++recovery_cases;
        }
    }
    check(recovery_cases==2 && shutdown_cases==2,
          "task-gate handler-entry recovery/shutdown matrix missed a READY policy");
    std::cout<<"PASS: 2 not-present #TS handler-entry faults recover through #DF and 2 not-present #DF target-TSS faults enter shutdown, in both READY modes\n";
}

static void protected_wait_async_delivery() {
    using namespace protected_mode_fixture;
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00, 0x8e,0xd0,
        0xbc,0x80,0x00,
        0xb8,0x68,0x00, 0x0f,0x00,0xd8,
        0xcf,0xf4
    };
    struct Level {
        unsigned cpl;
        uint16_t code_selector, stack_selector;
        uint32_t code_base, stack_base;
        uint32_t code_descriptor, stack_descriptor;
        uint8_t code_access, stack_access;
    };
    const Level levels[]={
        {1,0x0049,0x0051,0x00081000,0x00080000,0x48,0x50,0xba,0xb2},
        {2,0x005a,0x0062,0x00083000,0x00082000,0x58,0x60,0xda,0xd2}
    };
    constexpr uint16_t first_ip=0x0400;
    constexpr uint16_t successor_ip=0x0401;
    constexpr uint16_t ring_level_sp=0x0100;
    constexpr uint16_t saved_flags=0x0202;
    constexpr uint32_t tss_base=0x00000700;
    auto put_descriptor=[](Bench& b,uint32_t address,uint16_t limit,
                           uint32_t base,uint8_t access) {
        b.put(address,{uint8_t(limit),uint8_t(limit>>8),uint8_t(base),
                       uint8_t(base>>8),uint8_t(base>>16),access,0,0});
    };
    unsigned executions=0;
    for (const auto& level:levels)
      for (bool nmi_mode:{false,true})
        for (uint8_t gate_type:{uint8_t(6),uint8_t(7)})
          for (bool wait:{false,true}) {
        const uint8_t vector=nmi_mode ? uint8_t(2) : uint8_t(13);
        Bench b;
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x40]=0x77; // Include ring-1/2 descriptors and the TSS.
        for (const auto& descriptor_level:levels) {
            put_descriptor(b,kGdtBase+descriptor_level.code_descriptor,0x0fff,
                           descriptor_level.code_base,descriptor_level.code_access);
            put_descriptor(b,kGdtBase+descriptor_level.stack_descriptor,0x0fff,
                           descriptor_level.stack_base,descriptor_level.stack_access);
        }
        b.put(kGdtBase+0x68,{0x2b,0x00,0x00,0x07,0x00,0x81,0x00,0x00});
        b.put(kIdtBase+vector*8,{0x00,0x03,0x30,0x00,0x00,
                                 uint8_t(0x80|gate_type),0x00,0x00});
        b.put(tss_base+2,{0x00,0x01,0x28,0x00}); // SP0:SS0 = 0100:0028.
        b.memory[level.code_base+first_ip]=0x9b; // WAIT remains stalled on BUSY.
        b.memory[level.code_base+successor_ip]=0x90;
        b.memory[kHandlerBase+kHandlerIp]=0xcf;
        for (uint32_t offset=0x00f0;offset<0x0110;++offset)
            b.memory[level.stack_base+offset]=0xa5;

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
        b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x020e,wait);
        check(b.memory[kGdtBase+0x6d]==0x83,
              "protected WAIT fixture LTR did not mark the TSS busy");
        b.put(kStackBase+0x0080,{uint8_t(first_ip),uint8_t(first_ip>>8),
                                  uint8_t(level.code_selector),uint8_t(level.code_selector>>8),
                                  uint8_t(saved_flags),uint8_t(saved_flags>>8),
                                  0x00,0x01,uint8_t(level.stack_selector),
                                  uint8_t(level.stack_selector>>8)});
        b.step(kCodeBase+0x020e,0xcf,level.code_selector,first_ip,wait);
        check(uint16_t(b.d.segs_o>>32)==level.stack_selector &&
              b.reg(4)==ring_level_sp && b.d.flags_o==saved_flags,
              "initial outer IRET did not establish the protected WAIT ring");

        const unsigned retired_before=b.retired;
        b.data_transfers.clear();
        b.d.busy_i=1;
        for (unsigned cycle=0;cycle<50000 && b.d.ip_o!=successor_ip;++cycle)
            b.tick(wait);
        const auto wait_fetch_count=b.accepted.size();
        for (unsigned cycle=0;cycle<24;++cycle) b.tick(wait);
        check(!b.accepted.empty() &&
              b.accepted.back()==level.code_base+first_ip &&
              b.accepted.size()==wait_fetch_count &&
              b.d.ip_o==successor_ip && !b.d.bus_req_o && !b.d.retire_o &&
              b.retired==retired_before && b.cs()==level.code_selector,
              "protected WAIT fetched past or retired at its exact successor while BUSY was asserted");
        const unsigned acknowledgements_before=b.acknowledgements;
        if (nmi_mode) b.d.nmi_i=1;
        else {
            b.d.intr_i=1;
            b.acknowledge=true;
            b.interrupt_vector=vector;
        }
        bool event_seen=false,handler_entered=false;
        for (unsigned cycle=0;cycle<50000 && !b.d.fault_o &&
             b.cs()!=kHandlerSelector;++cycle) {
            b.tick(wait);
            event_seen=event_seen || b.d.event_o;
            if (b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp) {
                handler_entered=true;
                b.d.intr_i=0;
                b.d.nmi_i=0;
                b.acknowledge=false;
                break;
            }
        }
        constexpr uint16_t expected_stack_pointer=0x00f6;
        const bool event_committed=event_seen && handler_entered && !b.d.fault_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              !b.d.event_packet_error_valid_o && !b.d.event_packet_restartable_o &&
              b.d.event_vector_o==vector && b.d.event_packet_error_code_o==0 &&
              b.d.event_packet_saved_cs_o==level.code_selector &&
              b.d.event_packet_saved_ip_o==successor_ip &&
              b.d.event_packet_saved_flags_o==saved_flags &&
              b.d.event_packet_saved_sp_o==ring_level_sp &&
              (nmi_mode ? (b.acknowledgements==acknowledgements_before &&
                           b.d.nmi_blocked_o && !b.d.nmi_pending_o) :
                          b.acknowledgements>acknowledgements_before) &&
              b.retired==retired_before && b.cs()==kHandlerSelector &&
              b.d.ip_o==kHandlerIp && uint16_t(b.d.segs_o>>32)==kSsSelector &&
              b.reg(4)==expected_stack_pointer;
        if (!event_committed) {
            b.d.intr_i=0;
            b.d.nmi_i=0;
            b.acknowledge=false;
            throw std::runtime_error("protected NMI/INTR did not interrupt WAIT while BUSY was asserted");
        }

        const uint8_t expected_frame[]={
            uint8_t(successor_ip),uint8_t(successor_ip>>8),
            uint8_t(level.code_selector),uint8_t(level.code_selector>>8),
            uint8_t(saved_flags),uint8_t(saved_flags>>8),
            0x00,0x01,uint8_t(level.stack_selector),uint8_t(level.stack_selector>>8)
        };
        for (unsigned i=0;i<sizeof(expected_frame);++i)
            check(b.memory.at(kStackBase+expected_stack_pointer+i)==expected_frame[i],
                  "protected WAIT event frame bytes/order are incorrect");
        check(b.d.flags_o==(gate_type==6 ? uint16_t(saved_flags&0xfcff) :
                                                   uint16_t(saved_flags&0xfeff)),
              "protected WAIT interrupt/trap gate IF/TF handling mismatch");
        const auto tss_pair=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),
            [tss_base](const auto& t) { return !t.write && t.address==tss_base+2 && t.size==4; });
        const auto stack_descriptor=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),
            [](const auto& t) { return !t.write && t.address==kGdtBase+0x28; });
        const auto first_frame_write=std::find_if(b.data_transfers.begin(),b.data_transfers.end(),
            [](const auto& t) { return t.write && t.address==kStackBase+0x00fe; });
        check(tss_pair!=b.data_transfers.end() && stack_descriptor!=b.data_transfers.end() &&
              first_frame_write!=b.data_transfers.end() &&
              tss_pair<stack_descriptor && stack_descriptor<first_frame_write,
              "protected WAIT event wrote the new stack before reading TSS and validating SS0");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),
                  [&level](const auto& t) {
                      return t.write && t.address>=level.stack_base+0x00f0 &&
                             t.address<level.stack_base+0x0110;
                  }),"protected WAIT event wrote to the interrupted ring stack");
        for (uint32_t offset=0x00f0;offset<0x0110;++offset)
            check(b.memory.at(level.stack_base+offset)==0xa5,
                  "protected WAIT event changed the interrupted ring stack");

        b.step(kHandlerBase+kHandlerIp,0xcf,level.code_selector,successor_ip,wait);
        check(b.cs()==level.code_selector && uint16_t(b.d.segs_o>>32)==level.stack_selector &&
              b.reg(4)==ring_level_sp && b.d.flags_o==saved_flags,
              "outer IRET did not restore the protected WAIT context");
        if (nmi_mode)
            check(!b.d.nmi_blocked_o && !b.d.nmi_pending_o,
                  "outer IRET did not release the protected WAIT NMI");
        b.step(level.code_base+successor_ip,0x90,level.code_selector,successor_ip+1,wait);
        check(!b.d.halted_o && b.cs()==level.code_selector &&
              b.d.ip_o==successor_ip+1 && b.reg(4)==ring_level_sp,
              "protected WAIT handler missed the exact successor");
        ++executions;
    }
    check(executions==16,
          "protected WAIT event matrix did not cover levels, events, gate types and READY modes");
    std::cout<<"PASS: 16 protected CPL1/CPL2 NMI/INTR cases interrupt WAIT during BUSY, switch through TSS, write exact outer frames and IRET to the exact successor in both READY modes\n";
}

static void protected_null_ldt_invalidation() {
    using namespace protected_mode_fixture;
    const uint8_t program[]={
        0xb8,0x10,0x00, 0x8e,0xd8,
        0xb8,0x28,0x00, 0x8e,0xd0, 0xbc,0x80,0x00,
        0xb8,0x00,0x00, 0x0f,0x00,0xd0, 0x0f,0x00,0xc0,
        0xb8,0x0c,0x00, 0x8e,0xd8, 0xf4
    };
    const uint8_t repair_handler[]={
        0x83,0xc4,0x02, 0x58, 0x83,0xc0,0x02, 0x50, 0xcf
    };
    unsigned executions=0;
    for (bool wait:{false,true}) {
        Bench b;
        place_selector_fixture(b,program,sizeof(program));
        for (std::size_t i=0;i<sizeof(repair_handler);++i)
            b.memory[kHandlerBase+kHandlerIp+uint32_t(i)]=repair_handler[i];
        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xb8,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0x8e,kCodeSelector,0x020a,wait);
        b.step(kCodeBase+0x020a,0xbc,kCodeSelector,0x020d,wait);
        b.step(kCodeBase+0x020d,0xb8,kCodeSelector,0x0210,wait);
        b.step(kCodeBase+0x0210,0x0f,kCodeSelector,0x0213,wait);
        b.step(kCodeBase+0x0213,0x0f,kCodeSelector,0x0216,wait);
        check(b.reg(0)==0,"LLDT null selector did not expose an invalid/null LDTR");
        b.step(kCodeBase+0x0216,0xb8,kCodeSelector,0x0219,wait);
        const uint16_t saved_flags=b.d.flags_o;
        const unsigned retired_before=b.retired;
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<30000 && !b.d.event_o && !b.d.fault_o;++cycle) b.tick(wait);
        check(b.d.event_o && !b.d.fault_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_error_valid_o && b.d.event_packet_restartable_o &&
              b.d.event_vector_o==13 && b.d.event_packet_error_code_o==0x000c &&
              b.d.event_packet_saved_cs_o==kCodeSelector &&
              b.d.event_packet_saved_ip_o==0x0219 &&
              b.d.event_packet_saved_flags_o==saved_flags &&
              b.d.event_packet_saved_sp_o==kInitialSp && b.retired==retired_before &&
              b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp && b.reg(4)==kInitialSp-8,
              "descriptor reference through invalidated LDTR did not deliver #GP(selector)");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && t.address>=0x00000608 && t.address<0x00000610;
              }),"invalid LDTR still issued an LDT descriptor read");
        b.step(kHandlerBase+kHandlerIp,0x83,kHandlerSelector,kHandlerIp+3,wait);
        b.step(kHandlerBase+kHandlerIp+3,0x58,kHandlerSelector,kHandlerIp+4,wait);
        b.step(kHandlerBase+kHandlerIp+4,0x83,kHandlerSelector,kHandlerIp+7,wait);
        b.step(kHandlerBase+kHandlerIp+7,0x50,kHandlerSelector,kHandlerIp+8,wait);
        b.step(kHandlerBase+kHandlerIp+8,0xcf,kCodeSelector,0x021b,wait);
        check(b.reg(4)==kInitialSp && b.cs()==kCodeSelector && b.d.ip_o==0x021b &&
              b.d.flags_o==saved_flags,
              "#GP(selector) handler IRET did not restore the exact post-load successor");
        b.step(kCodeBase+0x021b,0xf4,kCodeSelector,0x021c,wait);
        check(b.d.halted_o && b.reg(4)==kInitialSp && b.d.ip_o==0x021c,
              "invalid-LDTR recovery did not reach the exact HLT");
        ++executions;
    }
    check(executions==2,"null-LDTR recovery did not cover both READY modes");
    std::cout<<"PASS: "<<executions<<" null-LDTR cases block LDT reads and recover #GP(selector) through IRET in both READY modes\n";
}

static void protected_shutdown_nmi_recovery() {
    using namespace protected_mode_fixture;
    const uint8_t shutdown_program[]={
        0xb8,0x28,0x00, 0x8e,0xd0, // Install ring-0 SS.
        0xbc,0x80,0x00,             // SP=0080.
        0x31,0xc0,                  // AX=0.
        0xf7,0xf0                   // DIV AX => #DE.
    };
    const uint8_t nmi_handler[]={0xb8,0x34,0x12,0xf4}; // MOV AX,1234; HLT.
    const uint8_t nmi_gate[]={0x00,0x03,0x30,0x00,0x00,0x86,0x00,0x00};
    const auto prepare=[&](Bench& b,bool wait,uint16_t idt_limit,bool valid_nmi_gate) {
        place_selector_fixture(b,shutdown_program,sizeof(shutdown_program));
        b.memory[0x46]=uint8_t(idt_limit);
        b.memory[0x47]=uint8_t(idt_limit>>8);
        if (valid_nmi_gate) b.put(kIdtBase+2*8,
            {nmi_gate[0],nmi_gate[1],nmi_gate[2],nmi_gate[3],
             nmi_gate[4],nmi_gate[5],nmi_gate[6],nmi_gate[7]});
        b.put(kHandlerBase+kHandlerIp,
              {nmi_handler[0],nmi_handler[1],nmi_handler[2],nmi_handler[3]});
        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0x31,kCodeSelector,0x020a,wait);
        const uint16_t saved_flags=b.d.flags_o;
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<50000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_vector_o==8 && !b.d.retire_o,
              "DIV-by-zero fixture did not reach protected #DF shutdown");
        for (unsigned cycle=0;cycle<8;++cycle) {
            b.tick(wait,0);
            check(b.d.shutdown_o && b.d.halted_o &&
                  !b.d.bus_halt_cycle_o && b.d.bus_shutdown_cycle_o &&
                  !b.d.bus_req_o && !b.d.retire_o,
                  "shutdown bus cycle depended on READY or issued a byte request");
        }
        return saved_flags;
    };

    unsigned recovered=0;
    for (bool wait:{false,true}) {
        Bench b;
        const uint16_t saved_flags=prepare(b,wait,0x006f,true);
        const unsigned retired_before=b.retired;
        b.d.intr_i=1;
        for (unsigned cycle=0;cycle<8;++cycle) {
            b.tick(wait,0);
            check(b.d.shutdown_o && b.d.halted_o && !b.d.bus_req_o &&
                  !b.d.bus_halt_cycle_o && b.d.bus_shutdown_cycle_o &&
                  !b.d.inta_req_o && b.acknowledgements==0,
                  "INTR woke protected shutdown or requested an acknowledgement");
        }
        b.d.intr_i=0;
        b.data_transfers.clear();
        b.d.nmi_i=1;
        bool entered=false;
        for (unsigned cycle=0;cycle<50000 && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp) {
                entered=true;
                break;
            }
        }
        b.d.nmi_i=0;
        check(entered && !b.d.shutdown_o && !b.d.halted_o && !b.d.fault_o &&
              b.d.event_vector_o==2 && b.d.event_packet_valid_o &&
              b.d.event_packet_protected_o && !b.d.event_packet_error_valid_o &&
              !b.d.event_packet_restartable_o &&
              b.d.event_packet_saved_cs_o==kCodeSelector &&
              b.d.event_packet_saved_ip_o==0x020a &&
              b.d.event_packet_saved_flags_o==saved_flags &&
              b.d.event_packet_saved_sp_o==0x0080 &&
              !b.d.nmi_pending_o && b.d.nmi_blocked_o &&
              b.retired==retired_before,
              "valid protected NMI did not leave shutdown with the interrupted context");
        std::vector<Bench::Transfer> frame_writes;
        for (const auto& transfer:b.data_transfers)
            if (transfer.write && transfer.address>=kStackBase+0x007a &&
                transfer.address<kStackBase+0x0080) frame_writes.push_back(transfer);
        const uint8_t expected_values[]={
            uint8_t(saved_flags),uint8_t(saved_flags>>8),
            uint8_t(kCodeSelector),uint8_t(kCodeSelector>>8),0x0a,0x02
        };
        const uint32_t expected_addresses[]={
            kStackBase+0x007e,kStackBase+0x007f,kStackBase+0x007c,
            kStackBase+0x007d,kStackBase+0x007a,kStackBase+0x007b
        };
        check(frame_writes.size()==6,"NMI shutdown recovery did not write one exact three-word frame");
        for (unsigned i=0;i<6;++i)
            check(frame_writes[i].address==expected_addresses[i] &&
                  frame_writes[i].value==expected_values[i],
                  "NMI shutdown-recovery frame byte order/value mismatch");
        b.step(kHandlerBase+kHandlerIp,0xb8,kHandlerSelector,kHandlerIp+3,wait);
        b.step(kHandlerBase+kHandlerIp+3,0xf4,kHandlerSelector,kHandlerIp+4,wait);
        check(b.d.halted_o && !b.d.shutdown_o && b.reg(0)==0x1234 &&
              b.d.ip_o==kHandlerIp+4 && b.retired==retired_before+2,
              "NMI handler did not execute after successful shutdown recovery");
        ++recovered;
    }
    check(recovered==2,"shutdown NMI recovery missed an immediate/stalled READY mode");

    unsigned failed=0;
    for (bool wait:{false,true})
      for (unsigned failure_kind=0;failure_kind<3;++failure_kind) {
        Bench b;
        const uint16_t idt_limit=failure_kind==1 ? 0x000f : 0x006f;
        prepare(b,wait,idt_limit,failure_kind==2);
        if (failure_kind==2)
            b.put(kIdtBase+2*8,{0x00,0x03,0x10,0x00,0x00,0x86,0x00,0x00});
        b.data_transfers.clear();
        b.d.nmi_i=1;
        bool left_shutdown=false;
        for (unsigned cycle=0;cycle<50000;++cycle) {
            b.tick(wait);
            left_shutdown=left_shutdown || !b.d.shutdown_o;
            if (left_shutdown && b.d.shutdown_o && b.d.halted_o) break;
        }
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              left_shutdown && !b.d.retire_o && !b.d.nmi_pending_o,
              "fault while processing shutdown NMI did not re-enter shutdown");
        if (failure_kind==0) {
            check(b.data_transfers.size()==8,
                  "invalid NMI gate performed an unexpected transfer or did not read all gate bytes");
            for (unsigned i=0;i<8;++i)
                check(!b.data_transfers[i].write &&
                      b.data_transfers[i].address==kIdtBase+2*8+i,
                      "invalid NMI gate read an unexpected address");
        } else if (failure_kind==1) {
            check(b.data_transfers.empty(),
                  "out-of-limit NMI gate issued an IDT descriptor read");
        }
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& transfer) {
                  return transfer.write;
              }),"failed NMI delivery partially wrote a handler frame");
        if (failure_kind!=1) {
            // Once NMI processing faults, only RESET may leave shutdown.
            b.put(kIdtBase+2*8,
                  {nmi_gate[0],nmi_gate[1],nmi_gate[2],nmi_gate[3],
                   nmi_gate[4],nmi_gate[5],nmi_gate[6],nmi_gate[7]});
            b.d.nmi_i=0; b.tick(wait); b.d.nmi_i=1;
            for (unsigned cycle=0;cycle<16;++cycle) b.tick(wait);
            check(b.d.shutdown_o && b.d.halted_o && !b.d.bus_req_o &&
                  !b.d.fault_o && b.cs()==kCodeSelector,
                  "a second NMI exited shutdown after NMI delivery had already faulted");
        }
        b.d.nmi_i=0;
        b.reset();
        check(!b.d.shutdown_o,"RESET did not clear shutdown after a failed NMI recovery");
        ++failed;
      }
    check(failed==6,"failed NMI recovery missed a fault phase or READY mode");
    std::cout<<"PASS: protected shutdown ignores INTR, exits through a valid NMI gate, and re-enters shutdown on NMI delivery faults in both READY modes\n";
}

static void protected_iopl_controls() {
    using namespace protected_mode_fixture;
    struct Level { uint16_t cs,ss; uint32_t code_base,stack_base; };
    const Level levels[]={
        {0x0008,0x0028,kCodeBase,kStackBase},
        {0x0060,0x0068,0x00060000,0x00080000},
        {0x0070,0x0078,0x00060000,0x00080000},
        {0x0038,0x0040,0x00060000,0x00080000}
    };
    const uint8_t ring0_program[]={
        0xb8,0x28,0x00, 0x8e,0xd0,       // 0200 Install ring-0 SS.
        0xbc,0x80,0x00,                   // 0205 SP=0080.
        0xb8,0x58,0x00, 0x0f,0x00,0xd8, // 0208 LTR TSS.
        0xb8,0x34,0x12,                   // 020E AX test data.
        0xba,0x44,0x00,                   // 0211 DX port.
        0xb9,0x01,0x00,                   // 0214 CX=1 for REP string cases.
        0xbe,0x10,0x00,                   // 0217 SI=0010.
        0xbf,0x20,0x00,                   // 021A DI=0020.
        0xcf,0xf4                         // 021D IRET.
    };
    struct Context { Level level; uint16_t flags,sp; };
    auto prepare=[&](Bench& b,bool wait,unsigned cpl,unsigned iopl,
                     const std::vector<uint8_t>& program,bool if_enabled=true,
                     uint16_t idt_limit=0x07ff,uint16_t gdt_limit=0x007f) {
        check(cpl<4 && iopl<4,"invalid IOPL fixture level");
        place_selector_fixture(b,ring0_program,sizeof(ring0_program));
        b.memory[0x46]=uint8_t(idt_limit);
        b.memory[0x47]=uint8_t(idt_limit>>8);
        b.memory[0x40]=uint8_t(gdt_limit);
        b.memory[0x41]=uint8_t(gdt_limit>>8); // GDT limit for the selected fixture.
        for (unsigned dpl=1;dpl<=3;++dpl) {
            const uint16_t code=dpl==1 ? 0x0060 : dpl==2 ? 0x0070 : 0x0038;
            const uint16_t stack=dpl==1 ? 0x0068 : dpl==2 ? 0x0078 : 0x0040;
            b.put(kGdtBase+code,{0xff,0x0f,0x00,0x00,0x06,
                                  uint8_t(0x9a|(dpl<<5)),0x00,0x00});
            b.put(kGdtBase+stack,{0xff,0xff,0x00,0x00,0x08,
                                   uint8_t(0x92|(dpl<<5)),0x00,0x00});
        }
        b.put(kGdtBase+0x58,{0x2b,0x00,0x00,0x00,0x07,0x81,0x00,0x00});
        b.put(kIdtBase+13*8,{0x00,0x03,0x30,0x00,0x00,0x86,0x00,0x00});
        b.put(0x00070002,{0x00,0x01,0x28,0x00}); // TSS SP0:SS0.
        b.put(kHandlerBase+kHandlerIp,{0xf4});
        b.memory[0x0010]=0x5a; b.memory[0x0011]=0xa5;
        for (std::size_t i=0;i<program.size();++i)
            b.memory[levels[cpl].code_base+0x0400+uint32_t(i)]=program[i];
        const uint16_t target_cs=levels[cpl].cs|uint16_t(cpl);
        const uint16_t target_ss=levels[cpl].ss|uint16_t(cpl);
        const uint16_t target_flags=uint16_t(0x0002|(if_enabled ? 0x0200 : 0)|(iopl<<12));
        auto put_word=[&](uint32_t address,uint16_t value) {
            b.memory[address]=uint8_t(value); b.memory[address+1]=uint8_t(value>>8);
        };
        put_word(kStackBase+0x0080,0x0400);
        put_word(kStackBase+0x0082,target_cs);
        put_word(kStackBase+0x0084,target_flags);
        if (cpl!=0) {
            put_word(kStackBase+0x0086,0x0100);
            put_word(kStackBase+0x0088,target_ss);
        }

        protected_mode_boot(b,wait);
        b.step(kCodeBase+0x0200,0xb8,kCodeSelector,0x0203,wait);
        b.step(kCodeBase+0x0203,0x8e,kCodeSelector,0x0205,wait);
        b.step(kCodeBase+0x0205,0xbc,kCodeSelector,0x0208,wait);
        b.step(kCodeBase+0x0208,0xb8,kCodeSelector,0x020b,wait);
        b.step(kCodeBase+0x020b,0x0f,kCodeSelector,0x020e,wait);
        b.step(kCodeBase+0x020e,0xb8,kCodeSelector,0x0211,wait);
        b.step(kCodeBase+0x0211,0xba,kCodeSelector,0x0214,wait);
        b.step(kCodeBase+0x0214,0xb9,kCodeSelector,0x0217,wait);
        b.step(kCodeBase+0x0217,0xbe,kCodeSelector,0x021a,wait);
        b.step(kCodeBase+0x021a,0xbf,kCodeSelector,0x021d,wait);
        b.step(kCodeBase+0x021d,0xcf,target_cs,0x0400,wait);
        check(b.cs()==target_cs && b.d.ip_o==0x0400 && b.d.flags_o==target_flags &&
              b.reg(4)==(cpl==0 ? 0x0086 : 0x0100),
              "ring-level IRET did not establish the requested CPL, IOPL, IF and stack");
        return Context{levels[cpl],target_flags,uint16_t(cpl==0 ? 0x0086 : 0x0100)};
    };

    struct IoCase { const char* name; std::vector<uint8_t> bytes; bool input,word; };
    const IoCase io_cases[]={
        {"IN AL,imm8",{0xe4,0x44},true,false}, {"IN AX,imm8",{0xe5,0x44},true,true},
        {"IN AL,DX",{0xec},true,false},       {"IN AX,DX",{0xed},true,true},
        {"OUT imm8,AL",{0xe6,0x44},false,false}, {"OUT imm8,AX",{0xe7,0x44},false,true},
        {"OUT DX,AL",{0xee},false,false},        {"OUT DX,AX",{0xef},false,true}
    };
    unsigned matrix_cases=0;
    for (bool wait:{false,true}) for (const auto& test:io_cases)
      for (unsigned cpl=0;cpl<4;++cpl) for (unsigned iopl=0;iopl<4;++iopl) {
        std::vector<uint8_t> program=test.bytes; program.push_back(0xf4);
        Bench b;
        const Context context=prepare(b,wait,cpl,iopl,program);
        b.ports[0x44]=0x5a; b.ports[0x45]=0xa5;
        const auto ports_before=b.ports;
        b.data_transfers.clear();
        const unsigned retired_before=b.retired;
        const bool allowed=cpl<=iopl;
        if (allowed) {
            b.step(context.level.code_base+0x0400,test.bytes[0],context.level.cs|uint16_t(cpl),
                   uint16_t(0x0400+test.bytes.size()),wait);
            check(!b.d.event_o && !b.d.fault_o && b.retired==retired_before+1 &&
                  b.cs()==(context.level.cs|uint16_t(cpl)) &&
                  b.d.ip_o==0x0400+test.bytes.size(),
                  "permitted protected I/O did not retire at its exact successor");
            std::vector<Bench::Transfer> io;
            for (const auto& transfer:b.data_transfers) if (transfer.io) io.push_back(transfer);
            const unsigned width=test.word ? 2 : 1;
            check(io.size()==width,"permitted protected I/O issued the wrong number of port bytes");
            for (unsigned byte=0;byte<width;++byte) {
                check(io[byte].address==0x44+byte && io[byte].write==!test.input,
                      "permitted protected I/O used the wrong port or direction");
                if (test.input)
                    check(io[byte].value==(byte==0 ? 0x5a : 0xa5),
                          "permitted protected IN read the wrong port byte");
                else check(io[byte].value==(byte==0 ? 0x34 : 0x12),
                           "permitted protected OUT wrote the wrong register byte");
            }
            if (test.input)
                check(b.reg(0)==(test.word ? 0xa55a : 0x125a),
                      "permitted protected IN updated AX incorrectly");
            else check(b.ports[0x44]==0x34 &&
                       (!test.word || b.ports[0x45]==0x12),
                       "permitted protected OUT did not update the port image");
        } else {
            bool event_seen=false,handler_entered=false;
            for (unsigned cycle=0;cycle<50000 && !b.d.fault_o;++cycle) {
                b.tick(wait);
                event_seen=event_seen||b.d.event_o;
                if (event_seen && b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp) {
                    handler_entered=true; break;
                }
            }
            check(handler_entered && !b.d.fault_o && b.d.event_packet_valid_o &&
                  b.d.event_packet_protected_o && b.d.event_packet_error_valid_o &&
                  b.d.event_packet_restartable_o && b.d.event_vector_o==13 &&
                  b.d.event_packet_error_code_o==0 &&
                  b.d.event_packet_saved_cs_o==(context.level.cs|uint16_t(cpl)) &&
                  b.d.event_packet_saved_ip_o==0x0400 &&
                  b.d.event_packet_saved_flags_o==context.flags &&
                  b.d.event_packet_saved_sp_o==context.sp && b.retired==retired_before &&
                  b.reg(0)==0x1234 && b.reg(2)==0x0044 && b.ports==ports_before,
                  (std::string("denied ")+test.name+" did not raise restartable #GP(0) before I/O").c_str());
            check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                      return t.io;
                  }),"denied protected I/O issued a port transfer before #GP(0)");
        }
        ++matrix_cases;
    }
    check(matrix_cases==256,"direct I/O privilege matrix missed an opcode/CPL/IOPL/READY case");

    struct StringCase { uint8_t opcode; bool input,word; };
    const StringCase string_cases[]={
        {0x6c,true,false},{0x6d,true,true},{0x6e,false,false},{0x6f,false,true}
    };
    unsigned string_cases_run=0;
    for (bool wait:{false,true}) for (const auto& test:string_cases)
      for (unsigned cpl:{0u,3u}) {
        const bool allowed=cpl==0;
        const std::vector<uint8_t> program={0xf3,test.opcode,0xf4};
        Bench b;
        const Context context=prepare(b,wait,cpl,0,program);
        b.ports[0x44]=0x5a; b.ports[0x45]=0xa5;
        const auto ports_before=b.ports;
        const uint8_t destination0=b.memory[0x20],destination1=b.memory[0x21];
        b.data_transfers.clear();
        const unsigned retired_before=b.retired;
        if (allowed) {
            b.step(context.level.code_base+0x0400,test.opcode,context.level.cs|uint16_t(cpl),0x0402,wait);
            if (!(b.retired==retired_before+1 && b.cs()==context.level.cs && b.d.ip_o==0x0402 &&
                  b.reg(1)==0 && b.reg(test.input ? 7 : 6)==
                      uint16_t((test.input ? 0x20 : 0x10)+(test.word ? 2 : 1))))
                throw std::runtime_error(std::string("permitted REP ")+
                    (test.input ? "INS" : "OUTS")+(test.word ? " word" : " byte")+
                    " did not complete one exact element: retired="+std::to_string(b.retired-retired_before)+
                    " CS:IP="+std::to_string(b.cs())+":"+std::to_string(b.d.ip_o)+
                    " CX="+std::to_string(b.reg(1))+" SI="+std::to_string(b.reg(6))+
                    " DI="+std::to_string(b.reg(7))+" event="+std::to_string(b.d.event_o));
            if (test.input) {
                check(b.memory[0x20]==0x5a &&
                      (!test.word || b.memory[0x21]==0xa5) && b.ports==ports_before,
                      "permitted REP INS used the wrong data or port");
            } else {
                check(b.ports[0x44]==0x5a &&
                      (!test.word || b.ports[0x45]==0xa5) &&
                      b.memory[0x10]==0x5a && b.memory[0x11]==0xa5,
                      "permitted REP OUTS used the wrong memory or port data");
            }
        } else {
            bool event_seen=false,handler_entered=false;
            for (unsigned cycle=0;cycle<50000 && !b.d.fault_o;++cycle) {
                b.tick(wait);
                event_seen=event_seen||b.d.event_o;
                if (event_seen && b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp) {
                    handler_entered=true; break;
                }
            }
            check(handler_entered && b.d.event_vector_o==13 &&
                  b.d.event_packet_restartable_o &&
                  b.d.event_packet_error_valid_o && b.d.event_packet_error_code_o==0 &&
                  b.d.event_packet_saved_ip_o==0x0400 &&
                  b.d.event_packet_saved_cs_o==(context.level.cs|3) &&
                  b.d.event_packet_saved_flags_o==context.flags &&
                  b.d.event_packet_saved_sp_o==context.sp && b.reg(1)==1 &&
                  b.reg(6)==0x10 && b.reg(7)==0x20 && b.retired==retired_before &&
                  b.ports==ports_before && b.memory[0x20]==destination0 &&
                  b.memory[0x21]==destination1,
                  "denied REP string I/O did not fault at its prefix before the first element");
            check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                      return t.io || t.address==0x10 || t.address==0x11 ||
                             t.address==0x20 || t.address==0x21;
                  }),"denied REP string I/O transferred port or operand data before #GP(0)");
        }
        ++string_cases_run;
    }
    check(string_cases_run==16,"INS/OUTS privilege cases missed a width or READY mode");

    for (bool wait:{false,true}) for (uint8_t opcode:{uint8_t(0xfa),uint8_t(0xfb)})
      for (bool allowed:{false,true}) {
        const bool initial_if=opcode==0xfa;
        const std::vector<uint8_t> program={opcode,0xf4};
        Bench b;
        const unsigned iopl=allowed ? 3 : 0;
        const Context context=prepare(b,wait,3,iopl,program,initial_if);
        b.data_transfers.clear();
        const unsigned retired_before=b.retired;
        if (allowed) {
            b.step(context.level.code_base+0x0400,opcode,context.level.cs|3,0x0401,wait);
            check(bool(b.d.flags_o&0x0200)==(opcode==0xfb) && b.retired==retired_before+1,
                  "permitted CLI/STI did not update IF and retire");
        } else {
            bool event_seen=false,handler_entered=false;
            for (unsigned cycle=0;cycle<50000 && !b.d.fault_o;++cycle) {
                b.tick(wait);
                event_seen=event_seen||b.d.event_o;
                if (event_seen && b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp) {
                    handler_entered=true; break;
                }
            }
            check(handler_entered && b.d.event_vector_o==13 &&
                  b.d.event_packet_restartable_o &&
                  b.d.event_packet_error_valid_o && b.d.event_packet_error_code_o==0 &&
                  b.d.event_packet_saved_ip_o==0x0400 &&
                  b.d.event_packet_saved_flags_o==context.flags &&
                  b.retired==retired_before,
                  "restricted CLI/STI did not raise #GP(0) without changing saved IF");
        }
    }

    // HLT is privileged at every nonzero CPL, independently of IOPL.
    unsigned hlt_cases=0;
    for (bool wait:{false,true}) for (unsigned cpl=0;cpl<4;++cpl)
      for (unsigned iopl=0;iopl<4;++iopl) {
        const std::vector<uint8_t> program={0xf4,0xf4};
        Bench b;
        const Context context=prepare(b,wait,cpl,iopl,program);
        const unsigned retired_before=b.retired;
        if (cpl==0) {
            b.step(context.level.code_base+0x0400,0xf4,context.level.cs,0x0401,wait);
            check(b.d.halted_o && !b.d.event_o && b.d.bus_halt_cycle_o &&
                  !b.d.bus_shutdown_cycle_o && !b.d.bus_req_o &&
                  b.retired==retired_before+1,
                  "CPL-0 HLT did not retire and enter HALT");
            for (unsigned cycle=0;cycle<8;++cycle) {
                b.tick(wait,0);
                check(b.d.halted_o && b.d.bus_halt_cycle_o &&
                      !b.d.bus_shutdown_cycle_o && !b.d.bus_req_o,
                      "HLT bus cycle depended on READY or issued a byte request");
            }
        } else {
            bool event_seen=false,handler_entered=false;
            for (unsigned cycle=0;cycle<50000 && !b.d.fault_o;++cycle) {
                b.tick(wait);
                event_seen=event_seen||b.d.event_o;
                if (event_seen && b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp) {
                    handler_entered=true; break;
                }
            }
            check(handler_entered && !b.d.fault_o && !b.d.halted_o &&
                  b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
                  b.d.event_packet_error_valid_o && b.d.event_packet_restartable_o &&
                  b.d.event_vector_o==13 && b.d.event_packet_error_code_o==0 &&
                  b.d.event_packet_saved_cs_o==(context.level.cs|uint16_t(cpl)) &&
                  b.d.event_packet_saved_ip_o==0x0400 &&
                  b.d.event_packet_saved_flags_o==context.flags &&
                  b.d.event_packet_saved_sp_o==context.sp &&
                  b.retired==retired_before && b.reg(0)==0x1234,
                  "nonzero-CPL HLT did not raise restartable #GP(0) before halting");
        }
        ++hlt_cases;
      }
    check(hlt_cases==32,"HLT privilege matrix missed a CPL/IOPL/READY case");

    // Intel 210498-005 §9.6.2: a second #GP while invoking the first #GP
    // handler escalates to #DF. A protection violation while invoking #DF
    // enters the 286 shutdown state.
    unsigned double_fault_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        const Context context=prepare(b,wait,3,0,{0xf4},true,0x0047);
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0}); // Invalid #DF gate causes shutdown.
        const unsigned retired_before=b.retired;
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<50000 && !b.d.shutdown_o && !b.d.fault_o;++cycle) b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==(context.level.cs|3) &&
              b.d.event_packet_saved_ip_o==0x0400 &&
              b.d.event_packet_saved_flags_o==context.flags &&
              b.d.event_packet_saved_sp_o==context.sp && b.retired==retired_before,
              "invalid protected #DF gate did not enter shutdown with the original null-error packet");
        check(b.data_transfers.size()==8,
              "double-fault shutdown read more than the vector-8 gate descriptor");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[i].write &&
                  b.data_transfers[i].address==kIdtBase+8*8+i,
                  "double-fault shutdown read an unexpected IDT entry or wrote a frame");
        for (unsigned cycle=0;cycle<8;++cycle) {
            b.tick(wait);
            check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
                  b.retired==retired_before,
                  "shutdown did not remain quiescent until reset");
        }
        b.reset();
        check(!b.d.shutdown_o,"RESET did not leave protected double-fault shutdown");
        ++double_fault_cases;
    }
    check(double_fault_cases==2,"double-fault escalation missed a READY policy");
    std::cout<<"PASS: "<<double_fault_cases
             <<" nested protected #GP cases enter sticky #DF shutdown after reading an invalid vector-8 gate in both READY modes\n";

    unsigned double_fault_limit_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        const Context context=prepare(b,wait,3,0,{0xf4},true,0x0046);
        const unsigned retired_before=b.retired;
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<50000 && !b.d.shutdown_o && !b.d.fault_o;++cycle) b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==(context.level.cs|3) &&
              b.d.event_packet_saved_ip_o==0x0400 &&
              b.d.event_packet_saved_flags_o==context.flags &&
              b.d.event_packet_saved_sp_o==context.sp && b.retired==retired_before,
              "vector-8 IDT-limit violation did not enter shutdown with the original #DF context");
        check(b.data_transfers.empty(),
              "vector-8 IDT-limit shutdown issued an out-of-bounds IDT transfer");
        ++double_fault_limit_cases;
    }
    check(double_fault_limit_cases==2,"double-fault IDT-limit cases missed a READY policy");
    std::cout<<"PASS: "<<double_fault_limit_cases
             <<" nested protected #GP cases enter shutdown when the vector-8 gate exceeds the IDT limit in both READY modes\n";

    unsigned divide_error_gate_escalation_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        const Context context=prepare(b,wait,3,0,{0xf7,0xf3},true,0x0047);
        b.put(kIdtBase,{0,0,0,0,0,0,0,0}); // Invalid #DE handler gate.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0}); // Invalid #DF gate.
        const unsigned retired_before=b.retired;
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<50000 && !b.d.shutdown_o && !b.d.fault_o;++cycle) b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==(context.level.cs|3) &&
              b.d.event_packet_saved_ip_o==0x0400 &&
              b.d.event_packet_saved_flags_o==context.flags &&
              b.d.event_packet_saved_sp_o==context.sp && b.retired==retired_before,
              "invalid #DE handler gate did not escalate to null-error #DF and then shutdown");
        check(b.data_transfers.size()==16,
              "#DE-to-#DF escalation read an unexpected table entry or wrote an event frame");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[i].write && b.data_transfers[i].address==kIdtBase+i,
                  "#DE handler-gate validation read an unexpected IDT byte");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[8+i].write &&
                  b.data_transfers[8+i].address==kIdtBase+8*8+i,
                  "#DF handler-gate validation read an unexpected IDT byte");
        ++divide_error_gate_escalation_cases;
    }
    check(divide_error_gate_escalation_cases==2,
          "#DE handler-gate escalation missed a READY policy");
    std::cout<<"PASS: 2 protected #DE handler-gate faults escalate to #DF and shut down on an invalid #DF gate in both READY modes\n";

    // Intel 210498-005 §9.6.2: a protection fault while looking up the
    // handler for contributory #NP or #SS escalates to a null-error #DF.
    // The invalid vector-8 gate then makes shutdown observable in this slice.
    unsigned contributory_first_fault_cases=0;
    for (bool wait:{false,true}) {
        {
            const std::vector<uint8_t> program={0xea,0x00,0x04,0x3b,0x00};
            Bench b;
            const Context context=prepare(b,wait,3,0,program,true,0x0047);
            // The current CS cache stays present, while reloading its now
            // non-present descriptor through a far jump raises #NP.
            b.memory[kGdtBase+0x38+5]=0x7a;
            const unsigned retired_before=b.retired;
            b.data_transfers.clear();
            for (unsigned cycle=0;cycle<50000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
                b.tick(wait);
            check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
                  b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
                  b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
                  b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
                  b.d.event_packet_saved_cs_o==(context.level.cs|3) &&
                  b.d.event_packet_saved_ip_o==0x0400 &&
                  b.d.event_packet_saved_flags_o==context.flags &&
                  b.d.event_packet_saved_sp_o==context.sp && b.retired==retired_before,
                  "non-present far-jump target did not escalate #NP to null-error #DF shutdown");
            check(b.data_transfers.size()==16,
                  "#NP-to-#DF escalation read an unexpected descriptor or gate");
            for (unsigned i=0;i<8;++i)
                check(!b.data_transfers[i].write &&
                      b.data_transfers[i].address==kGdtBase+0x38+i,
                      "#NP target validation read an unexpected GDT byte");
            for (unsigned i=0;i<8;++i)
                check(!b.data_transfers[8+i].write &&
                      b.data_transfers[8+i].address==kIdtBase+8*8+i,
                      "#NP-to-#DF escalation read an unexpected IDT byte or wrote a frame");
            ++contributory_first_fault_cases;
        }
        {
            const std::vector<uint8_t> program={
                0xb8,0x43,0x00, 0x8e,0xd0, 0xbc,0x00,0x01, 0x50
            };
            Bench b;
            const Context context=prepare(b,wait,3,0,program,true,0x0047);
            b.memory[kGdtBase+0x40]=0xfe; b.memory[kGdtBase+0x41]=0x00;
            b.step(context.level.code_base+0x0400,0xb8,context.level.cs|3,0x0403,wait);
            b.step(context.level.code_base+0x0403,0x8e,context.level.cs|3,0x0405,wait);
            b.step(context.level.code_base+0x0405,0xbc,context.level.cs|3,0x0408,wait);
            const unsigned retired_before=b.retired;
            b.data_transfers.clear();
            for (unsigned cycle=0;cycle<50000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
                b.tick(wait);
            check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
                  b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
                  b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
                  b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
                  b.d.event_packet_saved_cs_o==(context.level.cs|3) &&
                  b.d.event_packet_saved_ip_o==0x0408 &&
                  b.d.event_packet_saved_flags_o==context.flags &&
                  b.d.event_packet_saved_sp_o==context.sp && b.retired==retired_before,
                  "stack-limit PUSH did not escalate #SS to null-error #DF shutdown");
            check(b.data_transfers.size()==8,
                  "#SS-to-#DF escalation accessed more than the vector-8 gate");
            for (unsigned i=0;i<8;++i)
                check(!b.data_transfers[i].write &&
                      b.data_transfers[i].address==kIdtBase+8*8+i,
                      "#SS-to-#DF escalation read an unexpected table byte or wrote a frame");
            ++contributory_first_fault_cases;
        }
    }
    check(contributory_first_fault_cases==4,
          "protected #NP/#SS-to-#DF coverage missed a fault or READY policy");
    std::cout<<"PASS: 4 protected #NP/#SS first faults escalate to null-error #DF and enter sticky shutdown in both READY modes\n";

    // A valid #DF task gate switches to a present available 286 TSS. Task IRET
    // returns through its backlink, clears that task's busy bit, and restores
    // the interrupted HLT, which raises #DF again. The re-entered handler task
    // resumes after IRET and reaches its exact HLT landing.
    unsigned task_gate_switch_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        const Context context=prepare(b,wait,3,0,{0xf4},true,0x0047);
        const uint32_t target_tss_base=0x00080000;
        const uint8_t target_tss_descriptor[]={0x2b,0x00,0x00,0x00,0x08,0x81,0x00,0x00};
        const uint8_t double_fault_task_gate[]={0x00,0x00,0x50,0x00,0x00,0x85,0x00,0x00};
        b.put(kGdtBase+0x50,{target_tss_descriptor[0],target_tss_descriptor[1],
                              target_tss_descriptor[2],target_tss_descriptor[3],
                              target_tss_descriptor[4],target_tss_descriptor[5],
                              target_tss_descriptor[6],target_tss_descriptor[7]});
        b.put(kIdtBase+8*8,{double_fault_task_gate[0],double_fault_task_gate[1],
                             double_fault_task_gate[2],double_fault_task_gate[3],
                             double_fault_task_gate[4],double_fault_task_gate[5],
                             double_fault_task_gate[6],double_fault_task_gate[7]});
        const uint16_t old_cs=b.cs(),old_ss=uint16_t(b.d.segs_o>>32);
        const uint16_t old_flags=b.d.flags_o,old_sp=b.reg(4);
        const uint16_t old_regs[]={b.reg(0),b.reg(1),b.reg(2),b.reg(3),b.reg(5),b.reg(6),b.reg(7)};
        const uint16_t task_words[]={
            0x0300,0x0002,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0030,0x0028,0x0010,0x0000
        };
        auto put_word=[&](uint32_t address,uint16_t value) {
            b.memory[address]=uint8_t(value); b.memory[address+1]=uint8_t(value>>8);
        };
        auto read_word=[&](uint32_t address) {
            return uint16_t(b.memory[address]|(uint16_t(b.memory[address+1])<<8));
        };
        for (unsigned i=0;i<15;++i) put_word(target_tss_base+0x0e + 2*i,task_words[i]);
        b.put(kHandlerBase+kHandlerIp,{0xcf,0xf4});
        const unsigned retired_before=b.retired;
        b.data_transfers.clear();
        b.accepted.clear();
        unsigned event_pulses=0;
        for (unsigned cycle=0;cycle<100000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o) ++event_pulses;
        }
        if (b.d.fault_o || !b.d.halted_o || b.cs()!=0x0030 || b.d.ip_o!=0x0302 ||
            b.d.flags_o!=0x4002 || !(b.d.msw_o&0x0008) || event_pulses!=2) {
            std::cerr<<"task-gate state fault="<<unsigned(b.d.fault_o)
                     <<" code="<<unsigned(b.d.fault_code_o)
                     <<" halted="<<unsigned(b.d.halted_o)
                     <<" cs:ip="<<std::hex<<b.cs()<<":"<<b.d.ip_o
                     <<" flags="<<b.d.flags_o<<" msw="<<b.d.msw_o<<std::dec
                     <<" events="<<event_pulses<<" transfers="<<b.data_transfers.size();
            if (!b.data_transfers.empty()) {
                const auto& last=b.data_transfers.back();
                std::cerr<<" last="<<std::hex<<last.address<<":"
                         <<unsigned(last.write)<<":"<<unsigned(last.value)<<std::dec;
            }
            std::cerr<<'\n';
        }
        check(!b.d.fault_o && b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0302 &&
              b.d.flags_o==0x4002 && (b.d.msw_o&0x0008) && event_pulses==2 &&
              b.retired==retired_before+2,
              "task IRET did not restore the interrupted task and resume after IRET on re-entry");
        check(b.reg(0)==0xa001 && b.reg(1)==0xc003 && b.reg(2)==0xd004 &&
              b.reg(3)==0xb005 && b.reg(4)==0x007c && b.reg(5)==0xb007 &&
              b.reg(6)==0x5108 && b.reg(7)==0xd109 &&
              uint16_t(b.d.segs_o)==0x0020 && uint16_t(b.d.segs_o>>16)==0x0030 &&
              uint16_t(b.d.segs_o>>32)==0x0028 && uint16_t(b.d.segs_o>>48)==0x0010 &&
              b.cache_base(0)==kEsDataBase && b.cache_base(1)==kHandlerBase &&
              b.cache_base(2)==kStackBase && b.cache_base(3)==kWideDataBase,
              "#DF task gate did not load the incoming registers and segment caches");
        check(read_word(target_tss_base)==0x0058 && b.memory[kGdtBase+0x55]==0x83 &&
              b.memory[kGdtBase+0x5d]==0x83 &&
              b.memory[kStackBase+0x7e]==0 && b.memory[kStackBase+0x7f]==0 &&
              b.memory[kStackBase+0x7c]==0 && b.memory[kStackBase+0x7d]==0,
              "nested task switch did not restore backlink/busy state or push both #DF error words");
        check(read_word(target_tss_base+0x0e)==0x0301 &&
              read_word(target_tss_base+0x10)==0x0002 &&
              read_word(target_tss_base+0x1a)==0x007e,
              "task IRET did not save its post-instruction IP, cleared NT and current SP");
        const uint16_t outgoing_words[]={
            0x0400,old_flags,old_regs[0],old_regs[1],old_regs[2],old_regs[3],old_sp,
            old_regs[4],old_regs[5],old_regs[6],0x0000,old_cs,old_ss,0x0000,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(read_word(0x00070000+0x0e + 2*i)==outgoing_words[i],
                  "#DF task switch did not save the outgoing task-state image");
        const auto first_task_iret=std::find(b.accepted.begin(),b.accepted.end(),kHandlerBase+kHandlerIp);
        const auto restored_faulting_task=first_task_iret==b.accepted.end() ? b.accepted.end() :
            std::find(std::next(first_task_iret),b.accepted.end(),context.level.code_base+0x0400);
        const auto resumed_handler=restored_faulting_task==b.accepted.end() ? b.accepted.end() :
            std::find(std::next(restored_faulting_task),b.accepted.end(),kHandlerBase+kHandlerIp+1);
        check(first_task_iret!=b.accepted.end() && restored_faulting_task!=b.accepted.end() &&
              resumed_handler!=b.accepted.end(),
              "task IRET did not fetch from the interrupted task before re-entering at the saved handler successor");
        bool busy_cleared=false,busy_restored=false;
        for (const auto& transfer:b.data_transfers) if (transfer.write && transfer.address==kGdtBase+0x55) {
            if (transfer.value==0x81) busy_cleared=true;
            if (transfer.value==0x83 && busy_cleared) busy_restored=true;
        }
        check(busy_cleared && busy_restored,
              "task IRET did not clear the outgoing busy bit before the task was invoked again");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& transfer) {
                  return !transfer.write && transfer.address==kIdtBase+8*8 &&
                         transfer.value==double_fault_task_gate[0];
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& transfer) {
                  return !transfer.write && transfer.address==kGdtBase+0x50 &&
                         transfer.value==target_tss_descriptor[0];
              }),
              "#DF task switch skipped IDT task-gate or TSS descriptor reads");
        ++task_gate_switch_cases;
    }
    check(task_gate_switch_cases==2,
          "#DF task-gate switch missed a READY policy");
    std::cout<<"PASS: #DF task entry saves/loads 286 TSS state; task IRET clears busy and restores the interrupted task; re-entry resumes at the saved handler successor in both READY modes\n";

    // Reset after each accepted data beat in the nested #DF task-gate entry.
    // Accepted external writes survive reset, but the core must return to the
    // reset vector without resuming a partial task switch or event packet.
    const uint32_t reset_cut_tss_base=0x00080000;
    const uint8_t reset_cut_tss_descriptor[]={0x2b,0x00,0x00,0x00,0x08,0x81,0x00,0x00};
    const uint8_t reset_cut_task_gate[]={0x00,0x00,0x50,0x00,0x00,0x85,0x00,0x00};
    const uint16_t reset_cut_task_words[]={
        0x0300,0x0002,0xa001,0xc003,0xd004,0xb005,0x0080,
        0xb007,0x5108,0xd109,0x0020,0x0030,0x0028,0x0010,0x0000
    };
    auto prepare_task_reset_cut=[&](Bench& b,bool wait) {
        const Context context=prepare(b,wait,3,0,{0xf4},true,0x0047);
        b.put(kGdtBase+0x50,{reset_cut_tss_descriptor[0],reset_cut_tss_descriptor[1],
                              reset_cut_tss_descriptor[2],reset_cut_tss_descriptor[3],
                              reset_cut_tss_descriptor[4],reset_cut_tss_descriptor[5],
                              reset_cut_tss_descriptor[6],reset_cut_tss_descriptor[7]});
        b.put(kIdtBase+8*8,{reset_cut_task_gate[0],reset_cut_task_gate[1],
                             reset_cut_task_gate[2],reset_cut_task_gate[3],
                             reset_cut_task_gate[4],reset_cut_task_gate[5],
                             reset_cut_task_gate[6],reset_cut_task_gate[7]});
        for (unsigned i=0;i<15;++i) {
            const uint32_t address=reset_cut_tss_base+0x0e + 2*i;
            const uint16_t value=reset_cut_task_words[i];
            b.memory[address]=uint8_t(value);
            b.memory[address+1]=uint8_t(value>>8);
        }
        b.put(kHandlerBase+kHandlerIp,{0xcf,0xf4});
        b.data_transfers.clear();
        b.accepted.clear();
        return context;
    };
    unsigned reset_cut_transfer_count=0,task_switch_reset_cuts=0;
    for (bool wait:{false,true}) {
        Bench baseline;
        prepare_task_reset_cut(baseline,wait);
        bool entered=false;
        for (unsigned cycle=0;cycle<100000 && !baseline.d.fault_o;++cycle) {
            baseline.tick(wait);
            if (baseline.d.event_o && baseline.cs()==0x0030 && baseline.d.ip_o==0x0300) {
                entered=true;
                break;
            }
        }
        check(entered && !baseline.data_transfers.empty(),
              "task-gate reset-cut baseline did not reach the incoming handler");
        const unsigned transfer_count=static_cast<unsigned>(baseline.data_transfers.size());
        if (!reset_cut_transfer_count) reset_cut_transfer_count=transfer_count;
        else check(transfer_count==reset_cut_transfer_count,
                   "task-gate reset-cut transfer count changed across READY policies");
        for (unsigned cut=0;cut<transfer_count;++cut) {
            Bench b;
            prepare_task_reset_cut(b,wait);
            bool transfer_accepted=false;
            for (unsigned cycle=0;cycle<100000 && !b.d.fault_o;++cycle) {
                b.tick(wait);
                if (b.data_transfers.size()>cut) {
                    transfer_accepted=true;
                    break;
                }
            }
            check(transfer_accepted && b.data_transfers.size()==cut+1,
                  "task-gate reset cut did not stop after its selected accepted transfer");
            b.reset();
            check(!b.d.event_packet_valid_o && !b.d.bus_req_o &&
                  !b.d.bus_halt_cycle_o && !b.d.bus_shutdown_cycle_o,
                  "RESET left task-switch event state or a special bus cycle active");
            b.put(0xfffff0,{0xf4});
            b.step(0xfffff0,0xf4,0xf000,0xfff1,wait);
            check(b.d.halted_o && b.d.bus_halt_cycle_o &&
                  !b.d.bus_shutdown_cycle_o && !b.d.shutdown_o,
                  "RESET did not execute the reset-vector HLT after a task-switch cut");
            ++task_switch_reset_cuts;
        }
    }
    check(task_switch_reset_cuts==2*reset_cut_transfer_count,
          "task-switch reset cuts missed accepted transfers or READY policies");
    std::cout<<"PASS: "<<task_switch_reset_cuts
             <<" reset cuts after every accepted data transfer during nested #DF task-gate entry, with exact reset-vector replay in both READY modes\n";

    auto enter_df_task_handler=[&](Bench& b,bool wait) {
        for (unsigned cycle=0;cycle<100000 && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.cs()==0x0030 && b.d.ip_o==0x0300) return true;
        }
        return false;
    };
    unsigned task_iret_transfer_count=0,task_iret_reset_cuts=0;
    for (bool wait:{false,true}) {
        Bench baseline;
        const Context context=prepare_task_reset_cut(baseline,wait);
        check(enter_df_task_handler(baseline,wait),
              "task-IRET reset-cut baseline did not enter the #DF handler task");
        baseline.data_transfers.clear();
        bool returned=false;
        for (unsigned cycle=0;cycle<100000 && !baseline.d.fault_o;++cycle) {
            baseline.tick(wait);
            if (baseline.cs()==uint16_t(context.level.cs|3) &&
                baseline.d.ip_o==0x0400 && (baseline.d.msw_o&1)) {
                returned=true;
                break;
            }
        }
        check(returned && !baseline.data_transfers.empty(),
              "task-IRET reset-cut baseline did not return to the interrupted task");
        const unsigned transfer_count=static_cast<unsigned>(baseline.data_transfers.size());
        if (!task_iret_transfer_count) task_iret_transfer_count=transfer_count;
        else check(transfer_count==task_iret_transfer_count,
                   "task-IRET transfer count changed across READY policies");
        for (unsigned cut=0;cut<transfer_count;++cut) {
            Bench b;
            const Context cut_context=prepare_task_reset_cut(b,wait);
            check(enter_df_task_handler(b,wait),
                  "task-IRET reset cut did not enter the #DF handler task");
            b.data_transfers.clear();
            bool transfer_accepted=false;
            for (unsigned cycle=0;cycle<100000 && !b.d.fault_o;++cycle) {
                b.tick(wait);
                if (b.data_transfers.size()>cut) {
                    transfer_accepted=true;
                    break;
                }
            }
            check(transfer_accepted && b.data_transfers.size()==cut+1,
                  "task-IRET reset cut did not stop after its selected accepted transfer");
            b.reset();
            check(!b.d.event_packet_valid_o && !b.d.bus_req_o &&
                  !b.d.bus_halt_cycle_o && !b.d.bus_shutdown_cycle_o,
                  "RESET left task-IRET state or a special bus cycle active");
            b.put(0xfffff0,{0xf4});
            b.step(0xfffff0,0xf4,0xf000,0xfff1,wait);
            check(b.d.halted_o && b.d.bus_halt_cycle_o &&
                  !b.d.bus_shutdown_cycle_o && !b.d.shutdown_o,
                  "RESET did not execute reset-vector HLT after a task-IRET cut");
            check(cut_context.level.cs==context.level.cs,
                  "task-IRET reset-cut fixture changed its interrupted CS");
            ++task_iret_reset_cuts;
        }
    }
    check(task_iret_reset_cuts==2*task_iret_transfer_count,
          "task-IRET reset cuts missed accepted transfers or READY policies");
    std::cout<<"PASS: "<<task_iret_reset_cuts
             <<" reset cuts after every accepted data transfer during task IRET, with exact reset-vector replay in both READY modes\n";

    unsigned nested_df_delivery_fault_cases=0;
    for (bool wait:{false,true}) for (bool bad_ldtr:{false,true}) {
        Bench b;
        const Context context=prepare(b,wait,3,0,{0xf4},true,0x0047);
        const uint32_t target_tss_base=0x00080000;
        const uint8_t target_tss_descriptor[]={
            0x2b,0x00,0x00,0x00,0x08,uint8_t(bad_ldtr ? 0x81 : 0x01),0x00,0x00
        };
        const uint8_t double_fault_task_gate[]={0x00,0x00,0x50,0x00,0x00,0x85,0x00,0x00};
        b.put(kGdtBase+0x50,{target_tss_descriptor[0],target_tss_descriptor[1],
                              target_tss_descriptor[2],target_tss_descriptor[3],
                              target_tss_descriptor[4],target_tss_descriptor[5],
                              target_tss_descriptor[6],target_tss_descriptor[7]});
        b.put(kIdtBase+8*8,{double_fault_task_gate[0],double_fault_task_gate[1],
                             double_fault_task_gate[2],double_fault_task_gate[3],
                             double_fault_task_gate[4],double_fault_task_gate[5],
                             double_fault_task_gate[6],double_fault_task_gate[7]});
        const uint16_t task_words[]={
            0x0300,0x0002,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0030,0x0028,0x0010,
            uint16_t(bad_ldtr ? 0x005c : 0x0000)
        };
        for (unsigned i=0;i<15;++i) {
            b.memory[target_tss_base+0x0e + 2*i]=uint8_t(task_words[i]);
            b.memory[target_tss_base+0x0f + 2*i]=uint8_t(task_words[i]>>8);
        }
        const unsigned retired_before=b.retired;
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<100000 && !b.d.shutdown_o && !b.d.fault_o;++cycle) b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==(context.level.cs|3) &&
              b.d.event_packet_saved_ip_o==0x0400 &&
              b.d.event_packet_saved_flags_o==context.flags &&
              b.d.event_packet_saved_sp_o==context.sp && b.retired==retired_before,
              "nested #DF task-delivery protection violation did not enter shutdown");
        if (!bad_ldtr) {
            check(b.data_transfers.size()==16,
                  "not-present #DF task TSS issued a task-switch write or unexpected read");
            for (unsigned i=0;i<8;++i)
                check(!b.data_transfers[i].write &&
                      b.data_transfers[i].address==kIdtBase+8*8+i,
                      "not-present #DF task TSS lookup skipped the task gate read");
            for (unsigned i=0;i<8;++i)
                check(!b.data_transfers[8+i].write &&
                      b.data_transfers[8+i].address==kGdtBase+0x50+i,
                      "not-present #DF task TSS lookup read an unexpected descriptor");
        } else {
            check(b.memory[kGdtBase+0x55]==0x83 &&
                  uint16_t(b.memory[target_tss_base]|(uint16_t(b.memory[target_tss_base+1])<<8))==0x0058,
                  "incoming-LDTR #DF shutdown omitted task busy/backlink side effects");
            check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& transfer) {
                      return !transfer.write && transfer.address>=kIdtBase+10*8 &&
                             transfer.address<kIdtBase+11*8;
                  }),"incoming-LDTR #DF fault attempted to dispatch a nested #TS handler");
        }
        ++nested_df_delivery_fault_cases;
    }
    check(nested_df_delivery_fault_cases==4,
          "nested #DF task-delivery faults missed a READY policy or fault site");
    std::cout<<"PASS: 4 #DF task-gate target-TSS and incoming-LDTR protection faults enter shutdown in both READY modes\n";

    // Table 8-1 rows 1-3 are pre-transfer checks. A bad #DF target TSS must
    // shut down rather than attempt another exception delivery. The ordinary
    // task-transfer matrix checks these same exact first-fault classes; these
    // cases check their nested-#DF shutdown behavior.
    struct NestedDfTssFaultCase {
        const char* name;
        uint8_t access;
        uint16_t limit;
    };
    const NestedDfTssFaultCase nested_df_tss_faults[]={
        {"busy TSS",0x83,0x002b},
        {"short available TSS",0x81,0x002a},
        {"non-present short TSS",0x01,0x002a}
    };
    unsigned nested_df_tss_fault_cases=0;
    constexpr uint32_t nested_df_tss_base=0x00080000;
    for (bool wait:{false,true}) for (const auto& test:nested_df_tss_faults) {
        Bench b;
        const Context context=prepare(b,wait,3,0,{0xf4},true,0x0047);
        b.put(kIdtBase+8*8,{0x00,0x00,0x50,0x00,0x00,0x85,0x00,0x00});
        b.put(kGdtBase+0x50,{uint8_t(test.limit),uint8_t(test.limit>>8),
                             0x00,0x00,0x08,test.access,0x00,0x00});
        b.memory[nested_df_tss_base]=0x5a;
        b.memory[nested_df_tss_base+1]=0xa5;
        b.memory[0x0007000e]=0xa5;
        b.memory[0x0007000f]=0x5a;
        const unsigned retired_before=b.retired;
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<100000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==(context.level.cs|3) &&
              b.d.event_packet_saved_ip_o==0x0400 &&
              b.d.event_packet_saved_flags_o==context.flags &&
              b.d.event_packet_saved_sp_o==context.sp && b.retired==retired_before,
              (std::string("invalid #DF target ")+test.name+
               " did not enter shutdown with the original context").c_str());
        check(b.data_transfers.size()==16,
              (std::string("invalid #DF target ")+test.name+
               " performed unexpected task-switch traffic").c_str());
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[i].write &&
                  b.data_transfers[i].address==kIdtBase+8*8+i,
                  "invalid #DF target did not read exactly the vector-8 task gate");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[8+i].write &&
                  b.data_transfers[8+i].address==kGdtBase+0x50+i,
                  "invalid #DF target did not read exactly its TSS descriptor");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return t.write || (!t.io &&
                      ((t.address>=nested_df_tss_base && t.address<nested_df_tss_base+0x2e) ||
                       (t.address>=0x0007000e && t.address<=0x0007002c)));
              }) &&
              b.memory[kGdtBase+0x55]==test.access &&
              uint16_t(b.memory[nested_df_tss_base] |
                       (uint16_t(b.memory[nested_df_tss_base+1])<<8))==0xa55a &&
              uint16_t(b.memory[0x0007000e] |
                       (uint16_t(b.memory[0x0007000f])<<8))==0x5aa5,
              (std::string("invalid #DF target ")+test.name+
               " changed a descriptor, task image, busy bit, or error stack").c_str());
        ++nested_df_tss_fault_cases;
    }
    check(nested_df_tss_fault_cases==6,
          "Table 8-1 row 1-3 #DF target faults missed a descriptor or READY mode");
    std::cout<<"PASS: 6 nested-#DF target-TSS busy, short-limit and not-present-priority faults enter shutdown before task-state writes in both READY modes\n";

    struct BacklinkFaultCase {
        const char* name;
        uint16_t backlink;
        uint8_t access;
        uint16_t limit;
        uint8_t vector;
        uint16_t error;
    };
    const BacklinkFaultCase backlink_faults[]={
        {"null backlink",0x0000,0x83,0x002b,10,0x0000},
        {"LDT backlink",0x005c,0x83,0x002b,10,0x005c},
        {"GDT-limit backlink",0x0080,0x83,0x002b,10,0x0080},
        {"non-TSS backlink",0x0030,0x83,0x002b,10,0x0030},
        {"not-present backlink TSS",0x0058,0x03,0x002b,11,0x0058},
        {"available backlink TSS with RPL",0x005b,0x81,0x002b,13,0x0058},
        {"short backlink TSS",0x0058,0x83,0x0020,10,0x0058}
    };
    unsigned backlink_fault_cases=0;
    for (bool wait:{false,true}) for (const auto& test:backlink_faults) {
        Bench b;
        const Context context=prepare(b,wait,3,0,{0xf4},true,0x006f);
        const uint32_t target_tss_base=0x00080000;
        b.put(kGdtBase+0x50,{0x2b,0x00,0x00,0x00,0x08,0x81,0x00,0x00});
        // Use the same available task TSS for the initial ring-3 #GP, then
        // install same-task exception gates after entry for IRET fault checks.
        b.put(kIdtBase+13*8,{0x00,0x00,0x50,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0300,{0xcf,0xf4});
        b.put(kHandlerBase+0x0320,{0xf4});
        const uint16_t task_words[]={
            0x0300,0x0002,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0030,0x0028,0x0010,0x0000
        };
        auto put_word=[&](uint32_t address,uint16_t value) {
            b.memory[address]=uint8_t(value); b.memory[address+1]=uint8_t(value>>8);
        };
        for (unsigned i=0;i<15;++i)
            put_word(target_tss_base+0x0e + 2*i,task_words[i]);

        bool task_entered=false;
        unsigned event_pulses=0;
        for (unsigned cycle=0;cycle<100000 && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==13) {
                ++event_pulses;
                task_entered=true;
                break;
            }
        }
        check(task_entered && b.cs()==0x0030 && b.d.ip_o==0x0300 && !b.d.fault_o,
              "backlink-fault fixture did not enter its task-gate handler before corrupting the backlink");

        // Change the active handler task's backlink only after the valid
        // task-gate switch has completed, isolating IRET admission behavior.
        for (uint8_t vector:{10,11,13})
            b.put(kIdtBase+uint32_t(vector)*8,
                  {0x20,0x03,0x30,0x00,0x00,0x86,0x00,0x00});
        put_word(target_tss_base,test.backlink);
        b.memory[kGdtBase+0x58]=uint8_t(test.limit);
        b.memory[kGdtBase+0x59]=uint8_t(test.limit>>8);
        b.memory[kGdtBase+0x5d]=test.access;
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<100000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o) ++event_pulses;
        }

        if (b.d.fault_o || !b.d.halted_o || b.cs()!=0x0030 || b.d.ip_o!=0x0321)
            std::cerr<<"backlink delivery failure "<<test.name<<" fault="
                     <<unsigned(b.d.fault_o)<<" code="<<unsigned(b.d.fault_code_o)
                     <<" halted="<<unsigned(b.d.halted_o)<<" cs:ip="<<std::hex
                     <<b.cs()<<":"<<b.d.ip_o<<" vector="<<unsigned(b.d.event_vector_o)
                     <<" packet_error="<<b.d.event_packet_error_code_o<<std::dec
                     <<" events="<<event_pulses<<" transfers="<<b.data_transfers.size()<<'\n';
        check(!b.d.fault_o && b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0321,
              "invalid task-return backlink did not reach its same-task exception handler");
        const bool backlink_packet_ok=event_pulses==2 && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_vector_o==test.vector && b.d.event_packet_error_code_o==test.error &&
              b.d.event_packet_saved_cs_o==0x0030 && b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4002 && b.d.event_packet_saved_sp_o==0x007e;
        if (!backlink_packet_ok)
            std::cerr<<"backlink failure "<<test.name<<" expected vector/error="
                     <<unsigned(test.vector)<<"/"<<std::hex<<test.error<<" got="
                     <<unsigned(b.d.event_vector_o)<<"/"<<b.d.event_packet_error_code_o
                     <<" events="<<event_pulses<<" protected="
                     <<unsigned(b.d.event_packet_protected_o)<<" restartable="
                     <<unsigned(b.d.event_packet_restartable_o)<<" error-valid="
                     <<unsigned(b.d.event_packet_error_valid_o)<<" saved="
                     <<b.d.event_packet_saved_cs_o<<":"<<b.d.event_packet_saved_ip_o
                     <<" flags="<<b.d.event_packet_saved_flags_o<<" sp="
                     <<b.d.event_packet_saved_sp_o<<std::dec<<'\n';
        check(backlink_packet_ok,
              "invalid task-return backlink produced the wrong restartable exception packet");
        check(b.memory[target_tss_base]==uint8_t(test.backlink) &&
              b.memory[target_tss_base+1]==uint8_t(test.backlink>>8) &&
              b.memory[kGdtBase+0x55]==0x83,
              "failed task-return admission changed the backlink or active task busy state");
        for (const auto& transfer:b.data_transfers) {
            const bool wrote_dynamic=transfer.write && !transfer.io &&
                transfer.address>=target_tss_base+0x0e &&
                transfer.address<=target_tss_base+0x2c;
            const bool cleared_busy=transfer.write && !transfer.io &&
                transfer.address==kGdtBase+0x5d;
            check(!wrote_dynamic && !cleared_busy,
                  "invalid task-return admission saved state or cleared a busy bit before faulting");
        }
        ++backlink_fault_cases;
    }
    check(backlink_fault_cases==14,
          "task-return backlink fault matrix missed a READY policy or descriptor case");
    std::cout<<"PASS: 14 invalid task-return backlink cases deliver restartable #TS/#NP/#GP with selector errors before TSS save or busy-bit changes in both READY modes\n";

    struct IncomingLdtrFaultCase {
        const char* name;
        uint16_t selector;
        uint16_t error;
    };
    const IncomingLdtrFaultCase incoming_ldtr_faults[]={
        {"TI selector",0x005c,0x005c},
        {"wrong descriptor type",0x0058,0x0058},
        {"wrong descriptor type with RPL",0x005b,0x0058},
        {"not-present LDT",0x0070,0x0070},
        {"GDT-limit selector",0x0188,0x0188}
    };
    constexpr uint32_t incoming_tss1_base=0x00080000;
    constexpr uint32_t incoming_tss2_base=0x00090000;
    auto put_task_word=[](Bench& b,uint32_t address,uint16_t value) {
        b.memory[address]=uint8_t(value); b.memory[address+1]=uint8_t(value>>8);
    };
    auto setup_incoming_ldtr=[&](Bench& b,bool wait,uint16_t ldtr) {
        // Keep both tables at the documented boundary used by selector-limit
        // cases: selector 0188 starts one byte past limit 0187.
        prepare(b,wait,3,0,{0xcd,0x30,0xf4},true,0x0187,0x0187);
        b.put(kGdtBase+0x50,{0x2b,0x00,0x00,0x00,0x08,0x81,0x00,0x00});
        b.put(kGdtBase+0x60,{0x2b,0x00,0x00,0x00,0x09,0x81,0x00,0x00});
        b.put(kGdtBase+0x70,{0xff,0x00,0x00,0x00,0x00,0x02,0x00,0x00});
        b.put(kIdtBase+0x30*8,{0x00,0x00,0x50,0x00,0x00,0xe5,0x00,0x00});
        for (uint8_t vector:{10,11,12,13})
            b.put(kIdtBase+uint32_t(vector)*8,
                  {0x00,0x00,0x60,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0300,{0xf4});
        b.put(kHandlerBase+0x0400,{0xf4});
        const uint16_t task1[]={
            0x0300,0x0202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0030,0x0028,0x0010,ldtr
        };
        const uint16_t task2[]={
            0x0400,0x0002,0x0201,0x0202,0x0203,0x0204,0x0080,
            0x0205,0x0206,0x0207,0x0018,0x0030,0x0028,0x0018,0x0000
        };
        for (unsigned i=0;i<15;++i) {
            put_task_word(b,incoming_tss1_base+0x000e + 2*i,task1[i]);
            put_task_word(b,incoming_tss2_base+0x000e + 2*i,task2[i]);
        }
    };
    auto set_incoming_segments=[&](Bench& b,uint16_t es,uint16_t cs,
                                   uint16_t ss,uint16_t ds) {
        put_task_word(b,incoming_tss1_base+0x000e + 2*10,es);
        put_task_word(b,incoming_tss1_base+0x000e + 2*11,cs);
        put_task_word(b,incoming_tss1_base+0x000e + 2*12,ss);
        put_task_word(b,incoming_tss1_base+0x000e + 2*13,ds);
    };
    unsigned incoming_ldtr_fault_cases=0;
    for (bool wait:{false,true}) for (const auto& test:incoming_ldtr_faults) {
        Bench b;
        setup_incoming_ldtr(b,wait,test.selector);
        unsigned ts_task_entries=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==10) ++ts_task_entries;
        }
        if (b.d.fault_o || !b.d.halted_o || b.cs()!=0x0030 || b.d.ip_o!=0x0401)
            std::cerr<<"incoming-LDTR delivery failure "<<test.name<<" fault="
                     <<unsigned(b.d.fault_o)<<" code="<<unsigned(b.d.fault_code_o)
                     <<" halted="<<unsigned(b.d.halted_o)<<" cs:ip="<<std::hex
                     <<b.cs()<<":"<<b.d.ip_o<<" vector="<<unsigned(b.d.event_vector_o)
                     <<" error="<<b.d.event_packet_error_code_o<<std::dec
                     <<" #TS entries="<<ts_task_entries<<'\n';
        check(ts_task_entries==1 && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0401,
              "invalid incoming LDTR did not deliver #TS through its task gate");
        const bool incoming_packet_ok=b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_vector_o==10 && b.d.event_packet_error_code_o==test.error &&
              b.d.event_packet_saved_cs_o==0x0030 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080;
        if (!incoming_packet_ok)
            std::cerr<<"incoming-LDTR packet failure "<<test.name<<" valid/protected/restart/error="
                     <<unsigned(b.d.event_packet_valid_o)<<"/"<<unsigned(b.d.event_packet_protected_o)
                     <<"/"<<unsigned(b.d.event_packet_restartable_o)<<"/"
                     <<unsigned(b.d.event_packet_error_valid_o)<<" vector/error="
                     <<unsigned(b.d.event_vector_o)<<"/"<<std::hex
                     <<b.d.event_packet_error_code_o<<" saved="
                     <<b.d.event_packet_saved_cs_o<<":"<<b.d.event_packet_saved_ip_o
                     <<" flags/sp="<<b.d.event_packet_saved_flags_o<<"/"
                     <<b.d.event_packet_saved_sp_o<<std::dec<<'\n';
        check(incoming_packet_ok,
              "incoming-LDTR #TS packet did not preserve the transferred task context");
        const uint16_t saved_task1[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0030,0x0028,0x0010,test.selector
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base+0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base+0x000f + 2*i])<<8))==saved_task1[i],
                  "#TS task gate did not save the incoming task's transferred TSS image");
        check(uint16_t(b.memory[incoming_tss2_base] |
                       (uint16_t(b.memory[incoming_tss2_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x55]==0x83 && b.memory[kGdtBase+0x65]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==test.error,
              "#TS task gate did not set backlink/busy state and push the LDTR selector error");
        if (test.selector==0x0188)
            check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                      return !t.write && !t.io && t.address>=kGdtBase+0x0188 &&
                             t.address<kGdtBase+0x0190;
                  }),
                  "out-of-GDT incoming LDTR attempted a descriptor read");
        ++incoming_ldtr_fault_cases;
    }
    check(incoming_ldtr_fault_cases==10,
          "incoming-LDTR fault matrix missed a READY policy or selector case");
    std::cout<<"PASS: 10 invalid incoming LDTR cases deliver #TS through a task gate after task transfer and save the incoming TSS context in both READY modes\n";

    // Loading an invalid incoming LDTR raises the first #TS after the task
    // switch. A malformed #TS gate raises the second protection fault; the
    // invalid #DF gate makes the resulting shutdown state observable.
    unsigned incoming_ldtr_double_fault_cases=0;
    for (bool wait:{false,true}) for (const auto& test:incoming_ldtr_faults) {
        Bench b;
        setup_incoming_ldtr(b,wait,test.selector);
        b.put(kIdtBase+10*8,{0,0,0,0,0,0,0,0}); // Invalid #TS gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0030 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming-LDTR #TS handler fault did not escalate to null-error #DF shutdown with the incoming task context");
        const uint16_t ldtr_descriptor_offset=uint16_t(test.selector&0xfff8);
        const bool ldtr_descriptor_must_be_skipped=(test.selector&0x0004) ||
            uint32_t(ldtr_descriptor_offset)+7>0x0187;
        const bool ldtr_descriptor_was_read=std::any_of(
            b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                return !t.write && !t.io && t.address>=kGdtBase+ldtr_descriptor_offset &&
                       t.address<kGdtBase+ldtr_descriptor_offset+8;
            });
        check(ldtr_descriptor_must_be_skipped ? !ldtr_descriptor_was_read :
                                                 ldtr_descriptor_was_read,
              "incoming-LDTR #TS-to-#DF path used the wrong descriptor lookup for its selector variant");
        check(b.data_transfers.size()>=16,
              "incoming-LDTR #TS-to-#DF case omitted a handler-gate lookup");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+10*8+i,
                  "incoming-LDTR #TS delivery read an unexpected gate byte before escalation");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming-LDTR #DF shutdown read an unexpected gate byte or wrote an event frame");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming-LDTR #TS-to-#DF shutdown did not remain quiescent");
        ++incoming_ldtr_double_fault_cases;
    }
    check(incoming_ldtr_double_fault_cases==10,
          "incoming-LDTR first-fault #TS escalation missed a selector or READY policy");
    std::cout<<"PASS: 10 incoming-task #TS first faults across five LDTR selector variants escalate through an invalid #TS gate to null-error #DF shutdown in both READY modes\n";

    // Repeat the same #TS-to-#DF escalation with a valid vector-8 task gate.
    // This checks that the incoming faulting task is saved and that #DF can
    // reach an exact handler successor after a real 286 task switch.
    unsigned incoming_ldtr_double_fault_task_cases=0;
    constexpr uint32_t incoming_df_tss_base=0x000a0000;
    const uint16_t incoming_df_task_words[]={
        0x0500,0x0202,0x0201,0x0202,0x0203,0x0204,0x0080,
        0x0205,0x0206,0x0207,0x0010,0x0030,0x0028,0x0010,0x0000
    };
    for (bool wait:{false,true}) for (const auto& test:incoming_ldtr_faults) {
        Bench b;
        const uint16_t incoming_ldtr_selector=test.selector==0x0070 ? 0x0078 : test.selector;
        setup_incoming_ldtr(b,wait,incoming_ldtr_selector);
        b.put(kIdtBase+10*8,{0,0,0,0,0,0,0,0}); // Invalid #TS gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        if (test.selector==0x0070)
            b.put(kGdtBase+0x78,{0xff,0x00,0x00,0x00,0x00,0x02,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base + 0x000e + 2*i,incoming_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) ++df_task_entries;
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501,
              "incoming-LDTR #TS first fault did not enter the valid #DF task and execute its exact HLT successor");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83,
              "incoming-LDTR #TS-to-#DF task switch missed the backlink or busy-state updates");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0030,0x0028,0x0010,incoming_ldtr_selector
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base + 0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base + 0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save the first-fault incoming task's exact TSS context");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+10*8 &&
                         t.address<kIdtBase+11*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),"incoming-LDTR #TS-to-#DF task switch skipped a first-fault or double-fault gate lookup");
        ++incoming_ldtr_double_fault_task_cases;
    }
    check(incoming_ldtr_double_fault_task_cases==10,
          "incoming-LDTR #TS-to-#DF task delivery missed a selector or READY policy");
    std::cout<<"PASS: 10 incoming-task #TS first faults across five LDTR selector variants escalate to a valid #DF task gate, save the faulting TSS, and execute the exact handler successor in both READY modes\n";

    // Table 8-1 also raises #TS after task transfer when the incoming CS
    // selector is invalid. Exercise that later first-fault phase through both
    // malformed-#TS-gate shutdown and successful #DF task-gate delivery.
    unsigned incoming_cs_double_fault_shutdown_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0000,0x0028,0x0010);
        b.put(kIdtBase+10*8,{0,0,0,0,0,0,0,0}); // Invalid #TS gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0000 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming-CS #TS handler fault did not escalate to null-error #DF shutdown with the invalid CS context");
        check(b.data_transfers.size()>=16,
              "incoming-CS #TS-to-#DF case omitted one of the handler-gate lookups");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+10*8+i,
                  "incoming-CS #TS delivery read an unexpected gate byte before escalation");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming-CS #DF shutdown read an unexpected gate byte or wrote an event frame");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming-CS #TS-to-#DF shutdown did not remain quiescent");
        ++incoming_cs_double_fault_shutdown_cases;
    }
    check(incoming_cs_double_fault_shutdown_cases==2,
          "incoming-CS #TS-to-#DF shutdown missed a READY policy");

    unsigned incoming_cs_double_fault_task_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0000,0x0028,0x0010);
        b.put(kIdtBase+10*8,{0,0,0,0,0,0,0,0}); // Invalid #TS gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base + 0x000e + 2*i,incoming_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false;
        bool df_packet_protected=false;
        bool df_packet_restartable=false;
        bool df_packet_error_valid=false;
        uint16_t df_packet_error_code=0;
        unsigned df_packet_vector=0;
        uint16_t df_packet_saved_cs=0;
        uint16_t df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0;
        uint16_t df_packet_saved_sp=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0000 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming-CS #TS first fault did not enter #DF task with the exact invalid-CS context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming-CS #TS-to-#DF switch missed backlink/busy state or the null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0000,0x0028,0x0010,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base + 0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base + 0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save the incoming-CS #TS task image exactly");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+10*8 &&
                         t.address<kIdtBase+11*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),
              "incoming-CS #TS-to-#DF task switch skipped a first-fault or double-fault gate lookup");
        ++incoming_cs_double_fault_task_cases;
    }
    check(incoming_cs_double_fault_task_cases==2,
          "incoming-CS #TS-to-#DF task delivery missed a READY policy");
    std::cout<<"PASS: 4 incoming-CS #TS first-fault executions cover invalid #TS-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // Table 8-1 row 6 also rejects an incoming CS selector that names a data
    // descriptor. Check this distinct #TS(0010) first fault through both
    // malformed-gate shutdown and valid #DF task-gate delivery.
    unsigned incoming_cs_type_shutdown_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0010,0x0028,0x0010);
        b.put(kIdtBase+10*8,{0,0,0,0,0,0,0,0}); // Invalid #TS gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0010 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming data-type CS #TS did not escalate to null-error #DF shutdown with the rejected CS context");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x10 &&
                         t.address<kGdtBase+0x18;
              }),"incoming data-type CS #TS did not read the rejected code descriptor");
        check(b.data_transfers.size()>=16,
              "incoming data-type CS #TS-to-#DF case omitted a handler-gate lookup");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+10*8+i,
                  "incoming data-type CS #TS read an unexpected first-fault gate byte");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming data-type CS #DF shutdown read an unexpected gate byte");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming data-type CS #TS shutdown did not remain quiescent");
        ++incoming_cs_type_shutdown_cases;
    }
    check(incoming_cs_type_shutdown_cases==2,
          "incoming data-type CS #TS-to-#DF shutdown missed a READY policy");

    unsigned incoming_cs_type_df_task_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0010,0x0028,0x0010);
        b.put(kIdtBase+10*8,{0,0,0,0,0,0,0,0}); // Invalid #TS gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base+0x000e + 2*i,incoming_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false,df_packet_protected=false;
        bool df_packet_restartable=false,df_packet_error_valid=false;
        uint16_t df_packet_error_code=0,df_packet_saved_cs=0,df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0,df_packet_saved_sp=0;
        unsigned df_packet_vector=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0010 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming data-type CS #TS did not enter #DF task with the exact rejected-CS context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming data-type CS #DF switch missed backlink/busy state or null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0010,0x0028,0x0010,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base+0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base+0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save the incoming data-type CS TSS image exactly");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x10 &&
                         t.address<kGdtBase+0x18;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+10*8 &&
                         t.address<kIdtBase+11*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),"incoming data-type CS #TS-to-#DF skipped a descriptor or gate lookup");
        ++incoming_cs_type_df_task_cases;
    }
    check(incoming_cs_type_df_task_cases==2,
          "incoming data-type CS #TS-to-#DF task delivery missed a READY policy");
    std::cout<<"PASS: 4 incoming-CS wrong-type #TS first-fault executions cover invalid #TS-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // Table 8-1 also raises #NP when the incoming code descriptor is not
    // present. A malformed #NP handler gate is a second fault and selects #DF.
    unsigned incoming_cs_np_shutdown_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0008,0x0028,0x0010);
        b.memory[kGdtBase+0x000d]=0x1a; // Non-present DPL-0 code descriptor.
        b.put(kIdtBase+11*8,{0,0,0,0,0,0,0,0}); // Invalid #NP gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0008 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming-CS #NP handler fault did not escalate to null-error #DF shutdown with the non-present CS context");
        check(b.data_transfers.size()>=16,
              "incoming-CS #NP-to-#DF case omitted one of the handler-gate lookups");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+11*8+i,
                  "incoming-CS #NP delivery read an unexpected gate byte before escalation");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming-CS #DF shutdown read an unexpected gate byte or wrote an event frame");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming-CS #NP-to-#DF shutdown did not remain quiescent");
        ++incoming_cs_np_shutdown_cases;
    }
    check(incoming_cs_np_shutdown_cases==2,
          "incoming-CS #NP-to-#DF shutdown missed a READY policy");

    unsigned incoming_cs_np_double_fault_task_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0008,0x0028,0x0010);
        b.memory[kGdtBase+0x000d]=0x1a;
        b.put(kIdtBase+11*8,{0,0,0,0,0,0,0,0}); // Invalid #NP gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base + 0x000e + 2*i,incoming_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false;
        bool df_packet_protected=false;
        bool df_packet_restartable=false;
        bool df_packet_error_valid=false;
        uint16_t df_packet_error_code=0;
        unsigned df_packet_vector=0;
        uint16_t df_packet_saved_cs=0;
        uint16_t df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0;
        uint16_t df_packet_saved_sp=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0008 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming-CS #NP first fault did not enter #DF task with the exact non-present-CS context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming-CS #NP-to-#DF switch missed backlink/busy state or the null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0008,0x0028,0x0010,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base + 0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base + 0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save the incoming-CS #NP task image exactly");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+11*8 &&
                         t.address<kIdtBase+12*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),
              "incoming-CS #NP-to-#DF task switch skipped a first-fault or double-fault gate lookup");
        ++incoming_cs_np_double_fault_task_cases;
    }
    check(incoming_cs_np_double_fault_task_cases==2,
          "incoming-CS #NP-to-#DF task delivery missed a READY policy");
    std::cout<<"PASS: 4 incoming-CS #NP first-fault executions cover invalid #NP-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // Table 8-1 row 8 requires the incoming code descriptor DPL to match the
    // CS selector RPL. Selector 0038 has RPL 0 but names the DPL-3 code entry.
    // Its #TS fault must follow the same task-entry #DF paths as other #TSs.
    unsigned incoming_cs_dpl_shutdown_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0038,0x0028,0x0010);
        b.put(kIdtBase+10*8,{0,0,0,0,0,0,0,0}); // Invalid #TS gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0038 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming-CS DPL/RPL #TS did not escalate to null-error #DF shutdown with the rejected CS context");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x38 &&
                         t.address<kGdtBase+0x40;
              }),"incoming-CS DPL/RPL #TS did not read the rejected code descriptor");
        check(b.data_transfers.size()>=16,
              "incoming-CS DPL/RPL #TS-to-#DF case omitted one of the handler-gate lookups");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+10*8+i,
                  "incoming-CS DPL/RPL #TS read an unexpected first-fault gate byte");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming-CS DPL/RPL #DF shutdown read an unexpected gate byte or wrote an event frame");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming-CS DPL/RPL #TS-to-#DF shutdown did not remain quiescent");
        ++incoming_cs_dpl_shutdown_cases;
    }
    check(incoming_cs_dpl_shutdown_cases==2,
          "incoming-CS DPL/RPL #TS-to-#DF shutdown missed a READY policy");

    unsigned incoming_cs_dpl_df_task_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0038,0x0028,0x0010);
        b.put(kIdtBase+10*8,{0,0,0,0,0,0,0,0}); // Invalid #TS gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base+0x000e + 2*i,incoming_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false,df_packet_protected=false;
        bool df_packet_restartable=false,df_packet_error_valid=false;
        uint16_t df_packet_error_code=0,df_packet_saved_cs=0,df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0,df_packet_saved_sp=0;
        unsigned df_packet_vector=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0038 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming-CS DPL/RPL #TS did not enter #DF task with the exact rejected-CS context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming-CS DPL/RPL #DF switch missed backlink/busy state or null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0038,0x0028,0x0010,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base+0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base+0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save the incoming-CS DPL/RPL TSS image exactly");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x38 &&
                         t.address<kGdtBase+0x40;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+10*8 &&
                         t.address<kIdtBase+11*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),"incoming-CS DPL/RPL #TS-to-#DF skipped the rejected descriptor or a gate lookup");
        ++incoming_cs_dpl_df_task_cases;
    }
    check(incoming_cs_dpl_df_task_cases==2,
          "incoming-CS DPL/RPL #TS-to-#DF task delivery missed a READY policy");
    std::cout<<"PASS: 4 incoming-CS DPL/RPL-mismatch #TS first-fault executions cover invalid #TS-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // Table 8-1 row 6 rejects a CS selector beyond the incoming GDT limit.
    // The 0187 fixture limit makes CS=0188 raise #TS(0188) without a read.
    unsigned incoming_cs_limit_shutdown_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0188,0x0028,0x0010);
        b.put(kIdtBase+10*8,{0,0,0,0,0,0,0,0}); // Invalid #TS gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0188 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming-CS GDT-limit #TS did not escalate to null-error #DF shutdown");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x0188 &&
                         t.address<kGdtBase+0x0190;
              }),"incoming-CS GDT-limit #TS read a descriptor beyond the GDT limit");
        check(b.data_transfers.size()>=16,
              "incoming-CS GDT-limit #TS-to-#DF case omitted a handler-gate lookup");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+10*8+i,
                  "incoming-CS GDT-limit #TS read an unexpected first-fault gate byte");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming-CS GDT-limit #DF shutdown read an unexpected gate byte or wrote an event frame");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming-CS GDT-limit #TS-to-#DF shutdown did not remain quiescent");
        ++incoming_cs_limit_shutdown_cases;
    }
    check(incoming_cs_limit_shutdown_cases==2,
          "incoming-CS GDT-limit #TS-to-#DF shutdown missed a READY policy");

    unsigned incoming_cs_limit_df_task_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0188,0x0028,0x0010);
        b.put(kIdtBase+10*8,{0,0,0,0,0,0,0,0}); // Invalid #TS gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base+0x000e + 2*i,incoming_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false,df_packet_protected=false;
        bool df_packet_restartable=false,df_packet_error_valid=false;
        uint16_t df_packet_error_code=0,df_packet_saved_cs=0,df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0,df_packet_saved_sp=0;
        unsigned df_packet_vector=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0188 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming-CS GDT-limit #TS did not enter #DF task with the exact context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming-CS GDT-limit #DF switch missed backlink/busy state or null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0188,0x0028,0x0010,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base+0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base+0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save the incoming-CS GDT-limit TSS image exactly");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x0188 &&
                         t.address<kGdtBase+0x0190;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+10*8 &&
                         t.address<kIdtBase+11*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),"incoming-CS GDT-limit #TS-to-#DF read past the GDT or skipped a gate lookup");
        ++incoming_cs_limit_df_task_cases;
    }
    check(incoming_cs_limit_df_task_cases==2,
          "incoming-CS GDT-limit #TS-to-#DF task delivery missed a READY policy");
    std::cout<<"PASS: 4 incoming-CS GDT-limit #TS first-fault executions cover invalid #TS-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // A non-present incoming stack segment raises first-fault #SS after the
    // task state is loaded. A malformed #SS gate must escalate to null #DF.
    unsigned incoming_ss_np_shutdown_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x0010,0x0020);
        b.memory[kGdtBase+0x0015]=0x12; // Non-present writable DPL-0 data.
        b.put(kIdtBase+12*8,{0,0,0,0,0,0,0,0}); // Invalid #SS gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0030 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming-SS #SS handler fault did not escalate to null-error #DF shutdown with the original code context");
        check(b.data_transfers.size()>=16,
              "incoming-SS #SS-to-#DF case omitted one of the handler-gate lookups");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+12*8+i,
                  "incoming-SS #SS delivery read an unexpected gate byte before escalation");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming-SS #DF shutdown read an unexpected gate byte or wrote an event frame");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming-SS #SS-to-#DF shutdown did not remain quiescent");
        ++incoming_ss_np_shutdown_cases;
    }
    check(incoming_ss_np_shutdown_cases==2,
          "incoming-SS #SS-to-#DF shutdown missed a READY policy");

    unsigned incoming_ss_np_double_fault_task_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x0010,0x0020);
        b.memory[kGdtBase+0x0015]=0x12;
        b.put(kIdtBase+12*8,{0,0,0,0,0,0,0,0}); // Invalid #SS gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        const uint16_t ss_fault_df_task_words[]={
            0x0500,0x0202,0x0201,0x0202,0x0203,0x0204,0x0080,
            0x0205,0x0206,0x0207,0x0020,0x0030,0x0028,0x0020,0x0000
        };
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base + 0x000e + 2*i,ss_fault_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false;
        bool df_packet_protected=false;
        bool df_packet_restartable=false;
        bool df_packet_error_valid=false;
        uint16_t df_packet_error_code=0;
        unsigned df_packet_vector=0;
        uint16_t df_packet_saved_cs=0;
        uint16_t df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0;
        uint16_t df_packet_saved_sp=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0030 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming-SS #SS first fault did not enter #DF task with the exact code context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming-SS #SS-to-#DF switch missed backlink/busy state or the null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0030,0x0010,0x0020,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base + 0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base + 0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save the incoming-SS #SS task image exactly");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+12*8 &&
                         t.address<kIdtBase+13*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),
              "incoming-SS #SS-to-#DF task switch skipped a first-fault or double-fault gate lookup");
        ++incoming_ss_np_double_fault_task_cases;
    }
    check(incoming_ss_np_double_fault_task_cases==2,
          "incoming-SS #SS-to-#DF task delivery missed a READY policy");
    std::cout<<"PASS: 4 incoming-SS #SS first-fault executions cover invalid #SS-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // Table 8-1 row 10 requires the incoming SS descriptor to be writable
    // data. Both a present read-only data descriptor and a code descriptor
    // raise #GP(selector); test each through shutdown and valid #DF delivery.
    unsigned incoming_ss_type_shutdown_cases=0;
    for (uint8_t ss_access:{uint8_t(0x90),uint8_t(0x9a)}) {
      for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x0010,0x0020);
        b.memory[kGdtBase+0x0015]=ss_access; // Read-only data or readable code, DPL 0.
        b.put(kIdtBase+13*8,{0,0,0,0,0,0,0,0}); // Invalid #GP gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0030 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming non-writable SS #GP did not escalate to null-error #DF shutdown with the transferred context");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x10 &&
                         t.address<kGdtBase+0x18;
              }),"incoming non-writable SS #GP did not inspect the rejected descriptor");
        check(b.data_transfers.size()>=16,
              "incoming non-writable SS #GP-to-#DF case omitted a handler-gate lookup");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+13*8+i,
                  "incoming non-writable SS #GP read an unexpected first-fault gate byte");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming non-writable SS #DF shutdown read an unexpected gate byte");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming non-writable SS #GP shutdown did not remain quiescent");
        ++incoming_ss_type_shutdown_cases;
      }
    }
    check(incoming_ss_type_shutdown_cases==4,
          "incoming SS descriptor-type #GP-to-#DF shutdown missed an access type or READY policy");

    unsigned incoming_ss_type_df_task_cases=0;
    for (uint8_t ss_access:{uint8_t(0x90),uint8_t(0x9a)}) {
      for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x0010,0x0020);
        b.memory[kGdtBase+0x0015]=ss_access;
        b.put(kIdtBase+13*8,{0,0,0,0,0,0,0,0}); // Invalid #GP gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        const uint16_t ss_type_df_task_words[]={
            0x0500,0x0202,0x0201,0x0202,0x0203,0x0204,0x0080,
            0x0205,0x0206,0x0207,0x0020,0x0030,0x0028,0x0020,0x0000
        };
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base+0x000e + 2*i,ss_type_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false,df_packet_protected=false;
        bool df_packet_restartable=false,df_packet_error_valid=false;
        uint16_t df_packet_error_code=0,df_packet_saved_cs=0,df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0,df_packet_saved_sp=0;
        unsigned df_packet_vector=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0030 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming non-writable SS #GP did not enter #DF task with the exact code context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming non-writable SS #DF switch missed backlink/busy state or null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0030,0x0010,0x0020,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base + 0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base + 0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save the incoming non-writable SS TSS image exactly");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x10 &&
                         t.address<kGdtBase+0x18;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+13*8 &&
                         t.address<kIdtBase+14*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),"incoming non-writable SS #GP-to-#DF skipped a descriptor or gate lookup");
        ++incoming_ss_type_df_task_cases;
      }
    }
    check(incoming_ss_type_df_task_cases==4,
          "incoming SS descriptor-type #GP-to-#DF task delivery missed an access type or READY policy");
    std::cout<<"PASS: 8 incoming-SS descriptor-type #GP first-fault executions cover read-only data and code descriptors through invalid #GP-gate shutdown and valid #DF task entry in both READY modes\n";

    // Table 8-1 row 12 requires the incoming stack descriptor DPL to equal
    // the incoming CPL. This DPL-3 stack at selector 0040 faults as #SS(0040).
    unsigned incoming_ss_privilege_shutdown_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x0040,0x0020);
        b.put(kIdtBase+12*8,{0,0,0,0,0,0,0,0}); // Invalid #SS gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0030 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming SS DPL mismatch #SS did not escalate to null-error #DF shutdown with the transferred context");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x40 &&
                         t.address<kGdtBase+0x48;
              }),"incoming SS DPL mismatch #SS did not inspect the rejected descriptor");
        check(b.data_transfers.size()>=16,
              "incoming SS DPL mismatch #SS-to-#DF case omitted a handler-gate lookup");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+12*8+i,
                  "incoming SS DPL mismatch #SS read an unexpected first-fault gate byte");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming SS DPL mismatch #DF shutdown read an unexpected gate byte");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming SS DPL mismatch #DF shutdown did not remain quiescent");
        ++incoming_ss_privilege_shutdown_cases;
    }
    check(incoming_ss_privilege_shutdown_cases==2,
          "incoming SS DPL mismatch #SS-to-#DF shutdown missed a READY policy");

    unsigned incoming_ss_privilege_df_task_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x0040,0x0020);
        b.put(kIdtBase+12*8,{0,0,0,0,0,0,0,0}); // Invalid #SS gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        const uint16_t ss_privilege_df_task_words[]={
            0x0500,0x0202,0x0201,0x0202,0x0203,0x0204,0x0080,
            0x0205,0x0206,0x0207,0x0020,0x0030,0x0028,0x0020,0x0000
        };
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base + 0x000e + 2*i,
                          ss_privilege_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false,df_packet_protected=false;
        bool df_packet_restartable=false,df_packet_error_valid=false;
        uint16_t df_packet_error_code=0,df_packet_saved_cs=0,df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0,df_packet_saved_sp=0;
        unsigned df_packet_vector=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0030 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming SS DPL mismatch #SS did not enter #DF task with exact code context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming SS DPL mismatch #DF switch missed backlink/busy state or null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0030,0x0040,0x0020,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base + 0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base + 0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save the incoming SS DPL-mismatch TSS image exactly");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x40 &&
                         t.address<kGdtBase+0x48;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+12*8 &&
                         t.address<kIdtBase+13*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),"incoming SS DPL mismatch #SS-to-#DF skipped a descriptor or gate lookup");
        ++incoming_ss_privilege_df_task_cases;
    }
    check(incoming_ss_privilege_df_task_cases==2,
          "incoming SS DPL mismatch #SS-to-#DF task delivery missed a READY policy");
    std::cout<<"PASS: 4 incoming-SS DPL-mismatch #SS first-fault executions cover invalid #SS-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // Table 8-1 row 9 rejects an incoming SS selector whose RPL differs from CPL.
    // Selector 002B names the writable DPL-0 stack but has RPL 3, yielding #SS(0028).
    unsigned incoming_ss_selector_rpl_shutdown_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x002b,0x0020);
        b.put(kIdtBase+12*8,{0,0,0,0,0,0,0,0}); // Invalid #SS gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0030 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming SS selector RPL mismatch #SS did not escalate to null-error #DF shutdown with the transferred context");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x28 &&
                         t.address<kGdtBase+0x30;
              }),"incoming SS selector RPL mismatch #SS did not inspect the rejected descriptor");
        check(b.data_transfers.size()>=16,
              "incoming SS selector RPL mismatch #SS-to-#DF case omitted a handler-gate lookup");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+12*8+i,
                  "incoming SS selector RPL mismatch #SS read an unexpected first-fault gate byte");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming SS selector RPL mismatch #DF shutdown read an unexpected gate byte");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming SS selector RPL mismatch #DF shutdown did not remain quiescent");
        ++incoming_ss_selector_rpl_shutdown_cases;
    }
    check(incoming_ss_selector_rpl_shutdown_cases==2,
          "incoming SS selector RPL mismatch #SS-to-#DF shutdown missed a READY policy");

    unsigned incoming_ss_selector_rpl_df_task_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x002b,0x0020);
        b.put(kIdtBase+12*8,{0,0,0,0,0,0,0,0}); // Invalid #SS gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        const uint16_t ss_privilege_df_task_words[]={
            0x0500,0x0202,0x0201,0x0202,0x0203,0x0204,0x0080,
            0x0205,0x0206,0x0207,0x0020,0x0030,0x0028,0x0020,0x0000
        };
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base + 0x000e + 2*i,
                          ss_privilege_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false,df_packet_protected=false;
        bool df_packet_restartable=false,df_packet_error_valid=false;
        uint16_t df_packet_error_code=0,df_packet_saved_cs=0,df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0,df_packet_saved_sp=0;
        unsigned df_packet_vector=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0030 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming SS selector RPL mismatch #SS did not enter #DF task with exact code context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming SS selector RPL mismatch #DF switch missed backlink/busy state or null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0030,0x002b,0x0020,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base + 0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base + 0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save the incoming SS selector-RPL TSS image exactly");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x28 &&
                         t.address<kGdtBase+0x30;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+12*8 &&
                         t.address<kIdtBase+13*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),"incoming SS selector RPL mismatch #SS-to-#DF skipped a descriptor or gate lookup");
        ++incoming_ss_selector_rpl_df_task_cases;
    }
    check(incoming_ss_selector_rpl_df_task_cases==2,
          "incoming SS selector RPL mismatch #SS-to-#DF task delivery missed a READY policy");
    std::cout<<"PASS: 4 incoming-SS selector-RPL-mismatch #SS first-fault executions cover invalid #SS-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // Table 8-1 row 9 requires a valid stack selector. A null incoming SS
    // raises #SS(0000) without reading the GDT null descriptor.
    unsigned incoming_ss_null_shutdown_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x0000,0x0020);
        b.put(kIdtBase+12*8,{0,0,0,0,0,0,0,0}); // Invalid #SS gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0030 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming null SS #SS did not escalate to null-error #DF shutdown with transferred context");
        check(b.data_transfers.size()>=16,
              "incoming null SS #SS-to-#DF case omitted a handler-gate lookup");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+12*8+i,
                  "incoming null SS #SS read an unexpected first-fault gate byte");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming null SS #DF shutdown read an unexpected gate byte");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase &&
                         t.address<kGdtBase+8;
              }),"incoming null SS read the GDT null descriptor");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming null SS #DF shutdown did not remain quiescent");
        ++incoming_ss_null_shutdown_cases;
    }
    check(incoming_ss_null_shutdown_cases==2,
          "incoming null SS #SS-to-#DF shutdown missed a READY policy");

    unsigned incoming_ss_null_df_task_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x0000,0x0020);
        b.put(kIdtBase+12*8,{0,0,0,0,0,0,0,0}); // Invalid #SS gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        const uint16_t ss_null_df_task_words[]={
            0x0500,0x0202,0x0201,0x0202,0x0203,0x0204,0x0080,
            0x0205,0x0206,0x0207,0x0020,0x0030,0x0028,0x0020,0x0000
        };
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base + 0x000e + 2*i,
                          ss_null_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false,df_packet_protected=false;
        bool df_packet_restartable=false,df_packet_error_valid=false;
        uint16_t df_packet_error_code=0,df_packet_saved_cs=0,df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0,df_packet_saved_sp=0;
        unsigned df_packet_vector=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0030 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming null SS #SS did not enter #DF task with the exact code context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming null SS #DF switch missed backlink/busy state or null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0030,0x0000,0x0020,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base + 0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base + 0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save the incoming null-SS TSS image exactly");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase &&
                         t.address<kGdtBase+8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+12*8 &&
                         t.address<kIdtBase+13*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),"incoming null SS #SS-to-#DF read the null descriptor or skipped a gate");
        ++incoming_ss_null_df_task_cases;
    }
    check(incoming_ss_null_df_task_cases==2,
          "incoming null SS #SS-to-#DF task delivery missed a READY policy");
    std::cout<<"PASS: 4 incoming-SS null-selector #SS first-fault executions cover invalid #SS-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // Table 8-1 row 9 also requires the SS selector to be within its table.
    // GDT limit 0187 makes selector 0188 invalid and must raise #SS(0188).
    unsigned incoming_ss_limit_shutdown_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x0188,0x0020);
        b.put(kIdtBase+12*8,{0,0,0,0,0,0,0,0}); // Invalid #SS gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0030 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming-SS GDT-limit #SS did not escalate to null-error #DF shutdown");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x0188 &&
                         t.address<kGdtBase+0x0190;
              }),"incoming-SS GDT-limit #SS read a descriptor beyond the GDT limit");
        check(b.data_transfers.size()>=16,
              "incoming-SS GDT-limit #SS-to-#DF case omitted a handler-gate lookup");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+12*8+i,
                  "incoming-SS GDT-limit #SS read an unexpected first-fault gate byte");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming-SS GDT-limit #DF shutdown read an unexpected gate byte or wrote an event frame");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming-SS GDT-limit #SS-to-#DF shutdown did not remain quiescent");
        ++incoming_ss_limit_shutdown_cases;
    }
    check(incoming_ss_limit_shutdown_cases==2,
          "incoming-SS GDT-limit #SS-to-#DF shutdown missed a READY policy");

    unsigned incoming_ss_limit_df_task_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x0188,0x0020);
        b.put(kIdtBase+12*8,{0,0,0,0,0,0,0,0}); // Invalid #SS gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base+0x000e + 2*i,incoming_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false,df_packet_protected=false;
        bool df_packet_restartable=false,df_packet_error_valid=false;
        uint16_t df_packet_error_code=0,df_packet_saved_cs=0,df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0,df_packet_saved_sp=0;
        unsigned df_packet_vector=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0030 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming-SS GDT-limit #SS did not enter #DF task with the exact context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming-SS GDT-limit #DF switch missed backlink/busy state or null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0030,0x0188,0x0020,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base+0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base+0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save the incoming-SS GDT-limit TSS image exactly");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x0188 &&
                         t.address<kGdtBase+0x0190;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+12*8 &&
                         t.address<kIdtBase+13*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),"incoming-SS GDT-limit #SS-to-#DF read past the GDT or skipped a gate lookup");
        ++incoming_ss_limit_df_task_cases;
    }
    check(incoming_ss_limit_df_task_cases==2,
          "incoming-SS GDT-limit #SS-to-#DF task delivery missed a READY policy");
    std::cout<<"PASS: 4 incoming-SS GDT-limit #SS first-fault executions cover invalid #SS-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // Table 8-1 row 15 faults a non-present incoming DS/ES after task state
    // transfer. Exercise ES #NP through the same malformed-handler #DF path.
    unsigned incoming_es_np_shutdown_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x0028,0x0010);
        b.memory[kGdtBase+0x0025]=0x12; // Non-present writable DPL-0 data.
        b.put(kIdtBase+11*8,{0,0,0,0,0,0,0,0}); // Invalid #NP gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0030 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming-ES #NP handler fault did not escalate to null-error #DF shutdown with the transferred code context");
        check(b.data_transfers.size()>=16,
              "incoming-ES #NP-to-#DF case omitted one of the handler-gate lookups");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+11*8+i,
                  "incoming-ES #NP delivery read an unexpected gate byte before escalation");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming-ES #DF shutdown read an unexpected gate byte or wrote an event frame");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x20 &&
                         t.address<kGdtBase+0x28;
              }),"incoming-ES #NP-to-#DF case did not inspect the non-present ES descriptor");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming-ES #NP-to-#DF shutdown did not remain quiescent");
        ++incoming_es_np_shutdown_cases;
    }
    check(incoming_es_np_shutdown_cases==2,
          "incoming-ES #NP-to-#DF shutdown missed a READY policy");

    unsigned incoming_es_np_double_fault_task_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x0028,0x0010);
        b.memory[kGdtBase+0x0025]=0x12;
        b.put(kIdtBase+11*8,{0,0,0,0,0,0,0,0}); // Invalid #NP gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        const uint16_t es_fault_df_task_words[]={
            0x0500,0x0202,0x0201,0x0202,0x0203,0x0204,0x0080,
            0x0205,0x0206,0x0207,0x0010,0x0030,0x0028,0x0010,0x0000
        };
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base + 0x000e + 2*i,es_fault_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false;
        bool df_packet_protected=false;
        bool df_packet_restartable=false;
        bool df_packet_error_valid=false;
        uint16_t df_packet_error_code=0;
        unsigned df_packet_vector=0;
        uint16_t df_packet_saved_cs=0;
        uint16_t df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0;
        uint16_t df_packet_saved_sp=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0030 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming-ES #NP first fault did not enter #DF task with the exact code context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming-ES #NP-to-#DF switch missed backlink/busy state or the null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0030,0x0028,0x0010,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base + 0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base + 0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save the incoming-ES #NP task image exactly");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+11*8 &&
                         t.address<kIdtBase+12*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),"incoming-ES #NP-to-#DF task switch skipped a first-fault or double-fault gate lookup");
        ++incoming_es_np_double_fault_task_cases;
    }
    check(incoming_es_np_double_fault_task_cases==2,
          "incoming-ES #NP-to-#DF task delivery missed a READY policy");
    std::cout<<"PASS: 4 incoming-ES #NP first-fault executions cover invalid #NP-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // Table 8-1 row 15 faults a non-present incoming DS/ES after task state
    // transfer. Exercise the DS #NP case through malformed-handler #DF.
    unsigned incoming_ds_np_shutdown_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x0028,0x0010);
        b.memory[kGdtBase+0x0015]=0x12; // Non-present writable DPL-0 data.
        b.put(kIdtBase+11*8,{0,0,0,0,0,0,0,0}); // Invalid #NP gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0030 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming-DS #NP handler fault did not escalate to null-error #DF shutdown with the transferred code context");
        check(b.data_transfers.size()>=16,
              "incoming-DS #NP-to-#DF case omitted one of the handler-gate lookups");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+11*8+i,
                  "incoming-DS #NP delivery read an unexpected gate byte before escalation");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming-DS #DF shutdown read an unexpected gate byte or wrote an event frame");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x10 &&
                         t.address<kGdtBase+0x18;
              }),"incoming-DS #NP-to-#DF case did not inspect the non-present DS descriptor");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming-DS #NP-to-#DF shutdown did not remain quiescent");
        ++incoming_ds_np_shutdown_cases;
    }
    check(incoming_ds_np_shutdown_cases==2,
          "incoming-DS #NP-to-#DF shutdown missed a READY policy");

    unsigned incoming_ds_np_double_fault_task_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x0028,0x0010);
        b.memory[kGdtBase+0x0015]=0x12;
        b.put(kIdtBase+11*8,{0,0,0,0,0,0,0,0}); // Invalid #NP gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        const uint16_t ds_fault_df_task_words[]={
            0x0500,0x0202,0x0201,0x0202,0x0203,0x0204,0x0080,
            0x0205,0x0206,0x0207,0x0020,0x0030,0x0028,0x0020,0x0000
        };
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base + 0x000e + 2*i,ds_fault_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false;
        bool df_packet_protected=false;
        bool df_packet_restartable=false;
        bool df_packet_error_valid=false;
        uint16_t df_packet_error_code=0;
        unsigned df_packet_vector=0;
        uint16_t df_packet_saved_cs=0;
        uint16_t df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0;
        uint16_t df_packet_saved_sp=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0030 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming-DS #NP first fault did not enter #DF task with the exact code context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming-DS #NP-to-#DF switch missed backlink/busy state or the null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0030,0x0028,0x0010,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base + 0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base + 0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save the incoming-DS #NP task image exactly");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+11*8 &&
                         t.address<kIdtBase+12*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),"incoming-DS #NP-to-#DF task switch skipped a first-fault or double-fault gate lookup");
        ++incoming_ds_np_double_fault_task_cases;
    }
    check(incoming_ds_np_double_fault_task_cases==2,
          "incoming-DS #NP-to-#DF task delivery missed a READY policy");
    std::cout<<"PASS: 4 incoming-DS #NP first-fault executions cover invalid #NP-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // Table 8-1 row 14 requires incoming DS/ES code descriptors to be
    // readable. An execute-only ES therefore raises #GP after task transfer.
    unsigned incoming_es_readability_shutdown_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0030,0x0030,0x0028,0x0010);
        b.memory[kGdtBase+0x0035]=0x98; // Present, DPL-0 execute-only code.
        b.put(kIdtBase+13*8,{0,0,0,0,0,0,0,0}); // Invalid #GP gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0030 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming-ES #GP handler fault did not escalate to null-error #DF shutdown with the transferred code context");
        check(b.data_transfers.size()>=16,
              "incoming-ES #GP-to-#DF case omitted one of the handler-gate lookups");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+13*8+i,
                  "incoming-ES #GP delivery read an unexpected gate byte before escalation");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming-ES #DF shutdown read an unexpected gate byte");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x30 &&
                         t.address<kGdtBase+0x38;
              }),"incoming-ES #GP-to-#DF case did not inspect the execute-only ES descriptor");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming-ES #GP-to-#DF shutdown did not remain quiescent");
        ++incoming_es_readability_shutdown_cases;
    }
    check(incoming_es_readability_shutdown_cases==2,
          "incoming-ES #GP-to-#DF shutdown missed a READY policy");

    unsigned incoming_es_readability_df_task_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0030,0x0030,0x0028,0x0010);
        b.memory[kGdtBase+0x0035]=0x98;
        b.put(kIdtBase+13*8,{0,0,0,0,0,0,0,0}); // Invalid #GP gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        const uint16_t es_readability_df_task_words[]={
            0x0500,0x0202,0x0201,0x0202,0x0203,0x0204,0x0080,
            0x0205,0x0206,0x0207,0x0010,0x0030,0x0028,0x0010,0x0000
        };
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base + 0x000e + 2*i,
                          es_readability_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false;
        bool df_packet_protected=false;
        bool df_packet_restartable=false;
        bool df_packet_error_valid=false;
        uint16_t df_packet_error_code=0;
        unsigned df_packet_vector=0;
        uint16_t df_packet_saved_cs=0;
        uint16_t df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0;
        uint16_t df_packet_saved_sp=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0030 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming-ES #GP first fault did not enter #DF task with the exact code context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming-ES #GP-to-#DF switch missed backlink/busy state or the null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0030,0x0030,0x0028,0x0010,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base + 0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base + 0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save the incoming-ES #GP task image exactly");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+13*8 &&
                         t.address<kIdtBase+14*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),"incoming-ES #GP-to-#DF task switch skipped a first-fault or double-fault gate lookup");
        ++incoming_es_readability_df_task_cases;
    }
    check(incoming_es_readability_df_task_cases==2,
          "incoming-ES #GP-to-#DF task delivery missed a READY policy");
    std::cout<<"PASS: 4 incoming-ES #GP first-fault executions cover invalid #GP-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // Table 8-1 row 14 applies to DS as well as ES: code in DS must be readable.
    // Selector 0030 remains a valid execute-only CS but raises #GP(0030) as DS.
    unsigned incoming_ds_readability_shutdown_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x0028,0x0030);
        b.memory[kGdtBase+0x0035]=0x98;
        b.put(kIdtBase+13*8,{0,0,0,0,0,0,0,0}); // Invalid #GP gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0030 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming-DS readability #GP did not escalate to null-error #DF shutdown with the transferred context");
        check(b.data_transfers.size()>=16,
              "incoming-DS readability #GP-to-#DF case omitted a handler-gate lookup");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+13*8+i,
                  "incoming-DS readability #GP read an unexpected first-fault gate byte");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming-DS readability #DF shutdown read an unexpected gate byte");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x30 &&
                         t.address<kGdtBase+0x38;
              }),"incoming-DS readability #GP-to-#DF case did not inspect the execute-only descriptor");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming-DS readability #GP shutdown did not remain quiescent");
        ++incoming_ds_readability_shutdown_cases;
    }
    check(incoming_ds_readability_shutdown_cases==2,
          "incoming-DS readability #GP-to-#DF shutdown missed a READY policy");

    unsigned incoming_ds_readability_df_task_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x0028,0x0030);
        b.memory[kGdtBase+0x0035]=0x98;
        b.put(kIdtBase+13*8,{0,0,0,0,0,0,0,0}); // Invalid #GP gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        const uint16_t ds_readability_df_task_words[]={
            0x0500,0x0202,0x0201,0x0202,0x0203,0x0204,0x0080,
            0x0205,0x0206,0x0207,0x0010,0x0030,0x0028,0x0010,0x0000
        };
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base + 0x000e + 2*i,
                          ds_readability_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false;
        bool df_packet_protected=false;
        bool df_packet_restartable=false;
        bool df_packet_error_valid=false;
        uint16_t df_packet_error_code=0;
        unsigned df_packet_vector=0;
        uint16_t df_packet_saved_cs=0;
        uint16_t df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0;
        uint16_t df_packet_saved_sp=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0030 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming-DS readability #GP did not enter #DF task with the exact code context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming-DS readability #GP-to-#DF switch missed backlink/busy state or null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0030,0x0028,0x0030,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base + 0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base + 0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save incoming-DS readability fault TSS exactly");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+13*8 &&
                         t.address<kIdtBase+14*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),"incoming-DS readability #GP-to-#DF skipped a first-fault or double-fault gate lookup");
        ++incoming_ds_readability_df_task_cases;
    }
    check(incoming_ds_readability_df_task_cases==2,
          "incoming-DS readability #GP-to-#DF task delivery missed a READY policy");
    std::cout<<"PASS: 4 incoming-DS readability #GP first-fault executions cover invalid #GP-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // Table 8-1 row 13 requires incoming DS/ES selectors to name code or data
    // descriptors. Selector 0050 names a system TSS descriptor, so ES faults.
    unsigned incoming_es_type_shutdown_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0050,0x0030,0x0028,0x0010);
        b.put(kIdtBase+13*8,{0,0,0,0,0,0,0,0}); // Invalid #GP gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0030 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming-ES system-descriptor #GP did not escalate to null-error #DF shutdown with the transferred context");
        check(b.data_transfers.size()>=16,
              "incoming-ES system-descriptor #GP-to-#DF case omitted a handler-gate lookup");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+13*8+i,
                  "incoming-ES system-descriptor #GP read an unexpected first-fault gate byte");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming-ES system-descriptor #DF shutdown read an unexpected gate byte");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x50 &&
                         t.address<kGdtBase+0x58;
              }),"incoming-ES system-descriptor #GP case did not inspect selector 0050");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming-ES system-descriptor #GP shutdown did not remain quiescent");
        ++incoming_es_type_shutdown_cases;
    }
    check(incoming_es_type_shutdown_cases==2,
          "incoming-ES system-descriptor #GP-to-#DF shutdown missed a READY policy");

    unsigned incoming_es_type_df_task_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0050,0x0030,0x0028,0x0010);
        b.put(kIdtBase+13*8,{0,0,0,0,0,0,0,0}); // Invalid #GP gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        const uint16_t es_type_df_task_words[]={
            0x0500,0x0202,0x0201,0x0202,0x0203,0x0204,0x0080,
            0x0205,0x0206,0x0207,0x0010,0x0030,0x0028,0x0010,0x0000
        };
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base + 0x000e + 2*i,
                          es_type_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false;
        bool df_packet_protected=false;
        bool df_packet_restartable=false;
        bool df_packet_error_valid=false;
        uint16_t df_packet_error_code=0;
        unsigned df_packet_vector=0;
        uint16_t df_packet_saved_cs=0;
        uint16_t df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0;
        uint16_t df_packet_saved_sp=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0030 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming-ES system-descriptor #GP did not enter #DF task with the exact code context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming-ES system-descriptor #GP-to-#DF switch missed backlink/busy state or null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0050,0x0030,0x0028,0x0010,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base + 0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base + 0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save incoming-ES system-descriptor fault TSS exactly");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+13*8 &&
                         t.address<kIdtBase+14*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),"incoming-ES system-descriptor #GP-to-#DF skipped a first-fault or double-fault gate lookup");
        ++incoming_es_type_df_task_cases;
    }
    check(incoming_es_type_df_task_cases==2,
          "incoming-ES system-descriptor #GP-to-#DF task delivery missed a READY policy");
    std::cout<<"PASS: 4 incoming-ES system-descriptor #GP first-fault executions cover invalid #GP-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // Table 8-1 row 13 requires incoming DS/ES selectors to name code or data
    // descriptors. Selector 0050 names a system TSS descriptor, so DS faults.
    unsigned incoming_ds_type_shutdown_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0010,0x0030,0x0028,0x0050);
        b.put(kIdtBase+13*8,{0,0,0,0,0,0,0,0}); // Invalid #GP gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0030 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming-DS system-descriptor #GP did not escalate to null-error #DF shutdown with the transferred context");
        check(b.data_transfers.size()>=16,
              "incoming-DS system-descriptor #GP-to-#DF case omitted a handler-gate lookup");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+13*8+i,
                  "incoming-DS system-descriptor #GP read an unexpected first-fault gate byte");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming-DS system-descriptor #DF shutdown read an unexpected gate byte");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x50 &&
                         t.address<kGdtBase+0x58;
              }),"incoming-DS system-descriptor #GP case did not inspect selector 0050");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming-DS system-descriptor #GP shutdown did not remain quiescent");
        ++incoming_ds_type_shutdown_cases;
    }
    check(incoming_ds_type_shutdown_cases==2,
          "incoming-DS system-descriptor #GP-to-#DF shutdown missed a READY policy");

    unsigned incoming_ds_type_df_task_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0010,0x0030,0x0028,0x0050);
        b.put(kIdtBase+13*8,{0,0,0,0,0,0,0,0}); // Invalid #GP gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        const uint16_t ds_type_df_task_words[]={
            0x0500,0x0202,0x0201,0x0202,0x0203,0x0204,0x0080,
            0x0205,0x0206,0x0207,0x0010,0x0030,0x0028,0x0010,0x0000
        };
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base + 0x000e + 2*i,
                          ds_type_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false;
        bool df_packet_protected=false;
        bool df_packet_restartable=false;
        bool df_packet_error_valid=false;
        uint16_t df_packet_error_code=0;
        unsigned df_packet_vector=0;
        uint16_t df_packet_saved_cs=0;
        uint16_t df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0;
        uint16_t df_packet_saved_sp=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0030 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming-DS system-descriptor #GP did not enter #DF task with the exact code context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming-DS system-descriptor #GP-to-#DF switch missed backlink/busy state or null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0010,0x0030,0x0028,0x0050,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base + 0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base + 0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save incoming-DS system-descriptor fault TSS exactly");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+13*8 &&
                         t.address<kIdtBase+14*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),"incoming-DS system-descriptor #GP-to-#DF skipped a first-fault or double-fault gate lookup");
        ++incoming_ds_type_df_task_cases;
    }
    check(incoming_ds_type_df_task_cases==2,
          "incoming-DS system-descriptor #GP-to-#DF task delivery missed a READY policy");
    std::cout<<"PASS: 4 incoming-DS system-descriptor #GP first-fault executions cover invalid #GP-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // Table 8-1 row 13 requires a valid incoming DS selector;
    // selector 005C has TI=1 while LDTR is null, so #GP(005C) is raised.
    unsigned incoming_ds_ldtr_shutdown_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0010,0x0030,0x0028,0x005c);
        b.put(kIdtBase+13*8,{0,0,0,0,0,0,0,0}); // Invalid #GP gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0030 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming-DS TI/null-LDTR #GP did not escalate to null-error #DF shutdown with the transferred context");
        check(b.data_transfers.size()>=16,
              "incoming-DS TI/null-LDTR #GP-to-#DF case omitted a handler-gate lookup");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+13*8+i,
                  "incoming-DS TI/null-LDTR #GP read an unexpected first-fault gate byte");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming-DS TI/null-LDTR #DF shutdown read an unexpected gate byte");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=0x00007000 &&
                         t.address<0x00007008;
              }),"incoming-DS TI/null-LDTR #GP case read an LDT descriptor with a null LDTR");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming-DS TI/null-LDTR #GP shutdown did not remain quiescent");
        ++incoming_ds_ldtr_shutdown_cases;
    }
    check(incoming_ds_ldtr_shutdown_cases==2,
          "incoming-DS TI/null-LDTR #GP-to-#DF shutdown missed a READY policy");

    unsigned incoming_ds_ldtr_df_task_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0010,0x0030,0x0028,0x005c);
        b.put(kIdtBase+13*8,{0,0,0,0,0,0,0,0}); // Invalid #GP gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        const uint16_t ds_ldtr_df_task_words[]={
            0x0500,0x0202,0x0201,0x0202,0x0203,0x0204,0x0080,
            0x0205,0x0206,0x0207,0x0010,0x0030,0x0028,0x0010,0x0000
        };
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base + 0x000e + 2*i,
                          ds_ldtr_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false;
        bool df_packet_protected=false;
        bool df_packet_restartable=false;
        bool df_packet_error_valid=false;
        uint16_t df_packet_error_code=0;
        unsigned df_packet_vector=0;
        uint16_t df_packet_saved_cs=0;
        uint16_t df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0;
        uint16_t df_packet_saved_sp=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0030 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming-DS TI/null-LDTR #GP did not enter #DF task with the exact code context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming-DS TI/null-LDTR #GP-to-#DF switch missed backlink/busy state or null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0010,0x0030,0x0028,0x005c,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base + 0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base + 0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save incoming-DS TI/null-LDTR fault TSS exactly");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+13*8 &&
                         t.address<kIdtBase+14*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),"incoming-DS TI/null-LDTR #GP-to-#DF skipped a first-fault or double-fault gate lookup");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=0x00007000 &&
                         t.address<0x00007008;
              }),"incoming-DS TI/null-LDTR #GP-to-#DF task path read an LDT descriptor with a null LDTR");
        ++incoming_ds_ldtr_df_task_cases;
    }
    check(incoming_ds_ldtr_df_task_cases==2,
          "incoming-DS TI/null-LDTR #GP-to-#DF task delivery missed a READY policy");
    std::cout<<"PASS: 4 incoming-DS TI/null-LDTR #GP first-fault executions cover invalid #GP-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // Table 8-1 row 13 assigns #GP(selector) when an incoming DS or ES
    // descriptor lies beyond GDTR.limit. With limit 0187, selector 0188 is
    // exactly out of range. Exercise both post-transfer #DF outcomes.
    struct IncomingDataGdtLimitCase { const char* name; bool es; };
    const IncomingDataGdtLimitCase incoming_data_gdt_limits[]={
        {"DS",false},{"ES",true}
    };
    unsigned incoming_data_gdt_limit_shutdown_cases=0;
    for (const auto& test:incoming_data_gdt_limits) for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,test.es ? 0x0188 : 0x0020,
                              0x0030,0x0028,test.es ? 0x0010 : 0x0188);
        b.put(kIdtBase+13*8,{0,0,0,0,0,0,0,0}); // Invalid #GP gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0030 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              (std::string("incoming-")+test.name+
               " GDT-limit #GP did not escalate to null-error #DF shutdown").c_str());
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x0188 &&
                         t.address<kGdtBase+0x0190;
              }), (std::string("incoming-")+test.name+
                   " GDT-limit #GP read the descriptor beyond GDTR.limit").c_str());
        check(b.data_transfers.size()>=16,
              "incoming DS/ES GDT-limit #GP-to-#DF shutdown omitted a gate lookup");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+13*8+i,
                  "incoming DS/ES GDT-limit #GP read an unexpected first-fault gate byte");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming DS/ES GDT-limit #DF shutdown read an unexpected gate byte");
        for (unsigned cycle=0;cycle<8;++cycle) b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming DS/ES GDT-limit #GP shutdown did not remain quiescent");
        ++incoming_data_gdt_limit_shutdown_cases;
    }
    check(incoming_data_gdt_limit_shutdown_cases==4,
          "incoming DS/ES GDT-limit #GP shutdown missed a segment or READY policy");

    unsigned incoming_data_gdt_limit_df_task_cases=0;
    for (const auto& test:incoming_data_gdt_limits) for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,test.es ? 0x0188 : 0x0020,
                              0x0030,0x0028,test.es ? 0x0010 : 0x0188);
        b.put(kIdtBase+13*8,{0,0,0,0,0,0,0,0}); // Invalid #GP gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base+0x000e + 2*i,
                          incoming_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false,df_packet_protected=false;
        bool df_packet_restartable=false,df_packet_error_valid=false;
        uint16_t df_packet_error_code=0,df_packet_saved_cs=0,df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0,df_packet_saved_sp=0;
        unsigned df_packet_vector=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0030 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              (std::string("incoming-")+test.name+
               " GDT-limit #GP did not enter the #DF task with the exact context").c_str());
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming DS/ES GDT-limit #DF switch missed backlink/busy state or null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,
            uint16_t(test.es ? 0x0188 : 0x0020),0x0030,0x0028,
            uint16_t(test.es ? 0x0010 : 0x0188),0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base + 0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base + 0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save the incoming DS/ES GDT-limit TSS image exactly");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x0188 &&
                         t.address<kGdtBase+0x0190;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+13*8 &&
                         t.address<kIdtBase+14*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),"incoming DS/ES GDT-limit #GP-to-#DF read past the GDT or skipped a gate lookup");
        ++incoming_data_gdt_limit_df_task_cases;
    }
    check(incoming_data_gdt_limit_df_task_cases==4,
          "incoming DS/ES GDT-limit #GP task delivery missed a segment or READY policy");
    std::cout<<"PASS: 8 incoming-DS/ES GDT-limit #GP first-fault executions cover invalid #GP-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // Table 8-1 row 16 requires a nonconforming incoming DS DPL <= CPL.
    // RPL 3 on selector 0013 violates the rule at CPL 0 and raises #GP(0010).
    unsigned incoming_ds_privilege_shutdown_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x0028,0x0013);
        b.put(kIdtBase+13*8,{0,0,0,0,0,0,0,0}); // Invalid #GP gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0030 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming-DS privilege #GP did not escalate to null-error #DF shutdown with the transferred context");
        check(b.data_transfers.size()>=16,
              "incoming-DS privilege #GP-to-#DF case omitted a handler-gate lookup");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+13*8+i,
                  "incoming-DS privilege #GP read an unexpected first-fault gate byte");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming-DS privilege #DF shutdown read an unexpected gate byte");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x10 &&
                         t.address<kGdtBase+0x18;
              }),"incoming-DS privilege #GP case did not inspect the rejected descriptor");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming-DS privilege #GP shutdown did not remain quiescent");
        ++incoming_ds_privilege_shutdown_cases;
    }
    check(incoming_ds_privilege_shutdown_cases==2,
          "incoming-DS privilege #GP-to-#DF shutdown missed a READY policy");

    unsigned incoming_ds_privilege_df_task_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x0028,0x0013);
        b.put(kIdtBase+13*8,{0,0,0,0,0,0,0,0}); // Invalid #GP gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        const uint16_t ds_privilege_df_task_words[]={
            0x0500,0x0202,0x0201,0x0202,0x0203,0x0204,0x0080,
            0x0205,0x0206,0x0207,0x0010,0x0030,0x0028,0x0010,0x0000
        };
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base + 0x000e + 2*i,
                          ds_privilege_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false;
        bool df_packet_protected=false;
        bool df_packet_restartable=false;
        bool df_packet_error_valid=false;
        uint16_t df_packet_error_code=0;
        unsigned df_packet_vector=0;
        uint16_t df_packet_saved_cs=0;
        uint16_t df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0;
        uint16_t df_packet_saved_sp=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0030 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming-DS privilege #GP did not enter #DF task with the exact code context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming-DS privilege #GP-to-#DF switch missed backlink/busy state or null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0020,0x0030,0x0028,0x0013,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base + 0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base + 0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save incoming-DS privilege fault TSS exactly");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+13*8 &&
                         t.address<kIdtBase+14*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),"incoming-DS privilege #GP-to-#DF skipped a first-fault or double-fault gate lookup");
        ++incoming_ds_privilege_df_task_cases;
    }
    check(incoming_ds_privilege_df_task_cases==2,
          "incoming-DS privilege #GP-to-#DF task delivery missed a READY policy");
    std::cout<<"PASS: 4 incoming-DS privilege #GP first-fault executions cover invalid #GP-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // Table 8-1 row 16 also rejects an incoming ES whose RPL exceeds its DPL.
    // Selector 0023 names DPL-0 writable data with RPL 3 and raises #GP(0020).
    unsigned incoming_es_privilege_shutdown_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0023,0x0030,0x0028,0x0010);
        b.put(kIdtBase+13*8,{0,0,0,0,0,0,0,0}); // Invalid #GP gate raises #GP.
        b.put(kIdtBase+8*8,{0,0,0,0,0,0,0,0});  // Invalid #DF gate causes shutdown.
        b.data_transfers.clear();
        for (unsigned cycle=0;cycle<150000 && !b.d.shutdown_o && !b.d.fault_o;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o &&
              b.d.event_packet_valid_o && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_error_code_o==0 && b.d.event_vector_o==8 &&
              b.d.event_packet_saved_cs_o==0x0030 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming-ES privilege #GP did not escalate to null-error #DF shutdown with the transferred context");
        check(b.data_transfers.size()>=16,
              "incoming-ES privilege #GP-to-#DF case omitted a handler-gate lookup");
        const size_t final_gate_reads=b.data_transfers.size()-16;
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+i].write &&
                  b.data_transfers[final_gate_reads+i].address==kIdtBase+13*8+i,
                  "incoming-ES privilege #GP read an unexpected first-fault gate byte");
        for (unsigned i=0;i<8;++i)
            check(!b.data_transfers[final_gate_reads+8+i].write &&
                  b.data_transfers[final_gate_reads+8+i].address==kIdtBase+8*8+i,
                  "incoming-ES privilege #DF shutdown read an unexpected gate byte");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase+0x20 &&
                         t.address<kGdtBase+0x28;
              }),"incoming-ES privilege #GP case did not inspect the rejected descriptor");
        for (unsigned cycle=0;cycle<8;++cycle)
            b.tick(wait);
        check(b.d.shutdown_o && b.d.halted_o && !b.d.fault_o && !b.d.bus_req_o,
              "incoming-ES privilege #GP shutdown did not remain quiescent");
        ++incoming_es_privilege_shutdown_cases;
    }
    check(incoming_es_privilege_shutdown_cases==2,
          "incoming-ES privilege #GP-to-#DF shutdown missed a READY policy");

    unsigned incoming_es_privilege_df_task_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0023,0x0030,0x0028,0x0010);
        b.put(kIdtBase+13*8,{0,0,0,0,0,0,0,0}); // Invalid #GP gate raises #GP.
        b.put(kGdtBase+0x70,{0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00});
        b.put(kIdtBase+8*8,{0x00,0x00,0x70,0x00,0x00,0x85,0x00,0x00});
        b.put(kHandlerBase+0x0500,{0xf4});
        const uint16_t es_privilege_df_task_words[]={
            0x0500,0x0202,0x0201,0x0202,0x0203,0x0204,0x0080,
            0x0205,0x0206,0x0207,0x0010,0x0030,0x0028,0x0010,0x0000
        };
        for (unsigned i=0;i<15;++i)
            put_task_word(b,incoming_df_tss_base + 0x000e + 2*i,
                          es_privilege_df_task_words[i]);
        b.data_transfers.clear();
        unsigned df_task_entries=0;
        bool df_packet_valid=false;
        bool df_packet_protected=false;
        bool df_packet_restartable=false;
        bool df_packet_error_valid=false;
        uint16_t df_packet_error_code=0;
        unsigned df_packet_vector=0;
        uint16_t df_packet_saved_cs=0;
        uint16_t df_packet_saved_ip=0;
        uint16_t df_packet_saved_flags=0;
        uint16_t df_packet_saved_sp=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==8) {
                ++df_task_entries;
                df_packet_valid=b.d.event_packet_valid_o;
                df_packet_protected=b.d.event_packet_protected_o;
                df_packet_restartable=b.d.event_packet_restartable_o;
                df_packet_error_valid=b.d.event_packet_error_valid_o;
                df_packet_error_code=b.d.event_packet_error_code_o;
                df_packet_vector=b.d.event_vector_o;
                df_packet_saved_cs=b.d.event_packet_saved_cs_o;
                df_packet_saved_ip=b.d.event_packet_saved_ip_o;
                df_packet_saved_flags=b.d.event_packet_saved_flags_o;
                df_packet_saved_sp=b.d.event_packet_saved_sp_o;
            }
        }
        check(df_task_entries==1 && !b.d.shutdown_o && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0501 &&
              df_packet_valid && df_packet_protected && df_packet_restartable &&
              df_packet_error_valid && df_packet_error_code==0 && df_packet_vector==8 &&
              df_packet_saved_cs==0x0030 && df_packet_saved_ip==0x0300 &&
              df_packet_saved_flags==0x4202 && df_packet_saved_sp==0x0080,
              "incoming-ES privilege #GP did not enter #DF task with the exact code context");
        check(uint16_t(b.memory[incoming_df_tss_base] |
                       (uint16_t(b.memory[incoming_df_tss_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x75]==0x83 && b.memory[kGdtBase+0x55]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==0x0000,
              "incoming-ES privilege #GP-to-#DF switch missed backlink/busy state or null-error push");
        const uint16_t saved_faulting_task[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,0x0023,0x0030,0x0028,0x0010,0x0000
        };
        for (unsigned i=0;i<15;++i)
            check(uint16_t(b.memory[incoming_tss1_base + 0x000e + 2*i] |
                           (uint16_t(b.memory[incoming_tss1_base + 0x000f + 2*i])<<8))==
                      saved_faulting_task[i],
                  "#DF task switch did not save incoming-ES privilege fault TSS exactly");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+13*8 &&
                         t.address<kIdtBase+14*8;
              }) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kIdtBase+8*8 &&
                         t.address<kIdtBase+9*8;
              }),"incoming-ES privilege #GP-to-#DF skipped a first-fault or double-fault gate lookup");
        ++incoming_es_privilege_df_task_cases;
    }
    check(incoming_es_privilege_df_task_cases==2,
          "incoming-ES privilege #GP-to-#DF task delivery missed a READY policy");
    std::cout<<"PASS: 4 incoming-ES privilege #GP first-fault executions cover invalid #GP-gate shutdown and valid #DF task entry, exact TSS save, and null-error push in both READY modes\n";

    // Intel 210498-005 section 8.3 steps 7-8 validates the incoming segment
    // selectors before checking the incoming task IP against the CS limit.
    // Keep both faults live to prove this ordering, then check the IP-only
    // case independently. The #SS/#GP handlers use a separate valid code
    // segment so they cannot fetch from the invalid incoming IP.
    constexpr uint32_t incoming_ip_fault_handler_base=0x00035000;
    unsigned incoming_ip_fault_priority_cases=0;
    for (bool wait:{false,true}) for (bool null_ss:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,null_ss ? 0x0000 : 0x0028,0x0010);
        put_task_word(b,incoming_tss1_base+0x000e,0x0400);
        // CS=0030 is present and valid, but IP 0400 lies just past its 03ff limit.
        b.put(kGdtBase+0x30,{0xff,0x03,0x00,0x10,0x00,0x9a,0x00,0x00});
        // The exception task uses a separate, full-limit CPL0 code segment.
        b.put(kGdtBase+0x80,{0xff,0xff,0x00,0x50,0x03,0x9a,0x00,0x00});
        // The fixture already used some of these descriptors; clear their
        // accessed bits so this task entry's ordered writes are observable.
        for (uint32_t selector:{0x0010u,0x0020u,0x0028u,0x0030u})
            b.memory[kGdtBase+selector+5]&=0xfe;
        put_task_word(b,incoming_tss2_base+0x000e + 2*11,0x0080);
        b.put(incoming_ip_fault_handler_base+0x0400,{0xf4});
        b.data_transfers.clear();
        b.accepted.clear();

        const uint8_t expected_vector=null_ss ? 12 : 13;
        unsigned expected_fault_entries=0,wrong_fault_entries=0;
        bool packet_valid=false,packet_protected=false,packet_restartable=false;
        bool packet_error_valid=false;
        uint16_t packet_error=0,saved_cs=0,saved_ip=0,saved_flags=0,saved_sp=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && (b.d.event_vector_o==12 || b.d.event_vector_o==13)) {
                if (b.d.event_vector_o==expected_vector) {
                    ++expected_fault_entries;
                    packet_valid=b.d.event_packet_valid_o;
                    packet_protected=b.d.event_packet_protected_o;
                    packet_restartable=b.d.event_packet_restartable_o;
                    packet_error_valid=b.d.event_packet_error_valid_o;
                    packet_error=b.d.event_packet_error_code_o;
                    saved_cs=b.d.event_packet_saved_cs_o;
                    saved_ip=b.d.event_packet_saved_ip_o;
                    saved_flags=b.d.event_packet_saved_flags_o;
                    saved_sp=b.d.event_packet_saved_sp_o;
                } else ++wrong_fault_entries;
            }
        }
        if (expected_fault_entries!=1 || wrong_fault_entries!=0 || b.d.fault_o ||
            !b.d.halted_o || b.cs()!=0x0080 || b.d.ip_o!=0x0401)
            std::cerr<<"incoming task IP/SS priority failure null-SS="<<null_ss
                     <<" wait="<<wait<<" entries="<<expected_fault_entries
                     <<" wrong="<<wrong_fault_entries<<" fault="<<unsigned(b.d.fault_o)
                     <<" halted="<<unsigned(b.d.halted_o)<<" cs:ip="<<std::hex
                     <<b.cs()<<":"<<b.d.ip_o<<std::dec<<'\n';
        check(expected_fault_entries==1 && wrong_fault_entries==0 && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0080 && b.d.ip_o==0x0401,
              "incoming segment/IP fault did not follow Intel task-switch validation order");
        check(packet_valid && packet_protected && packet_restartable &&
              packet_error_valid && packet_error==0 &&
              saved_cs==0x0030 && saved_ip==0x0400 &&
              saved_flags==0x4202 && saved_sp==0x0080,
              "incoming segment/IP task-entry fault lost its exact transferred context");
        const uint32_t incoming_segment_descriptors[]={
            kGdtBase+0x28,kGdtBase+0x30,kGdtBase+0x10,kGdtBase+0x20
        };
        auto is_incoming_segment_descriptor=[&](uint32_t address,unsigned index) {
            return address>=incoming_segment_descriptors[index] &&
                   address<incoming_segment_descriptors[index]+8;
        };
        std::vector<uint32_t> incoming_segment_descriptor_reads;
        std::vector<std::pair<uint32_t,uint8_t>> incoming_segment_access_writes;
        for (const auto& transfer:b.data_transfers) {
            if (!transfer.io && !transfer.write)
                for (unsigned index=0;index<4;++index)
                    if (is_incoming_segment_descriptor(transfer.address,index))
                        incoming_segment_descriptor_reads.push_back(transfer.address);
            if (transfer.write && !transfer.io)
                for (unsigned index=0;index<4;++index)
                    if (transfer.address==incoming_segment_descriptors[index]+5)
                        incoming_segment_access_writes.emplace_back(transfer.address,transfer.value);
        }
        if (null_ss) {
            const bool later_segment_read=std::any_of(
                b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& transfer) {
                    return !transfer.io && !transfer.write &&
                        (is_incoming_segment_descriptor(transfer.address,1) ||
                         is_incoming_segment_descriptor(transfer.address,2) ||
                         is_incoming_segment_descriptor(transfer.address,3));
                });
            const bool later_access_write=std::any_of(
                b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& transfer) {
                    return transfer.write && !transfer.io &&
                        (transfer.address==incoming_segment_descriptors[1]+5 ||
                         transfer.address==incoming_segment_descriptors[2]+5 ||
                         transfer.address==incoming_segment_descriptors[3]+5);
                });
            check(!later_segment_read && !later_access_write,
                  "null incoming SS read or marked a later CS/DS/ES descriptor before faulting");
        } else {
            check(incoming_segment_descriptor_reads.size()>=32,
                  "out-of-limit incoming IP fault skipped a segment descriptor lookup");
            for (unsigned descriptor=0;descriptor<4;++descriptor)
                for (unsigned byte=0;byte<8;++byte)
                    check(incoming_segment_descriptor_reads[descriptor*8+byte]==
                              incoming_segment_descriptors[descriptor]+byte,
                          "out-of-limit incoming IP did not validate SS/CS/DS/ES in order");
            check(incoming_segment_access_writes.size()>=4,
                  "out-of-limit incoming IP fault missed a segment accessed-bit write");
            for (unsigned descriptor=0;descriptor<4;++descriptor)
                check(incoming_segment_access_writes[descriptor].first==
                          incoming_segment_descriptors[descriptor]+5 &&
                      (incoming_segment_access_writes[descriptor].second&1),
                      "out-of-limit incoming IP did not mark SS/CS/DS/ES accessed in order");
        }
        check(uint16_t(b.memory[incoming_tss1_base] |
                       (uint16_t(b.memory[incoming_tss1_base+1])<<8))==0x0058 &&
              b.memory[kGdtBase+0x55]==0x83 && b.memory[kGdtBase+0x65]==0x83 &&
              uint16_t(b.memory[kStackBase+0x007e] |
                       (uint16_t(b.memory[kStackBase+0x007f])<<8))==0x0000,
              "incoming segment/IP task fault missed nested backlink, busy state, or zero error push");
        check(std::none_of(b.accepted.begin(),b.accepted.end(),[](uint32_t address) {
                  return address==kHandlerBase+0x0400;
              }) &&
              std::any_of(b.accepted.begin(),b.accepted.end(),[](uint32_t address) {
                  return address==incoming_ip_fault_handler_base+0x0400;
              }),
              "task switch fetched from the invalid incoming IP or skipped the valid handler");
        ++incoming_ip_fault_priority_cases;
    }
    check(incoming_ip_fault_priority_cases==4,
          "incoming task segment/IP priority missed a READY mode or fault variant");
    std::cout<<"PASS: 4 incoming-task fault cases verify SS-before-IP priority, SS/CS/DS/ES descriptor order and accessed effects, and #GP(0) for invalid IP in both READY modes\n";

    unsigned incoming_ldt_ss_priority_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0x0058);
        set_incoming_segments(b,0x0020,0x0030,0x0000,0x0010);
        b.data_transfers.clear();
        unsigned expected_fault_entries=0,wrong_fault_entries=0;
        bool fault_packet_valid=false;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && (b.d.event_vector_o==10 || b.d.event_vector_o==12)) {
                if (b.d.event_vector_o==10) {
                    ++expected_fault_entries;
                    fault_packet_valid=b.d.event_packet_valid_o;
                }
                else ++wrong_fault_entries;
            }
        }
        check(expected_fault_entries==1 && wrong_fault_entries==0 && !b.d.fault_o &&
              b.d.halted_o && b.cs()==0x0030 && b.d.ip_o==0x0401,
              "incoming invalid LDT did not fault before the null incoming SS");
        check(fault_packet_valid && b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o && b.d.event_packet_error_valid_o &&
              b.d.event_vector_o==10 && b.d.event_packet_error_code_o==0x0058 &&
              b.d.event_packet_saved_cs_o==0x0030 &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080,
              "incoming LDT-before-SS fault lost its exact #TS packet");
        std::size_t ldt_descriptor_read=std::numeric_limits<std::size_t>::max();
        std::size_t segment_descriptor_read=std::numeric_limits<std::size_t>::max();
        for (std::size_t index=0;index<b.data_transfers.size();++index) {
            const auto& transfer=b.data_transfers[index];
            if (transfer.write || transfer.io) continue;
            if (ldt_descriptor_read==std::numeric_limits<std::size_t>::max() &&
                transfer.address>=kGdtBase+0x58 && transfer.address<kGdtBase+0x60)
                ldt_descriptor_read=index;
            const bool incoming_segment_descriptor=
                (transfer.address>=kGdtBase+0x10 && transfer.address<kGdtBase+0x18) ||
                (transfer.address>=kGdtBase+0x20 && transfer.address<kGdtBase+0x38);
            if (segment_descriptor_read==std::numeric_limits<std::size_t>::max() &&
                incoming_segment_descriptor)
                segment_descriptor_read=index;
        }
        check(ldt_descriptor_read!=std::numeric_limits<std::size_t>::max() &&
              segment_descriptor_read!=std::numeric_limits<std::size_t>::max() &&
              segment_descriptor_read>ldt_descriptor_read,
              "incoming SS/CS/DS/ES descriptor access preceded incoming LDT validation");
        ++incoming_ldt_ss_priority_cases;
    }
    check(incoming_ldt_ss_priority_cases==2,
          "incoming LDT-before-SS priority missed a READY mode");
    std::cout<<"PASS: 2 combined invalid-LDT/null-SS task faults verify LDT-before-segment priority in both READY modes\n";

    // Far CALL/JMP to an available 286 TSS are architectural task switches,
    // distinct from interrupt task gates. CALL nests and returns through the
    // backlink; JMP clears the old busy bit and does not write a backlink.
    constexpr uint32_t direct_task_tss_base=0x000a0000;
    constexpr uint16_t direct_task_tss_selector=0x0078;
    constexpr uint16_t direct_task_gate_selector=0x0070;
    constexpr uint16_t current_task_tss_selector=0x0058;
    const uint8_t direct_task_tss_descriptor[]={0x2b,0x00,0x00,0x00,0x0a,0x81,0x00,0x00};
    const uint16_t direct_task_words[]={
        0x0500,0x0202,0x0201,0x0202,0x0203,0x0204,0x0080,
        0x0205,0x0206,0x0207,0x0010,0x0030,0x0028,0x0010,0x0000
    };
    unsigned direct_task_switch_cases=0;
    for (bool wait:{false,true}) for (bool nested_call:{false,true})
        for (bool through_task_gate:{false,true}) {
        const uint16_t transfer_selector=through_task_gate ? direct_task_gate_selector :
                                                             direct_task_tss_selector;
        const std::vector<uint8_t> program=nested_call ?
            std::vector<uint8_t>{0x9a,0x00,0x05,uint8_t(transfer_selector),
                                 uint8_t(transfer_selector>>8),0xf4} :
            std::vector<uint8_t>{0xea,0x00,0x05,uint8_t(transfer_selector),
                                 uint8_t(transfer_selector>>8),0xf4};
        Bench b;
        const Context context=prepare(b,wait,0,0,program,true);
        b.put(kGdtBase+direct_task_tss_selector,
              {direct_task_tss_descriptor[0],direct_task_tss_descriptor[1],
               direct_task_tss_descriptor[2],direct_task_tss_descriptor[3],
               direct_task_tss_descriptor[4],direct_task_tss_descriptor[5],
               direct_task_tss_descriptor[6],direct_task_tss_descriptor[7]});
        if (through_task_gate)
            b.put(kGdtBase+direct_task_gate_selector,
                  {0x5a,0xa5,uint8_t(direct_task_tss_selector),
                   uint8_t(direct_task_tss_selector>>8),0x00,0x85,0x00,0x00});
        for (unsigned i=0;i<15;++i)
            put_task_word(b,direct_task_tss_base+0x000e + 2*i,direct_task_words[i]);
        put_task_word(b,direct_task_tss_base,0xa55a); // Detect an illegal JMP backlink write.
        if (nested_call) b.put(kHandlerBase+0x0500,{0xcf,0xf4});
        else b.put(kHandlerBase+0x0500,{0xf4});
        b.data_transfers.clear();
        const unsigned retired_before=b.retired;
        unsigned task_events=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o &&
                                 !b.d.shutdown_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o) ++task_events;
        }
        const uint16_t expected_ip=nested_call ? 0x0406 : 0x0501;
        const uint16_t expected_cs=nested_call ? context.level.cs : 0x0030;
        check(b.d.halted_o && !b.d.fault_o && !b.d.shutdown_o && task_events==0 &&
              b.cs()==expected_cs && b.d.ip_o==expected_ip,
              nested_call ?
                "far CALL to an available TSS did not task-switch, IRET through its backlink, and reach the exact caller successor" :
                "far JMP to an available TSS did not task-switch and reach the exact target HLT successor");
        check(b.retired==retired_before+(nested_call ? 3u : 2u),
              "direct TSS CALL/JMP or its target instructions retired the wrong number of times");
        check(b.memory[kGdtBase+0x5d]==(nested_call ? 0x83 : 0x81) &&
              b.memory[kGdtBase+direct_task_tss_selector+5]==(nested_call ? 0x81 : 0x83),
              "direct TSS CALL/JMP left incorrect outgoing or incoming busy state");
        check(uint16_t(b.memory[direct_task_tss_base] |
                       (uint16_t(b.memory[direct_task_tss_base+1])<<8))==
                  (nested_call ? current_task_tss_selector : 0xa55a),
              "direct TSS CALL/JMP wrote the wrong backlink state");
        check(uint16_t(b.memory[0x0007000e] |
                       (uint16_t(b.memory[0x0007000f])<<8))==0x0405 &&
              uint16_t(b.memory[0x00070010] |
                       (uint16_t(b.memory[0x00070011])<<8))==context.flags &&
              uint16_t(b.memory[0x00070024] |
                       (uint16_t(b.memory[0x00070025])<<8))==context.level.cs,
              "direct TSS CALL/JMP did not save the exact outgoing instruction successor and state");
        check(std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                  return !t.write && !t.io &&
                      t.address==kGdtBase+(through_task_gate ? direct_task_gate_selector :
                                                              direct_task_tss_selector);
              }) &&
              (!through_task_gate || std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                  return !t.write && !t.io && t.address==kGdtBase+direct_task_tss_selector;
              })) &&
              std::any_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address==direct_task_tss_base+0x000e;
              }),"direct TSS CALL/JMP omitted the target descriptor or TSS image read");
        ++direct_task_switch_cases;
    }
    check(direct_task_switch_cases==8,
          "direct TSS CALL/JMP task-transfer matrix missed a transfer or READY policy");
    std::cout<<"PASS: 8 protected far CALL/JMP transfers through available TSS descriptors and task gates check nested backlink/NT return versus non-nested busy clearing and exact successors in both READY modes\n";

    // Intel 210498-005 §8.5 applies the task-gate DPL check to the effective
    // privilege of the far selector: max(CPL,RPL) must be <= gate DPL.
    unsigned task_gate_privilege_cases=0;
    unsigned task_gate_privilege_successes=0;
    unsigned task_gate_cpl_denials=0;
    unsigned task_gate_rpl_denials=0;
    unsigned task_gate_privilege_denials=0;
    constexpr uint16_t ring12_task_gate_selector=0x0048;
    constexpr uint16_t ring12_task_tss_selector=0x0050;
    for (bool wait:{false,true}) for (unsigned cpl=0;cpl<=2;++cpl)
      for (unsigned gate_rpl=0;gate_rpl<=3;++gate_rpl)
       for (unsigned gate_dpl=0;gate_dpl<=3;++gate_dpl)
        for (bool nested_call:{false,true}) {
        const bool allowed=std::max(cpl,gate_rpl)<=gate_dpl;
        const uint16_t gate_selector=uint16_t(ring12_task_gate_selector|gate_rpl);
        const std::vector<uint8_t> program=nested_call ?
            std::vector<uint8_t>{0x9a,0x5a,0xa5,uint8_t(gate_selector),
                                 uint8_t(gate_selector>>8),0xcd,0x0d} :
            std::vector<uint8_t>{0xea,0x5a,0xa5,uint8_t(gate_selector),
                                 uint8_t(gate_selector>>8),0xf4};
        Bench b;
        const Context context=prepare(b,wait,cpl,0,program,true);
        // Let the ring-1/ring-2 CALL case stop through a DPL-3 software INT;
        // HLT itself is privileged and cannot be its caller successor.
        if (nested_call)
            b.put(kIdtBase+13*8,{0x00,0x03,0x30,0x00,0x00,0xe6,0x00,0x00});
        b.put(kGdtBase+ring12_task_tss_selector,
              {direct_task_tss_descriptor[0],direct_task_tss_descriptor[1],
               direct_task_tss_descriptor[2],direct_task_tss_descriptor[3],
               direct_task_tss_descriptor[4],direct_task_tss_descriptor[5],
               direct_task_tss_descriptor[6],direct_task_tss_descriptor[7]});
        b.put(kGdtBase+ring12_task_gate_selector,
              {0x5a,0xa5,uint8_t(ring12_task_tss_selector),
               uint8_t(ring12_task_tss_selector>>8),0x00,
               uint8_t(0x85|(gate_dpl<<5)),0x00,0x00});
        for (unsigned i=0;i<15;++i)
            put_task_word(b,direct_task_tss_base+0x000e + 2*i,direct_task_words[i]);
        put_task_word(b,direct_task_tss_base,0xa55a);
        if (nested_call) b.put(kHandlerBase+0x0500,{0xcf,0xf4});
        else b.put(kHandlerBase+0x0500,{0xf4});
        b.data_transfers.clear();
        const unsigned retired_before=b.retired;
        unsigned task_events=0;
        bool packet_seen=false,packet_protected=false,packet_restartable=false;
        bool packet_error_valid=false;
        uint8_t packet_vector=0;
        uint16_t packet_error=0,packet_cs=0,packet_ip=0,packet_flags=0,packet_sp=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o &&
                                 !b.d.shutdown_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o) {
                ++task_events;
                if (b.d.event_packet_valid_o) {
                    packet_seen=true;
                    packet_protected=b.d.event_packet_protected_o;
                    packet_restartable=b.d.event_packet_restartable_o;
                    packet_error_valid=b.d.event_packet_error_valid_o;
                    packet_vector=b.d.event_vector_o;
                    packet_error=b.d.event_packet_error_code_o;
                    packet_cs=b.d.event_packet_saved_cs_o;
                    packet_ip=b.d.event_packet_saved_ip_o;
                    packet_flags=b.d.event_packet_saved_flags_o;
                    packet_sp=b.d.event_packet_saved_sp_o;
                }
            }
        }
        const uint32_t gate_address=kGdtBase+ring12_task_gate_selector;
        const uint32_t target_descriptor_address=kGdtBase+ring12_task_tss_selector;
        const auto transfer_count=[&](uint32_t first,uint32_t last,bool write) {
            return std::count_if(b.data_transfers.begin(),b.data_transfers.end(),
                [&](const auto& t) {
                    return !t.io && t.write==write && t.address>=first && t.address<last;
                });
        };
        if (allowed) {
            const uint16_t expected_cs=0x0030;
            const uint16_t expected_ip=nested_call ? 0x0301 : 0x0501;
            check(b.d.halted_o && !b.d.fault_o && !b.d.shutdown_o &&
                  task_events==(nested_call ? 1u : 0u) &&
                  b.cs()==expected_cs && b.d.ip_o==expected_ip,
                  "equal-CPL/RPL task-gate DPL boundary did not reach the exact CALL/JMP successor");
            check(b.retired==retired_before+(nested_call ? 4u : 2u),
                  "permitted ring-1/ring-2 task-gate CALL/JMP retired the wrong count");
            if (nested_call) {
                const uint16_t frame_sp=uint16_t(context.sp-(cpl==0 ? 6u : 10u));
                check(packet_seen && packet_vector==13 && !packet_error_valid &&
                      packet_cs==uint16_t(context.level.cs|cpl) && packet_ip==0x0407 &&
                      packet_flags==context.flags && packet_sp==context.sp &&
                      b.reg(4)==frame_sp &&
                      uint16_t(b.memory[kStackBase+frame_sp] |
                          (uint16_t(b.memory[kStackBase+frame_sp+1])<<8))==0x0407 &&
                      uint16_t(b.memory[kStackBase+frame_sp+2] |
                          (uint16_t(b.memory[kStackBase+frame_sp+3])<<8))==
                          uint16_t(context.level.cs|cpl) &&
                      uint16_t(b.memory[kStackBase+frame_sp+4] |
                          (uint16_t(b.memory[kStackBase+frame_sp+5])<<8))==context.flags &&
                      (cpl==0 ||
                       (uint16_t(b.memory[kStackBase+frame_sp+6] |
                          (uint16_t(b.memory[kStackBase+frame_sp+7])<<8))==context.sp &&
                      uint16_t(b.memory[kStackBase+frame_sp+8] |
                          (uint16_t(b.memory[kStackBase+frame_sp+9])<<8))==
                          uint16_t(context.level.ss|cpl))),
                      "task-gate CALL did not return to the exact ring-level INT successor/frame");
            }
            check(b.memory[kGdtBase+0x5d]==(nested_call ? 0x83 : 0x81) &&
                  b.memory[kGdtBase+ring12_task_tss_selector+5]==
                      (nested_call ? 0x81 : 0x83) &&
                  uint16_t(b.memory[direct_task_tss_base] |
                      (uint16_t(b.memory[direct_task_tss_base+1])<<8))==
                      (nested_call ? current_task_tss_selector : 0xa55a),
                  "permitted ring-level task-gate transfer left incorrect backlink/busy state");
            check(uint16_t(b.memory[0x0007000e] |
                      (uint16_t(b.memory[0x0007000f])<<8))==0x0405 &&
                  uint16_t(b.memory[0x00070024] |
                      (uint16_t(b.memory[0x00070025])<<8))==
                      uint16_t(context.level.cs|cpl),
                  "ring-level task-gate transfer did not save the exact caller successor");
            check(transfer_count(gate_address,gate_address+8,false)==8 &&
                  transfer_count(target_descriptor_address,
                                 target_descriptor_address+8,false)>=8 &&
                  transfer_count(direct_task_tss_base,direct_task_tss_base+0x2e,false)>0,
                  "permitted ring-level task-gate transfer skipped gate/TSS admission reads");
            ++task_gate_privilege_successes;
        } else {
            const uint16_t frame_sp=uint16_t(context.sp-(cpl==0 ? 8u : 12u));
            check(b.d.halted_o && !b.d.fault_o && !b.d.shutdown_o && task_events==1 &&
                  b.cs()==0x0030 && b.d.ip_o==0x0301 &&
                  b.retired==retired_before+1,
                  "task-gate DPL denial did not reach the exact same-task #GP handler");
            check(packet_seen && packet_protected && packet_restartable &&
                  packet_error_valid && packet_vector==13 &&
                  packet_error==(gate_selector&0xfffc) &&
                  packet_cs==uint16_t(context.level.cs|cpl) && packet_ip==0x0400 &&
                  packet_flags==context.flags && packet_sp==context.sp,
                  "task-gate DPL denial produced the wrong #GP selector packet");
            check(b.reg(4)==frame_sp &&
                  uint16_t(b.memory[kStackBase+frame_sp] |
                      (uint16_t(b.memory[kStackBase+frame_sp+1])<<8))==
                      (gate_selector&0xfffc) &&
                  uint16_t(b.memory[kStackBase+frame_sp+2] |
                      (uint16_t(b.memory[kStackBase+frame_sp+3])<<8))==0x0400 &&
                  uint16_t(b.memory[kStackBase+frame_sp+4] |
                      (uint16_t(b.memory[kStackBase+frame_sp+5])<<8))==
                      uint16_t(context.level.cs|cpl) &&
                  uint16_t(b.memory[kStackBase+frame_sp+6] |
                      (uint16_t(b.memory[kStackBase+frame_sp+7])<<8))==context.flags &&
                  (cpl==0 ||
                   (uint16_t(b.memory[kStackBase+frame_sp+8] |
                      (uint16_t(b.memory[kStackBase+frame_sp+9])<<8))==context.sp &&
                  uint16_t(b.memory[kStackBase+frame_sp+10] |
                      (uint16_t(b.memory[kStackBase+frame_sp+11])<<8))==
                      uint16_t(context.level.ss|cpl))),
                  "task-gate DPL denial wrote the wrong privilege-change #GP frame");
            check(transfer_count(gate_address,gate_address+8,false)==8 &&
                  transfer_count(target_descriptor_address,
                                 target_descriptor_address+8,false)==0 &&
                  transfer_count(direct_task_tss_base,direct_task_tss_base+0x2e,false)==0 &&
                  transfer_count(direct_task_tss_base,
                                 direct_task_tss_base+0x2e,true)==0 &&
                  b.memory[kGdtBase+ring12_task_tss_selector+5]==0x81 &&
                  b.memory[kGdtBase+0x5d]==0x83 &&
                  uint16_t(b.memory[direct_task_tss_base] |
                      (uint16_t(b.memory[direct_task_tss_base+1])<<8))==0xa55a,
                  "task-gate DPL denial accessed or changed the destination task state");
            ++task_gate_privilege_denials;
            if (cpl>gate_dpl) ++task_gate_cpl_denials;
            if (gate_rpl>gate_dpl) ++task_gate_rpl_denials;
        }
        ++task_gate_privilege_cases;
    }
    check(task_gate_privilege_cases==192 && task_gate_privilege_successes==104 &&
          task_gate_privilege_denials==88 && task_gate_cpl_denials==48 &&
          task_gate_rpl_denials==72,
          "task-gate privilege matrix missed a CPL/RPL/DPL combination, transfer form, or READY mode");
    std::cout<<"PASS: 192 task-gate CALL/JMP privilege cases exhaust CPL0-2, selector RPL0-3 and gate DPL0-3, checking max(CPL,RPL)<=DPL, exact #GP frames, preflight and exact successors in both READY modes\n";

    // Intel 210498-005 §8.3 applies the data-access privilege rule to TSS
    // descriptors: max(CPL,RPL) must not exceed the TSS descriptor DPL.
    // Selector 0050 avoids aliasing the CPL2 stack descriptor at 0078.
    constexpr uint16_t direct_task_privilege_selector=0x0050;
    unsigned direct_task_privilege_cases=0;
    unsigned direct_task_privilege_successes=0;
    unsigned direct_task_privilege_denials=0;
    unsigned direct_task_cpl_denials=0;
    unsigned direct_task_rpl_denials=0;
    for (bool wait:{false,true}) for (unsigned cpl=0;cpl<=2;++cpl)
      for (unsigned task_rpl=0;task_rpl<=3;++task_rpl)
       for (unsigned task_dpl=0;task_dpl<=3;++task_dpl)
        for (bool nested_call:{false,true}) {
        const bool allowed=std::max(cpl,task_rpl)<=task_dpl;
        const uint16_t task_selector=uint16_t(direct_task_privilege_selector|task_rpl);
        const std::vector<uint8_t> program=nested_call ?
            std::vector<uint8_t>{0x9a,0x5a,0xa5,uint8_t(task_selector),
                                 uint8_t(task_selector>>8),0xcd,0x0d} :
            std::vector<uint8_t>{0xea,0x5a,0xa5,uint8_t(task_selector),
                                 uint8_t(task_selector>>8),0xf4};
        Bench b;
        const Context context=prepare(b,wait,cpl,0,program,true);
        // CALL returns to the exact ring-level successor, which raises a
        // DPL-3 software interrupt to stop in the shared ring-0 handler.
        b.put(kIdtBase+13*8,{0x00,0x03,0x30,0x00,0x00,0xe6,0x00,0x00});
        b.put(kGdtBase+direct_task_privilege_selector,
              {direct_task_tss_descriptor[0],direct_task_tss_descriptor[1],
               direct_task_tss_descriptor[2],direct_task_tss_descriptor[3],
               direct_task_tss_descriptor[4],
               uint8_t(0x81|(task_dpl<<5)),
               direct_task_tss_descriptor[6],direct_task_tss_descriptor[7]});
        for (unsigned i=0;i<15;++i)
            put_task_word(b,direct_task_tss_base+0x000e + 2*i,direct_task_words[i]);
        put_task_word(b,direct_task_tss_base,0xa55a);
        if (nested_call) b.put(kHandlerBase+0x0500,{0xcf,0xf4});
        else b.put(kHandlerBase+0x0500,{0xf4});
        b.data_transfers.clear();
        const unsigned retired_before=b.retired;
        unsigned task_events=0;
        bool packet_seen=false,packet_protected=false,packet_restartable=false;
        bool packet_error_valid=false;
        uint8_t packet_vector=0;
        uint16_t packet_error=0,packet_cs=0,packet_ip=0,packet_flags=0,packet_sp=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o &&
                                 !b.d.shutdown_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o) {
                ++task_events;
                if (b.d.event_packet_valid_o) {
                    packet_seen=true;
                    packet_protected=b.d.event_packet_protected_o;
                    packet_restartable=b.d.event_packet_restartable_o;
                    packet_error_valid=b.d.event_packet_error_valid_o;
                    packet_vector=b.d.event_vector_o;
                    packet_error=b.d.event_packet_error_code_o;
                    packet_cs=b.d.event_packet_saved_cs_o;
                    packet_ip=b.d.event_packet_saved_ip_o;
                    packet_flags=b.d.event_packet_saved_flags_o;
                    packet_sp=b.d.event_packet_saved_sp_o;
                }
            }
        }
        const uint32_t target_descriptor_address=kGdtBase+direct_task_privilege_selector;
        const auto transfer_count=[&](uint32_t first,uint32_t last,bool write) {
            return std::count_if(b.data_transfers.begin(),b.data_transfers.end(),
                [&](const auto& t) {
                    return !t.io && t.write==write && t.address>=first && t.address<last;
                });
        };
        if (allowed) {
            check(b.d.halted_o && !b.d.fault_o && !b.d.shutdown_o &&
                  task_events==(nested_call ? 1u : 0u) &&
                  b.cs()==0x0030 && b.d.ip_o==(nested_call ? 0x0301 : 0x0501),
                  "permitted direct-TSS CALL/JMP DPL boundary did not reach the exact task successor");
            check(b.retired>retired_before,
                  "permitted direct-TSS CALL/JMP made no instruction-retirement progress");
            if (nested_call) {
                const uint16_t frame_sp=uint16_t(context.sp-(cpl==0 ? 6u : 10u));
                const bool call_frame_ok=packet_seen && packet_vector==13 && !packet_error_valid &&
                      packet_cs==uint16_t(context.level.cs|cpl) && packet_ip==0x0407 &&
                      packet_flags==context.flags && packet_sp==context.sp &&
                      b.reg(4)==frame_sp &&
                      uint16_t(b.memory[kStackBase+frame_sp] |
                          (uint16_t(b.memory[kStackBase+frame_sp+1])<<8))==0x0407 &&
                      uint16_t(b.memory[kStackBase+frame_sp+2] |
                          (uint16_t(b.memory[kStackBase+frame_sp+3])<<8))==
                          uint16_t(context.level.cs|cpl) &&
                      uint16_t(b.memory[kStackBase+frame_sp+4] |
                          (uint16_t(b.memory[kStackBase+frame_sp+5])<<8))==context.flags &&
                      (cpl==0 ||
                       (uint16_t(b.memory[kStackBase+frame_sp+6] |
                          (uint16_t(b.memory[kStackBase+frame_sp+7])<<8))==context.sp &&
                        uint16_t(b.memory[kStackBase+frame_sp+8] |
                          (uint16_t(b.memory[kStackBase+frame_sp+9])<<8))==
                          uint16_t(context.level.ss|cpl)));
                check(call_frame_ok,
                      "direct-TSS CALL did not return to the exact ring-level successor/frame");
            }
            const uint8_t current_access=b.memory[kGdtBase+0x5d];
            const uint8_t target_access=b.memory[target_descriptor_address+5];
            const uint16_t backlink=uint16_t(b.memory[direct_task_tss_base] |
                (uint16_t(b.memory[direct_task_tss_base+1])<<8));
            check(current_access==(nested_call ? 0x83 : 0x81) &&
                  target_access==uint8_t((nested_call ? 0x81 : 0x83)|(task_dpl<<5)) &&
                  backlink==(nested_call ? current_task_tss_selector : 0xa55a),
                  "permitted direct-TSS CALL/JMP left the wrong backlink or busy state");
            check(uint16_t(b.memory[0x0007000e] |
                      (uint16_t(b.memory[0x0007000f])<<8))==0x0405 &&
                  uint16_t(b.memory[0x00070010] |
                      (uint16_t(b.memory[0x00070011])<<8))==context.flags &&
                  uint16_t(b.memory[0x00070024] |
                      (uint16_t(b.memory[0x00070025])<<8))==
                      uint16_t(context.level.cs|cpl),
                  "direct-TSS CALL/JMP did not save the exact caller successor and context");
            check(transfer_count(target_descriptor_address,target_descriptor_address+8,false)>=8 &&
                  transfer_count(target_descriptor_address,target_descriptor_address+8,true)>0 &&
                  transfer_count(direct_task_tss_base,direct_task_tss_base+0x2e,false)>0,
                  "permitted direct-TSS transfer skipped its descriptor/TSS reads or busy write");
            ++direct_task_privilege_successes;
        } else {
            const uint16_t frame_sp=uint16_t(context.sp-(cpl==0 ? 8u : 12u));
            check(b.d.halted_o && !b.d.fault_o && !b.d.shutdown_o && task_events==1 &&
                  b.cs()==0x0030 && b.d.ip_o==0x0301 &&
                  b.retired==retired_before+1,
                  "direct-TSS DPL denial did not reach the exact same-task #GP handler");
            check(packet_seen && packet_protected && packet_restartable &&
                  packet_error_valid && packet_vector==13 &&
                  packet_error==(task_selector&0xfffc) &&
                  packet_cs==uint16_t(context.level.cs|cpl) && packet_ip==0x0400 &&
                  packet_flags==context.flags && packet_sp==context.sp,
                  "direct-TSS DPL denial produced the wrong #GP selector packet");
            check(b.reg(4)==frame_sp &&
                  uint16_t(b.memory[kStackBase+frame_sp] |
                      (uint16_t(b.memory[kStackBase+frame_sp+1])<<8))==
                      (task_selector&0xfffc) &&
                  uint16_t(b.memory[kStackBase+frame_sp+2] |
                      (uint16_t(b.memory[kStackBase+frame_sp+3])<<8))==0x0400 &&
                  uint16_t(b.memory[kStackBase+frame_sp+4] |
                      (uint16_t(b.memory[kStackBase+frame_sp+5])<<8))==
                      uint16_t(context.level.cs|cpl) &&
                  uint16_t(b.memory[kStackBase+frame_sp+6] |
                      (uint16_t(b.memory[kStackBase+frame_sp+7])<<8))==context.flags &&
                  (cpl==0 ||
                   (uint16_t(b.memory[kStackBase+frame_sp+8] |
                      (uint16_t(b.memory[kStackBase+frame_sp+9])<<8))==context.sp &&
                    uint16_t(b.memory[kStackBase+frame_sp+10] |
                      (uint16_t(b.memory[kStackBase+frame_sp+11])<<8))==
                      uint16_t(context.level.ss|cpl))),
                  "direct-TSS DPL denial wrote the wrong privilege-change #GP frame");
            check(transfer_count(target_descriptor_address,target_descriptor_address+8,false)==8 &&
                  transfer_count(target_descriptor_address,target_descriptor_address+8,true)==0 &&
                  transfer_count(direct_task_tss_base,direct_task_tss_base+0x2e,false)==0 &&
                  transfer_count(direct_task_tss_base,direct_task_tss_base+0x2e,true)==0 &&
                  transfer_count(0x0007000e,0x0007002e,true)==0 &&
                  b.memory[target_descriptor_address+5]==uint8_t(0x81|(task_dpl<<5)) &&
                  b.memory[kGdtBase+0x5d]==0x83 &&
                  uint16_t(b.memory[direct_task_tss_base] |
                      (uint16_t(b.memory[direct_task_tss_base+1])<<8))==0xa55a,
                  "direct-TSS DPL denial accessed or changed task state/busy bits");
            ++direct_task_privilege_denials;
            if (cpl>task_dpl) ++direct_task_cpl_denials;
            if (task_rpl>task_dpl) ++direct_task_rpl_denials;
        }
        ++direct_task_privilege_cases;
    }
    check(direct_task_privilege_cases==192 && direct_task_privilege_successes==104 &&
          direct_task_privilege_denials==88 && direct_task_cpl_denials==48 &&
          direct_task_rpl_denials==72,
          "direct-TSS privilege matrix missed a CPL/RPL/DPL combination, transfer form, or READY mode");
    std::cout<<"PASS: 192 direct-TSS CALL/JMP privilege cases exhaust CPL0-2, selector RPL0-3 and TSS DPL0-3, checking max(CPL,RPL)<=DPL, exact #GP frames, preflight and exact successors in both READY modes\n";

    // Intel 210498-005 Tables 8-1/8-2: reject a direct task transfer before
    // changing either task image or its busy state. Exception delivery itself
    // may read IDT/GDT entries, write the current exception frame, and set the
    // handler CS accessed bit; those effects are checked separately.
    struct DirectTaskFaultCase {
        const char* name;
        bool through_task_gate,far_call;
        uint16_t selector;
        uint8_t gate_access,gate_offset;
        uint8_t tss_access;
        uint16_t tss_limit,tss_tail;
        uint8_t current_access;
        uint8_t vector;
        uint16_t error;
        bool read_target_descriptor;
        uint16_t gdt_limit=0x007f;
    };
    const DirectTaskFaultCase direct_task_faults[]={
        {"null direct selector",false,false,0x0000,0x85,0,0x81,0x002b,0,0xff,13,0x0000,false},
        {"out-of-GDT direct selector",false,true,0x0080,0x85,0,0x81,0x002b,0,0xff,13,0x0080,false},
        {"direct TSS DPL denial",false,false,0x007b,0x85,0,0x81,0x002b,0,0xff,13,0x0078,true},
        {"direct TSS DPL precedes not-present",false,true,0x007b,0x85,0,0x01,0x002b,0,0xff,13,0x0078,true},
        {"not-present direct TSS",false,true,0x0078,0x85,0,0x01,0x002b,0,0xff,11,0x0078,true},
        {"not-present short direct TSS",false,false,0x0078,0x85,0,0x01,0x002a,0,0xff,11,0x0078,true},
        {"busy direct TSS",false,false,0x0078,0x85,0,0x83,0x002b,0,0xff,13,0x0078,true},
        {"short direct TSS",false,true,0x0078,0x85,0,0x81,0x002a,0,0xff,10,0x0078,true},
        {"reserved direct TSS tail",false,false,0x0078,0x85,0,0x81,0x002b,0x0001,0xff,10,0x0078,true},
        {"task-gate DPL denial",true,false,0x0073,0x85,0,0x81,0x002b,0,0xff,13,0x0070,false},
        {"task-gate DPL precedes not-present",true,true,0x0073,0x05,0,0x81,0x002b,0,0xff,13,0x0070,false},
        {"not-present task gate",true,true,0x0070,0x05,0,0x81,0x002b,0,0xff,11,0x0070,false},
        {"not-present task-gate TSS",true,true,0x0070,0x85,0,0x01,0x002b,0,0xff,11,0x0078,true},
        {"not-present short task-gate TSS",true,false,0x0070,0x85,0,0x01,0x002a,0,0xff,11,0x0078,true},
        {"short task-gate TSS",true,false,0x0070,0x85,0,0x81,0x002a,0,0xff,10,0x0078,true},
        {"busy task-gate TSS CALL",true,true,0x0070,0x85,0,0x83,0x002b,0,0xff,13,0x0078,true},
        {"busy task-gate TSS JMP",true,false,0x0070,0x85,0,0x83,0x002b,0,0xff,13,0x0078,true},
        {"out-of-GDT task-gate TSS CALL",true,true,0x0070,0x85,0,0x81,0x002b,0,0xff,10,0x0078,false,0x0077},
        {"out-of-GDT task-gate TSS JMP",true,false,0x0070,0x85,0,0x81,0x002b,0,0xff,10,0x0078,false,0x0077},
        {"available current TR",false,true,0x0078,0x85,0,0x81,0x002b,0,0x81,10,0x0058,true},
        {"not-present current TR",true,false,0x0070,0x85,0,0x81,0x002b,0,0x03,10,0x0058,true}
    };
    unsigned direct_task_fault_cases=0;
    constexpr uint32_t outgoing_task_tss_base=0x00070000;
    for (bool wait:{false,true}) for (const auto& test:direct_task_faults) {
        const std::vector<uint8_t> program=test.far_call ?
            std::vector<uint8_t>{0x9a,0x00,0x05,uint8_t(test.selector),uint8_t(test.selector>>8),0xf4} :
            std::vector<uint8_t>{0xea,0x00,0x05,uint8_t(test.selector),uint8_t(test.selector>>8),0xf4};
        Bench b;
        const Context context=prepare(b,wait,0,0,program,true,0x07ff,test.gdt_limit);
        const uint8_t tss_descriptor[]={
            uint8_t(test.tss_limit),uint8_t(test.tss_limit>>8),0x00,0x00,0x0a,
            test.tss_access,uint8_t(test.tss_tail),uint8_t(test.tss_tail>>8)
        };
        b.put(kGdtBase+direct_task_tss_selector,
              {tss_descriptor[0],tss_descriptor[1],tss_descriptor[2],tss_descriptor[3],
               tss_descriptor[4],tss_descriptor[5],tss_descriptor[6],tss_descriptor[7]});
        b.put(kGdtBase+direct_task_gate_selector,
              {test.gate_offset,0x00,uint8_t(direct_task_tss_selector),
               uint8_t(direct_task_tss_selector>>8),0x00,test.gate_access,0x00,0x00});
        for (uint8_t vector:{10,11,13})
            b.put(kIdtBase+uint32_t(vector)*8,{0x00,0x03,0x30,0x00,0x00,0x86,0x00,0x00});
        if (test.current_access!=0xff)
            b.memory[kGdtBase+current_task_tss_selector+5]=test.current_access;
        put_task_word(b,direct_task_tss_base,0xa55a);
        put_task_word(b,outgoing_task_tss_base,0x5aa5);
        b.data_transfers.clear();
        const unsigned retired_before=b.retired;
        unsigned task_fault_events=0;
        bool task_fault_packet_seen=false,task_fault_protected=false;
        bool task_fault_restartable=false,task_fault_error_valid=false;
        uint8_t task_fault_vector=0;
        uint16_t task_fault_error=0,task_fault_saved_cs=0,task_fault_saved_ip=0;
        uint16_t task_fault_saved_flags=0,task_fault_saved_sp=0;
        for (unsigned cycle=0;cycle<100000 && !b.d.halted_o && !b.d.fault_o &&
                                 !b.d.shutdown_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o) {
                ++task_fault_events;
                if (b.d.event_packet_valid_o) {
                    task_fault_packet_seen=true;
                    task_fault_protected=b.d.event_packet_protected_o;
                    task_fault_restartable=b.d.event_packet_restartable_o;
                    task_fault_error_valid=b.d.event_packet_error_valid_o;
                    task_fault_vector=b.d.event_vector_o;
                    task_fault_error=b.d.event_packet_error_code_o;
                    task_fault_saved_cs=b.d.event_packet_saved_cs_o;
                    task_fault_saved_ip=b.d.event_packet_saved_ip_o;
                    task_fault_saved_flags=b.d.event_packet_saved_flags_o;
                    task_fault_saved_sp=b.d.event_packet_saved_sp_o;
                }
            }
        }
        const uint32_t target_descriptor_address=kGdtBase+
            (test.through_task_gate ? direct_task_tss_selector : (test.selector&0xfff8));
        const uint32_t task_gate_descriptor_address=kGdtBase+direct_task_gate_selector;
        const auto read_bytes=[&](uint32_t first,uint32_t last) {
            return std::count_if(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& transfer) {
                return !transfer.write && !transfer.io && transfer.address>=first && transfer.address<last;
            });
        };
        const auto task_image_transfer=[](const auto& transfer,uint32_t base) {
            return transfer.address>=base && transfer.address<base+0x002e;
        };
        const bool no_task_writes=std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& transfer) {
            return transfer.write && !transfer.io &&
                (task_image_transfer(transfer,direct_task_tss_base) ||
                 (transfer.address>=outgoing_task_tss_base+0x000e &&
                  transfer.address<=outgoing_task_tss_base+0x002c) ||
                 transfer.address==kGdtBase+direct_task_tss_selector+5 ||
                 transfer.address==kGdtBase+current_task_tss_selector+5);
        });
        const auto no_task_image_reads=std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& transfer) {
            return !transfer.write && !transfer.io &&
                (task_image_transfer(transfer,direct_task_tss_base) ||
                 (transfer.address>=outgoing_task_tss_base+0x000e &&
                  transfer.address<=outgoing_task_tss_base+0x002c));
        });
        const bool selected_descriptor_reads=test.read_target_descriptor ?
            read_bytes(target_descriptor_address,target_descriptor_address+8)==8 :
            read_bytes(target_descriptor_address,target_descriptor_address+8)==0;
        const bool gate_descriptor_reads=!test.through_task_gate ||
            read_bytes(task_gate_descriptor_address,task_gate_descriptor_address+8)==8;
        const bool current_access_read=test.current_access==0xff ?
            read_bytes(kGdtBase+current_task_tss_selector+5,
                       kGdtBase+current_task_tss_selector+6)==0 :
            read_bytes(kGdtBase+current_task_tss_selector+5,
                       kGdtBase+current_task_tss_selector+6)==1;
        check(b.d.halted_o && !b.d.fault_o && !b.d.shutdown_o && task_fault_events==1 &&
              b.cs()==0x0030 && b.d.ip_o==0x0301 && b.retired==retired_before+1,
              (std::string("direct task fault did not reach the exact same-task handler HLT: ")+test.name).c_str());
        const bool task_fault_packet_ok=task_fault_packet_seen && task_fault_protected &&
              task_fault_restartable && task_fault_error_valid &&
              task_fault_vector==test.vector && task_fault_error==test.error &&
              task_fault_saved_cs==context.level.cs && task_fault_saved_ip==0x0400 &&
              task_fault_saved_flags==context.flags && task_fault_saved_sp==context.sp;
        if (!task_fault_packet_ok)
            std::cerr<<"direct task fault packet "<<test.name<<" vector="
                     <<unsigned(task_fault_vector)<<" expected="<<unsigned(test.vector)
                     <<" packet-seen="<<unsigned(task_fault_packet_seen)
                     <<" error-valid="<<unsigned(task_fault_error_valid)
                     <<" error="<<std::hex<<task_fault_error<<" expected="<<test.error
                     <<" saved="<<task_fault_saved_cs<<":"<<task_fault_saved_ip
                     <<" flags="<<task_fault_saved_flags<<" sp="<<task_fault_saved_sp
                     <<" protected="<<unsigned(task_fault_protected)
                     <<" restartable="<<unsigned(task_fault_restartable)
                     <<std::dec<<" pulses="<<task_fault_events<<" transfers="<<b.data_transfers.size()<<'\n';
        check(task_fault_packet_ok,
              (std::string("direct task fault produced the wrong restartable exception packet: ")+test.name).c_str());
        check(uint16_t(b.memory[kStackBase+0x84] | (uint16_t(b.memory[kStackBase+0x85])<<8))==context.flags &&
              uint16_t(b.memory[kStackBase+0x82] | (uint16_t(b.memory[kStackBase+0x83])<<8))==context.level.cs &&
              uint16_t(b.memory[kStackBase+0x80] | (uint16_t(b.memory[kStackBase+0x81])<<8))==0x0400 &&
              uint16_t(b.memory[kStackBase+0x7e] | (uint16_t(b.memory[kStackBase+0x7f])<<8))==test.error &&
              b.reg(4)==0x007e,
              (std::string("direct task fault wrote the wrong exception frame: ")+test.name).c_str());
        check(selected_descriptor_reads && gate_descriptor_reads && current_access_read &&
              no_task_writes && no_task_image_reads &&
              b.memory[direct_task_tss_base]==0x5a && b.memory[direct_task_tss_base+1]==0xa5 &&
              b.memory[outgoing_task_tss_base]==0xa5 && b.memory[outgoing_task_tss_base+1]==0x5a &&
              b.memory[kGdtBase+direct_task_tss_selector+5]==test.tss_access &&
              b.memory[kGdtBase+current_task_tss_selector+5]==
                  (test.current_access==0xff ? 0x83 : test.current_access),
              (std::string("rejected task switch read or changed task state/busy state: ")+test.name).c_str());
        ++direct_task_fault_cases;
    }
    check(direct_task_fault_cases==42,
          "direct TSS/task-gate fault matrix missed an exception case or READY policy");
    std::cout<<"PASS: 42 rejected direct TSS/task-gate CALL/JMP cases check exact #GP/#NP/#TS priority packets and no task-image/busy-bit side effects in both READY modes\n";

    // Reset after every accepted data transfer in direct task entry. Accepted
    // writes survive RESET; the partially completed task switch must not resume.
    auto prepare_direct_task_reset_cut=[&](Bench& b,bool wait,bool far_call,
                                           bool through_task_gate) {
        const uint16_t transfer_selector=through_task_gate ? direct_task_gate_selector :
                                                               direct_task_tss_selector;
        const std::vector<uint8_t> program=far_call ?
            std::vector<uint8_t>{0x9a,0x00,0x05,uint8_t(transfer_selector),
                                 uint8_t(transfer_selector>>8),0xf4} :
            std::vector<uint8_t>{0xea,0x00,0x05,uint8_t(transfer_selector),
                                 uint8_t(transfer_selector>>8),0xf4};
        const Context context=prepare(b,wait,0,0,program,true);
        b.put(kGdtBase+direct_task_tss_selector,
              {direct_task_tss_descriptor[0],direct_task_tss_descriptor[1],
               direct_task_tss_descriptor[2],direct_task_tss_descriptor[3],
               direct_task_tss_descriptor[4],direct_task_tss_descriptor[5],
               direct_task_tss_descriptor[6],direct_task_tss_descriptor[7]});
        if (through_task_gate)
            b.put(kGdtBase+direct_task_gate_selector,
                  {0x00,0x00,uint8_t(direct_task_tss_selector),
                   uint8_t(direct_task_tss_selector>>8),0x00,0x85,0x00,0x00});
        for (unsigned i=0;i<15;++i)
            put_task_word(b,direct_task_tss_base+0x000e + 2*i,direct_task_words[i]);
        b.put(kHandlerBase+0x0500,{0xf4});
        b.data_transfers.clear();
        b.accepted.clear();
        return context;
    };
    auto enter_direct_task=[&](Bench& b,bool wait) {
        for (unsigned cycle=0;cycle<150000 && !b.d.fault_o && !b.d.shutdown_o;++cycle) {
            b.tick(wait);
            if (b.cs()==0x0030 && b.d.ip_o==0x0500) return true;
        }
        return false;
    };
    unsigned direct_task_reset_cuts=0;
    for (bool far_call:{false,true}) for (bool through_task_gate:{false,true}) {
        unsigned direct_transfer_count=0;
        unsigned combo_reset_cuts=0;
        for (bool wait:{false,true}) {
            Bench baseline;
            prepare_direct_task_reset_cut(baseline,wait,far_call,through_task_gate);
            check(enter_direct_task(baseline,wait) && !baseline.d.fault_o &&
                  !baseline.d.shutdown_o && !baseline.data_transfers.empty(),
                  "direct task-reset baseline did not reach its exact target task entry");
            const unsigned transfer_count=static_cast<unsigned>(baseline.data_transfers.size());
            if (!direct_transfer_count) direct_transfer_count=transfer_count;
            else check(transfer_count==direct_transfer_count,
                       "direct task-reset transfer count changed across READY policies");
            for (unsigned cut=0;cut<transfer_count;++cut) {
                Bench b;
                prepare_direct_task_reset_cut(b,wait,far_call,through_task_gate);
                bool transfer_accepted=false;
                for (unsigned cycle=0;cycle<150000 && !b.d.fault_o && !b.d.shutdown_o;++cycle) {
                    b.tick(wait);
                    if (b.data_transfers.size()>cut) {
                        transfer_accepted=true;
                        break;
                    }
                }
                check(transfer_accepted && b.data_transfers.size()==cut+1,
                      "direct task reset cut did not stop after its selected accepted transfer");
                b.reset();
                check(!b.d.event_packet_valid_o && !b.d.bus_req_o &&
                      !b.d.bus_halt_cycle_o && !b.d.bus_shutdown_cycle_o &&
                      b.data_transfers.size()==cut+1,
                      "RESET resumed a partial direct task switch or emitted a stale bus/event packet");
                b.put(0xfffff0,{0xf4});
                b.step(0xfffff0,0xf4,0xf000,0xfff1,wait);
                check(b.d.halted_o && b.d.bus_halt_cycle_o &&
                      !b.d.bus_shutdown_cycle_o && !b.d.shutdown_o &&
                      b.data_transfers.size()==cut+1,
                      "direct task reset cut did not replay only the reset-vector HLT");
                ++direct_task_reset_cuts;
                ++combo_reset_cuts;
            }
            const unsigned committed_transfer_count=static_cast<unsigned>(baseline.data_transfers.size());
            baseline.reset();
            check(!baseline.d.event_packet_valid_o && !baseline.d.bus_req_o &&
                  !baseline.d.bus_halt_cycle_o && !baseline.d.bus_shutdown_cycle_o &&
                  baseline.data_transfers.size()==committed_transfer_count,
                  "RESET resumed a committed direct task or changed its accepted-transfer history");
            baseline.put(0xfffff0,{0xf4});
            baseline.step(0xfffff0,0xf4,0xf000,0xfff1,wait);
            check(baseline.d.halted_o && baseline.d.bus_halt_cycle_o &&
                  !baseline.d.bus_shutdown_cycle_o && !baseline.d.shutdown_o &&
                  baseline.data_transfers.size()==committed_transfer_count,
                  "post-commit direct task reset did not replay only reset-vector HLT");
            ++direct_task_reset_cuts;
            ++combo_reset_cuts;
        }
        check(combo_reset_cuts==2*direct_transfer_count+2,
              "direct task reset cuts missed an accepted transfer or READY policy");
    }
    std::cout<<"PASS: "<<direct_task_reset_cuts
             <<" reset cuts across direct TSS/task-gate CALL/JMP entry replay the reset vector without resuming a partial task switch in both READY modes\n";

    {
        const std::vector<uint8_t> program={0xea,0x00,0x05,0x08,0x00};
        Bench b;
        const Context context=prepare(b,false,0,0,program,true);
        b.put(kCodeBase+0x0500,{0xf4});
        b.data_transfers.clear();
        const unsigned retired_before=b.retired;
        unsigned task_events=0;
        for (unsigned cycle=0;cycle<30000 && !b.d.halted_o && !b.d.fault_o &&
                                 !b.d.shutdown_o;++cycle) {
            b.tick(false);
            if (b.d.event_o) ++task_events;
        }
        check(b.d.halted_o && !b.d.fault_o && !b.d.shutdown_o && task_events==0 &&
              b.cs()==context.level.cs && b.d.ip_o==0x0501 &&
              b.retired==retired_before+2,
              "protected far JMP to a code descriptor did not reach the exact target successor");
    }
    std::cout<<"PASS: protected far JMP to an ordinary code descriptor retains the exact target successor\n";

    struct NullTaskSelectorCase { uint16_t ldtr,es,ds; };
    // Test the target profile's literal visible selector values. Intel's
    // 1984 B-2/B-3 sheet records an earlier-stepping DS/ES null-selector
    // erratum that clears them to zero; those stepping errata are not selected.
    const NullTaskSelectorCase null_task_selectors[]={
        {0x0000,0x0001,0x0003}, {0x0001,0x0002,0x0000},
        {0x0002,0x0003,0x0001}, {0x0003,0x0000,0x0002}
    };
    unsigned noerror_task_gate_cases=0;
    const uint8_t noerror_task_program[]={
        0x0f,0x00,0xc0,             // SLDT AX
        0x8c,0xdb,                   // MOV BX,DS
        0x8c,0xc1,                   // MOV CX,ES
        0xf4                         // HLT
    };
    for (bool wait:{false,true}) for (const auto& test:null_task_selectors) {
        Bench b;
        setup_incoming_ldtr(b,wait,test.ldtr);
        set_incoming_segments(b,test.es,0x0030,0x0028,test.ds);
        b.put(kHandlerBase+0x0300,
              {noerror_task_program[0],noerror_task_program[1],noerror_task_program[2],
               noerror_task_program[3],noerror_task_program[4],noerror_task_program[5],
               noerror_task_program[6],noerror_task_program[7]});
        unsigned software_task_entries=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==0x30) ++software_task_entries;
        }
        check(software_task_entries==1 && !b.d.fault_o && b.d.halted_o &&
              b.cs()==0x0030 && b.d.ip_o==0x0308 &&
              b.reg(0)==test.ldtr && b.reg(3)==test.ds && b.reg(1)==test.es,
              "no-error software task gate did not preserve the null selectors and reach HLT");
        std::vector<uint32_t> incoming_task_fetches;
        for (uint32_t address:b.accepted)
            if (address>=kHandlerBase+0x0300 && address<kHandlerBase+0x0308)
                incoming_task_fetches.push_back(address);
        check(incoming_task_fetches.size()==sizeof(noerror_task_program),
              "no-error task gate did not fetch every incoming instruction byte");
        for (unsigned i=0;i<sizeof(noerror_task_program);++i)
            check(incoming_task_fetches[i]==kHandlerBase+0x0300+i,
                  "no-error task gate fetched a task instruction out of order");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return !t.write && !t.io && t.address>=kGdtBase && t.address<kGdtBase+8;
              }),
              "null LDTR/DS/ES selector caused a GDT null-descriptor read");
        check(!b.d.event_packet_error_valid_o && b.reg(4)==0x0080 &&
              uint16_t(b.memory[incoming_tss1_base] |
                       (uint16_t(b.memory[incoming_tss1_base+1])<<8))==0x0058 &&
              b.memory[kGdtBase+0x55]==0x83 && b.memory[kGdtBase+0x65]==0x81,
              "no-error task gate pushed an error or missed backlink/busy updates");
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                  return t.write && t.address>=kStackBase && t.address<kStackBase+0x0080;
              }),
              "no-error task gate wrote an exception word on the incoming stack");
        ++noerror_task_gate_cases;
    }
    check(noerror_task_gate_cases==8,
          "no-error task-gate/null-selector matrix missed a READY mode or RPL variant");
    std::cout<<"PASS: 8 no-error task-gate entries load all four null-selector RPL values into LDTR/DS/ES and reach the exact HLT successor in both READY modes\n";

    constexpr uint32_t incoming_ldt_base=0x00007000;
    auto put_incoming_descriptor=[](Bench& b,uint32_t address,uint16_t limit,
                                    uint32_t base,uint8_t access) {
        b.put(address,{uint8_t(limit),uint8_t(limit>>8),uint8_t(base),
                       uint8_t(base>>8),uint8_t(base>>16),access,0,0});
    };
    const uint8_t ldt_privilege_task_program[]={
        0x0f,0x00,0xc0,             // SLDT AX
        0x8c,0xdb,                   // MOV BX,DS
        0x8c,0xc1,                   // MOV CX,ES
        0x90                         // NOP; stop at its exact successor, including CPL1/2.
    };
    unsigned valid_ldt_task_cases=0;
    for (bool wait:{false,true}) for (unsigned cpl=0;cpl<=2;++cpl)
      for (unsigned ds_dpl=cpl;ds_dpl<=3;++ds_dpl)
        for (unsigned es_dpl=cpl;es_dpl<=3;++es_dpl)
          for (unsigned ds_rpl=0;ds_rpl<=ds_dpl;++ds_rpl)
            for (unsigned es_rpl=0;es_rpl<=es_dpl;++es_rpl) {
            Bench b;
            const uint16_t es_selector=uint16_t(0x0024|es_rpl);
            const uint16_t cs_selector=uint16_t(0x000c|cpl);
            const uint16_t ss_selector=uint16_t(0x0014|cpl);
            const uint16_t ds_selector=uint16_t(0x001c|ds_rpl);
            const uint8_t code_access=uint8_t(0x9a|(cpl<<5));
            const uint8_t stack_access=uint8_t(0x92|(cpl<<5));
            const uint8_t ds_access=uint8_t(0x92|(ds_dpl<<5));
            const uint8_t es_access=uint8_t(0x92|(es_dpl<<5));
            setup_incoming_ldtr(b,wait,0x0078);
            set_incoming_segments(b,es_selector,cs_selector,ss_selector,ds_selector);
            put_incoming_descriptor(b,kGdtBase+0x78,0x0027,incoming_ldt_base,0x82);
            put_incoming_descriptor(b,incoming_ldt_base+0x08,0x03ff,kHandlerBase,code_access);
            put_incoming_descriptor(b,incoming_ldt_base+0x10,0x00ff,kStackBase,stack_access);
            put_incoming_descriptor(b,incoming_ldt_base+0x18,0xffff,kWideDataBase,ds_access);
            put_incoming_descriptor(b,incoming_ldt_base+0x20,0xffff,kEsDataBase,es_access);
            b.put(kHandlerBase+0x0300,
                  {ldt_privilege_task_program[0],ldt_privilege_task_program[1],
                   ldt_privilege_task_program[2],ldt_privilege_task_program[3],
                   ldt_privilege_task_program[4],ldt_privilege_task_program[5],
                   ldt_privilege_task_program[6],ldt_privilege_task_program[7]});
            b.data_transfers.clear(); b.accepted.clear();
            const unsigned retired_before=b.retired;
            unsigned software_task_entries=0;
            for (unsigned cycle=0;cycle<150000 && !b.d.fault_o &&
                 !(b.cs()==cs_selector && b.d.ip_o==0x0308);++cycle) {
                b.tick(wait);
                if (b.d.event_o && b.d.event_vector_o==0x30) ++software_task_entries;
            }
            const bool ldt_task_progress_ok=software_task_entries==1 && !b.d.fault_o &&
                  !b.d.halted_o && b.cs()==cs_selector && b.d.ip_o==0x0308 &&
                  b.retired>retired_before && b.reg(0)==0x0078 &&
                  b.reg(3)==ds_selector && b.reg(1)==es_selector;
            if (!ldt_task_progress_ok)
                std::cerr<<"incoming-LDT progress CPL/DS-DPL/DS-RPL/ES-DPL/ES-RPL="
                         <<cpl<<"/"<<ds_dpl<<"/"<<ds_rpl<<"/"<<es_dpl<<"/"<<es_rpl
                         <<" events="<<software_task_entries<<" fault/halt="
                         <<unsigned(b.d.fault_o)<<"/"<<unsigned(b.d.halted_o)<<" cs:ip="
                         <<std::hex<<b.cs()<<":"<<b.d.ip_o<<" regs="<<b.reg(0)<<":"
                         <<b.reg(3)<<":"<<b.reg(1)<<std::dec<<" retired="<<b.retired
                         <<" before="<<retired_before<<'\n';
            check(ldt_task_progress_ok,
                  "valid non-null incoming LDT privilege case missed its exact task successor/selectors");
            check(uint16_t(b.d.segs_o)==es_selector &&
                  uint16_t(b.d.segs_o>>16)==cs_selector &&
                  uint16_t(b.d.segs_o>>32)==ss_selector &&
                  uint16_t(b.d.segs_o>>48)==ds_selector &&
                  b.cache_base(0)==kEsDataBase && b.cache_base(1)==kHandlerBase &&
                  b.cache_base(2)==kStackBase && b.cache_base(3)==kWideDataBase &&
                  b.d.seg_valid_o==0x0f && !b.d.event_packet_error_valid_o && b.reg(4)==0x0080,
                  "valid non-null incoming LDT privilege case published the wrong segment caches");
            std::vector<uint32_t> incoming_task_fetches;
            for (uint32_t address:b.accepted)
                if (address>=kHandlerBase+0x0300 && address<kHandlerBase+0x0308)
                    incoming_task_fetches.push_back(address);
            check(incoming_task_fetches.size()>=sizeof(ldt_privilege_task_program),
                  "valid non-null incoming LDT privilege case missed instruction fetches");
            for (unsigned i=0;i<sizeof(ldt_privilege_task_program);++i)
                check(incoming_task_fetches[i]==kHandlerBase+0x0300+i,
                      "incoming LDT privilege case fetched a task instruction out of order");
            std::vector<uint32_t> ldt_descriptor_reads;
            for (const auto& transfer:b.data_transfers)
                if (!transfer.write && !transfer.io && transfer.address>=incoming_ldt_base+8 &&
                    transfer.address<incoming_ldt_base+0x28)
                    ldt_descriptor_reads.push_back(transfer.address);
            check(ldt_descriptor_reads.size()==32,
                  "valid incoming task did not read all four descriptors through the loaded LDT");
            const uint32_t incoming_ldt_read_offsets[]={0x10,0x08,0x18,0x20};
            for (unsigned descriptor=0;descriptor<4;++descriptor)
                for (unsigned byte=0;byte<8;++byte)
                    check(ldt_descriptor_reads[descriptor*8+byte]==
                          incoming_ldt_base+incoming_ldt_read_offsets[descriptor]+byte,
                          "incoming LDT descriptor read used the wrong base or SS/CS/DS/ES order");
            const std::pair<uint32_t,uint8_t> ldt_access_writes[]={
                {incoming_ldt_base+0x15,uint8_t(stack_access|0x01)},
                {incoming_ldt_base+0x0d,uint8_t(code_access|0x01)},
                {incoming_ldt_base+0x1d,uint8_t(ds_access|0x01)},
                {incoming_ldt_base+0x25,uint8_t(es_access|0x01)}
            };
            std::vector<std::pair<uint32_t,uint8_t>> actual_ldt_access_writes;
            for (const auto& transfer:b.data_transfers)
                if (transfer.write && !transfer.io && transfer.address>=incoming_ldt_base &&
                    transfer.address<incoming_ldt_base+0x28)
                    actual_ldt_access_writes.emplace_back(transfer.address,transfer.value);
            check(actual_ldt_access_writes.size()==std::size(ldt_access_writes),
                  "incoming LDT segment loads did not write exactly four accessed bytes");
            for (unsigned i=0;i<std::size(ldt_access_writes);++i)
                check(actual_ldt_access_writes[i]==ldt_access_writes[i],
                      "incoming LDT privilege case wrote the wrong accessed byte");
            check(uint16_t(b.memory[incoming_tss1_base] |
                           (uint16_t(b.memory[incoming_tss1_base+1])<<8))==0x0058 &&
                  b.memory[kGdtBase+0x55]==0x83 && b.memory[kGdtBase+0x65]==0x81,
                  "valid non-null task gate missed backlink/busy updates");
            ++valid_ldt_task_cases;
        }
    check(valid_ldt_task_cases==460,
          "valid non-null LDTR privilege matrix missed a CPL/DPL/RPL/READY combination");
    std::cout<<"PASS: 460 valid non-null incoming-LDT task entries cover CPL0-2, CS/SS DPL=CPL and every DS/ES DPL/RPL pair satisfying max(CPL,RPL)<=DPL through limit 0027, checking exact successors/caches/accessed bytes in both READY modes\n";

    struct IncomingLdtLimitCase {
        const char* name;
        uint8_t vector;
        uint16_t es,cs,ss,ds;
        unsigned preceding_descriptors;
    };
    const IncomingLdtLimitCase incoming_ldt_limit_faults[]={
        {"CS beyond LDT limit",10,0x0024,0x003c,0x0014,0x001c,1},
        {"SS beyond LDT limit",12,0x0024,0x000c,0x003c,0x001c,0},
        {"DS beyond LDT limit",13,0x0024,0x000c,0x0014,0x003c,2},
        {"ES beyond LDT limit",13,0x003c,0x000c,0x0014,0x001c,3}
    };
    constexpr uint16_t incoming_ldt_out_of_limit_error=0x003c;
    unsigned incoming_ldt_limit_fault_cases=0;
    const uint32_t ldt_descriptor_offsets[]={0x15,0x0d,0x1d,0x25};
    const uint8_t ldt_descriptor_accessed[]={0x93,0x9b,0x93,0x93};
    for (bool wait:{false,true}) for (const auto& test:incoming_ldt_limit_faults) {
        Bench b;
        setup_incoming_ldtr(b,wait,0x0078);
        set_incoming_segments(b,test.es,test.cs,test.ss,test.ds);
        put_incoming_descriptor(b,kGdtBase+0x78,0x0027,incoming_ldt_base,0x82);
        put_incoming_descriptor(b,incoming_ldt_base+0x08,0x03ff,kHandlerBase,0x9a);
        put_incoming_descriptor(b,incoming_ldt_base+0x10,0x00ff,kStackBase,0x92);
        put_incoming_descriptor(b,incoming_ldt_base+0x18,0xffff,kWideDataBase,0x92);
        put_incoming_descriptor(b,incoming_ldt_base+0x20,0xffff,kEsDataBase,0x92);
        b.data_transfers.clear();
        unsigned expected_task_entries=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==test.vector) ++expected_task_entries;
        }
        check(expected_task_entries==1 && !b.d.fault_o && b.d.halted_o &&
              b.cs()==0x0030 && b.d.ip_o==0x0401,
              (std::string("incoming LDT ")+test.name+
               " did not deliver its Table 8-1 exception through the task gate").c_str());
        const bool incoming_ldt_packet_ok=b.d.event_packet_protected_o &&
              b.d.event_packet_restartable_o &&
              b.d.event_packet_error_valid_o && b.d.event_vector_o==test.vector &&
              b.d.event_packet_error_code_o==incoming_ldt_out_of_limit_error &&
              b.d.event_packet_saved_cs_o==test.cs &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080;
        if (!incoming_ldt_packet_ok)
            std::cerr<<"incoming-LDT packet "<<test.name<<" protected/restart/error="
                     <<unsigned(b.d.event_packet_protected_o)<<"/"
                     <<unsigned(b.d.event_packet_restartable_o)<<"/"
                     <<unsigned(b.d.event_packet_error_valid_o)<<" vector/error="
                     <<unsigned(b.d.event_vector_o)<<"/"<<std::hex
                     <<b.d.event_packet_error_code_o<<" saved="
                     <<b.d.event_packet_saved_cs_o<<":"<<b.d.event_packet_saved_ip_o
                     <<" flags/sp="<<b.d.event_packet_saved_flags_o<<"/"
                     <<b.d.event_packet_saved_sp_o<<std::dec<<" expected="
                     <<unsigned(test.vector)<<"/"<<std::hex
                     <<incoming_ldt_out_of_limit_error<<" saved="<<test.cs<<":0300 flags/sp=4202/0080"
                     <<std::dec<<'\n';
        check(incoming_ldt_packet_ok,
              (std::string("incoming LDT ")+test.name+
               " produced the wrong transferred-task exception packet").c_str());
        const uint16_t saved_task1[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,test.es,test.cs,test.ss,test.ds,0x0078
        };
        for (unsigned i=0;i<std::size(saved_task1);++i) {
            const uint16_t actual=uint16_t(b.memory[incoming_tss1_base+0x000e + 2*i] |
                (uint16_t(b.memory[incoming_tss1_base+0x000f + 2*i])<<8));
            check(actual==saved_task1[i],
                  (std::string("incoming LDT ")+test.name+
                   " failed to save the exact transferred-task TSS image").c_str());
        }
        check(uint16_t(b.memory[incoming_tss2_base] |
                       (uint16_t(b.memory[incoming_tss2_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x55]==0x83 && b.memory[kGdtBase+0x65]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==
                  incoming_ldt_out_of_limit_error,
              (std::string("incoming LDT ")+test.name+
               " missed backlink, task busy state, or the exact error push").c_str());
        std::vector<uint32_t> ldt_fault_descriptor_reads;
        for (const auto& transfer:b.data_transfers)
            if (!transfer.write && !transfer.io &&
                transfer.address>=incoming_ldt_base+8 && transfer.address<incoming_ldt_base+0x40)
                ldt_fault_descriptor_reads.push_back(transfer.address);
        check(ldt_fault_descriptor_reads.size()==test.preceding_descriptors*8,
              (std::string("incoming LDT ")+test.name+
               " read beyond the selector's descriptor limit").c_str());
        for (unsigned descriptor=0;descriptor<test.preceding_descriptors;++descriptor)
            for (unsigned byte=0;byte<8;++byte)
                check(ldt_fault_descriptor_reads[descriptor*8+byte]==
                      incoming_ldt_base+ldt_descriptor_offsets[descriptor]-5+byte,
                      (std::string("incoming LDT ")+test.name+
                       " read prior descriptors out of order").c_str());
        check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& transfer) {
                  return !transfer.write && !transfer.io &&
                         transfer.address>=incoming_ldt_base+0x38 &&
                         transfer.address<incoming_ldt_base+0x40;
              }),
              (std::string("incoming LDT ")+test.name+
               " issued a descriptor read beyond limit 0027").c_str());
        std::vector<std::pair<uint32_t,uint8_t>> ldt_fault_access_writes;
        for (const auto& transfer:b.data_transfers)
            if (transfer.write && !transfer.io &&
                transfer.address>=incoming_ldt_base && transfer.address<incoming_ldt_base+0x28)
                ldt_fault_access_writes.emplace_back(transfer.address,transfer.value);
        check(ldt_fault_access_writes.size()==test.preceding_descriptors,
              (std::string("incoming LDT ")+test.name+
               " wrote an accessed byte for the rejected descriptor").c_str());
        for (unsigned i=0;i<test.preceding_descriptors;++i)
            check(ldt_fault_access_writes[i]==std::make_pair(
                      incoming_ldt_base+ldt_descriptor_offsets[i],ldt_descriptor_accessed[i]),
                  (std::string("incoming LDT ")+test.name+
                   " changed the wrong prior descriptor accessed byte").c_str());
        ++incoming_ldt_limit_fault_cases;
    }
    check(incoming_ldt_limit_fault_cases==8,
          "incoming LDT limit matrix missed a segment type or READY policy");
    std::cout<<"PASS: 8 incoming-LDT limit faults check #TS(CS), #SS(SS), #GP(DS/ES), exact task state and no descriptor read past limit 0027 in both READY modes\n";

    struct IncomingSegmentFaultCase {
        const char* name;
        uint8_t vector;
        uint16_t error,es,cs,ss,ds;
        uint16_t access_offset;
        uint8_t access_value;
    };
    const IncomingSegmentFaultCase incoming_segment_faults[]={
        {"CS null",10,0x0000,0x0020,0x0000,0x0028,0x0010,0,0},
        {"CS wrong data type",10,0x0010,0x0020,0x0010,0x0028,0x0010,0,0},
        {"CS not-present",11,0x0008,0x0020,0x0008,0x0028,0x0010,0x000d,0x1a},
        {"CS DPL/RPL mismatch",10,0x0038,0x0020,0x0038,0x0028,0x0010,0,0},
        {"CS GDT limit",10,0x0188,0x0020,0x0188,0x0028,0x0010,0,0},
        {"SS null",12,0x0000,0x0020,0x0030,0x0000,0x0010,0,0},
        {"SS GDT limit",12,0x0188,0x0020,0x0030,0x0188,0x0010,0,0},
        {"SS code type",13,0x0008,0x0020,0x0030,0x0008,0x0010,0,0},
        {"SS read-only data",13,0x0010,0x0020,0x0030,0x0010,0x0010,0x0015,0x90},
        {"SS not-present",12,0x0010,0x0020,0x0030,0x0010,0x0010,0x0015,0x12},
        {"SS privilege mismatch",12,0x0040,0x0020,0x0030,0x0040,0x0010,0,0},
        {"SS selector RPL mismatch",12,0x0028,0x0020,0x0030,0x002b,0x0010,0,0},
        {"DS TI with null LDTR",13,0x005c,0x0020,0x0030,0x0028,0x005c,0,0},
        {"DS GDT limit",13,0x0188,0x0020,0x0030,0x0028,0x0188,0,0},
        {"DS system descriptor",13,0x0050,0x0020,0x0030,0x0028,0x0050,0,0},
        {"DS not-present",11,0x0010,0x0020,0x0030,0x0028,0x0010,0x0015,0x12},
        {"DS privilege mismatch",13,0x0010,0x0020,0x0030,0x0028,0x0013,0,0},
        {"DS execute-only code",13,0x0030,0x0020,0x0030,0x0028,0x0030,0x0035,0x98},
        {"ES GDT limit",13,0x0188,0x0188,0x0030,0x0028,0x0010,0,0},
        {"ES not-present",11,0x0020,0x0020,0x0030,0x0028,0x0010,0x0025,0x12},
        {"ES privilege mismatch",13,0x0020,0x0023,0x0030,0x0028,0x0010,0,0},
        {"ES system descriptor",13,0x0050,0x0050,0x0030,0x0028,0x0010,0,0},
        {"ES execute-only code",13,0x0030,0x0030,0x0030,0x0028,0x0010,0x0035,0x98},
        {"SS fault precedes CS",12,0x0188,0x0020,0x0010,0x0188,0x0010,0,0},
        {"SS fault precedes DS",12,0x0188,0x0020,0x0030,0x0188,0x0050,0,0},
        {"DS fault precedes ES",13,0x0050,0x0020,0x0030,0x0028,0x0050,0x0025,0x12}
    };
    unsigned incoming_segment_fault_cases=0;
    for (bool wait:{false,true}) for (const auto& test:incoming_segment_faults) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,test.es,test.cs,test.ss,test.ds);
        if (test.access_offset)
            b.memory[kGdtBase+test.access_offset]=test.access_value;
        unsigned expected_task_entries=0;
        for (unsigned cycle=0;cycle<150000 && !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==test.vector) ++expected_task_entries;
        }
        if (expected_task_entries!=1 || b.d.fault_o || !b.d.halted_o ||
            b.cs()!=0x0030 || b.d.ip_o!=0x0401)
            std::cerr<<"incoming-segment delivery failure "<<test.name
                     <<" entries="<<expected_task_entries
                     <<" fault="<<unsigned(b.d.fault_o)
                     <<" code="<<unsigned(b.d.fault_code_o)
                     <<" halted="<<unsigned(b.d.halted_o)<<" cs:ip="<<std::hex
                     <<b.cs()<<":"<<b.d.ip_o<<" vector="<<unsigned(b.d.event_vector_o)
                     <<" error="<<b.d.event_packet_error_code_o<<std::dec<<'\n';
        check(expected_task_entries==1 && !b.d.fault_o && b.d.halted_o &&
              b.cs()==0x0030 && b.d.ip_o==0x0401,
              (std::string("incoming segment ")+test.name+
               " did not deliver its expected exception through the task gate").c_str());
        const bool incoming_segment_packet_ok=b.d.event_packet_restartable_o &&
              b.d.event_packet_error_valid_o &&
              b.d.event_vector_o==test.vector &&
              b.d.event_packet_error_code_o==test.error &&
              b.d.event_packet_saved_cs_o==test.cs &&
              b.d.event_packet_saved_ip_o==0x0300 &&
              b.d.event_packet_saved_flags_o==0x4202 &&
              b.d.event_packet_saved_sp_o==0x0080;
        if (!incoming_segment_packet_ok)
            std::cerr<<"incoming-segment packet failure "<<test.name<<" valid/protected/restart/error="
                     <<unsigned(b.d.event_packet_valid_o)<<"/"<<unsigned(b.d.event_packet_protected_o)
                     <<"/"<<unsigned(b.d.event_packet_restartable_o)<<"/"
                     <<unsigned(b.d.event_packet_error_valid_o)<<" vector/error="
                     <<unsigned(b.d.event_vector_o)<<"/"<<std::hex
                     <<b.d.event_packet_error_code_o<<" saved="
                     <<b.d.event_packet_saved_cs_o<<":"<<b.d.event_packet_saved_ip_o
                     <<" flags/sp="<<b.d.event_packet_saved_flags_o<<"/"
                     <<b.d.event_packet_saved_sp_o<<std::dec<<'\n';
        check(incoming_segment_packet_ok && b.d.event_packet_protected_o,
              (std::string("incoming segment ")+test.name+
               " produced the wrong transferred-task exception packet").c_str());
        const uint16_t saved_task1[]={
            0x0300,0x4202,0xa001,0xc003,0xd004,0xb005,0x0080,
            0xb007,0x5108,0xd109,test.es,test.cs,test.ss,test.ds,0x0000
        };
        for (unsigned i=0;i<15;++i) {
            const uint16_t actual=uint16_t(b.memory[incoming_tss1_base+0x000e + 2*i] |
                               (uint16_t(b.memory[incoming_tss1_base+0x000f + 2*i])<<8));
            if (actual!=saved_task1[i])
                std::cerr<<"incoming-segment TSS mismatch "<<test.name<<" word="<<i
                         <<" actual/expected="<<std::hex<<actual<<"/"<<saved_task1[i]
                         <<std::dec<<'\n';
            check(actual==saved_task1[i],
                  (std::string("incoming segment ")+test.name+
                   " did not save all 15 words of the transferred TSS").c_str());
        }
        check(uint16_t(b.memory[incoming_tss2_base] |
                       (uint16_t(b.memory[incoming_tss2_base+1])<<8))==0x0050 &&
              b.memory[kGdtBase+0x55]==0x83 && b.memory[kGdtBase+0x65]==0x83 &&
              uint16_t(b.memory[kStackBase+0x7e] |
                       (uint16_t(b.memory[kStackBase+0x7f])<<8))==test.error,
              (std::string("incoming segment ")+test.name+
               " did not write backlink, busy state, and the error word").c_str());
        if (test.cs==0x0188 || test.ss==0x0188 || test.ds==0x0188 ||
            test.es==0x0188)
            check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[](const auto& t) {
                      return !t.write && !t.io && t.address>=kGdtBase+0x0188 &&
                             t.address<kGdtBase+0x0190;
                  }),
                  (std::string("incoming segment ")+test.name+
                   " attempted a descriptor read beyond the GDT limit").c_str());
        ++incoming_segment_fault_cases;
    }
    check(incoming_segment_fault_cases==52,
          "incoming-segment fault matrix missed a READY policy or architectural case");
    std::cout<<"PASS: 52 invalid incoming CS/SS/DS/ES executions deliver Table 8-1 exceptions in architectural priority order through task gates in both READY modes\n";
    // Intel 210498-005 p.8-6 notes that task registers are loaded before
    // incoming segment checks. A fault handler therefore runs in the new
    // task context: validated SS must supply its stack cache, while the
    // rejected DS selector must not retain the outgoing task's usable cache.
    unsigned incoming_fault_context_cases=0;
    for (bool wait:{false,true}) {
        Bench b;
        setup_incoming_ldtr(b,wait,0);
        set_incoming_segments(b,0x0020,0x0030,0x0028,0x0050);
        b.put(kIdtBase+13*8,{0x00,0x04,0x30,0x00,0x00,0x86,0x00,0x00});
        b.put(kHandlerBase+0x0400,{0xa1,0x00,0x00,0xf4}); // MOV AX,DS:[0000]; HLT.
        const uint32_t incoming_stack_base=kStackBase;
        const uint32_t outgoing_stack_base=b.cache_base(2);
        const uint32_t outgoing_ds_base=b.cache_base(3);
        check(incoming_stack_base!=outgoing_stack_base,
              "task-fault fixture must distinguish incoming and outgoing SS bases");
        b.data_transfers.clear();
        unsigned gp_events=0;
        bool handler_fault_packet_ok=false;
        std::size_t handler_transfer_start=0;
        for (unsigned cycle=0;cycle<150000 && gp_events<2 &&
             !b.d.halted_o && !b.d.fault_o;++cycle) {
            b.tick(wait);
            if (b.d.event_o && b.d.event_vector_o==13) {
                ++gp_events;
                if (gp_events==1) {
                    handler_fault_packet_ok=b.d.event_packet_error_valid_o &&
                        b.d.event_packet_error_code_o==0x0050 &&
                        b.d.event_packet_saved_cs_o==0x0030 &&
                        b.d.event_packet_saved_ip_o==0x0300 &&
                        b.d.event_packet_saved_sp_o==0x0080;
                    handler_transfer_start=b.data_transfers.size();
                }
            }
        }
        auto read_word=[&](uint32_t address) {
            return uint16_t(b.memory[address] |
                            (uint16_t(b.memory[address+1])<<8));
        };
        const bool incoming_frame=read_word(incoming_stack_base+0x78)==0x0050 &&
            read_word(incoming_stack_base+0x7a)==0x0300 &&
            read_word(incoming_stack_base+0x7c)==0x0030 &&
            read_word(incoming_stack_base+0x7e)==0x4202;
        const bool used_outgoing_stack=std::any_of(
            b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                return t.write && !t.io && t.address>=outgoing_stack_base+0x70 &&
                       t.address<outgoing_stack_base+0x80;
            });
        const bool read_through_outgoing_ds=handler_transfer_start<=b.data_transfers.size() &&
            std::any_of(b.data_transfers.begin()+handler_transfer_start,
                        b.data_transfers.end(),[&](const auto& t) {
                return !t.write && !t.io && t.address==outgoing_ds_base;
            });
        if (gp_events<2 || !incoming_frame || used_outgoing_stack ||
            read_through_outgoing_ds || b.d.fault_o || b.d.halted_o)
            std::cerr<<"incoming task fault context wait="<<wait
                     <<" #GP events="<<gp_events
                     <<" frame="<<std::hex<<read_word(incoming_stack_base+0x78)<<'/'
                     <<read_word(incoming_stack_base+0x7a)<<'/'
                     <<read_word(incoming_stack_base+0x7c)<<'/'
                     <<read_word(incoming_stack_base+0x7e)<<std::dec
                     <<" old-stack-write="<<used_outgoing_stack
                     <<" old-DS-read="<<read_through_outgoing_ds
                     <<" fault="<<unsigned(b.d.fault_o)
                     <<" halted="<<unsigned(b.d.halted_o)<<'\n';
        check(handler_fault_packet_ok && incoming_frame && !used_outgoing_stack &&
              gp_events==2 && !read_through_outgoing_ds &&
              !b.d.fault_o && !b.d.halted_o,
              "incoming-task #GP did not use validated incoming SS and reject the failed DS cache");
        ++incoming_fault_context_cases;
    }
    check(incoming_fault_context_cases==2,
          "incoming task fault-context cache test missed a READY policy");
    std::cout<<"PASS: incoming-task #GP handlers use the validated incoming SS cache and cannot access through the rejected DS cache in both READY modes\n";
    // The 286's protected-mode privileged system instructions fault at every
    // nonzero CPL, independently of IOPL. Memory forms must fault before an
    // operand read can alter a table register or MSW.
    struct PrivSystemCase {
        const char* name;
        std::vector<uint8_t> bytes;
        unsigned operand_bytes;
    };
    const PrivSystemCase privileged_system_cases[]={
        {"CLTS",{0x0f,0x06},0},
        {"LMSW AX",{0x0f,0x01,0xf0},0},
        {"LMSW memory",{0x0f,0x01,0x36,0x10,0x00},2},
        {"LGDT memory",{0x0f,0x01,0x16,0x10,0x00},6},
        {"LIDT memory",{0x0f,0x01,0x1e,0x10,0x00},6}
    };
    unsigned privileged_system_runs=0;
    for (bool wait:{false,true}) for (unsigned cpl=1;cpl<4;++cpl)
      for (unsigned iopl=0;iopl<4;++iopl) for (const auto& test:privileged_system_cases) {
        const uint16_t data_selector=levels[cpl].ss|uint16_t(cpl);
        std::vector<uint8_t> program={0xb8,uint8_t(data_selector),uint8_t(data_selector>>8),
                                      0x8e,0xd8}; // MOV AX,SS selector; MOV DS,AX.
        program.insert(program.end(),test.bytes.begin(),test.bytes.end());
        program.push_back(0xf4); // If wrongly allowed, CPL>0 HLT faults at the wrong saved IP.
        Bench b;
        const Context context=prepare(b,wait,cpl,iopl,program);
        const uint32_t operand_address=context.level.stack_base+0x0010;
        const uint8_t operand_image[]={0x0e,0x00,0x34,0x12,0x00,0x00};
        for (unsigned i=0;i<test.operand_bytes;++i)
            b.memory[operand_address+i]=operand_image[i];
        b.step(context.level.code_base+0x0400,0xb8,context.level.cs|uint16_t(cpl),0x0403,wait);
        b.step(context.level.code_base+0x0403,0x8e,context.level.cs|uint16_t(cpl),0x0405,wait);
        const uint16_t fault_ip=0x0405;
        const uint16_t expected_cs=context.level.cs|uint16_t(cpl);
        const uint16_t msw_before=b.d.msw_o;
        const unsigned retired_before=b.retired;
        b.data_transfers.clear();
        bool event_seen=false,handler_entered=false;
        for (unsigned cycle=0;cycle<50000 && !b.d.fault_o;++cycle) {
            b.tick(wait);
            event_seen=event_seen||b.d.event_o;
            if (event_seen && b.cs()==kHandlerSelector && b.d.ip_o==kHandlerIp) {
                handler_entered=true; break;
            }
        }
        check(handler_entered && !b.d.fault_o && b.d.event_packet_valid_o &&
              b.d.event_packet_protected_o && b.d.event_packet_error_valid_o &&
              b.d.event_packet_restartable_o && b.d.event_vector_o==13 &&
              b.d.event_packet_error_code_o==0 &&
              b.d.event_packet_saved_cs_o==expected_cs &&
              b.d.event_packet_saved_ip_o==fault_ip &&
              b.d.event_packet_saved_flags_o==context.flags &&
              b.d.event_packet_saved_sp_o==context.sp &&
              b.retired==retired_before && b.reg(0)==data_selector &&
              b.d.msw_o==msw_before,
              (std::string("CPL ")+std::to_string(cpl)+" "+test.name+
               " did not raise restartable #GP(0) before changing CPU state").c_str());
        if (test.operand_bytes) {
            check(std::none_of(b.data_transfers.begin(),b.data_transfers.end(),[&](const auto& t) {
                      return !t.write && !t.io && t.address>=operand_address &&
                             t.address<operand_address+test.operand_bytes;
                  }),
                  (std::string("CPL ")+std::to_string(cpl)+" "+test.name+
                   " read its memory operand before #GP(0)").c_str());
        }
        ++privileged_system_runs;
      }
    check(privileged_system_runs==120,
          "protected system privilege matrix missed an instruction/CPL/IOPL/READY case");

    unsigned ring0_system_runs=0;
    for (bool wait:{false,true}) for (unsigned iopl=0;iopl<4;++iopl)
      for (const auto& test:privileged_system_cases) {
        const uint16_t data_selector=levels[0].ss;
        std::vector<uint8_t> program={0xb8,uint8_t(data_selector),uint8_t(data_selector>>8),
                                      0x8e,0xd8};
        program.insert(program.end(),test.bytes.begin(),test.bytes.end());
        program.push_back(0xf4);
        Bench b;
        const Context context=prepare(b,wait,0,iopl,program);
        const uint32_t operand_address=context.level.stack_base+0x0010;
        const uint8_t operand_image[]={0x0e,0x00,0x34,0x12,0x00,0x00};
        for (unsigned i=0;i<test.operand_bytes;++i)
            b.memory[operand_address+i]=operand_image[i];
        b.step(context.level.code_base+0x0400,0xb8,context.level.cs,0x0403,wait);
        b.step(context.level.code_base+0x0403,0x8e,context.level.cs,0x0405,wait);
        const uint16_t system_ip=0x0405;
        const uint16_t successor_ip=system_ip+uint16_t(test.bytes.size());
        const uint16_t msw_before=b.d.msw_o;
        b.data_transfers.clear();
        const unsigned retired_before=b.retired;
        b.step(context.level.code_base+system_ip,0x0f,context.level.cs,successor_ip,wait);
        check(!b.d.event_o && !b.d.fault_o && b.retired==retired_before+1 &&
              b.cs()==context.level.cs && b.d.ip_o==successor_ip,
              (std::string("CPL-0 ")+test.name+" was rejected or failed to retire").c_str());
        if (test.name==std::string("LMSW AX"))
            check((b.d.msw_o&0x0008)!=0,"CPL-0 LMSW AX failed to set TS");
        else if (test.name==std::string("LMSW memory"))
            check((b.d.msw_o&0x000e)==0x000e,"CPL-0 memory LMSW failed to set MP/EM/TS");
        else if (test.name==std::string("CLTS"))
            check((b.d.msw_o&0x0008)==0,"CPL-0 CLTS failed to clear TS");
        else check(b.d.msw_o==msw_before,"CPL-0 table load changed the MSW");
        if (test.operand_bytes) {
            check(b.data_transfers.size()==test.operand_bytes,
                  (std::string("CPL-0 ")+test.name+" read an incorrect operand width").c_str());
            for (unsigned i=0;i<test.operand_bytes;++i)
                check(!b.data_transfers[i].write && !b.data_transfers[i].io &&
                      b.data_transfers[i].address==operand_address+i &&
                      b.data_transfers[i].value==operand_image[i],
                      (std::string("CPL-0 ")+test.name+" read incorrect operand bytes").c_str());
        } else check(b.data_transfers.empty(),
                     (std::string("CPL-0 ")+test.name+" issued an unexpected data transfer").c_str());
        b.step(context.level.code_base+successor_ip,0xf4,context.level.cs,
               uint16_t(successor_ip+1),wait);
        check(b.d.halted_o && b.retired==retired_before+2,
              (std::string("CPL-0 ")+test.name+" missed its exact HLT successor").c_str());
        ++ring0_system_runs;
      }
    check(ring0_system_runs==40,
          "CPL-0 system instruction controls missed an opcode/IOPL/READY case");

    // POPF and IRET at CPL 0 can set IOPL; at CPL 3 both IOPL and IF changes are ignored
    // when IOPL is 0. IRET follows the same protected-mode flag restrictions.
    for (bool wait:{false,true}) {
        const std::vector<uint8_t> popf_program={0x9d,0xf4};
        Bench supervisor;
        const Context supervisor_context=prepare(supervisor,wait,0,0,popf_program);
        supervisor.memory[kStackBase+supervisor_context.sp]=0x02;
        supervisor.memory[kStackBase+supervisor_context.sp+1]=0x32; // IOPL=3, IF=1.
        supervisor.step(supervisor_context.level.code_base+0x0400,0x9d,
                        supervisor_context.level.cs,0x0401,wait);
        check(supervisor.d.flags_o==0x3202 && supervisor.reg(4)==supervisor_context.sp+2,
              "CPL-0 POPF failed to load IOPL/IF from its stack image");

        const std::vector<uint8_t> iret_program={0xcf,0xf4};
        Bench supervisor_iret;
        const Context supervisor_iret_context=prepare(supervisor_iret,wait,0,0,iret_program);
        const uint32_t supervisor_frame=kStackBase+supervisor_iret_context.sp;
        supervisor_iret.memory[supervisor_frame]=0x01;
        supervisor_iret.memory[supervisor_frame+1]=0x04;
        supervisor_iret.memory[supervisor_frame+2]=uint8_t(supervisor_iret_context.level.cs);
        supervisor_iret.memory[supervisor_frame+3]=uint8_t(supervisor_iret_context.level.cs>>8);
        supervisor_iret.memory[supervisor_frame+4]=0x02;
        supervisor_iret.memory[supervisor_frame+5]=0x32;
        supervisor_iret.step(supervisor_iret_context.level.code_base+0x0400,0xcf,
                             supervisor_iret_context.level.cs,0x0401,wait);
        check(supervisor_iret.d.flags_o==0x3202 &&
              supervisor_iret.reg(4)==supervisor_iret_context.sp+6,
              "CPL-0 IRET failed to load IOPL/IF from its frame");

        Bench application;
        const Context application_context=prepare(application,wait,3,0,popf_program,false);
        application.memory[application_context.level.stack_base+application_context.sp]=0x02;
        application.memory[application_context.level.stack_base+application_context.sp+1]=0x32;
        application.step(application_context.level.code_base+0x0400,0x9d,
                         application_context.level.cs|3,0x0401,wait);
        check((application.d.flags_o&0x3200)==0 &&
              application.reg(4)==application_context.sp+2,
              "restricted CPL-3 POPF changed IOPL or IF");

        Bench returner;
        const Context return_context=prepare(returner,wait,3,0,iret_program,false);
        const uint32_t frame=return_context.level.stack_base+return_context.sp;
        returner.memory[frame]=0x01; returner.memory[frame+1]=0x04;
        returner.memory[frame+2]=uint8_t(return_context.level.cs|3);
        returner.memory[frame+3]=uint8_t((return_context.level.cs|3)>>8);
        returner.memory[frame+4]=0x02; returner.memory[frame+5]=0x32;
        returner.step(return_context.level.code_base+0x0400,0xcf,
                      return_context.level.cs|3,0x0401,wait);
        check(returner.d.flags_o==0x0002 && returner.reg(4)==return_context.sp+6,
              "restricted CPL-3 IRET changed IOPL or IF from its stack image");
    }
    protected_shutdown_nmi_recovery();
    std::cout<<"PASS: 480 protected privilege scenarios including IN/OUT CPL/IOPL, REP INS/OUTS, CLI/STI, HLT, POPF/IRET, nonzero-CPL LGDT/LIDT/LMSW/CLTS faults and CPL-0 system-instruction controls in both READY modes\n";
}

static void processor_extension_contract() {
    // WAIT must hold retirement and the next fetch while BUSY is asserted high.
    Bench busy_wait;
    busy_wait.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
    busy_wait.put(0xf0100,{0x9b,0xf4});
    busy_wait.reset();
    busy_wait.step(0xfffff0,0xea,0xf000,0x0100,false);
    const unsigned retired_before=busy_wait.retired;
    busy_wait.d.busy_i=1;
    for (unsigned n=0;n<40;++n) busy_wait.tick(false);
    check(busy_wait.d.ip_o==0x0101 && !busy_wait.d.bus_req_o &&
          !busy_wait.d.retire_o && !busy_wait.d.event_o &&
          busy_wait.retired==retired_before &&
          !busy_wait.accepted.empty() && busy_wait.accepted.back()==0xf0100,
          "WAIT did not hold before the exact successor while BUSY was asserted");
    busy_wait.d.busy_i=0;
    for (unsigned n=0;n<8 && busy_wait.retired==retired_before;++n) busy_wait.tick(false);
    check(busy_wait.retired==retired_before+1 && busy_wait.d.retire_pc_o==0xf0100 &&
          busy_wait.d.retire_opcode_o==0x9b && busy_wait.d.ip_o==0x0101,
          "WAIT did not retire at its exact PC after BUSY went low");
    busy_wait.step(0xf0101,0xf4,0xf000,0x0102,false);

    // Event selection and BUSY deassertion can coincide. WAIT retires on
    // that edge; the selected event must survive BOUNDARY and precede the
    // exact successor fetch. Exercise both NMI and a delayed INTR acknowledge.
    for (bool maskable : {false, true}) {
        Bench race;
        interrupt_setup(race);
        const unsigned vector=maskable ? 0x20 : 2;
        const uint16_t handler=maskable ? 0x2000 : 0x2100;
        interrupt_vector(race,vector,handler);
        if (maskable) {
            race.put(0xf0109,{0xfb,0x9b,0x43,0xf4});
            race.step(0xf0109,0xfb,0xf000,0x010a,false);
        } else race.put(0xf0109,{0x9b,0x43,0xf4});
        const uint16_t successor=maskable ? 0x010b : 0x010a;
        race.d.busy_i=1;
        for (unsigned n=0;n<80 && race.d.ip_o!=successor;++n) race.tick(false);
        for (unsigned n=0;n<24;++n) race.tick(false);
        check(race.d.ip_o==successor && !race.d.bus_req_o && !race.d.retire_o,
              "WAIT event race setup did not reach a stalled WAIT");
        const auto retired=race.retired;
        race.d.busy_i=0;
        race.d.nmi_i=!maskable;
        race.d.intr_i=maskable;
        race.interrupt_vector=uint8_t(vector);
        race.tick(false);
        check(race.retired==retired+1 && race.d.retire_o &&
              race.d.retire_opcode_o==0x9b && race.d.ip_o==successor,
              "WAIT did not retire on the BUSY-release edge");
        if (maskable) {
            check(!race.d.inta_req_o,"WAIT claimed INTR before the retirement boundary");
            race.tick(false);
            check(race.d.inta_req_o && !race.d.bus_req_o,
                  "WAIT retirement boundary did not start INTR acknowledgement");
            race.tick(false);
            check(race.d.inta_req_o && !race.d.bus_req_o,
                  "WAIT race did not hold a delayed INTR acknowledgement");
            race.acknowledge=true;
        }
        interrupt_entry(race,vector,successor,maskable ? 0x0202 : 0x0002,handler);
        check(!maskable || race.acknowledgements==1,"WAIT race acknowledgement count");
        race.d.nmi_i=0; race.d.intr_i=0; race.acknowledge=false;
        race.step((uint32_t(handler)<<4)+0x100,0x43,handler,0x0101,false);
        race.step((uint32_t(handler)<<4)+0x101,0xcf,0xf000,successor,false);
        race.step(0xf0000+successor,0x43,0xf000,uint16_t(successor+1),false);
        check(race.reg(3)==2,"WAIT race lost, repeated, or skipped an instruction");
    }

    // Intel's 1983 iAPX 286/10 handbook says the processor may be interrupted
    // while waiting for BUSY to become inactive. ASSUMPTION A25: it saves the
    // already advanced IP after WAIT; the source does not state the saved IP.
    // Keep BUSY high through IRET so restarting WAIT cannot pass this check.
    {
        Bench nmi_wait;
        interrupt_setup(nmi_wait); interrupt_vector(nmi_wait,2,0x2100);
        nmi_wait.put(0xf0109,{0x9b,0x43,0xf4});
        const auto retired=nmi_wait.retired;
        nmi_wait.d.busy_i=1;
        for(unsigned n=0;n<64 && nmi_wait.d.ip_o!=0x010a;++n) nmi_wait.tick(false);
        for(unsigned n=0;n<24;++n) nmi_wait.tick(false);
        check(nmi_wait.d.ip_o==0x010a && !nmi_wait.d.bus_req_o &&
              !nmi_wait.d.retire_o && nmi_wait.retired==retired,
              "NMI/WAIT setup did not remain stalled after fetching WAIT");
        nmi_wait.d.nmi_i=1;
        interrupt_entry(nmi_wait,2,0x010a,0x0002,0x2100);
        check(nmi_wait.retired==retired && nmi_wait.d.nmi_blocked_o,
              "NMI while WAIT busy fabricated retirement or was not blocked in its handler");
        nmi_wait.d.nmi_i=0;
        nmi_wait.step(0x21100,0x43,0x2100,0x0101,false);
        nmi_wait.step(0x21101,0xcf,0xf000,0x010a,false);
        nmi_wait.step(0xf010a,0x43,0xf000,0x010b,false);
        check(nmi_wait.reg(3)==2,"NMI return restarted or skipped interrupted WAIT");
        nmi_wait.step(0xf010b,0xf4,0xf000,0x010c,false);
    }
    {
        Bench intr_wait;
        interrupt_setup(intr_wait); interrupt_vector(intr_wait,0x20);
        intr_wait.put(0xf0109,{0xfb,0x9b,0x43,0xf4});
        intr_wait.step(0xf0109,0xfb,0xf000,0x010a,false);
        intr_wait.d.busy_i=1;
        for(unsigned n=0;n<64 && intr_wait.accepted.back()!=0xf010a;++n) intr_wait.tick(false);
        for(unsigned n=0;n<24;++n) intr_wait.tick(false);
        check(intr_wait.d.ip_o==0x010b && !intr_wait.d.bus_req_o &&
              !intr_wait.d.retire_o,"INTR/WAIT setup did not remain stalled after WAIT");
        const auto retired=intr_wait.retired;
        intr_wait.d.intr_i=1; intr_wait.interrupt_vector=0x20; intr_wait.acknowledge=true;
        for(unsigned n=0;n<32 && !intr_wait.d.inta_req_o;++n) intr_wait.tick(false);
        check(intr_wait.d.inta_req_o,"INTR was not acknowledged while WAIT was busy");
        interrupt_entry(intr_wait,0x20,0x010b,0x0202);
        check(intr_wait.retired==retired && intr_wait.acknowledgements==1,
              "INTR while WAIT busy fabricated retirement or missed acknowledgement");
        intr_wait.d.intr_i=0; intr_wait.acknowledge=false;
        intr_wait.step(0x20100,0x43,0x2000,0x0101,false);
        intr_wait.step(0x20101,0xcf,0xf000,0x010b,false);
        intr_wait.step(0xf010b,0x43,0xf000,0x010c,false);
        check(intr_wait.reg(3)==2,"INTR return restarted or skipped interrupted WAIT");
        intr_wait.step(0xf010c,0xf4,0xf000,0x010d,false);
    }

    // EM without TS does not make WAIT raise vector 7 in Intel 80287 Table 4.
    Bench em_wait;
    em_wait.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
    em_wait.put(0xf0100,{0xb8,0x04,0x00,0x0f,0x01,0xf0,0x9b,0xf4});
    em_wait.reset();
    em_wait.step(0xfffff0,0xea,0xf000,0x0100,false);
    em_wait.step(0xf0100,0xb8,0xf000,0x0103,false);
    em_wait.step(0xf0103,0x0f,0xf000,0x0106,false);
    check((em_wait.d.msw_o&0x000c)==0x0004,"LMSW did not set EM without TS");
    em_wait.step(0xf0106,0x9b,0xf000,0x0107,false);
    check(!em_wait.d.event_o && !em_wait.d.fault_o,
          "EM alone caused WAIT to raise a processor-extension fault");

    // ESC raises vector 7 for EM or TS; WAIT raises it for TS. Assert BUSY
    // and ERROR# too, checking that these fault gates take priority.
    Bench em_escape;
    em_escape.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
    em_escape.put(0xf0100,{0xb8,0x04,0x00,0x0f,0x01,0xf0,0xd8,0xc0});
    em_escape.reset();
    em_escape.step(0xfffff0,0xea,0xf000,0x0100,false);
    em_escape.step(0xf0100,0xb8,0xf000,0x0103,false);
    em_escape.step(0xf0103,0x0f,0xf000,0x0106,false);
    em_escape.d.busy_i=1; em_escape.d.error_n_i=0;
    em_escape.processor_fault(7,0x0106,false);
    check(em_escape.d.event_packet_restartable_o &&
          !em_escape.d.event_packet_error_valid_o,
          "ESC #NM did not preserve the restartable no-error-code fault contract");

    Bench ts_wait;
    ts_wait.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
    ts_wait.put(0xf0100,{0xb8,0x08,0x00,0x0f,0x01,0xf0,0x9b});
    ts_wait.reset();
    ts_wait.step(0xfffff0,0xea,0xf000,0x0100,false);
    ts_wait.step(0xf0100,0xb8,0xf000,0x0103,false);
    ts_wait.step(0xf0103,0x0f,0xf000,0x0106,false);
    ts_wait.d.busy_i=1; ts_wait.d.error_n_i=0;
    ts_wait.processor_fault(7,0x0106,false);
    check(ts_wait.d.event_packet_restartable_o &&
          !ts_wait.d.event_packet_error_valid_o,
          "WAIT #NM did not preserve the restartable no-error-code fault contract");

    // An unmasked 80287 error is delivered as vector 16 by WAIT or ESC.
    Bench wait_error;
    wait_error.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
    wait_error.put(0xf0100,{0x9b});
    wait_error.reset();
    wait_error.step(0xfffff0,0xea,0xf000,0x0100,false);
    wait_error.d.error_n_i=0;
    wait_error.processor_fault(16,0x0100,false);
    check(wait_error.d.event_packet_restartable_o &&
          !wait_error.d.event_packet_error_valid_o,
          "WAIT #MF did not preserve the restartable no-error-code fault contract");

    // ERROR# may assert while the 80287 is still BUSY; WAIT reports it only
    // after BUSY deasserts, as shown by the Intel 80287 sheet's PDF page 20.
    Bench delayed_wait_error;
    delayed_wait_error.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
    delayed_wait_error.put(0xf0100,{0x9b});
    delayed_wait_error.reset();
    delayed_wait_error.step(0xfffff0,0xea,0xf000,0x0100,false);
    delayed_wait_error.d.busy_i=1;
    for (unsigned n=0;n<24;++n) delayed_wait_error.tick(false);
    check(!delayed_wait_error.d.event_o && !delayed_wait_error.d.retire_o,
          "WAIT did not remain suspended while BUSY was asserted");
    delayed_wait_error.d.error_n_i=0;
    for (unsigned n=0;n<16;++n) delayed_wait_error.tick(false);
    check(!delayed_wait_error.d.event_o && !delayed_wait_error.d.retire_o,
          "WAIT reported ERROR# before BUSY went inactive");
    delayed_wait_error.d.busy_i=0;
    delayed_wait_error.processor_fault(16,0x0100,false);
    check(delayed_wait_error.d.event_packet_restartable_o &&
          !delayed_wait_error.d.event_packet_error_valid_o &&
          delayed_wait_error.d.event_packet_saved_ip_o==0x0100,
          "WAIT did not report the completed extension error at the WAIT PC");

    // Intel 210498-005 tables 5-1 and 9-4 give an instruction exception
    // priority over NMI. An NMI edge coincident with BUSY falling and ERROR#
    // active must remain pending while WAIT's #MF frame is established.
    for (bool wait : {false, true}) {
        Bench race;
        interrupt_setup(race);
        interrupt_vector(race,16,0x2000);
        interrupt_vector(race,2,0x2100);
        race.put(0xf0109,{0x9b,0x43,0xf4});
        race.d.busy_i=1;
        for (unsigned n=0;n<128 && race.d.ip_o!=0x010a;++n) race.tick(wait);
        for (unsigned n=0;n<24;++n) race.tick(wait);
        check(race.d.ip_o==0x010a && !race.d.retire_o && !race.d.bus_req_o,
              "WAIT #MF/NMI race setup did not stall at WAIT");
        race.d.busy_i=0; race.d.error_n_i=0; race.d.nmi_i=1;
        race.tick(wait);
        check(race.d.nmi_pending_o && !race.d.nmi_blocked_o,
              "WAIT selected NMI before a simultaneous instruction exception");
        race.d.nmi_i=0;
        interrupt_entry(race,16,0x0109,0x0002,0x2000);
        check(race.d.nmi_pending_o && !race.d.nmi_blocked_o,
              "WAIT #MF entry lost or prematurely claimed the pending NMI");
        race.d.error_n_i=1;
        interrupt_entry(race,2,0x0100,0x0002,0x2100,0x2000);
        race.step(0x21100,0x43,0x2100,0x0101,wait);
        race.step(0x21101,0xcf,0x2000,0x0100,wait);
        race.step(0x20100,0x43,0x2000,0x0101,wait);
        race.step(0x20101,0xcf,0xf000,0x0109,wait);
        race.step(0xf0109,0x9b,0xf000,0x010a,wait);
        race.step(0xf010a,0x43,0xf000,0x010b,wait);
        check(race.reg(3)==3,"WAIT #MF/NMI race skipped or repeated an instruction");
        race.step(0xf010b,0xf4,0xf000,0x010c,wait);
    }

    // A8's already-claimed INTR remains atomic while its INTA handshake is
    // stalled. A later extension error cannot strand the claimed vector.
    for (bool wait : {false, true}) {
        Bench race;
        interrupt_setup(race);
        interrupt_vector(race,0x20,0x2000);
        race.put(0xf0109,{0xfb,0x9b,0x9b,0xf4});
        race.step(0xf0109,0xfb,0xf000,0x010a,wait);
        race.d.busy_i=1;
        for (unsigned n=0;n<128 && race.d.ip_o!=0x010b;++n) race.tick(wait);
        for (unsigned n=0;n<24;++n) race.tick(wait);
        race.d.intr_i=1; race.interrupt_vector=0x20;
        for (unsigned n=0;n<64 && !race.d.inta_req_o;++n) race.tick(wait);
        check(race.d.inta_req_o,"WAIT did not claim INTR before the error race");
        race.d.busy_i=0; race.d.error_n_i=0;
        for (unsigned n=0;n<4;++n) {
            race.tick(wait);
            check(race.d.inta_req_o && !race.d.event_o && !race.d.retire_o &&
                  !race.d.bus_req_o,"WAIT abandoned an outstanding INTR acknowledge");
        }
        race.acknowledge=true;
        interrupt_entry(race,0x20,0x010b,0x0202,0x2000);
        check(race.acknowledgements==1,"WAIT error race duplicated INTA");
        race.d.intr_i=0; race.acknowledge=false;
        race.step(0x20100,0x43,0x2000,0x0101,wait);
        race.step(0x20101,0xcf,0xf000,0x010b,wait);
        race.processor_fault(16,0x010b,wait);
        check(race.d.event_packet_saved_ip_o==0x010b && !race.d.retire_o,
              "following WAIT did not report the deferred extension error");
    }

    // Intel 210498-005 tables 5-1 and 9-4 prioritize a completed
    // instruction's single-step trap over NMI and INTR. A request first
    // presented exactly as BUSY falls must not be claimed before WAIT's
    // retirement boundary samples the pending TF trap.
    for (bool wait : {false, true}) for (bool nmi : {false, true}) {
        Bench race;
        debug_setup(race);
        interrupt_vector(race,nmi ? 2 : 0x20,0x2100);
        race.put(0x8000,{0x02,0x03}); // POPF enables both TF and IF.
        race.put(0xf0109,{0x9d,0x9b,0x43,0xf4});
        race.step(0xf0109,0x9d,0xf000,0x010a,wait);
        race.d.busy_i=1;
        for (unsigned n=0;n<128 && race.d.ip_o!=0x010b;++n) race.tick(wait);
        for (unsigned n=0;n<24;++n) race.tick(wait);
        check(race.d.ip_o==0x010b && !race.d.retire_o && !race.d.bus_req_o,
              "TF/WAIT setup did not stall at the exact successor");
        const unsigned before=race.retired;
        race.d.busy_i=0;
        if (nmi) race.d.nmi_i=1;
        else { race.d.intr_i=1; race.interrupt_vector=0x20; race.acknowledge=true; }
        race.tick(wait);
        check(race.retired==before+1 && race.d.retire_pc_o==0xf010a &&
              race.d.retire_opcode_o==0x9b && !race.d.inta_req_o && !race.d.nmi_blocked_o,
              "WAIT completion claimed an interrupt before the sampled TF trap");
        if (nmi) race.d.nmi_i=0;
        interrupt_entry(race,1,0x010b,0x0302);
        check(race.acknowledgements==0 && (!nmi || race.d.nmi_pending_o),
              "WAIT debug trap lost or acknowledged a lower-priority interrupt");
        if (nmi) {
            // NMI remains eligible after the #DB frame clears TF/IF and can
            // nest at the handler boundary before its first instruction.
            interrupt_entry(race,2,0x0100,0x0002,0x2100,0x2000);
            race.step(0x21100,0x43,0x2100,0x0101,wait);
            race.step(0x21101,0xcf,0x2000,0x0100,wait);
            debug_return(race,0x010b);
        } else {
            debug_return(race,0x010b);
            interrupt_entry(race,0x20,0x010b,0x0202,0x2100);
            race.d.intr_i=0; race.acknowledge=false;
            race.step(0x21100,0x43,0x2100,0x0101,wait);
            race.step(0x21101,0xcf,0xf000,0x010b,wait);
        }
        check(race.acknowledgements==(nmi ? 0u : 1u),"WAIT race acknowledge count");
        race.step(0xf010b,0x43,0xf000,0x010c,wait);
        check(race.reg(3)==2,"WAIT race lost or repeated its exact successor");
        race.step(0xf010c,0xf4,0xf000,0x010d,wait);
    }

    Bench escape_error;
    escape_error.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
    escape_error.put(0xf0100,{0xd8,0xc0});
    escape_error.reset();
    escape_error.step(0xfffff0,0xea,0xf000,0x0100,false);
    escape_error.d.error_n_i=0;
    escape_error.processor_fault(16,0x0100,false);

    // ESC waits for BUSY to clear before reporting an unmasked ERROR. Intel
    // 210760-002 §6.2 (printed p.6-4) and 80287 data sheet PDF p.20.
    Bench delayed_escape_error;
    delayed_escape_error.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
    delayed_escape_error.put(0xf0100,{0xd8,0xc0});
    delayed_escape_error.reset();
    delayed_escape_error.step(0xfffff0,0xea,0xf000,0x0100,false);
    delayed_escape_error.d.busy_i=1;
    const auto delayed_escape_retired=delayed_escape_error.retired;
    for (unsigned n=0;n<48;++n) delayed_escape_error.tick(false);
    check(!delayed_escape_error.d.event_o && !delayed_escape_error.d.retire_o &&
          delayed_escape_error.retired==delayed_escape_retired,
          "ESC did not wait while the extension BUSY signal was active");
    delayed_escape_error.d.error_n_i=0;
    for (unsigned n=0;n<16;++n) delayed_escape_error.tick(false);
    check(!delayed_escape_error.d.event_o && !delayed_escape_error.d.retire_o &&
          delayed_escape_error.retired==delayed_escape_retired,
          "ESC reported ERROR# before the extension BUSY signal cleared");
    delayed_escape_error.d.busy_i=0;
    delayed_escape_error.processor_fault(16,0x0100,false);
    check(delayed_escape_error.d.event_packet_restartable_o &&
          !delayed_escape_error.d.event_packet_error_valid_o &&
          delayed_escape_error.d.event_packet_saved_ip_o==0x0100,
          "ESC did not report the completed extension error at the ESC PC");

    // Pinned physical-286 D8 captures show command word at F8 followed by
    // instruction IP and CS at FC. Exercise every register encoding, prefixes,
    // BUSY release and byte-interface READY stalls, with exact successor PC.
    for (bool wait : {false,true}) for (unsigned rm=0xc0;rm<=0xff;++rm) {
        Bench esc;
        esc.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
        esc.put(0xf0100,{0x3e,0xd8,uint8_t(rm),0xf4});
        esc.reset();
        esc.step(0xfffff0,0xea,0xf000,0x0100,wait);
        esc.data_transfers.clear();
        esc.d.busy_i=1;
        for (unsigned n=0;n<40;++n) esc.tick(wait);
        check(esc.data_transfers.empty() && !esc.d.retire_o && !esc.d.fault_o,
              "D8 register command escaped while BUSY");
        esc.d.busy_i=0;
        esc.step(0xf0100,0xd8,0xf000,0x0103,wait);
        const uint32_t addresses[]={0xf8,0xf9,0xfc,0xfd,0xfc,0xfd};
        const uint8_t values[]={0xd8,uint8_t(rm),0x00,0x01,0x00,0xf0};
        check(esc.data_transfers.size()==6,"D8 register command transfer count");
        for (unsigned i=0;i<6;++i) {
            const auto& t=esc.data_transfers[i];
            check(t.io && t.write && t.address==addresses[i] && t.value==values[i],
                  "D8 register command/pointer transfer mismatch");
        }
        esc.step(0xf0103,0xf4,0xf000,0x0104,wait);
    }

    // A non-trapping memory ESC is recognized but cannot read its operand
    // until PEREQ/PEACK command transfers are implemented.
    Bench unsupported_escape;
    unsupported_escape.put(0xfffff0,{0xea,0x00,0x01,0x00,0xf0});
    unsupported_escape.put(0xf0100,{0xd8,0x06,0x00,0x02});
    unsupported_escape.reset();
    unsupported_escape.step(0xfffff0,0xea,0xf000,0x0100,false);
    unsupported_escape.data_transfers.clear();
    unsupported_escape.stop(3,0x0100);
    check(unsupported_escape.data_transfers.empty(),
          "unsupported ESC touched its memory operand before the extension transfer path");

    std::cout << "PASS: 80286 WAIT interruption/BUSY/ERROR#, ESC fault gates and D8 register commands\n";
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc,argv);
    try {
        if (argc==3 && std::string(argv[1])=="--hardware") hardware_vectors(argv[2]);
        else if (argc==2 && std::string(argv[1])=="--ud") undefined_opcode_contracts();
        else if (argc==2 && std::string(argv[1])=="--protection") protection_fault_contracts();
        else if (argc==2 && std::string(argv[1])=="--references") reference_routing_contracts();
        else if (argc==2 && std::string(argv[1])=="--caches") cache_state_contracts();
        else if (argc==2 && std::string(argv[1])=="--system") system_register_contracts();
        else if (argc==2 && std::string(argv[1])=="--system-decode") protected_selector_opcode_decode();
        else if (argc==2 && std::string(argv[1])=="--selector-exec") {
            protected_selector_state_execution(); protected_selector_descriptor_faults();
            protected_selector_privilege_faults(); protected_null_ldt_invalidation();
            protected_selector_query_execution(); protected_selector_query_ring3_execution();
            protected_selector_query_ring12_matrix();
        }
        else if (argc==2 && std::string(argv[1])=="--protected-event-outer")
            protected_event_outer_delivery();
        else if (argc==2 && std::string(argv[1])=="--protected-event-ring12")
            protected_event_ring12_delivery();
        else if (argc==2 && std::string(argv[1])=="--protected-event-ring12-exception")
            protected_event_ring12_exception_delivery();
        else if (argc==2 && std::string(argv[1])=="--protected-event-ring12-external")
            protected_event_ring12_async_delivery(false);
        else if (argc==2 && std::string(argv[1])=="--protected-event-task-gate")
            { protected_event_task_gate_delivery(); protected_event_task_gate_fault_recovery(); protected_event_task_gate_handler_entry_fault(); }
        else if (argc==2 && std::string(argv[1])=="--protected-event-ring12-nmi")
            protected_event_ring12_async_delivery(true);
        else if (argc==2 && std::string(argv[1])=="--protected-wait")
            protected_wait_async_delivery();
        else if (argc==2 && std::string(argv[1])=="--outer-iret") protected_outer_iret();
        else if (argc==2 && std::string(argv[1])=="--protected-iret-faults") {
            protected_outer_iret_faults(); protected_outer_iret_inward_faults();
            protected_outer_iret_ss_faults(); protected_outer_iret_frame_faults();
            protected_outer_iret_fault_priorities();
        }
        else if (argc==2 && std::string(argv[1])=="--call-gate") protected_call_gate_same_level();
        else if (argc==2 && std::string(argv[1])=="--call-gate-faults") protected_call_gate_access_faults();
        else if (argc==2 && std::string(argv[1])=="--call-gate-target-faults") protected_call_gate_target_faults();
        else if (argc==2 && std::string(argv[1])=="--call-gate-ldt-target-faults") protected_call_gate_ldt_target_faults();
        else if (argc==2 && std::string(argv[1])=="--call-gate-tss-stack-faults") protected_call_gate_tss_stack_faults();
        else if (argc==2 && std::string(argv[1])=="--call-gate-outer") protected_call_gate_outer_level();
        else if (argc==2 && std::string(argv[1])=="--call-gate-ring-levels") protected_call_gate_ring1_ring2();
        else if (argc==2 && std::string(argv[1])=="--call-gate-conforming") protected_call_gate_conforming_target();
        else if (argc==2 && std::string(argv[1])=="--call-gate-retf-faults") protected_call_gate_outer_return_faults();
        else if (argc==2 && std::string(argv[1])=="--call-gate-ldt") protected_call_gate_ldt();
        else if (argc==2 && std::string(argv[1])=="--iopl-controls") protected_iopl_controls();
        else if (argc==2 && std::string(argv[1])=="--shutdown-nmi") protected_shutdown_nmi_recovery();
        else if (argc==2 && std::string(argv[1])=="--protected-segments") {
            protected_mode_segment_integration(); protected_arpl_contracts();
            protected_arpl_reachable_privilege_matrix();
        }
        else if (argc==2 && std::string(argv[1])=="--arpl") {
            protected_arpl_contracts(); protected_arpl_reachable_privilege_matrix();
        }
        else if (argc==3 && std::string(argv[1])=="--bios-system") bios_system_registers(argv[2]);
        else if (argc==2 && std::string(argv[1])=="--debug") debug_trap_contracts();
        else if (argc==2 && std::string(argv[1])=="--interrupts") hardware_interrupt_contracts();
        else if (argc==3 && std::string(argv[1])=="--bios-irq") bios_timer_interrupt(argv[2]);
        else if (argc==3 && std::string(argv[1])=="--software") software(argv[2]);
        else if (argc==3 && std::string(argv[1])=="--vectors") vectors(argv[2]);
        else if (argc==3 && std::string(argv[1])=="--firmware") vectors(argv[2],true);
        else if (argc==3 && std::string(argv[1])=="--bios-decimal") vectors(argv[2],false,true);
        else if (argc==2 && std::string(argv[1])=="--processor-extension") processor_extension_contract();
        else {
            directed(false); directed(true); boundaries(); rejection_and_reset(); undefined_opcode_contracts(); protection_fault_contracts(); intel_shift_carry(); memory_boundaries(); manufacturer_stack_contracts(); bounds_translation_contracts(); procedure_reset_contracts(); string_contracts(); decimal_contracts(); hardware_interrupt_contracts(); debug_trap_contracts(); system_register_contracts(); processor_extension_contract(); protected_selector_opcode_decode(); protected_selector_state_execution(); protected_selector_descriptor_faults(); protected_selector_privilege_faults(); protected_null_ldt_invalidation(); protected_selector_query_execution(); protected_selector_query_ring3_execution(); protected_selector_query_ring12_matrix(); protected_outer_iret(); protected_outer_iret_faults(); protected_outer_iret_inward_faults(); protected_outer_iret_ss_faults(); protected_outer_iret_frame_faults(); protected_outer_iret_fault_priorities(); protected_event_outer_delivery(); protected_event_ring12_delivery(); protected_event_ring12_exception_delivery(); protected_event_ring12_async_delivery(false); protected_event_task_gate_delivery(); protected_event_task_gate_fault_recovery(); protected_event_task_gate_handler_entry_fault(); protected_event_ring12_async_delivery(true); protected_wait_async_delivery(); protected_call_gate_same_level(); protected_call_gate_access_faults(); protected_call_gate_target_faults(); protected_call_gate_ldt_target_faults(); protected_call_gate_tss_stack_faults(); protected_call_gate_outer_level(); protected_call_gate_ring1_ring2(); protected_call_gate_conforming_target(); protected_call_gate_outer_return_faults(); protected_call_gate_ldt(); protected_iopl_controls(); cache_state_contracts(); reference_routing_contracts(); protected_mode_segment_integration(); protected_arpl_contracts(); protected_arpl_reachable_privilege_matrix();
            std::cout << "PASS: 80286 bootstrap reset, register aliases, flags, exact branches, stalls and diagnostic boundaries\n";
        }
    } catch (const std::exception& error) {
        std::cerr << "FAIL: " << error.what() << '\n'; return 1;
    }
}

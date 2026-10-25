// Included inside intel_80286. Only initial reset constrains the environment.
`ifdef FORMAL
    logic past_valid = 0;
    logic witnessed_async, witnessed_halt, witnessed_rep, rep_progress;
    logic witnessed_debug, witnessed_vector_limit;
    always_ff @(posedge clk) begin
        past_valid <= 1;
        if (!past_valid) assume(!rst_n);
        if (!rst_n) begin
            witnessed_async<=0; witnessed_halt<=0; witnessed_rep<=0; rep_progress<=0;
            witnessed_debug<=0; witnessed_vector_limit<=0;
        end else begin
            if (state==EVENT_START && event_vector_o!=8 &&
                ({7'h0,event_vector_o,2'b00}+17'd3)>{1'b0,idt_limit})
                witnessed_vector_limit<=1;
            else if (event_o) witnessed_vector_limit<=0;

            if (async_boundary && async_step && !ss_shadow &&
                !(state==STRING_BOUNDARY && instruction_ss_shadow)) witnessed_debug<=1;
            if (event_o) witnessed_debug<=0;
            if (state==FETCH && !prefix_active && core_bus_ready) rep_progress<=0;
            if (element_o && !retire_o) rep_progress<=1;
            if (async_poll && async_valid) begin
                witnessed_async<=1; witnessed_halt<=halt_latch;
                witnessed_rep<=state==STRING_POLL && rep_progress;
            end else if (event_o) begin witnessed_async<=0; witnessed_halt<=0; witnessed_rep<=0; end
        end
        if (past_valid) begin
            if (!$past(rst_n)) begin
                assert(ip == 16'hfff0 && cs == 16'hf000);
                assert(cs_base == 24'hff0000 && flags == 16'h0002);
                assert(msw==16'hfff0 && idt_base==0 && idt_limit==16'h03ff);
                assert(gdt_base==0 && gdt_limit==0); // A12 project reset policy.
                assert(seg_bases_o=={24'h0,24'h0,24'hff0000,24'h0});
                assert(!retire_o && !halted_o && !fault_o && !element_o);
            end
            assert((msw_o & 16'hfff0)==16'hfff0);
            if (rst_n && $past(rst_n && msw[0])) assert(msw[0]);
            // Protected descriptor engines start only after PE is set; PE
            // remains set until reset. These relations strengthen the
            // reset-reachable cache-mode invariants below.
            if (rst_n) begin
                assert(!code_load_busy || msw[0]);
                assert(!segment_load_busy || msw[0]);
            end
            if (rst_n && !msw[0]) begin
                // ASSUMPTION A14 applies to the inherited real-mode cache only, after reset.
                assert(seg_limits_o==64'hffffffffffffffff && seg_access_o==32'h93939393 && seg_valid_o==4'hf);
                assert(es_base=={4'h0,es,4'h0} && ss_base=={4'h0,ss,4'h0} && ds_base=={4'h0,ds,4'h0});
                assert(cs_base=={4'h0,cs,4'h0} || (cs==16'hf000 && cs_base==24'hff0000));
            end
            if (rst_n && $past(rst_n) && !retire_o && !event_o) begin
                assert($stable(seg_bases_o) && $stable(seg_limits_o));
                assert($stable(seg_access_o) && $stable(seg_valid_o));
            end
            assert(!(halted_o && fault_o));
            if (halted_o || fault_o)
                assert(!core_bus_req && !(descriptor_claim && descriptor_bus_req) && !event_bus_req);
            assert(!(cpu_bus_ready && event_bus_ready));
            assert(core_bus_ready==(cpu_bus_ready || owner_descriptor_ready || event_bus_ready));
            assert(owner_cpu_grant==(bus_owner==0));
            assert(owner_descriptor_grant==(bus_owner==1));
            assert(owner_event_grant==(bus_owner==2));
            // The owner may finish a previously held physical beat after the
            // engine drops its request; validate the routed handshake itself.
            if (owner_descriptor_ready)
                assert(owner_descriptor_grant && owner_bus_req && bus_ready_i);
            if (bus_owner==2)
                assert(event_bus_path_active || state==STOPPED ||
                       (state==EVENT_START && event_packet.protected_mode));
            if (rst_n && bus_owner==1)
                assert(descriptor_bus_path_active || state==STOPPED || descriptor_bus_req ||
                       code_load_busy || segment_load_busy || descriptor_release);
            if (event_bus_ready) assert(bus_owner==2);
            // A stopped event may finish a previously stalled physical beat;
            // validate the event request when each new physical beat starts.
            if (bus_owner==2 && bus_req_o &&
                !$past(rst_n && bus_req_o && !bus_ready_i))
                assert(event_bus_req);
            // Check descriptor context when each physical request starts;
            // the bus-owner properties preserve it if that request stalls.
            if (owner_descriptor_grant && bus_req_o &&
                !$past(rst_n && bus_req_o && !bus_ready_i))
                assert(!bus_fetch_o && !bus_io_o && !bus_segmented_o && bus_kind_o==3);
            if (rst_n && $past(rst_n && bus_req_o && !bus_ready_i)) begin
                assert(bus_req_o);
                assert($stable(bus_addr_o));
                assert($stable(bus_fetch_o));
                assert($stable(bus_write_o));
                assert($stable(bus_io_o));
                if (bus_write_o) assert($stable(bus_wdata_o));
            end
            if (rst_n && $past(rst_n && owner_cpu_grant && core_bus_req && !core_bus_ready)) begin
                assert($stable(regs_o));
                assert($stable(flags_o));
                assert(!retire_o);
            end
            if (rst_n && $past(rst_n && (halted_o || fault_o))) begin
                assert($stable(ip_o));
                assert($stable(regs_o));
                assert(!retire_o);
            end
            if (retire_o) assert($past(rst_n && (state == EXECUTE || (state == SHIFT && shift_remaining == 1) ||
                state == COMMIT_MEMORY || state == IO_DONE || state == PUSH_DONE || state == POP_DONE ||
                state == MULDIV_WAIT || state == FAR_CALL_DONE || state == FAR_RETURN_DONE || state == EVENT_COMMIT ||
                state == IRET_COMMIT ||
                state == ALL_COMMIT || state == ENTER_COMMIT || state == LEAVE_DONE ||
                state == STRING_START || state == STRING_COMMIT || state==SYSTEM_DONE ||
                state==CODE_LOAD_WAIT || state==SEGMENT_LOAD_WAIT)));
            if (state == SHIFT) assert(shift_remaining != 0);
            if (state == SHIFT) assert(shift_op);
            if (rst_n && $past(rst_n &&
                (state==DECODE || state==MODRM_DECODE || state==AFTER_DISP) && undefined_encoding)) begin
                assert(state==EVENT_START && event_vector_o==6 && !event_packet.instruction_retired);
                assert(event_packet.saved_ip==$past(instruction_ip) && !retire_o);
                assert($stable(regs_o) && $stable(flags_o));
            end
            assert(state <= EVENT_GATE_CHECK);
            assert(cs_trusted); // Real-mode prelude; protected CS commit must clear it.
            if (state==MEMORY_CHECK || state==BUS) begin
                assert(memory_size>=1 && memory_size<=6);
                assert(memory_remaining+memory_index==memory_size);
                assert(memory_write ? memory_kind==1 : (memory_kind==0 || memory_kind==3));
            end
            if (rst_n && state==CODE_LOAD_WAIT && code_load_done && !code_load_fault && !code_load_special) begin
                assert(code_load_cache_valid);
            end
            if (rst_n && $past(rst_n && code_load_start && !code_load_busy)) begin
                // The request outputs publish only when the transaction completes;
                // the engine properties check that its private request capture is exact.
                assert(state==CODE_LOAD_WAIT);
                assert(code_load_busy);
            end
            if (rst_n && $past(rst_n && state==CODE_LOAD_WAIT && code_load_done && code_load_target==0 &&
                      code_load_cache_valid && !code_load_fault && !code_load_special &&
                      code_load_request_selector==(opcode==8'hea ? immediate[31:16] : memory_result[31:16]) &&
                      code_load_request_offset==(opcode==8'hea ? immediate[15:0] : memory_result[15:0]))) begin
                assert(cs==$past(code_load_selector) && cs_base==$past(code_load_base));
                assert(ip==$past(code_load_request_offset) && cache_valid[1]);
            end
            if (rst_n && $past(rst_n && state==CODE_LOAD_WAIT && code_load_done &&
                      code_load_cache_valid && !code_load_fault && !code_load_special &&
                      code_load_target==1)) begin
                assert(state==EVENT_FRAME_CHECK);
                assert(event_target_selector==$past(code_load_selector));
                assert(event_target_base==$past(code_load_base));
                assert(event_target_limit==$past(code_load_limit));
                assert(event_target_access==$past(code_load_access));
                assert(cs==$past(cs) && cs_base==$past(cs_base));
            end
            if (rst_n && $past(rst_n && state==CODE_LOAD_WAIT && code_load_done &&
                      code_load_cache_valid && !code_load_fault && !code_load_special &&
                      code_load_target==2)) begin
                assert(state==IRET_COMMIT);
                assert(iret_target_base==$past(code_load_base));
                assert(iret_target_limit==$past(code_load_limit));
                assert(iret_target_access==$past(code_load_access));
                assert(cs==$past(cs) && cs_base==$past(cs_base));
                assert(gpr[4]==$past(gpr[4]) && flags==$past(flags));
            end
            if (rst_n && $past(rst_n && state==SEGMENT_LOAD_WAIT && segment_load_done && !segment_load_fault)) begin
                case ($past(segment_load_target))
                    0: assert(es==$past(segment_load_selector) && es_base==$past(segment_load_base) &&
                              cache_valid[0]==$past(segment_load_cache_valid));
                    2: if ($past(segment_load_cache_valid))
                           assert(ss==$past(segment_load_selector) && ss_base==$past(segment_load_base) && cache_valid[2]);
                    3: assert(ds==$past(segment_load_selector) && ds_base==$past(segment_load_base) &&
                              cache_valid[3]==$past(segment_load_cache_valid));
                    // MOV to CS is rejected by the core after descriptor lookup.
                    default: assert(state==STOPPED && fault_code_o==3 &&
                                    ip==$past(instruction_ip) && !retire_o);
                endcase
            end
            if (rst_n && state==MEMORY_CHECK) begin
                // A previously stalled descriptor beat may still own the
                // physical bus while this core state validates the operand.
                assert(memory_segmented && !memory_io && !core_bus_req && !retire_o && !event_o);
                assert(memory_index==0);
            end
            if (rst_n && state==MEMORY_CHECK && memory_precheck_only) begin
                assert(event_delivery_active && memory_return==EVENT_FRAME_READY);
                assert(memory_role==2 && memory_kind==1 && memory_write && memory_size==1);
                assert(memory_offset==event_packet.saved_sp-16'd8 && memory_span_delta==16'd7);
                assert(!core_bus_req && !retire_o && !event_o);
            end
            if (ins_precheck_active) begin
                assert(opcode==8'h6c || opcode==8'h6d);
                assert((state==MEMORY_CHECK && memory_return==STRING_FIRST &&
                        memory_segmented && !memory_io && memory_write && memory_role==0 &&
                        memory_kind==1 && memory_offset==gpr[7] &&
                        memory_size==(wide ? 2 : 1)) ||
                       (state==BUS && memory_return==STRING_FIRST &&
                        !memory_segmented && memory_io && !memory_write));
            end
            if (rst_n && $past(rst_n && state==MEMORY_CHECK)) begin
                assert($stable(segs_o) && $stable(flags_o));
                if ($past(msw[0] && ins_precheck_active && !data_reference_allow &&
                          !event_delivery_active && !protected_iret_active)) begin
                    assert(gpr[7]==$past(gpr[7])+$past(string_delta));
                    assert(gpr[1]==($past(repeat_valid) ? $past(gpr[1])-16'd2 : $past(gpr[1])));
                    for (integer r=0;r<8;r=r+1)
                        if (r!=1 && r!=7) assert(gpr[r]==$past(gpr[r]));
                end else assert($stable(regs_o));
                if ($past(data_reference_allow)) begin
                    if ($past(memory_precheck_only)) begin
                        assert(state==EVENT_FRAME_READY && !memory_precheck_only);
                    end else if ($past(ins_precheck_active)) begin
                        assert(state==BUS && memory_io && !memory_segmented && !memory_write);
                        assert(memory_address=={8'h0,$past(gpr[2])} &&
                               memory_size==$past(memory_size));
                        assert(ins_precheck_active);
                    end else begin
                        assert(state==BUS && memory_address==$past(data_reference_address));
                        assert($stable(memory_role) && $stable(memory_offset) && $stable(memory_size));
                        assert($stable(memory_kind) && $stable(memory_write) && $stable(memory_data));
                    end
                end else begin
                    if ($past(event_delivery_active || protected_iret_active)) begin
                        assert(state==STOPPED && fault_code_o==3 && !core_bus_req);
                    end else begin
                        assert(state==EVENT_START && !event_packet.instruction_retired && !core_bus_req);
                        assert(event_vector_o==($past(data_reference_fault && msw[0]) ?
                                               $past(data_reference_vector) : 8'd13));
                        assert(event_packet.saved_ip==$past(instruction_ip) && !retire_o);
                    end
                end
            end
            if (rst_n && $past(rst_n && state==MEMORY_CHECK && data_reference_fault)) begin
                if ($past(event_delivery_active || protected_iret_active)) begin
                    assert(state==STOPPED && fault_code_o==3);
                end else begin
                    assert(event_packet.valid);
                    if ($past(msw[0])) begin
                        assert(event_packet.vector==$past(data_reference_vector));
                        assert(event_packet.error_present);
                        assert(event_packet.error_code==$past(data_reference_error));
                    end else begin
                        assert(event_packet.vector==13 && !event_packet.error_present);
                    end
                    assert(event_packet.saved_cs==$past(cs));
                    assert(event_packet.saved_ip==$past(instruction_ip));
                    assert(event_packet.saved_flags==$past(flags));
                    assert(event_packet.saved_sp==$past(gpr[4]));
                    assert(event_packet.deferred_valid==!$past(ins_precheck_active &&
                        (opcode==8'h6c || opcode==8'h6d) && memory_return==STRING_FIRST));
                    assert(event_packet.deferred_flags==$past(pending_flags));
                    assert(event_packet.deferred_register_value==$past(pending_register_value));
                end
            end
            // Check reference construction before bus-owner holding. Its
            // separate properties cover external request retention/stability.
            if (core_bus_req && core_bus_segmented && !event_bus_path_active) begin
                if (core_bus_fetch) begin
                    assert(core_bus_segment==1 && core_bus_kind==2 && core_bus_size==1);
                    assert(fetch_reference_allow && core_bus_offset==ip);
                    case (core_bus_segment)
                        0: assert(core_bus_addr==seg_bases_o[23:0]+{8'h0,core_bus_offset});
                        1: assert(core_bus_addr==seg_bases_o[47:24]+{8'h0,core_bus_offset});
                        2: assert(core_bus_addr==seg_bases_o[71:48]+{8'h0,core_bus_offset});
                        3: assert(core_bus_addr==seg_bases_o[95:72]+{8'h0,core_bus_offset});
                        default: assert(0);
                    endcase
                end else begin
                    if (rst_n && $past(rst_n && state==MEMORY_CHECK &&
                                       data_reference_allow && !memory_io)) begin
                        assert(!core_bus_io && core_bus_size>=1 && core_bus_size<=6);
                        assert(data_reference_allow);
                        assert(core_bus_kind==memory_kind && core_bus_size==memory_size);
                        case (core_bus_segment)
                            0: assert(core_bus_addr==seg_bases_o[23:0]+{8'h0,core_bus_offset});
                            1: assert(core_bus_addr==seg_bases_o[47:24]+{8'h0,core_bus_offset});
                            2: assert(core_bus_addr==seg_bases_o[71:48]+{8'h0,core_bus_offset});
                            3: assert(core_bus_addr==seg_bases_o[95:72]+{8'h0,core_bus_offset});
                            default: assert(0);
                        endcase
                    end
                    if (rst_n && $past(rst_n && state==BUS && core_bus_ready &&
                        memory_remaining>1 && data_reference_allow && !memory_io)) begin
                        assert(!core_bus_io && core_bus_size>=1 && core_bus_size<=6);
                        assert(data_reference_allow);
                        assert(core_bus_kind==memory_kind && core_bus_size==memory_size);
                        assert(core_bus_segment==$past(core_bus_segment));
                        assert(core_bus_offset==$past(core_bus_offset)+16'd1);
                        assert(core_bus_addr==$past(core_bus_addr)+24'd1);
                    end
                end
            end
            if (rst_n && state==MEMORY_CHECK &&
                (opcode==8'h6c || opcode==8'h6d) && memory_return==STRING_FIRST)
                assert(ins_precheck_active);
            if (rst_n && $past(rst_n && bus_req_o && !bus_ready_i)) begin
                assert($stable(bus_segmented_o) && $stable(bus_segment_o));
                assert($stable(bus_offset_o) && $stable(bus_size_o) && $stable(bus_kind_o));
            end
            // Halt persists through idle recognition/acknowledgement, but
            // cannot own an instruction execution state or memory transfer.
            if (halt_latch) assert(state==HALTED || state==BOUNDARY || state==EVENT_POLL);
            if (state==HALTED) assert(halt_latch);
            if (rst_n && $past(rst_n && state==FETCH && !prefix_active &&
                owner_cpu_grant && cpu_bus_ready && !fetch_reference_fault))
                assert(instruction_tf==$past(flags[8]));
            if (rst_n && $past(rst_n && async_boundary && async_step && !ss_shadow &&
                !(state==STRING_BOUNDARY && instruction_ss_shadow)))
                assert(async_poll && async_valid && async_vector==1);
            if (async_boundary || async_poll) assert(!core_bus_req);
            if (inta_req_o) begin assert(async_poll); assert(!core_bus_req); end
            if (async_valid) assert(async_poll);
            if (state==STRING_BOUNDARY || state==STRING_POLL) begin
                assert(string_op && repeat_valid && gpr[1]!=0);
            end
            cover(event_o && event_vector_o==2);
            cover(inta_req_o && !inta_ready_i);
            cover(event_o && event_vector_o==8'h20);
            cover(event_o && witnessed_async && event_vector_o==2);
            cover(event_o && witnessed_async && witnessed_halt);
            cover(event_o && witnessed_async && witnessed_rep);
            cover(event_o && witnessed_async && witnessed_debug && event_vector_o==1);
            // Strengthen induction with the real continuation invariant rather
            // than assuming arbitrary memory-return encodings are reachable.
            assert(memory_return == FETCH || memory_return == EXECUTE || memory_return == COMMIT_MEMORY ||
                   memory_return == IO_DONE || memory_return == PUSH_DONE || memory_return == POP_DONE ||
                   memory_return == FAR_CS_DONE || memory_return == FAR_CALL_DONE || memory_return == FAR_RETURN_DONE ||
                   memory_return == EVENT_VECTOR || memory_return == EVENT_FLAGS || memory_return == EVENT_CS || memory_return == EVENT_COMMIT ||
                   memory_return == EVENT_GATE_TAIL || memory_return == EVENT_GATE_VALIDATE ||
                   memory_return == EVENT_FRAME_READY || memory_return == EVENT_FRAME_FLAGS ||
                   memory_return == EVENT_FRAME_CS || memory_return == EVENT_FRAME_IP ||
                   memory_return == EVENT_FRAME_ERROR || memory_return == EVENT_PROTECTED_COMMIT ||
                   memory_return == ALL_NEXT || memory_return == ENTER_FIRST || memory_return == ENTER_READ ||
                   memory_return == ENTER_COPY || memory_return == ENTER_COMMIT || memory_return == LEAVE_DONE ||
                   memory_return == SYSTEM_DONE ||
                   memory_return == STRING_FIRST || memory_return == STRING_COMMIT);
            if (state == BUS) begin
                assert(memory_remaining >= 1 && memory_remaining <= 6);
                assert(({1'b0,memory_index}+{1'b0,memory_remaining})<=6);
                if (opcode==8'h0f)
                    assert(memory_return==EXECUTE || memory_return==SYSTEM_DONE ||
                           memory_return==EVENT_VECTOR || memory_return==EVENT_FLAGS ||
                           memory_return==EVENT_CS || memory_return==EVENT_COMMIT ||
                           memory_return==EVENT_GATE_TAIL || memory_return==EVENT_GATE_VALIDATE ||
                           memory_return==EVENT_FRAME_READY || memory_return==EVENT_FRAME_FLAGS ||
                           memory_return==EVENT_FRAME_CS || memory_return==EVENT_FRAME_IP ||
                           memory_return==EVENT_FRAME_ERROR);
            end
            // An accepted divider operation owns the CPU until its result is ready.
            assert(!md_busy || state==MULDIV_WAIT);
            if (state==MULDIV_WAIT) assert(muldiv_op);
            if (state==SYSTEM_DONE || (state==BUS && memory_return==SYSTEM_DONE)) begin
                assert(opcode==8'h0f && system_opcode==1);
                assert(modrm[5:3]<2 || modrm[5:3]==4);
            end
            if (state==EVENT_START || state==EVENT_VECTOR || state==EVENT_FLAGS ||
                state==EVENT_CS || state==EVENT_COMMIT || state==EVENT_GATE_TAIL ||
                state==EVENT_GATE_VALIDATE || state==EVENT_GATE_CHECK || state==EVENT_CODE_START ||
                state==EVENT_FRAME_CHECK || state==EVENT_FRAME_READY || state==EVENT_FRAME_FLAGS ||
                state==EVENT_FRAME_CS || state==EVENT_FRAME_IP || state==EVENT_FRAME_ERROR ||
                state==EVENT_PROTECTED_COMMIT || (state==BUS &&
                (memory_return==EVENT_VECTOR || memory_return==EVENT_FLAGS ||
                 memory_return==EVENT_CS || memory_return==EVENT_COMMIT ||
                 memory_return==EVENT_GATE_TAIL || memory_return==EVENT_GATE_VALIDATE ||
                 memory_return==EVENT_FRAME_READY || memory_return==EVENT_FRAME_FLAGS ||
                 memory_return==EVENT_FRAME_CS || memory_return==EVENT_FRAME_IP ||
                 memory_return==EVENT_FRAME_ERROR || memory_return==EVENT_PROTECTED_COMMIT))) begin
                if (event_packet.instruction_retired) assert(opcode==8'hcc || opcode==8'hcd || opcode==8'hce);
            end
            if (state==MULDIV_WAIT && aam_op) assert(md_flags==flags);
            if (state==STRING_START || state==STRING_FIRST || state==STRING_COMMIT ||
                (state==BUS && (memory_return==STRING_FIRST || memory_return==STRING_COMMIT))) begin
                assert(string_op);
                if (state!=STRING_START && repeat_valid) assert(gpr[1]!=0);
            end
            if (rst_n && $past(rst_n) && !retire_o && !event_o && !element_o) begin
                assert($stable(regs_o));
                assert($stable(segs_o));
                assert($stable(flags_o));
                assert($stable(msw) && $stable(gdt_base) && $stable(gdt_limit));
                assert($stable(idt_base) && $stable(idt_limit));
            end
            if (event_o) begin
                assert($past(rst_n && (state==EVENT_COMMIT || state==EVENT_PROTECTED_COMMIT)));
                assert((flags_o & 16'h0300)==0);
                if ($past(state==EVENT_PROTECTED_COMMIT)) begin
                    assert(event_packet.protected_mode && event_packet.vector==13);
                    assert(cs==$past(event_target_selector) && cs_base==$past(event_target_base));
                    assert(gpr[4]==$past(pending_sp));
                    assert(flags==(event_packet.saved_flags&16'hfcff));
                end
            end
            if (retire_o && $past(rst_n && state==IRET_COMMIT)) begin
                assert(cs==$past(code_load_selector) && cs_base==$past(iret_target_base));
                assert(ip==$past(iret_saved_ip) && gpr[4]==$past(iret_saved_sp));
                assert(flags==(($past(flags)&16'h7000)|($past(iret_saved_flags)&16'h0fd5)|16'h0002));
                assert(ds==$past(ds) && ds_base==$past(ds_base));
            end
            if (element_o) begin
                assert($past(rst_n && state==STRING_COMMIT && string_op));
                assert(gpr[1]==($past(gpr[1])-($past(repeat_valid) ? 16'd1 : 16'd0)));
                assert(gpr[6]==($past(gpr[6])+($past(string_source) ? $past(string_delta) : 16'd0)));
                assert(gpr[7]==($past(gpr[7])+($past(string_destination) ? $past(string_delta) : 16'd0)));
                if (!$past(string_compare)) assert(flags==$past(flags));
                assert(segs_o==$past(segs_o));
            end
            if (retire_o && $past(rst_n && state==MULDIV_WAIT && aam_op)) begin
                assert(gpr[2]==$past(gpr[2]));
                assert(flags[7]==gpr[0][7] && flags[6]==(gpr[0][7:0]==0) && flags[2]==~^gpr[0][7:0]);
                assert(((flags^$past(flags)) & 16'hff3b)==0);
            end
            // Intel system-instruction effects, independently pinned in the
            // system-register contract; no environment data assumptions.
            if (retire_o && $past(rst_n && state==EXECUTE && opcode==8'h0f)) begin
                assert(retire_opcode_o==8'h0f);
                assert(flags_o==$past(flags_o) && segs_o==$past(segs_o));
                if ($past(system_opcode==6)) assert(msw==($past(msw)&16'hfff7));
                if ($past(system_opcode==1 && modrm[5:3]==6))
                    assert(msw==(16'hfff0|($past(rm_value)&16'h000e)|
                                 {15'd0,$past(msw[0] | rm_value[0])}));
                if ($past(system_opcode==1 && modrm[5:3]==2)) begin
                    assert(gdt_limit==$past(memory_result[15:0]));
                    assert(gdt_base==$past(memory_result[39:16]));
                end
                if ($past(system_opcode==1 && modrm[5:3]==3)) begin
                    assert(idt_limit==$past(memory_result[15:0]));
                    assert(idt_base==$past(memory_result[39:16]));
                end
            end
            if (rst_n && $past(rst_n) && (!$stable(gdt_base) || !$stable(gdt_limit)))
                assert(retire_o && $past(state==EXECUTE && opcode==8'h0f && system_opcode==1 && modrm[5:3]==2));
            if (rst_n && $past(rst_n) && (!$stable(idt_base) || !$stable(idt_limit)))
                assert(retire_o && $past(state==EXECUTE && opcode==8'h0f && system_opcode==1 && modrm[5:3]==3));
            if (retire_o && $past(state == EXECUTE && opcode == 8'h9e)) begin
                assert((flags_o & 16'h00d5) == ($past(gpr[0]) >> 8 & 16'h00d5));
                assert((flags_o & 16'hff2a) == ($past(flags_o) & 16'hff2a));
            end
            if (retire_o && $past(state == EXECUTE && opcode >= 8'h70 && opcode <= 8'h7f))
                assert(ip_o == ($past(ip_o) + ($past(jump_taken) ? {{8{$past(immediate[7])}},$past(immediate[7:0])} : 16'h0000)));
            cover(rst_n && bus_req_o && bus_addr_o == 24'hfffff0);
            cover(retire_o && retire_opcode_o == 8'hea && cs_base_o == 24'h0f0000);
            cover(retire_o && retire_opcode_o == 8'hb8 && regs_o[15:0] == 16'h1234);
            cover(halted_o);
            cover(fault_o && fault_code_o == 1);
            cover(fault_o && fault_code_o == 2);
            cover(retire_o && retire_opcode_o == 8'hd2);
            cover(retire_o && retire_opcode_o == 8'h83);
            cover(bus_req_o && bus_write_o && !bus_io_o);
            cover(bus_req_o && bus_write_o && bus_io_o);
            cover(retire_o && retire_opcode_o == 8'he8);
            cover(retire_o && retire_opcode_o == 8'hf7 && modrm[5:3]==6);
            cover(event_o && event_vector_o==0);
            cover(retire_o && retire_opcode_o == 8'h60);
            cover(retire_o && retire_opcode_o == 8'hc8);
            cover(retire_o && retire_opcode_o == 8'h9a);
            cover(retire_o && retire_opcode_o == 8'h62);
            cover(event_o && event_vector_o==5);
            cover(event_o && event_vector_o==6 && !retire_o && opcode==8'h64);
            if (rst_n && $past(rst_n && state==EVENT_START && !event_packet.protected_mode &&
                event_vector_o!=8 &&
                ({7'h0,event_vector_o,2'b00}+17'd3)>{1'b0,idt_limit})) begin
                assert(state==EVENT_START && event_vector_o==8 && !event_packet.instruction_retired);
                assert(!retire_o && !event_bus_req);
                assert(event_packet.saved_ip==($past(event_packet.instruction_retired) ?
                       $past(instruction_ip) : $past(event_packet.saved_ip)));
                assert($stable(regs_o) && $stable(flags_o));
            end
            if (state==EVENT_START && event_packet.protected_mode) assert(!event_bus_req);
            if (rst_n && $past(rst_n && state==EVENT_START && event_packet.protected_mode)) begin
                if ($past(event_vector_o==13 && event_packet.error_present &&
                          event_packet.error_code==0 && event_packet.saved_sp>=8 &&
                          ({6'h0,event_vector_o,3'b000}+17'd7)<={1'b0,idt_limit})) begin
                    assert(state==BUS && event_delivery_active && memory_return==EVENT_GATE_TAIL);
                    assert(memory_address==$past(idt_base)+{13'h0,$past(event_vector_o),3'b000});
                end else begin
                    assert(state==STOPPED && fault_code_o==3);
                    assert(ip==event_packet.saved_ip && !retire_o && !event_o);
                end
            end
            if (rst_n && state==BUS && core_bus_req &&
                event_packet.protected_mode && event_delivery_active) begin
                if (memory_return==EVENT_GATE_TAIL)
                    assert(memory_address==idt_base+{13'h0,event_vector_o,3'b000}+{21'h0,memory_index});
                if (memory_return==EVENT_GATE_VALIDATE)
                    assert(memory_address==idt_base+{13'h0,event_vector_o,3'b000}+24'd6+{21'h0,memory_index});
            end
            if (rst_n && $past(rst_n && state==EVENT_GATE_VALIDATE)) begin
                assert(state==EVENT_GATE_CHECK);
                assert(event_gate[63:48]==$past(memory_result[15:0]));
                assert(event_gate[47:0]==$past(event_gate[47:0]));
            end
            if (rst_n && $past(rst_n && state==EVENT_GATE_CHECK &&
                event_gate[39:32]==0 && !event_gate[44] && event_gate[43:40]==4'h6 &&
                event_gate[47] && event_gate[63:48]==0)) begin
                assert(state==EVENT_CODE_START);
                assert(event_pointer=={event_gate[31:16],event_gate[15:0]});
            end
            if (state==EVENT_CODE_START && owner_event_grant) assert(code_load_start);
            if (state==EVENT_FRAME_ERROR) assert(event_packet.error_present);
            if (state==IRET_CODE_START && owner_cpu_grant) assert(code_load_start);
            if (event_packet.valid) assert(event_packet.vector==event_vector_o);
            cover(event_o && event_vector_o==13 && !retire_o);
            cover(bus_owner==2 && bus_req_o && event_packet.protected_mode &&
                  memory_return==EVENT_GATE_TAIL && bus_addr_o==idt_base+{13'h0,event_vector_o,3'b000});
            cover(state==EVENT_FRAME_ERROR && event_delivery_active && memory_write);
            cover(state==IRET_COMMIT && protected_iret_active && code_load_target==2);
            cover(retire_o && retire_opcode_o==8'hea && msw[0] && cs_base_o==24'h010000);
            cover(retire_o && retire_opcode_o==8'h8e && msw[0] && segment_load_target==3 && ds_base!=0);
            cover(retire_o && retire_opcode_o==8'h8e && msw[0] && segment_load_target==0 && es_base!=0);
            cover(retire_o && retire_opcode_o==8'h8e && msw[0] && segment_load_target==2 && ss_base!=0);
            cover(bus_owner==2 && event_bus_req && bus_ready_i);
            cover(event_o && event_vector_o==8 && !retire_o && witnessed_vector_limit);
            cover(retire_o && retire_opcode_o == 8'hd7);
            cover(element_o && !retire_o && repeat_valid);
            cover(retire_o && retire_opcode_o==8'ha4 && repeat_valid);
            cover(retire_o && retire_opcode_o==8'ha6 && repeat_valid && gpr[1]!=0);
            cover(element_o && opcode==8'h6c);
            cover(retire_o && retire_opcode_o==8'h37 && gpr[0]==16'h0100);
            cover(retire_o && retire_opcode_o==8'hd4);
            cover(retire_o && opcode==8'h0f && system_opcode==1 && modrm[5:3]==0);
            cover(retire_o && opcode==8'h0f && system_opcode==1 && modrm[5:3]==2 && gdt_base!=0);
            cover(msw[3] && retire_o && opcode==8'h0f);
            cover(fault_o && fault_code_o==3);
            cover(retire_o && opcode==8'h8e && modrm[4:3]==2 && ss_base!=0);
            cover(retire_o && opcode==8'hc5 && ds_base!=0);
        end
    end
`endif

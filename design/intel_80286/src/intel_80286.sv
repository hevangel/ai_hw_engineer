// Functional 80286 core in development; see spec/memory_execution.md.
// ASSUMPTION: A1. Byte transactions and scheduling are project abstractions.
module intel_80286 (
    input logic clk, rst_n,
    input logic bus_ready_i,
    input logic [7:0] bus_rdata_i,
    input logic intr_i, nmi_i, inta_ready_i,
    input logic [7:0] inta_vector_i,
    output logic inta_req_o, nmi_pending_o, nmi_blocked_o,
    output logic bus_req_o,
    output logic [23:0] bus_addr_o,
    output logic bus_fetch_o, bus_write_o, bus_io_o,
    output logic bus_segmented_o,
    output logic [1:0] bus_segment_o, bus_kind_o,
    output logic [15:0] bus_offset_o,
    output logic [2:0] bus_size_o,
    output logic [7:0] bus_wdata_o,
    output logic halted_o, fault_o,
    output logic [1:0] fault_code_o,
    output logic retire_o,
    output logic [23:0] retire_pc_o,
    output logic [7:0] retire_opcode_o,
    output logic [127:0] regs_o,
    output logic [63:0] segs_o,
    output logic [95:0] seg_bases_o,
    output logic [63:0] seg_limits_o,
    output logic [31:0] seg_access_o,
    output logic [3:0] seg_valid_o,
    output logic [15:0] ip_o, flags_o, msw_o,
    output logic [23:0] cs_base_o,
    output logic event_o,
    output logic [7:0] event_vector_o,
    output logic event_packet_valid_o, event_packet_protected_o,
    output logic event_packet_error_valid_o, event_packet_restartable_o,
    output logic [15:0] event_packet_error_code_o,
    output logic [15:0] event_packet_saved_cs_o, event_packet_saved_ip_o,
    output logic [15:0] event_packet_saved_flags_o, event_packet_saved_sp_o,
    output logic event_packet_deferred_valid_o,
    output logic event_packet_deferred_flags_valid_o,
    output logic event_packet_deferred_register_write_o,
    output logic event_packet_deferred_sp_valid_o,
    output logic [2:0] event_packet_deferred_register_o,
    output logic [15:0] event_packet_deferred_flags_o,
    output logic [15:0] event_packet_deferred_register_value_o,
    output logic [15:0] event_packet_deferred_sp_o,
    output logic [15:0] event_packet_deferred_ip_o,
    output logic event_packet_deferred_call_o,
    output logic element_o
);
    localparam [5:0] FETCH=0, DECODE=1, IMMEDIATE=2, EXECUTE=3,
                     HALTED=4, STOPPED=5, MODRM_FETCH=6, MODRM_DECODE=7, SHIFT=8,
                     DISPLACEMENT=9, AFTER_DISP=10, PREPARE=11, BUS=12,
                     COMMIT_MEMORY=13, IO_DONE=14, PUSH_DONE=15, POP_DONE=16,
                     MULDIV_WAIT=17, FAR_CS_DONE=18, FAR_CALL_DONE=19, FAR_RETURN_DONE=20,
                     EVENT_VECTOR=21, EVENT_FLAGS=22, EVENT_CS=23, EVENT_COMMIT=24,
                     ALL_NEXT=25, ALL_COMMIT=26, ENTER_FIRST=27, ENTER_READ=28,
                     ENTER_COPY=29, ENTER_COMMIT=30, LEAVE_DONE=31,
                     STRING_START=32, STRING_FIRST=33, STRING_COMMIT=34,
                     BOUNDARY=35, EVENT_POLL=36, STRING_BOUNDARY=37, STRING_POLL=38,
                     EXT_FETCH=39, SYSTEM_DONE=40, EVENT_START=41, MEMORY_CHECK=42,
                     SEGMENT_LOAD_WAIT=43, CODE_LOAD_WAIT=44, EVENT_GATE_TAIL=45,
                     EVENT_GATE_VALIDATE=46, EVENT_CODE_START=47, EVENT_FRAME_CHECK=48,
                     EVENT_FRAME_READY=49, EVENT_FRAME_FLAGS=50, EVENT_FRAME_CS=51,
                     EVENT_FRAME_IP=52, EVENT_FRAME_ERROR=53, EVENT_PROTECTED_COMMIT=54,
                     IRET_CODE_START=55, IRET_COMMIT=56, EVENT_GATE_CHECK=57;
    logic [5:0] state, memory_return;
    typedef struct packed {
        logic valid;
        logic protected_mode;
        logic error_present;
        logic restartable;
        logic instruction_retired;
        logic [7:0] vector;
        logic [15:0] error_code;
        logic [15:0] saved_cs, saved_ip, saved_flags, saved_sp;
        logic deferred_valid, deferred_flags_valid, deferred_register_write, deferred_sp_valid;
        logic [2:0] deferred_register;
        logic [15:0] deferred_flags, deferred_register_value, deferred_sp, deferred_ip;
        logic deferred_call;
    } event_packet_t;
    event_packet_t event_packet;
    logic [15:0] gpr [0:7];
    logic [15:0] ip, cs, ds, es, ss, flags, instruction_ip;
    logic [23:0] cs_base, instruction_pc;
    logic [23:0] es_base, ss_base, ds_base;
    logic [63:0] cache_limits;
    logic [31:0] cache_access;
    logic [3:0] cache_valid;
    logic cs_trusted;
    logic [7:0] opcode, modrm;
    logic [7:0] system_opcode;
    logic system_table, extension_allowed;
    logic [15:0] msw, gdt_limit, idt_limit;
    logic [23:0] gdt_base, idt_base;
    logic [47:0] system_image;
    logic [31:0] immediate;
    logic [2:0] immediate_count, immediate_index, immediate_bytes;
    logic opcode_modrm, opcode_valid, modrm_valid, instruction_crosses_limit;
    logic undefined_encoding;
    logic binary_rm, binary_acc, group_alu, test_op, shift_op, mov_rm;
    logic incdec, unary_op, exchange_rm;
    logic wide, alu_enable, alu_write;
    logic [2:0] destination, alu_kind;
    logic [15:0] alu_lhs, alu_rhs, alu_value, alu_flags, segment_value;
    logic [4:0] shift_count, shift_remaining;
    logic [15:0] shift_value, shift_flags, shifted_value, shifted_flags;
    logic shifted_carry, shifted_overflow, shift_single;
    logic jump_taken;
    logic prefix_active, override_valid, fetch_allowed;
    logic [1:0] override_segment;
    logic [3:0] instruction_bytes;
    logic [15:0] displacement, ea_offset, rm_offset, rm_value;
    logic [1:0] rm_role;
    logic ea_stack, rm_memory, memory_destination, rm_read;
    logic [1:0] displacement_bytes, displacement_remaining;
    logic displacement_high;
    logic [4:0] remaining_bytes;
    logic [23:0] memory_address;
    logic [47:0] memory_data;
    logic [47:0] memory_result;
    logic [15:0] memory_span_delta;
    logic memory_write, memory_io;
    logic memory_precheck_only;
    logic ins_precheck_active;
    logic memory_segmented;
    logic [1:0] memory_role, memory_kind;
    logic [15:0] memory_offset;
    logic [2:0] memory_size;
    logic core_bus_req, core_bus_fetch, core_bus_write, core_bus_io, core_bus_segmented;
    logic [23:0] core_bus_addr;
    logic [1:0] core_bus_segment, core_bus_kind;
    logic [15:0] core_bus_offset;
    logic [2:0] core_bus_size;
    logic [7:0] core_bus_wdata;
    logic [25:0] core_bus_context, owner_bus_context;
    logic owner_bus_req, owner_bus_write, cpu_bus_ready, event_bus_ready, core_bus_ready;
    logic owner_cpu_grant, owner_descriptor_grant, owner_event_grant, owner_descriptor_ready;
    logic [23:0] owner_bus_addr;
    logic [7:0] owner_bus_wdata, owner_bus_rdata;
    logic [1:0] bus_owner;
    logic event_bus_path_active, event_bus_req, event_bus_claim, event_bus_release;
    logic descriptor_bus_path_active, descriptor_bus_req, descriptor_bus_write;
    logic descriptor_claim, descriptor_release;
    logic [23:0] descriptor_bus_addr;
    logic [7:0] descriptor_bus_wdata;
    logic [25:0] descriptor_bus_context;
    logic code_load_start, code_load_busy, code_load_done, code_load_req, code_load_write;
    logic code_load_fault, code_load_cache_valid, code_load_special;
    logic [7:0] code_load_fault_vector, code_load_access, code_load_bus_wdata;
    logic [15:0] code_load_fault_error, code_load_selector, code_load_limit;
    logic [15:0] code_load_request_selector, code_load_request_offset;
    logic [23:0] code_load_bus_addr, code_load_base;
    logic [47:0] code_load_special_descriptor;
    logic segment_load_start, segment_load_busy, segment_load_done, segment_load_req, segment_load_write;
    logic segment_load_fault, segment_load_cache_valid;
    logic [7:0] segment_load_fault_vector, segment_load_access, segment_load_bus_wdata;
    logic [15:0] segment_load_fault_error, segment_load_selector, segment_load_limit;
    logic [23:0] segment_load_bus_addr, segment_load_base;
    logic [1:0] segment_load_target;
    logic data_reference_allow, fetch_reference_allow;
    logic [23:0] data_reference_address, fetch_reference_address;
    // Diagnostic stop 2 is temporary; precise architectural delivery is pending.
    logic data_reference_fault, fetch_reference_fault;
    logic [7:0] data_reference_vector, fetch_reference_vector;
    logic [15:0] data_reference_error, fetch_reference_error;
    logic [2:0] memory_remaining;
    logic [2:0] memory_index;
    logic [15:0] pending_flags, pending_register_value, pending_sp, pending_ip;
    logic pending_register_write, pending_call;
    logic [2:0] pending_register;
    logic [15:0] store_value;
    logic io_op, push_op, pop_op, near_call, near_return;
    logic far_call, far_return, far_memory_pointer, immediate_imul, muldiv_op;
    logic md_done, md_fault, md_busy;
    logic [15:0] md_ax, md_dx, md_flags, md_lhs, md_rhs;
    logic [1:0] md_operation;
    logic [15:0] far_ip, far_cs;
    logic [31:0] event_pointer;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [63:0] event_gate; // Gate DPL bits are ignored for exception delivery.
    /* verilator lint_on UNUSEDSIGNAL */
    logic event_delivery_active, protected_iret_active;
    logic [1:0] code_load_target;
    logic [15:0] event_target_selector, event_target_limit, iret_saved_ip, iret_saved_cs,
                 iret_saved_flags, iret_saved_sp, iret_target_limit;
    logic [7:0] event_target_access, iret_target_access;
    logic [23:0] event_target_base, iret_target_base;
    logic [15:0] all_values [0:7];
    logic [2:0] all_index;
    logic [15:0] stack_origin, frame_pointer, frame_sp, frame_source;
    logic [4:0] frame_level, frame_index;
    logic string_op, string_compare, string_source, string_destination;
    logic repeat_valid, repeat_ne;
    logic [15:0] string_value, string_delta;
    logic decimal_op, aam_op;
    logic [2:0] decimal_operation;
    logic [15:0] decimal_ax, decimal_flags;
    logic async_valid, async_boundary, async_poll;
    logic [7:0] async_vector;
    logic halt_latch, ss_shadow, sti_shadow, instruction_ss_shadow, instruction_sti_shadow;
    logic instruction_tf, async_step;

    task automatic memory_start(input segmented, input [1:0] role, input [15:0] offset_value,
                                input [23:0] address, input writing, input io_space,
                                input [2:0] count, input [31:0] data, input [5:0] continuation);
        memory_address <= address; memory_write <= writing; memory_io <= io_space;
        memory_remaining <= count; memory_index <= 0; memory_data <= {16'h0,data};
        memory_result <= 0; memory_return <= continuation; state <= segmented ? MEMORY_CHECK : BUS;
        memory_segmented<=segmented; memory_role<=role; memory_offset<=offset_value;
        memory_size<=count; memory_span_delta<={13'h0,count}-16'd1;
        memory_kind<=writing ? 2'd1 : 2'd0;
        memory_precheck_only<=1'b0;
        retire_o <= 0;
    endtask
    task automatic enter_event(input [7:0] vector, input [15:0] saved_ip,
                               input instruction_retired, input is_fault,
                               input error_present, input [15:0] error_code);
        // ASSUMPTION A5: real-mode IVT reads precede frame writes; native
        // bus order is unverified. The packet freezes architectural context
        // and deferred effects at the event boundary before frame sequencing.
        event_packet.valid<=1'b1;
        event_packet.protected_mode<=msw[0];
        event_packet.error_present<=msw[0] && error_present;
        event_packet.restartable<=is_fault;
        event_packet.instruction_retired<=instruction_retired;
        event_packet.vector<=vector;
        event_packet.error_code<=error_code;
        event_packet.saved_cs<=cs;
        event_packet.saved_ip<=saved_ip;
        event_packet.saved_flags<=flags;
        event_packet.saved_sp<=gpr[4];
        event_packet.deferred_valid<=state==MEMORY_CHECK &&
            !(ins_precheck_active && (opcode==8'h6c || opcode==8'h6d) && memory_return==STRING_FIRST);
        event_packet.deferred_flags_valid<=state==MEMORY_CHECK && memory_return==COMMIT_MEMORY;
        event_packet.deferred_register_write<=state==MEMORY_CHECK && memory_return==COMMIT_MEMORY && pending_register_write;
        event_packet.deferred_sp_valid<=state==MEMORY_CHECK && memory_return==COMMIT_MEMORY && opcode==8'h8f;
        event_packet.deferred_register<=pending_register;
        event_packet.deferred_flags<=pending_flags;
        event_packet.deferred_register_value<=pending_register_value;
        event_packet.deferred_sp<=pending_sp;
        event_packet.deferred_ip<=pending_ip;
        event_packet.deferred_call<=pending_call;
        prefix_active<=0;
        halt_latch<=0; ss_shadow<=0; sti_shadow<=0;
        instruction_ss_shadow<=0; instruction_sti_shadow<=0;
        pending_sp<=gpr[4]-(msw[0] && error_present ? 16'd8 : 16'd6);
    endtask
    task automatic memory_store(input [15:0] data, input [15:0] new_flags,
                                input write_register, input [2:0] register_index,
                                input [15:0] register_value);
        pending_flags <= new_flags; pending_register_write <= write_register;
        pending_register <= register_index; pending_register_value <= register_value;
        memory_start(1'b1, rm_role, rm_offset, 24'd0, 1'b1, 1'b0, wide ? 3'd2 : 3'd1, {16'h0,data}, COMMIT_MEMORY);
    endtask

    function automatic [15:0] read_register(input [2:0] index, input is_word);
        if (is_word) read_register = gpr[index];
        else if (index[2]) read_register = {8'h00,gpr[{1'b0,index[1:0]}][15:8]};
        else read_register = {8'h00,gpr[{1'b0,index[1:0]}][7:0]};
    endfunction
    function automatic [15:0] merge_register(input [15:0] old_value,
                                             input high_byte, input is_word,
                                             input [15:0] value);
        if (is_word) merge_register = value;
        else if (high_byte) merge_register = {value[7:0],old_value[7:0]};
        else merge_register = {old_value[15:8],value[7:0]};
    endfunction
    function automatic condition(input [3:0] code, input cf,zf,sf,pf,oflag);
        logic base_condition;
        begin
            case (code[3:1])
                0: base_condition = oflag;
                1: base_condition = cf;
                2: base_condition = zf;
                3: base_condition = cf || zf;
                4: base_condition = sf;
                5: base_condition = pf;
                6: base_condition = sf ^ oflag;
                7: base_condition = zf || (sf ^ oflag);
                default: base_condition = 0;
            endcase
            condition = base_condition ^ code[0];
        end
    endfunction

    assign ip_o = ip;
    assign flags_o = flags;
    assign msw_o = msw;
    assign cs_base_o = cs_base;
    assign seg_bases_o={ds_base,ss_base,cs_base,es_base};
    assign seg_limits_o=cache_limits;
    assign seg_access_o=cache_access;
    assign seg_valid_o=cache_valid;
    assign segs_o = {ds,ss,cs,es};
    for (genvar r=0; r<8; r=r+1) begin : pack_registers
        assign regs_o[r*16 +: 16] = gpr[r];
    end
    assign halted_o = halt_latch;
    assign event_vector_o=event_packet.vector;
    assign event_packet_valid_o=event_packet.valid;
    assign event_packet_protected_o=event_packet.protected_mode;
    assign event_packet_error_valid_o=event_packet.error_present;
    assign event_packet_error_code_o=event_packet.error_code;
    assign event_packet_restartable_o=event_packet.restartable;
    assign event_packet_saved_cs_o=event_packet.saved_cs;
    assign event_packet_saved_ip_o=event_packet.saved_ip;
    assign event_packet_saved_flags_o=event_packet.saved_flags;
    assign event_packet_saved_sp_o=event_packet.saved_sp;
    assign event_packet_deferred_valid_o=event_packet.deferred_valid;
    assign event_packet_deferred_flags_valid_o=event_packet.deferred_flags_valid;
    assign event_packet_deferred_register_write_o=event_packet.deferred_register_write;
    assign event_packet_deferred_sp_valid_o=event_packet.deferred_sp_valid;
    assign event_packet_deferred_register_o=event_packet.deferred_register;
    assign event_packet_deferred_flags_o=event_packet.deferred_flags;
    assign event_packet_deferred_register_value_o=event_packet.deferred_register_value;
    assign event_packet_deferred_sp_o=event_packet.deferred_sp;
    assign event_packet_deferred_ip_o=event_packet.deferred_ip;
    assign event_packet_deferred_call_o=event_packet.deferred_call;
    assign fault_o = state == STOPPED;
    assign fetch_allowed = !prefix_active || (instruction_bytes < 10 &&
                           ({1'b0,instruction_ip}+{13'b0,instruction_bytes}) <= 17'h0ffff);
    assign extension_allowed = instruction_bytes<10 &&
        ({1'b0,instruction_ip}+{13'b0,instruction_bytes})<=17'h0ffff;
    intel_80286_cached_reference data_reference(.bases_i(seg_bases_o),.limits_i(cache_limits),
        .access_i(cache_access),.usable_i(cache_valid),.role_i(memory_role),.kind_i(memory_kind),
        .offset_i(memory_offset),.last_delta_i(memory_span_delta),
        .trusted_cs_i(cs_trusted),.allow_o(data_reference_allow),.fault_o(data_reference_fault),
        .fault_vector_o(data_reference_vector),.fault_error_o(data_reference_error),.physical_o(data_reference_address));
    intel_80286_cached_reference fetch_reference(.bases_i(seg_bases_o),.limits_i(cache_limits),
        .access_i(cache_access),.usable_i(cache_valid),.role_i(2'd1),.kind_i(2'd2),
        .offset_i(ip),.last_delta_i(16'd0),.trusted_cs_i(cs_trusted),
        .allow_o(fetch_reference_allow),.fault_o(fetch_reference_fault),
        .fault_vector_o(fetch_reference_vector),.fault_error_o(fetch_reference_error),
        .physical_o(fetch_reference_address));
    assign core_bus_req = rst_n && (((state == FETCH && fetch_allowed) ||
        (state==EXT_FETCH && extension_allowed) || state == IMMEDIATE || state == MODRM_FETCH || state == DISPLACEMENT) &&
        fetch_reference_allow || state == BUS);
    assign core_bus_addr = state == BUS ? memory_address : fetch_reference_address;
    assign core_bus_segmented=state!=BUS || memory_segmented;
    assign core_bus_segment=state==BUS ? memory_role : 2'd1;
    assign core_bus_kind=state==BUS ? memory_kind : 2'd2;
    assign core_bus_offset=state==BUS ? memory_offset+{13'h0,memory_index} : ip;
    assign core_bus_size=state==BUS ? memory_size : 3'd1;
    assign core_bus_fetch = state != BUS;
    assign core_bus_write = state == BUS && memory_write;
    assign core_bus_io = state == BUS && memory_io;
    // Define all selector encodings, including unreachable indices 6/7, so
    // formal AIG export does not introduce an out-of-range part-select X.
    always_comb begin
        case (memory_index)
            0: core_bus_wdata=memory_data[7:0];
            1: core_bus_wdata=memory_data[15:8];
            2: core_bus_wdata=memory_data[23:16];
            3: core_bus_wdata=memory_data[31:24];
            4: core_bus_wdata=memory_data[39:32];
            5: core_bus_wdata=memory_data[47:40];
            default: core_bus_wdata=0;
        endcase
    end
    assign core_bus_context={core_bus_offset,core_bus_size,core_bus_kind,
                             core_bus_segment,core_bus_segmented,core_bus_io,core_bus_fetch};
    assign event_bus_path_active =
        (!event_packet.protected_mode &&
         (state==EVENT_START || state==EVENT_VECTOR || state==EVENT_FLAGS || state==EVENT_CS ||
          state==EVENT_COMMIT || ((state==MEMORY_CHECK || state==BUS) &&
          (memory_return==EVENT_VECTOR || memory_return==EVENT_FLAGS ||
           memory_return==EVENT_CS || memory_return==EVENT_COMMIT)))) ||
        (event_packet.protected_mode &&
          (state==EVENT_START || state==EVENT_GATE_TAIL || state==EVENT_GATE_VALIDATE || state==EVENT_GATE_CHECK ||
          state==EVENT_CODE_START || state==EVENT_FRAME_CHECK || state==EVENT_FRAME_READY ||
          state==EVENT_FRAME_FLAGS || state==EVENT_FRAME_CS || state==EVENT_FRAME_IP ||
          state==EVENT_FRAME_ERROR || state==EVENT_PROTECTED_COMMIT ||
          ((state==MEMORY_CHECK || state==BUS) && event_delivery_active &&
           (memory_return==EVENT_GATE_TAIL || memory_return==EVENT_GATE_VALIDATE ||
            memory_return==EVENT_FRAME_READY || memory_return==EVENT_FRAME_FLAGS ||
            memory_return==EVENT_FRAME_CS || memory_return==EVENT_FRAME_IP ||
            memory_return==EVENT_FRAME_ERROR || memory_return==EVENT_PROTECTED_COMMIT))));
    assign event_bus_req=core_bus_req && event_bus_path_active;
    assign event_bus_claim=event_bus_path_active && owner_cpu_grant;
    assign event_bus_release=state==EVENT_COMMIT ||
        (state==EVENT_CODE_START && owner_event_grant) ||
        state==EVENT_PROTECTED_COMMIT || (state==STOPPED && bus_owner==2);
    assign code_load_start=(state==EXECUTE && msw[0] &&
        (opcode==8'hea || (opcode==8'hff && modrm[5:3]==5))) ||
        (state==EVENT_CODE_START && owner_event_grant) ||
        (state==IRET_CODE_START && owner_cpu_grant);
    assign segment_load_start=state==EXECUTE && msw[0] && opcode==8'h8e;
    assign descriptor_bus_path_active=state==SEGMENT_LOAD_WAIT || state==CODE_LOAD_WAIT;
    // Drop the level claim when the completed engine's release is consumed;
    // otherwise the CPU owner can re-acquire DESCRIPTOR as the wait state exits.
    assign descriptor_claim=(descriptor_bus_path_active && !descriptor_release) ||
                            code_load_start || segment_load_start;
    assign descriptor_release=(code_load_done || segment_load_done) &&
                              !code_load_busy && !segment_load_busy;
    always_comb begin
        descriptor_bus_req=1'b0;
        descriptor_bus_addr=24'd0;
        descriptor_bus_write=1'b0;
        descriptor_bus_wdata=8'd0;
        if (code_load_busy) begin
            descriptor_bus_req=code_load_req;
            descriptor_bus_addr=code_load_bus_addr;
            descriptor_bus_write=code_load_write;
            descriptor_bus_wdata=code_load_bus_wdata;
        end else if (segment_load_busy) begin
            descriptor_bus_req=segment_load_req;
            descriptor_bus_addr=segment_load_bus_addr;
            descriptor_bus_write=segment_load_write;
            descriptor_bus_wdata=segment_load_bus_wdata;
        end
    end
    assign descriptor_bus_context={descriptor_bus_addr[15:0],3'd1,2'd3,2'd0,
                                   1'b0,1'b0,1'b0};
    intel_80286_code_load code_load_unit(
        .clk(clk),.rst_n(rst_n),.start_i(code_load_start),
        .selector_i(state==EVENT_CODE_START ? event_pointer[31:16] :
                    state==IRET_CODE_START ? iret_saved_cs :
                    opcode==8'hea ? immediate[31:16] : memory_result[31:16]),
        .offset_i(state==EVENT_CODE_START ? event_pointer[15:0] :
                  state==IRET_CODE_START ? iret_saved_ip :
                  opcode==8'hea ? immediate[15:0] : memory_result[15:0]),
        .gdt_limit_i(gdt_limit),.ldt_limit_i(16'd0),.gdt_base_i(gdt_base),.ldt_base_i(24'd0),
        .cpl_i(cs[1:0]),.call_i(1'b0),.stack_ok_i(1'b1),.ldt_valid_i(1'b0),
        .busy_o(code_load_busy),.done_o(code_load_done),
        .bus_req_o(code_load_req),.bus_write_o(code_load_write),
        .bus_addr_o(code_load_bus_addr),.bus_wdata_o(code_load_bus_wdata),
        .bus_ready_i(owner_descriptor_ready),.bus_rdata_i(owner_bus_rdata),
        .fault_o(code_load_fault),.cache_valid_o(code_load_cache_valid),.special_o(code_load_special),
        .fault_vector_o(code_load_fault_vector),.access_o(code_load_access),
        .fault_error_o(code_load_fault_error),.selector_o(code_load_selector),.limit_o(code_load_limit),
        .request_selector_o(code_load_request_selector),.request_offset_o(code_load_request_offset),
        .base_o(code_load_base),.special_descriptor_o(code_load_special_descriptor));
    intel_80286_segment_load segment_load_unit(
        .clk(clk),.rst_n(rst_n),.start_i(segment_load_start),.selector_i(rm_value),
        .gdt_limit_i(gdt_limit),.ldt_limit_i(16'd0),.gdt_base_i(gdt_base),.ldt_base_i(24'd0),
        .cpl_i(cs[1:0]),.stack_i(modrm[4:3]==2),.ldt_valid_i(1'b0),
        .busy_o(segment_load_busy),.done_o(segment_load_done),
        .bus_req_o(segment_load_req),.bus_write_o(segment_load_write),
        .bus_addr_o(segment_load_bus_addr),.bus_wdata_o(segment_load_bus_wdata),
        .bus_ready_i(owner_descriptor_ready),.bus_rdata_i(owner_bus_rdata),
        .fault_o(segment_load_fault),.cache_valid_o(segment_load_cache_valid),
        .fault_vector_o(segment_load_fault_vector),.access_o(segment_load_access),
        .fault_error_o(segment_load_fault_error),.selector_o(segment_load_selector),
        .limit_o(segment_load_limit),.base_o(segment_load_base));
    intel_80286_bus_owner #(.FORMAL_PROPERTIES(1'b1),.CONTEXT_WIDTH(26)) bus_owner_unit(
        .clk(clk),.rst_n(rst_n),
        .cpu_req_i(core_bus_req && !event_bus_path_active && !descriptor_bus_path_active),.cpu_addr_i(core_bus_addr),
        .cpu_write_i(core_bus_write),.cpu_wdata_i(core_bus_wdata),.cpu_context_i(core_bus_context),
        .descriptor_claim_i(descriptor_claim),.descriptor_release_i(descriptor_release),
        .descriptor_req_i(descriptor_bus_req),.descriptor_addr_i(descriptor_bus_addr),
        .descriptor_write_i(descriptor_bus_write),.descriptor_wdata_i(descriptor_bus_wdata),
        .descriptor_context_i(descriptor_bus_context),
        .event_claim_i(event_bus_claim),.event_release_i(event_bus_release),.event_req_i(event_bus_req),
        .event_addr_i(core_bus_addr),.event_write_i(core_bus_write),.event_wdata_i(core_bus_wdata),
        .event_context_i(core_bus_context),.bus_ready_i(bus_ready_i),.bus_rdata_i(bus_rdata_i),
        .bus_req_o(owner_bus_req),.bus_addr_o(owner_bus_addr),.bus_write_o(owner_bus_write),
        .bus_wdata_o(owner_bus_wdata),.bus_context_o(owner_bus_context),
        .cpu_grant_o(owner_cpu_grant),.descriptor_grant_o(owner_descriptor_grant),
        .event_grant_o(owner_event_grant),.cpu_ready_o(cpu_bus_ready),
        .descriptor_ready_o(owner_descriptor_ready),.event_ready_o(event_bus_ready),
        .bus_rdata_o(owner_bus_rdata),
        .owner_o(bus_owner));
    assign core_bus_ready=(owner_cpu_grant && cpu_bus_ready) ||
                          (owner_descriptor_grant && owner_descriptor_ready) ||
                          (owner_event_grant && event_bus_ready);
    assign bus_req_o=owner_bus_req;
    assign bus_addr_o=owner_bus_addr;
    assign bus_write_o=owner_bus_write;
    assign bus_wdata_o=owner_bus_wdata;
    assign bus_fetch_o=owner_bus_context[0];
    assign bus_io_o=owner_bus_context[1];
    assign bus_segmented_o=owner_bus_context[2];
    assign bus_segment_o=owner_bus_context[4:3];
    assign bus_kind_o=owner_bus_context[6:5];
    assign bus_size_o=owner_bus_context[9:7];
    assign bus_offset_o=owner_bus_context[25:10];
    intel_80286_ea effective_address(.address_mode_i({modrm[7:6],modrm[2:0]}),.bx_i(gpr[3]),.bp_i(gpr[5]),
        .si_i(gpr[6]),.di_i(gpr[7]),.displacement_i(displacement),.offset_o(ea_offset),
        .stack_o(ea_stack),.displacement_bytes_o(displacement_bytes));
    assign rm_memory = opcode_modrm && modrm[7:6] != 3;
    assign rm_value = rm_memory ? memory_result[15:0] : read_register(modrm[2:0],wide);

    always_comb begin
        binary_rm = opcode <= 8'h3b && opcode[2:0] <= 3;
        binary_acc = opcode <= 8'h3d && (opcode[2:0] == 4 || opcode[2:0] == 5);
        group_alu = opcode == 8'h80 || opcode == 8'h81 || opcode == 8'h83;
        test_op = opcode == 8'h84 || opcode == 8'h85 || opcode == 8'ha8 || opcode == 8'ha9 ||
                  // ASSUMPTION: A15. Physical Harris-286 F6/F7 /1 captures
                  // establish a TEST alias despite Intel Appendix B's #UD example.
                  ((opcode == 8'hf6 || opcode == 8'hf7) && modrm[5:3] <= 1);
        shift_op = opcode == 8'hc0 || opcode == 8'hc1 || (opcode >= 8'hd0 && opcode <= 8'hd3);
        mov_rm = opcode >= 8'h88 && opcode <= 8'h8b;
        exchange_rm = opcode == 8'h86 || opcode == 8'h87;
        incdec = (opcode >= 8'h40 && opcode <= 8'h4f) || opcode == 8'hfe || opcode == 8'hff;
        unary_op = opcode == 8'hf6 || opcode == 8'hf7;
        immediate_imul = opcode == 8'h69 || opcode == 8'h6b;
        aam_op=opcode==8'hd4;
        decimal_op=opcode==8'h27 || opcode==8'h2f || opcode==8'h37 || opcode==8'h3f || opcode==8'hd5;
        case(opcode)
            8'h27: decimal_operation=0;
            8'h2f: decimal_operation=1;
            8'h37: decimal_operation=2;
            8'h3f: decimal_operation=3;
            default: decimal_operation=4;
        endcase
        muldiv_op = immediate_imul || (unary_op && modrm[5:3]>=4) || aam_op;
        far_call = opcode == 8'h9a || (opcode == 8'hff && modrm[5:3]==3);
        far_return = opcode == 8'hca || opcode == 8'hcb || opcode == 8'hcf;
        far_memory_pointer = opcode == 8'hff && (modrm[5:3]==3 || modrm[5:3]==5);
        string_op = (opcode>=8'ha4 && opcode<=8'ha7) || (opcode>=8'haa && opcode<=8'haf) ||
                    (opcode>=8'h6c && opcode<=8'h6f);
        string_compare = opcode==8'ha6 || opcode==8'ha7 || opcode==8'hae || opcode==8'haf;
        string_source = (opcode>=8'ha4 && opcode<=8'ha7) || opcode==8'hac || opcode==8'had ||
                        opcode==8'h6e || opcode==8'h6f;
        string_destination = string_op && opcode!=8'hac && opcode!=8'had && opcode!=8'h6e && opcode!=8'h6f;
        string_delta = flags[10] ? (wide ? 16'hfffe : 16'hffff) : (wide ? 16'd2 : 16'd1);
        io_op = (opcode >= 8'he4 && opcode <= 8'he7) || (opcode >= 8'hec && opcode <= 8'hef);
        near_call = opcode == 8'he8 || (opcode == 8'hff && modrm[5:3] == 2);
        near_return = opcode == 8'hc2 || opcode == 8'hc3;
        push_op = (opcode >= 8'h50 && opcode <= 8'h57) || opcode == 8'h06 || opcode == 8'h0e ||
                  opcode == 8'h16 || opcode == 8'h1e || opcode == 8'h68 || opcode == 8'h6a ||
                  opcode == 8'h9c || (opcode == 8'hff && modrm[5:3] == 6) || near_call;
        pop_op = (opcode >= 8'h58 && opcode <= 8'h5f) || opcode == 8'h07 || opcode == 8'h17 ||
                 opcode == 8'h1f || opcode == 8'h9d || opcode == 8'h8f || near_return;
        opcode_modrm = binary_rm || group_alu || mov_rm || exchange_rm || shift_op || unary_op ||
                       opcode == 8'h84 || opcode == 8'h85 || opcode == 8'h8c || opcode == 8'h8e ||
                       opcode == 8'hfe || opcode == 8'hff || opcode == 8'h8d || opcode == 8'h8f ||
                       opcode == 8'hc4 || opcode == 8'hc5 || opcode == 8'hc6 || opcode == 8'hc7 || opcode == 8'h62 || immediate_imul;
        if (opcode==8'h0f) opcode_modrm=system_opcode==8'h01;
        system_table=opcode==8'h0f && system_opcode==8'h01 && modrm[5:3]<4;
        opcode_valid = opcode_modrm || binary_acc || (opcode >= 8'h40 && opcode <= 8'h4f) ||
                       (opcode >= 8'h70 && opcode <= 8'h7f) || (opcode >= 8'h90 && opcode <= 8'h99) ||
                       opcode == 8'h9e || opcode == 8'h9f || opcode == 8'ha8 || opcode == 8'ha9 ||
                       (opcode >= 8'hb0 && opcode <= 8'hbf) || (opcode >= 8'he0 && opcode <= 8'he3) ||
                       (opcode >= 8'ha0 && opcode <= 8'ha3) || io_op || push_op || pop_op || string_op || decimal_op || aam_op;
        case (opcode)
            8'h0f: opcode_valid=system_opcode==8'h01 || system_opcode==8'h06;
            8'hea,8'he9,8'heb,8'hf4,8'hf5,8'hf8,8'hf9,8'hfa,8'hfb,8'hfc,8'hfd,
            8'h60,8'h61,8'h9a,8'hca,8'hcb,8'hcc,8'hcd,8'hce,8'hcf,8'hc8,8'hc9,8'hd7: opcode_valid = 1;
            default: begin end
        endcase
        if (repeat_valid && (!string_op || (repeat_ne && !string_compare) || opcode==8'hac || opcode==8'had))
            opcode_valid=0;
        modrm_valid = 1;
        if ((opcode == 8'h8d || opcode == 8'hc4 || opcode == 8'hc5 || opcode == 8'h62) && modrm[7:6] == 3) modrm_valid = 0;
        if ((opcode == 8'h8f || opcode == 8'hc6 || opcode == 8'hc7) && modrm[5:3] != 0) modrm_valid = 0;
        if (shift_op && modrm[5:3] == 6) modrm_valid = 0;
        if (opcode == 8'hfe && modrm[5:3] > 1) modrm_valid = 0;
        if (opcode == 8'hff && (modrm[5:3] == 7 || (far_memory_pointer && modrm[7:6]==3))) modrm_valid = 0;
        if ((opcode == 8'h8c || opcode == 8'h8e) && modrm[5]) modrm_valid = 0;
        if (opcode == 8'h8e && modrm[4:3] == 1) modrm_valid = 0;
        if (opcode==8'h0f && system_opcode==8'h01 &&
            (modrm[5:3]==5 || modrm[5:3]==7 || (modrm[5:3]<4 && modrm[7:6]==3))) modrm_valid=0;
        // Intel 9.6.1 / Appendix B #UD: classify architectural invalidity
        // separately from unimplemented features and undocumented aliases.
        undefined_encoding = opcode==8'h64 || opcode==8'h63 ||
            (opcode==8'h0f && (system_opcode==8'hff || system_opcode==8'h00 ||
                              system_opcode==8'h02 || system_opcode==8'h03)) ||
            (state==MODRM_DECODE && !modrm_valid && !(shift_op && modrm[5:3]==6));
        immediate_bytes = 0;
        if ((opcode >= 8'hb0 && opcode <= 8'hb7) || (opcode >= 8'h70 && opcode <= 8'h7f) ||
            (opcode >= 8'he0 && opcode <= 8'he3) || opcode == 8'heb || opcode == 8'h80 ||
            opcode == 8'h83 || opcode == 8'hc0 || opcode == 8'hc1) immediate_bytes = 1;
        if ((opcode >= 8'hb8 && opcode <= 8'hbf) || opcode == 8'he9 || opcode == 8'h81 || opcode == 8'he8 ||
            opcode == 8'h68 || opcode == 8'hc2 || (opcode >= 8'ha0 && opcode <= 8'ha3)) immediate_bytes = 2;
        if ((opcode >= 8'he4 && opcode <= 8'he7) || opcode == 8'h6a) immediate_bytes = 1;
        if (opcode == 8'hc6 || opcode == 8'hc7) immediate_bytes = opcode[0] ? 2 : 1;
        if (opcode == 8'h69 || opcode == 8'hca) immediate_bytes = 2;
        if (opcode == 8'h6b || opcode == 8'hcd) immediate_bytes = 1;
        if (opcode == 8'hd4 || opcode == 8'hd5) immediate_bytes = 1;
        if (opcode == 8'hc8) immediate_bytes = 3;
        if (opcode == 8'hea || opcode == 8'h9a) immediate_bytes = 4;
        if (binary_acc || opcode == 8'ha8 || opcode == 8'ha9 || (unary_op && test_op))
            immediate_bytes = opcode[0] ? 2 : 1;
        remaining_bytes = {2'b0,immediate_bytes};
        if (state == DECODE && opcode_modrm) remaining_bytes = 1;
        if (state == MODRM_DECODE) remaining_bytes = {3'b0,displacement_bytes} + {2'b0,immediate_bytes};
        instruction_crosses_limit = ({1'b0,instruction_ip} + {13'b0,instruction_bytes} +
                                     {12'b0,remaining_bytes}) > 17'h10000;
    end

    always_comb begin
        wide = opcode[0];
        if (opcode >= 8'h40 && opcode <= 8'h4f) wide = 1;
        if (opcode == 8'h8c || opcode == 8'h8e) wide = 1;
        if (opcode==8'h0f) wide=1;
        if (opcode == 8'h8d || opcode == 8'h8f || opcode == 8'hc4 || opcode == 8'hc5) wide = 1;
        if (immediate_imul || opcode == 8'h62) wide = 1;
        if (aam_op) wide=0;
        if (opcode >= 8'hb0 && opcode <= 8'hbf) wide = opcode[3];
        destination = modrm[2:0];
        if ((binary_rm || mov_rm) && opcode[1]) destination = modrm[5:3];
        if (binary_acc || opcode == 8'ha8 || opcode == 8'ha9) destination = 0;
        if (opcode >= 8'h40 && opcode <= 8'h4f) destination = opcode[2:0];
        alu_kind = opcode[5:3];
        if (group_alu) alu_kind = modrm[5:3];
        if (test_op) alu_kind = 4;
        if (incdec) alu_kind = ((opcode >= 8'h40 && opcode <= 8'h4f) ? opcode[3] : modrm[3]) ? 5 : 0;
        if (unary_op && modrm[5:3] == 3) alu_kind = 5;
        alu_lhs = read_register(destination,wide);
        if (rm_memory && !((binary_rm || mov_rm) && opcode[1])) alu_lhs = rm_value;
        alu_rhs = read_register(modrm[5:3],wide);
        if ((binary_rm || mov_rm) && opcode[1]) alu_rhs = rm_value;
        if (binary_acc || group_alu || opcode == 8'ha8 || opcode == 8'ha9 || (unary_op && test_op))
            alu_rhs = opcode == 8'h83 ? {{8{immediate[7]}},immediate[7:0]} : immediate[15:0];
        if (incdec) alu_rhs = 1;
        if (unary_op && modrm[5:3] == 3) begin alu_lhs = 0; alu_rhs = rm_value; end
        alu_enable = binary_rm || binary_acc || group_alu || test_op || (incdec && (!opcode_modrm || modrm[5:3] <= 1)) ||
                     (unary_op && modrm[5:3] == 3);
        alu_write = alu_enable && !test_op && !((binary_rm || binary_acc || group_alu) && alu_kind == 7);
        case (modrm[4:3])
            0: segment_value = es;
            1: segment_value = cs;
            2: segment_value = ss;
            3: segment_value = ds;
            default: segment_value = 0;
        endcase
        shift_count = opcode[7:4] == 4'hc ? immediate[4:0] : (opcode[1] ? gpr[1][4:0] : 5'd1);
        shifted_flags = shift_flags;
        shifted_flags[0] = shifted_carry;
        // ASSUMPTION: A3. Preserve undefined OF/AF for multi-bit shifts.
        if (shift_single) shifted_flags[11] = shifted_overflow;
        if (modrm[5:3] >= 4) begin
            shifted_flags[7] = wide ? shifted_value[15] : shifted_value[7];
            shifted_flags[6] = shifted_value == 0;
            shifted_flags[2] = ~^shifted_value[7:0];
        end
        jump_taken = condition(opcode[3:0],flags[0],flags[6],flags[7],flags[2],flags[11]);
        if (opcode >= 8'he0 && opcode <= 8'he3) begin
            case (opcode[1:0])
                0: jump_taken = gpr[1] != 1 && !flags[6];
                1: jump_taken = gpr[1] != 1 && flags[6];
                2: jump_taken = gpr[1] != 1;
                3: jump_taken = gpr[1] == 0;
                default: jump_taken = 0;
            endcase
        end
        memory_destination = rm_memory && !((binary_rm || mov_rm) && opcode[1]) &&
                             opcode != 8'h8d && opcode != 8'h8e && opcode != 8'hc4 && opcode != 8'hc5;
        rm_read = rm_memory && opcode != 8'h8d && opcode != 8'h8f && opcode != 8'h8c &&
                  opcode != 8'hc6 && opcode != 8'hc7 && !(mov_rm && !opcode[1]);
        if (opcode==8'h0f) rm_read=rm_memory && (modrm[5:3]==2 || modrm[5:3]==3 || modrm[5:3]==6);
        // ASSUMPTION: A12. Pinned 286 SGDT/SIDT unused byte is FF; see system spec.
        system_image=modrm[3] ? {8'hff,idt_base,idt_limit} : {8'hff,gdt_base,gdt_limit};
        store_value = alu_rhs;
        if (alu_enable) store_value = alu_value;
        if (unary_op && modrm[5:3] == 2) store_value = ~rm_value;
        if (opcode == 8'h8c) store_value = segment_value;
        if (opcode == 8'hc6 || opcode == 8'hc7) store_value = immediate[15:0];
        md_operation=immediate_imul ? 2'd1 : modrm[4:3];
        md_lhs=immediate_imul ? rm_value : gpr[0];
        md_rhs=immediate_imul ? (opcode==8'h6b ? {{8{immediate[7]}},immediate[7:0]} : immediate[15:0]) : rm_value;
        // ASSUMPTION: A7. General AAM bases, including zero-base #DE, follow the pinned external artifact.
        if (aam_op) begin md_operation=2; md_lhs={8'h0,gpr[0][7:0]}; md_rhs={8'h0,immediate[7:0]}; end
        if (string_compare) begin
            alu_kind=5;
            alu_lhs=(opcode==8'ha6 || opcode==8'ha7) ? memory_result[15:0] : gpr[0];
            alu_rhs=(opcode==8'ha6 || opcode==8'ha7) ? string_value : memory_result[15:0];
        end
    end
    intel_80286_decimal decimal_adjust(.operation_i(decimal_operation),.ax_i(gpr[0]),.flags_i(flags),
                                      .base_i(immediate[7:0]),.ax_o(decimal_ax),.flags_o(decimal_flags));
    intel_80286_alu alu(.operation_i(alu_kind),.wide_i(wide),.lhs_i(alu_lhs),.rhs_i(alu_rhs),
                        .flags_i(flags),.value_o(alu_value),.flags_o(alu_flags));
    intel_80286_shift shift_step(.operation_i(modrm[5:3]),.wide_i(wide),.carry_i(shift_flags[0]),
                                .value_i(shift_value),.value_o(shifted_value),
                                .carry_o(shifted_carry),.overflow_o(shifted_overflow));
    intel_80286_muldiv multiply_divide(.clk(clk),.rst_n(rst_n),.start_i(state==EXECUTE && muldiv_op),
        .wide_i(wide),.operation_i(md_operation),.ax_i(md_lhs),.dx_i(gpr[2]),.operand_i(md_rhs),.flags_i(flags),
        .done_o(md_done),.fault_o(md_fault),.busy_o(md_busy),.ax_o(md_ax),.dx_o(md_dx),.flags_o(md_flags));

    assign async_boundary = state==BOUNDARY || state==STRING_BOUNDARY;
    assign async_poll = state==EVENT_POLL || state==STRING_POLL;
    // ASSUMPTION: A10. Pinned 86Box clears a sampled TF request on INT/fault.
    // POPF/IRET change the next instruction's sample, not this one's sample.
    assign async_step = instruction_tf &&
        ((state==BOUNDARY && retire_o && !event_o) ||
         (state==STRING_BOUNDARY && element_o));
    intel_80286_event_control event_control(.clk(clk),.rst_n(rst_n),
        .boundary_i(async_boundary),
        .inhibit_i(ss_shadow || (state==STRING_BOUNDARY && instruction_ss_shadow)),
        .step_i(async_step),
        .if_i(flags[9] && !sti_shadow && !(state==STRING_BOUNDARY && instruction_sti_shadow)),
        .intr_i(intr_i),.nmi_i(nmi_i),
        .iret_i((state==FAR_RETURN_DONE && opcode==8'hcf && !msw[0]) ||
                (state==IRET_COMMIT && protected_iret_active)),
        .ack_ready_i(inta_ready_i),.ack_vector_i(inta_vector_i),.ack_req_o(inta_req_o),
        .event_valid_o(async_valid),.event_vector_o(async_vector),.event_ready_i(async_poll),
        .nmi_pending_o(nmi_pending_o),.nmi_blocked_o(nmi_blocked_o));

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= BOUNDARY;
            ip <= 16'hfff0; cs <= 16'hf000; cs_base <= 24'hff0000;
            ds <= 0; es <= 0; ss <= 0; flags <= 16'h0002;
            es_base<=0; ss_base<=0; ds_base<=0;
            cache_limits<=64'hffffffffffffffff;
            // ASSUMPTION: A14. Pinned MAME real-cache attributes; not native bit evidence.
            cache_access<=32'h93939393; cache_valid<=4'hf;
            // ASSUMPTION: A2. Deterministic reset, not an Intel GPR guarantee.
            for (integer r=0; r<8; r=r+1) gpr[r] <= 0;
            instruction_ip <= 0; instruction_pc <= 0; opcode <= 0; modrm <= 0;
            system_opcode<=0; msw<=16'hfff0; idt_base<=0; idt_limit<=16'h03ff;
            // ASSUMPTION: A12. GDTR reset payload is deterministic, not Intel-defined.
            gdt_base<=0; gdt_limit<=0;
            immediate <= 0; immediate_count <= 0; immediate_index <= 0;
            retire_o <= 0; retire_pc_o <= 0; retire_opcode_o <= 0; fault_code_o <= 0;
            shift_value <= 0; shift_flags <= 0; shift_remaining <= 0; shift_single <= 0;
            prefix_active <= 0; override_valid <= 0; override_segment <= 0; instruction_bytes <= 0;
            displacement <= 0; displacement_remaining <= 0; displacement_high <= 0;
            rm_offset <= 0; rm_role <= 0; cs_trusted<=1;
            memory_address <= 0; memory_data <= 0; memory_result <= 0;
            memory_write <= 0; memory_io <= 0; memory_remaining <= 0; memory_index <= 0; memory_return <= FETCH;
            memory_segmented<=0; memory_role<=0; memory_kind<=0; memory_offset<=0; memory_size<=0;
            memory_span_delta<=0; memory_precheck_only<=0;
            ins_precheck_active<=0;
            pending_flags <= 0; pending_register_write <= 0; pending_register <= 0;
            pending_register_value <= 0; pending_sp <= 0; pending_ip <= 0; pending_call <= 0;
            far_ip<=0; far_cs<=0; event_pointer<=0; event_gate<=0;
            event_delivery_active<=0; protected_iret_active<=0; code_load_target<=0;
            event_target_selector<=0; event_target_limit<=0; event_target_access<=0; event_target_base<=0;
            iret_saved_ip<=0; iret_saved_cs<=0; iret_saved_flags<=0; iret_saved_sp<=0;
            iret_target_limit<=0; iret_target_access<=0; iret_target_base<=0;
            segment_load_target<=0;
            event_packet<='0;
            event_o<=0;
            halt_latch<=0; ss_shadow<=0; sti_shadow<=0;
            instruction_ss_shadow<=0; instruction_sti_shadow<=0;
            instruction_tf<=0;
            all_index<=0; stack_origin<=0; frame_pointer<=0; frame_sp<=0; frame_source<=0;
            frame_level<=0; frame_index<=0;
            repeat_valid<=0; repeat_ne<=0; string_value<=0; element_o<=0;
            for (integer r=0;r<8;r=r+1) all_values[r]<=0;
        end else begin
            retire_o <= 0;
            event_o <= 0;
            element_o <= 0;
            if (fetch_reference_fault && (state==FETCH || state==EXT_FETCH ||
                state==IMMEDIATE || state==MODRM_FETCH || state==DISPLACEMENT)) begin
                if (msw[0]) begin
                    enter_event(fetch_reference_vector,
                                state==FETCH && !prefix_active ? ip : instruction_ip,
                                1'b0,1'b1,1'b1,fetch_reference_error);
                    state<=EVENT_START;
                end else begin
                    state<=STOPPED; fault_code_o<=2;
                    ip<=state==FETCH && !prefix_active ? ip : instruction_ip;
                end
            end else case (state)
                BOUNDARY: state<=EVENT_POLL;
                STRING_BOUNDARY: state<=STRING_POLL;
                EVENT_POLL,STRING_POLL: begin
                    if (async_valid) begin
                        enter_event(async_vector,state==STRING_POLL ? instruction_ip : ip,
                                    1'b0,1'b0,1'b0,16'd0);
                        state<=EVENT_START; retire_o<=0;
                    end
                    else if (!inta_req_o) begin
                        if (state==STRING_POLL) state<=STRING_START;
                        else if (halt_latch) state<=HALTED;
                        else state<=FETCH;
                    end
                end
                FETCH: begin
                    if (prefix_active && (instruction_bytes >= 10 ||
                        ({1'b0,instruction_ip}+{13'b0,instruction_bytes}) > 17'h0ffff)) begin
                        // ASSUMPTION A16: native 286 overlength erratum uses #13.
                        if (instruction_bytes>=10) begin enter_event(13,instruction_ip,1'b0,1'b1,1'b1,16'd0); state<=EVENT_START; end
                        else begin state<=STOPPED; ip<=instruction_ip; fault_code_o<=2; end
                    end else if (core_bus_ready) begin
                        if (!prefix_active) begin
                            event_packet.valid<=0;
                            instruction_tf<=flags[8];
                            instruction_ss_shadow<=ss_shadow; instruction_sti_shadow<=sti_shadow;
                            ss_shadow<=0; sti_shadow<=0;
                            instruction_ip <= ip; instruction_pc <= bus_addr_o;
                            instruction_bytes <= 1; override_valid <= 0;
                            repeat_valid<=0; repeat_ne<=0;
                        end else instruction_bytes <= instruction_bytes + 4'd1;
                        ip <= ip + 16'd1;
                        if (owner_bus_rdata == 8'h26 || owner_bus_rdata == 8'h2e || owner_bus_rdata == 8'h36 || owner_bus_rdata == 8'h3e) begin
                            prefix_active <= 1; override_valid <= 1; override_segment <= owner_bus_rdata[4:3];
                        end else if (owner_bus_rdata==8'hf0) begin
                            // A1: consume the real-mode LOCK prefix on the serialized
                            // functional bus. Native LOCK output/arbitration is pending.
                            prefix_active<=1;
                        end else if (owner_bus_rdata==8'hf2 || owner_bus_rdata==8'hf3) begin
                            prefix_active<=1; repeat_valid<=1; repeat_ne<=!owner_bus_rdata[0];
                        end else begin opcode <= owner_bus_rdata; state <= owner_bus_rdata==8'h0f ? EXT_FETCH : DECODE; end
                    end
                end
                EXT_FETCH: begin
                    if (!extension_allowed) begin
                        if (instruction_bytes>=10) begin enter_event(13,instruction_ip,1'b0,1'b1,1'b1,16'd0); state<=EVENT_START; end
                        else begin state<=STOPPED; ip<=instruction_ip; fault_code_o<=2; end
                    end else if (core_bus_ready) begin
                        system_opcode<=owner_bus_rdata; ip<=ip+16'd1;
                        instruction_bytes<=instruction_bytes+4'd1; state<=DECODE;
                    end
                end
                DECODE,MODRM_DECODE,AFTER_DISP: begin
                    if (undefined_encoding) begin
                        enter_event(8'd6,instruction_ip,1'b0,1'b1,1'b0,16'd0); state<=EVENT_START;
                    end else if (!opcode_valid || (state == MODRM_DECODE && !modrm_valid)) begin
                        fault_code_o <= 1; ip <= instruction_ip; state <= STOPPED;
                    end else if (({1'b0,instruction_bytes} + remaining_bytes) > 10) begin
                        enter_event(13,instruction_ip,1'b0,1'b1,1'b1,16'd0); state<=EVENT_START;
                    end else if (instruction_crosses_limit) begin
                        // Development stop; architectural exception delivery is deferred.
                        fault_code_o <= 2; ip <= instruction_ip; state <= STOPPED;
                    end else if (state == DECODE && opcode_modrm) state <= MODRM_FETCH;
                    else if (state == MODRM_DECODE && displacement_bytes != 0) begin
                        displacement <= 0; displacement_high <= 0;
                        displacement_remaining <= displacement_bytes; state <= DISPLACEMENT;
                    end
                    else if (immediate_bytes != 0) begin
                        immediate <= 0; immediate_index <= 0;
                        immediate_count <= immediate_bytes; state <= IMMEDIATE;
                    end else state <= PREPARE;
                end
                MODRM_FETCH: if (core_bus_ready) begin
                    modrm <= owner_bus_rdata; displacement <= 0;
                    ip <= ip + 16'd1; instruction_bytes <= instruction_bytes + 4'd1; state <= MODRM_DECODE;
                end
                DISPLACEMENT: if (core_bus_ready) begin
                    ip <= ip + 16'd1; instruction_bytes <= instruction_bytes + 4'd1;
                    if (displacement_bytes == 1) displacement <= {{8{owner_bus_rdata[7]}},owner_bus_rdata};
                    else if (displacement_high) displacement[15:8] <= owner_bus_rdata;
                    else displacement[7:0] <= owner_bus_rdata;
                    displacement_high <= 1;
                    displacement_remaining <= displacement_remaining - 2'd1;
                    if (displacement_remaining == 1) state <= AFTER_DISP;
                end
                IMMEDIATE: if (core_bus_ready) begin
                    immediate[immediate_index[1:0]*8 +: 8] <= owner_bus_rdata;
                    immediate_index <= immediate_index + 3'd1;
                    immediate_count <= immediate_count - 3'd1;
                    ip <= ip + 16'd1; instruction_bytes <= instruction_bytes + 4'd1;
                    if (immediate_count == 1) state <= PREPARE;
                end
                PREPARE: begin
                    rm_offset <= ea_offset;
                    rm_role <= override_valid ? override_segment : (ea_stack ? 2'd2 : 2'd3);
                    if (rm_memory && opcode != 8'h8d && ((wide && ea_offset == 16'hffff) ||
                        (system_table && ea_offset>16'hfffa) ||
                        ((opcode == 8'hc4 || opcode == 8'hc5 || opcode == 8'h62 || far_memory_pointer) && ea_offset > 16'hfffc))) begin
                        enter_event(13,instruction_ip,1'b0,1'b1,1'b1,16'd0); state<=EVENT_START;
                    end else if (rm_read) begin
                        memory_start(1'b1, override_valid ? override_segment : (ea_stack ? 2'd2 : 2'd3), ea_offset, 24'd0, 1'b0, 1'b0, system_table ? 3'd6 :
                            ((opcode == 8'hc4 || opcode == 8'hc5 || opcode == 8'h62 || far_memory_pointer) ? 3'd4 : (wide ? 3'd2 : 3'd1)), 0, EXECUTE);
                        if (memory_destination && ((alu_enable && alu_write) || exchange_rm ||
                            (unary_op && modrm[5:3]==2) || shift_op)) memory_kind<=3;
                    end else if (opcode == 8'ha0 || opcode == 8'ha1) begin
                        if (wide && immediate[15:0] == 16'hffff) begin enter_event(13,instruction_ip,1'b0,1'b1,1'b1,16'd0); state<=EVENT_START; end
                        else memory_start(1'b1, override_valid ? override_segment : 2'd3, immediate[15:0], 24'd0, 1'b0, 1'b0, wide ? 3'd2 : 3'd1, 0, EXECUTE);
                    end else if (opcode == 8'hd7)
                        memory_start(1'b1, override_valid ? override_segment : 2'd3, (gpr[3]+{8'h0,gpr[0][7:0]}), 24'd0, 1'b0, 1'b0, 1, 0, EXECUTE);
                    else state <= EXECUTE;
                end
                MEMORY_CHECK: begin
                    if (data_reference_allow) begin
                        if (memory_precheck_only) begin
                            memory_precheck_only<=0;
                            state<=memory_return;
                        end else if (ins_precheck_active && (opcode==8'h6c || opcode==8'h6d) &&
                            memory_return==STRING_FIRST) begin
                            // ASSUMPTION A20: validate the full INS destination before
                            // the I/O read, which may consume an external input value.
                            memory_start(1'b0,2'd0,16'd0,{8'h0,gpr[2]},1'b0,1'b1,
                                         wide ? 3'd2 : 3'd1,0,STRING_FIRST);
                        end else begin
                            memory_address<=data_reference_address; state<=BUS;
                        end
                    end
                    else begin
                        ins_precheck_active<=0;
                        memory_precheck_only<=0;
                        if (event_delivery_active || protected_iret_active) begin
                            // Delivery/return failure escalation is outside the
                            // bounded ring-0 slice. Keep it visible and never
                            // recurse through the real-mode IVT.
                            state<=STOPPED; fault_code_o<=3;
                            ip<=event_delivery_active ? event_packet.saved_ip : instruction_ip;
                            event_delivery_active<=0; protected_iret_active<=0;
                        end else begin
                            if (msw[0] && ins_precheck_active) begin
                                // Native 286 handler-repair state: Intel LOADALL
                                // memo p14 and REP restart memo 1984-10-15.
                                // Target corrected post-C2 behavior: a failed
                                // last REP INS element leaves CX=FFFF, not 0000.
                                gpr[7]<=gpr[7]+string_delta;
                                if (repeat_valid) gpr[1]<=gpr[1]-16'd2;
                            end else if (msw[0] && (opcode==8'ha4 || opcode==8'ha5) &&
                                (memory_return==STRING_FIRST || memory_return==STRING_COMMIT)) begin
                                // Intel LOADALL memo p14: MOVS always requires
                                // SI repair; destination faults also require DI
                                // repair and a second CX increment by the handler.
                                gpr[6]<=gpr[6]+string_delta;
                                if (memory_return==STRING_COMMIT) gpr[7]<=gpr[7]+string_delta;
                                if (repeat_valid)
                                    gpr[1]<=gpr[1]-(memory_return==STRING_COMMIT ? 16'd2 : 16'd1);
                            end else if (msw[0] && (opcode==8'ha6 || opcode==8'ha7) &&
                                (memory_return==STRING_FIRST || memory_return==STRING_COMMIT)) begin
                                // Intel LOADALL memo p14: CMPS always requires
                                // DI repair; repair SI only after ES:DI passed.
                                gpr[7]<=gpr[7]+string_delta;
                                if (memory_return==STRING_COMMIT) gpr[6]<=gpr[6]+string_delta;
                                if (repeat_valid)
                                    gpr[1]<=gpr[1]-(memory_return==STRING_COMMIT ? 16'd2 : 16'd1);
                            end else if (msw[0] && (opcode==8'haa || opcode==8'hab) &&
                                memory_return==STRING_COMMIT) begin
                                // Intel LOADALL memo p14: STOS DI/CX repair.
                                gpr[7]<=gpr[7]+string_delta;
                                if (repeat_valid) gpr[1]<=gpr[1]-16'd2;
                            end else if (msw[0] && (opcode==8'h6e || opcode==8'h6f) &&
                                memory_return==STRING_FIRST) begin
                                // Intel LOADALL memo p14: OUTS SI/CX repair
                                // for memory-source protection failure.
                                gpr[6]<=gpr[6]+string_delta;
                                if (repeat_valid) gpr[1]<=gpr[1]-16'd2;
                            end
                            if (data_reference_fault && msw[0]) enter_event(data_reference_vector,instruction_ip,1'b0,1'b1,1'b1,data_reference_error);
                            else enter_event(13,instruction_ip,1'b0,1'b1,1'b0,16'd0);
                            state<=EVENT_START;
                        end
                    end
                end
                BUS: if (core_bus_ready) begin
                    if (!memory_write) memory_result[memory_index*8 +: 8] <= owner_bus_rdata;
                    memory_index <= memory_index + 3'd1; memory_remaining <= memory_remaining - 3'd1;
                    memory_address <= memory_io ? {8'h0,memory_address[15:0]+16'd1} : memory_address + 24'd1;
                    if (memory_remaining == 1) begin
                        state <= memory_return;
                        if (ins_precheck_active && memory_io && !memory_write) ins_precheck_active<=0;
                    end
                end
                EXECUTE: begin
                    retire_o <= 1; retire_pc_o <= instruction_pc; retire_opcode_o <= opcode; state <= BOUNDARY;
                    prefix_active <= 0;
                    if (opcode==8'h0f) begin
                        if (system_opcode==8'h06) msw[3]<=0;
                        else if (system_table) begin
                            if (!modrm[4]) begin
                                memory_start(1'b1, rm_role, rm_offset, 24'd0, 1'b1, 1'b0, 6, 0, SYSTEM_DONE);
                                memory_data<=system_image;
                            end else if (modrm[3]) begin idt_limit<=memory_result[15:0]; idt_base<=memory_result[39:16]; end
                            else begin gdt_limit<=memory_result[15:0]; gdt_base<=memory_result[39:16]; end
                        end else if (modrm[5:3]==4) begin
                            if (rm_memory) memory_start(1'b1, rm_role, rm_offset, 24'd0, 1'b1, 1'b0, 2, {16'h0,msw}, SYSTEM_DONE);
                            else gpr[modrm[2:0]]<=msw;
                        end else if (modrm[5:3]==6) begin
                            // PE is sticky until reset; LMSW may update the other low MSW bits.
                            msw<={12'hfff,rm_value[3:1],msw[0] | rm_value[0]};
                        end
                    end else if (string_op) begin
                        state<=repeat_valid && gpr[1]!=0 ? STRING_BOUNDARY : STRING_START;
                        retire_o<=0;
                    end
                    else if (opcode == 8'h62) begin
                        if ($signed(gpr[modrm[5:3]]) < $signed(memory_result[15:0]) ||
                            $signed(gpr[modrm[5:3]]) > $signed(memory_result[31:16])) begin
                            enter_event(5,instruction_ip,1'b0,1'b1,1'b0,16'd0); state<=EVENT_START; retire_o<=0;
                        end
                    end else if (opcode == 8'hd7) gpr[0][7:0] <= memory_result[7:0];
                    else if (decimal_op) begin gpr[0]<=decimal_ax; flags<=decimal_flags; end
                    else if (muldiv_op) begin state<=MULDIV_WAIT; retire_o<=0; end
                    else if (msw[0] && (far_call || (far_return && opcode!=8'hcf) || opcode==8'h07 ||
                                        opcode==8'h17 || opcode==8'h1f || opcode==8'hc4 || opcode==8'hc5)) begin
                        // These protected transfers/load forms await their own transaction engines.
                        state<=STOPPED; fault_code_o<=3; ip<=instruction_ip; retire_o<=0;
                    end else if (code_load_start) begin
                        code_load_target<=0; state<=CODE_LOAD_WAIT; retire_o<=0;
                    end else if (segment_load_start) begin
                        segment_load_target<=modrm[4:3]; state<=SEGMENT_LOAD_WAIT; retire_o<=0;
                    end
                    else if (far_call) begin
                        far_ip<=opcode==8'h9a ? immediate[15:0] : memory_result[15:0];
                        far_cs<=opcode==8'h9a ? immediate[31:16] : memory_result[31:16];
                        pending_ip<=ip; pending_sp<=gpr[4]-16'd4;
                        if (gpr[4][0] && gpr[4]<4) begin state<=STOPPED; fault_code_o<=2; ip<=instruction_ip; retire_o<=0; end
                        else memory_start(1'b1, 2, (gpr[4]-16'd2), 24'd0, 1'b1, 1'b0, 2, {16'h0,cs}, FAR_CS_DONE);
                    end else if (far_return) begin
                        if (gpr[4]>(opcode==8'hcf ? 16'hfffa : 16'hfffc)) begin state<=STOPPED; fault_code_o<=2; ip<=instruction_ip; retire_o<=0; end
                        else begin
                            if (msw[0] && opcode==8'hcf) protected_iret_active<=1;
                            memory_start(1'b1, 2, gpr[4], 24'd0, 1'b0, 1'b0,
                                opcode==8'hcf ? 3'd6 : 3'd4, 0, FAR_RETURN_DONE);
                        end
                    end else if (opcode==8'hcc || opcode==8'hcd || (opcode==8'hce && flags[11])) begin
                        enter_event(opcode==8'hcc ? 8'd3 : opcode==8'hce ? 8'd4 : immediate[7:0],
                                    ip,1'b1,1'b0,1'b0,16'd0);
                        state<=EVENT_START; retire_o<=0;
                    end else if (opcode==8'h60 || opcode==8'h61) begin
                        retire_o<=0; stack_origin<=gpr[4]; all_index<=0;
                        for (integer r=0;r<8;r=r+1) all_values[r]<=gpr[r];
                        if ((opcode==8'h60 && gpr[4][0] && gpr[4]<16) ||
                            (opcode==8'h61 && gpr[4][0] && gpr[4]>=16'hfff1)) begin state<=STOPPED; fault_code_o<=2; ip<=instruction_ip; end
                        else memory_start(1'b1, 2, (opcode==8'h60 ? gpr[4]-16'd2 : gpr[4]), 24'd0, opcode==8'h60, 1'b0, 2, {16'h0,gpr[0]}, ALL_NEXT);
                    end else if (opcode==8'hc8) begin
                        frame_pointer<=gpr[4]-16'd2; frame_sp<=gpr[4]-16'd2; frame_source<=gpr[5]-16'd2;
                        frame_level<=immediate[20:16]; frame_index<=1;
                        if (gpr[4]-16'd2==16'hffff) begin state<=STOPPED; fault_code_o<=2; ip<=instruction_ip; retire_o<=0; end
                        else memory_start(1'b1, 2, (gpr[4]-16'd2), 24'd0, 1'b1, 1'b0, 2, {16'h0,gpr[5]}, ENTER_FIRST);
                    end else if (opcode==8'hc9) begin
                        if (gpr[5]==16'hffff) begin state<=STOPPED; fault_code_o<=2; ip<=instruction_ip; retire_o<=0; end
                        else memory_start(1'b1, 2, gpr[5], 24'd0, 1'b0, 1'b0, 2, 0, LEAVE_DONE);
                    end else if (memory_destination && ((alu_write && alu_enable) || mov_rm || exchange_rm ||
                        (unary_op && modrm[5:3] == 2) || opcode == 8'h8c || opcode == 8'hc6 || opcode == 8'hc7)) begin
                        memory_store(store_value,alu_enable ?
                            (incdec ? ((alu_flags & 16'hfffe) | (flags & 16'h0001)) : alu_flags) : flags,
                            exchange_rm,modrm[5:3],rm_value);
                    end else if (alu_enable) begin
                        flags <= alu_flags;
                        if (incdec) flags[0] <= flags[0];
                        if (alu_write)
                            gpr[wide ? destination : {1'b0,destination[1:0]}] <=
                                merge_register(gpr[wide ? destination : {1'b0,destination[1:0]}],destination[2],wide,alu_value);
                    end else if (mov_rm) begin
                        gpr[wide ? destination : {1'b0,destination[1:0]}] <=
                            merge_register(gpr[wide ? destination : {1'b0,destination[1:0]}],destination[2],wide,alu_rhs);
                    end else if (exchange_rm) begin
                        // Byte aliases can name two halves of one physical register.
                        if (!wide && modrm[1:0] == modrm[4:3]) begin
                            if (modrm[2] != modrm[5])
                                gpr[{1'b0,modrm[1:0]}] <= {gpr[{1'b0,modrm[1:0]}][7:0],gpr[{1'b0,modrm[1:0]}][15:8]};
                        end else begin
                            gpr[wide ? modrm[2:0] : {1'b0,modrm[1:0]}] <=
                                merge_register(gpr[wide ? modrm[2:0] : {1'b0,modrm[1:0]}],modrm[2],wide,read_register(modrm[5:3],wide));
                            gpr[wide ? modrm[5:3] : {1'b0,modrm[4:3]}] <=
                                merge_register(gpr[wide ? modrm[5:3] : {1'b0,modrm[4:3]}],modrm[5],wide,read_register(modrm[2:0],wide));
                        end
                    end else if (unary_op && modrm[5:3] == 2) begin
                        gpr[wide ? destination : {1'b0,destination[1:0]}] <=
                            merge_register(gpr[wide ? destination : {1'b0,destination[1:0]}],destination[2],wide,~alu_lhs);
                    end else if (shift_op) begin
                        if (shift_count != 0) begin
                            retire_o <= 0; state <= SHIFT; shift_value <= alu_lhs;
                            shift_flags <= flags; shift_remaining <= shift_count; shift_single <= shift_count == 1;
                        end else if (memory_destination)
                            // ASSUMPTION: A4. Abstract RMW bus trace includes zero-count writeback.
                            memory_store(rm_value,flags,1'b0,0,0);
                    end else if (push_op) begin
                        if (gpr[4]-16'd2 == 16'hffff) begin
                            retire_o <= 0; state <= STOPPED; fault_code_o <= 2; ip <= instruction_ip;
                        end else begin
                            pending_sp <= gpr[4]-16'd2; pending_call <= near_call;
                            pending_ip <= opcode == 8'he8 ? ip + immediate[15:0] : rm_value;
                            memory_start(1'b1, 2, (gpr[4]-16'd2), 24'd0, 1'b1, 1'b0, 2, {16'h0,near_call ? ip : opcode == 8'h9c ? flags :
                                 opcode == 8'h68 ? immediate[15:0] : opcode == 8'h6a ? {{8{immediate[7]}},immediate[7:0]} :
                                 opcode == 8'hff ? rm_value : opcode == 8'h06 ? es : opcode == 8'h0e ? cs :
                                 opcode == 8'h16 ? ss : opcode == 8'h1e ? ds : gpr[opcode[2:0]]}, PUSH_DONE);
                        end
                    end else if (pop_op) begin
                        if (gpr[4] == 16'hffff) begin retire_o <= 0; state <= STOPPED; fault_code_o <= 2; ip <= instruction_ip; end
                        else memory_start(1'b1, 2, gpr[4], 24'd0, 1'b0, 1'b0, 2, 0, POP_DONE);
                    end else if (io_op) begin
                        memory_start(1'b0, 2'd0, 16'd0, {8'h0,opcode[3] ? gpr[2] : {8'h0,immediate[7:0]}}, opcode[1], 1'b1, wide ? 3'd2 : 3'd1, {16'h0,gpr[0]}, IO_DONE);
                    end else if (opcode == 8'ha2 || opcode == 8'ha3) begin
                        if (wide && immediate[15:0] == 16'hffff) begin enter_event(13,instruction_ip,1'b0,1'b1,1'b1,16'd0); state<=EVENT_START; retire_o<=0; end
                        else begin
                            pending_flags <= flags; pending_register_write <= 0;
                            memory_start(1'b1, override_valid ? override_segment : 2'd3, immediate[15:0], 24'd0, 1'b1, 1'b0, wide ? 3'd2 : 3'd1, {16'h0,gpr[0]}, COMMIT_MEMORY);
                        end
                    end else if (opcode >= 8'hb8 && opcode <= 8'hbf) gpr[opcode[2:0]] <= immediate[15:0];
                    else if (opcode >= 8'hb0 && opcode <= 8'hb7)
                        gpr[{1'b0,opcode[1:0]}] <= merge_register(gpr[{1'b0,opcode[1:0]}],opcode[2],1'b0,immediate[15:0]);
                    else if (opcode >= 8'h70 && opcode <= 8'h7f) begin
                        if (jump_taken) ip <= ip + {{8{immediate[7]}},immediate[7:0]};
                    end else if (opcode >= 8'he0 && opcode <= 8'he3) begin
                        if (opcode != 8'he3) gpr[1] <= gpr[1] - 16'd1;
                        if (jump_taken) ip <= ip + {{8{immediate[7]}},immediate[7:0]};
                    end else if (opcode >= 8'h91 && opcode <= 8'h97) begin
                        gpr[0] <= gpr[opcode[2:0]]; gpr[opcode[2:0]] <= gpr[0];
                    end else begin
                        case (opcode)
                            8'h8c: gpr[modrm[2:0]] <= segment_value;
                            8'h8e: case (modrm[4:3])
                                0: begin es <= rm_value; es_base<={4'h0,rm_value,4'h0}; cache_valid[0]<=1; end
                                2: begin ss <= rm_value; ss_base<={4'h0,rm_value,4'h0}; cache_valid[2]<=1; ss_shadow<=1; end
                                3: begin ds <= rm_value; ds_base<={4'h0,rm_value,4'h0}; cache_valid[3]<=1; end
                                default: begin end // CS loads rejected in MODRM_DECODE.
                            endcase
                            8'h8d: gpr[modrm[5:3]] <= rm_offset;
                            8'hc4: begin
                                gpr[modrm[5:3]] <= memory_result[15:0]; es <= memory_result[31:16];
                                es_base<={4'h0,memory_result[31:16],4'h0}; cache_valid[0]<=1;
                            end
                            8'hc5: begin
                                gpr[modrm[5:3]] <= memory_result[15:0]; ds <= memory_result[31:16];
                                ds_base<={4'h0,memory_result[31:16],4'h0}; cache_valid[3]<=1;
                            end
                            8'hc6,8'hc7: gpr[wide ? modrm[2:0] : {1'b0,modrm[1:0]}] <=
                                merge_register(gpr[wide ? modrm[2:0] : {1'b0,modrm[1:0]}],modrm[2],wide,immediate[15:0]);
                            8'ha0,8'ha1: gpr[0] <= wide ? memory_result[15:0] : {gpr[0][15:8],memory_result[7:0]};
                            8'hff: begin
                                if (modrm[5:3]==5) begin
                                    ip<=memory_result[15:0]; cs<=memory_result[31:16]; cs_base<={4'h0,memory_result[31:16],4'h0};
                                    cache_limits[31:16]<=16'hffff; cache_access[15:8]<=8'h93; cache_valid[1]<=1; cs_trusted<=1;
                                end
                                else ip <= rm_value; // /4 near JMP; other extensions handled above.
                            end
                            8'h98: gpr[0] <= {{8{gpr[0][7]}},gpr[0][7:0]};
                            8'h99: gpr[2] <= {16{gpr[0][15]}};
                            8'h9e: flags <= (flags & 16'hff2a) | {8'h00,(gpr[0][15:8] & 8'hd5)};
                            // ASSUMPTION: A3. Canonical values for undefined LAHF bits.
                            8'h9f: gpr[0][15:8] <= (flags[7:0] & 8'hd5) | 8'h02;
                            8'hea: begin
                                ip <= immediate[15:0]; cs <= immediate[31:16]; cs_base <= {4'h0,immediate[31:16],4'h0};
                                cache_limits[31:16]<=16'hffff; cache_access[15:8]<=8'h93; cache_valid[1]<=1; cs_trusted<=1;
                            end
                            8'he9: ip <= ip + immediate[15:0];
                            8'heb: ip <= ip + {{8{immediate[7]}},immediate[7:0]};
                            8'hf4: begin state <= BOUNDARY; halt_latch<=1; end
                            8'hf5: flags[0] <= !flags[0];
                            8'hf8: flags[0] <= 0;
                            8'hf9: flags[0] <= 1;
                            8'hfa: flags[9] <= 0;
                            // ASSUMPTION: A9. Pinned PCjs/86Box STI shadow; see interrupt spec.
                            8'hfb: begin flags[9] <= 1; sti_shadow<=1; end
                            8'hfc: flags[10] <= 0;
                            8'hfd: flags[10] <= 1;
                            default: begin end // NOP
                        endcase
                    end
                end
                CODE_LOAD_WAIT: if (code_load_done) begin
                    if (code_load_fault || code_load_special || code_load_special_descriptor!=48'd0 ||
                        !code_load_cache_valid ||
                        code_load_request_selector!=(code_load_target==1 ? event_pointer[31:16] :
                            code_load_target==2 ? iret_saved_cs : opcode==8'hea ? immediate[31:16] : memory_result[31:16]) ||
                        code_load_request_offset!=(code_load_target==1 ? event_pointer[15:0] :
                            code_load_target==2 ? iret_saved_ip : opcode==8'hea ? immediate[15:0] : memory_result[15:0])) begin
                        if (code_load_target==0 && code_load_fault && !code_load_special) begin
                            enter_event(code_load_fault_vector,instruction_ip,1'b0,1'b1,1'b1,code_load_fault_error);
                            state<=EVENT_START; retire_o<=0;
                        end else begin
                            // Nested delivery and invalid protected return
                            // escalation remain explicit unsupported stops.
                            event_delivery_active<=0; protected_iret_active<=0;
                            state<=STOPPED; fault_code_o<=3;
                            ip<=code_load_target==1 ? event_packet.saved_ip : instruction_ip;
                            retire_o<=0;
                        end
                    end else if (code_load_target==1) begin
                        event_target_selector<=code_load_selector; event_target_base<=code_load_base;
                        event_target_limit<=code_load_limit; event_target_access<=code_load_access;
                        state<=EVENT_FRAME_CHECK; retire_o<=0;
                    end else if (code_load_target==2) begin
                        iret_target_base<=code_load_base; iret_target_limit<=code_load_limit;
                        iret_target_access<=code_load_access; state<=IRET_COMMIT; retire_o<=0;
                    end else begin
                        cs<=code_load_selector; cs_base<=code_load_base;
                        cache_limits[31:16]<=code_load_limit; cache_access[15:8]<=code_load_access;
                        cache_valid[1]<=1'b1; cs_trusted<=1'b1; ip<=code_load_request_offset;
                        state<=BOUNDARY; retire_o<=1; retire_pc_o<=instruction_pc; retire_opcode_o<=opcode;
                    end
                end
                SEGMENT_LOAD_WAIT: if (segment_load_done) begin
                    if (segment_load_fault) begin
                        enter_event(segment_load_fault_vector,instruction_ip,1'b0,1'b1,1'b1,segment_load_fault_error);
                        state<=EVENT_START; retire_o<=0;
                    end else if (segment_load_target==0 || segment_load_target==2 || segment_load_target==3) begin
                        case (segment_load_target)
                            0: begin
                                es<=segment_load_selector; es_base<=segment_load_base;
                                cache_limits[15:0]<=segment_load_limit; cache_access[7:0]<=segment_load_access;
                                cache_valid[0]<=segment_load_cache_valid;
                            end
                            2: begin
                                if (!segment_load_cache_valid) begin
                                    state<=STOPPED; fault_code_o<=3; ip<=instruction_ip; retire_o<=0;
                                end else begin
                                    ss<=segment_load_selector; ss_base<=segment_load_base;
                                    cache_limits[47:32]<=segment_load_limit; cache_access[23:16]<=segment_load_access;
                                    cache_valid[2]<=1'b1; ss_shadow<=1'b1;
                                    state<=BOUNDARY; retire_o<=1; retire_pc_o<=instruction_pc; retire_opcode_o<=opcode;
                                end
                            end
                            3: begin
                                ds<=segment_load_selector; ds_base<=segment_load_base;
                                cache_limits[63:48]<=segment_load_limit; cache_access[31:24]<=segment_load_access;
                                cache_valid[3]<=segment_load_cache_valid;
                            end
                            default: begin end
                        endcase
                        if (segment_load_target!=2) begin
                            state<=BOUNDARY; retire_o<=1; retire_pc_o<=instruction_pc; retire_opcode_o<=opcode;
                        end
                    end else begin
                        state<=STOPPED; fault_code_o<=3; ip<=instruction_ip; retire_o<=0;
                    end
                end
                SHIFT: begin
                    shift_value <= shifted_value; shift_flags <= shifted_flags;
                    shift_remaining <= shift_remaining - 5'd1;
                    if (shift_remaining == 1) begin
                        if (memory_destination) memory_store(shifted_value,shifted_flags,1'b0,0,0);
                        else begin
                            gpr[wide ? destination : {1'b0,destination[1:0]}] <=
                            merge_register(gpr[wide ? destination : {1'b0,destination[1:0]}],destination[2],wide,shifted_value);
                            flags <= shifted_flags; state <= BOUNDARY;
                            retire_o <= 1; retire_pc_o <= instruction_pc; retire_opcode_o <= opcode;
                        end
                    end
                end
                COMMIT_MEMORY: begin
                    flags <= pending_flags;
                    if (opcode == 8'h8f) gpr[4] <= pending_sp;
                    if (pending_register_write)
                        gpr[wide ? pending_register : {1'b0,pending_register[1:0]}] <=
                            merge_register(gpr[wide ? pending_register : {1'b0,pending_register[1:0]}],pending_register[2],wide,pending_register_value);
                    retire_o <= 1; retire_pc_o <= instruction_pc; retire_opcode_o <= opcode; state <= BOUNDARY;
                end
                SYSTEM_DONE: begin
                    retire_o<=1; retire_pc_o<=instruction_pc; retire_opcode_o<=opcode; state<=BOUNDARY;
                end
                IO_DONE: begin
                    if (!opcode[1]) gpr[0] <= wide ? memory_result[15:0] : {gpr[0][15:8],memory_result[7:0]};
                    retire_o <= 1; retire_pc_o <= instruction_pc; retire_opcode_o <= opcode; state <= BOUNDARY;
                end
                PUSH_DONE: begin
                    gpr[4] <= pending_sp; if (pending_call) ip <= pending_ip;
                    retire_o <= 1; retire_pc_o <= instruction_pc; retire_opcode_o <= opcode; state <= BOUNDARY;
                end
                POP_DONE: begin
                    if (opcode == 8'h8f && rm_memory) begin
                        // SP and the destination are committed together after the write.
                        pending_sp <= gpr[4] + 16'd2;
                        pending_flags <= flags; pending_register_write <= 0;
                        memory_start(1'b1, rm_role, rm_offset, 24'd0, 1'b1, 1'b0, 2, {16'h0,memory_result[15:0]}, COMMIT_MEMORY);
                    end else begin
                        gpr[4] <= gpr[4]+16'd2;
                        if (near_return) begin
                            ip <= memory_result[15:0];
                            if (opcode == 8'hc2) gpr[4] <= gpr[4]+16'd2+immediate[15:0];
                        end else if (opcode == 8'h07) begin
                            es <= memory_result[15:0]; es_base<={4'h0,memory_result[15:0],4'h0}; cache_valid[0]<=1;
                        end else if (opcode == 8'h17) begin
                            ss <= memory_result[15:0]; ss_base<={4'h0,memory_result[15:0],4'h0}; cache_valid[2]<=1; ss_shadow<=1;
                        end else if (opcode == 8'h1f) begin
                            ds <= memory_result[15:0]; ds_base<={4'h0,memory_result[15:0],4'h0}; cache_valid[3]<=1;
                        end
                        else if (opcode == 8'h9d) flags <= (flags & 16'h7000) | (memory_result[15:0] & 16'h0fd5) | 16'h0002;
                        else gpr[opcode == 8'h8f ? modrm[2:0] : opcode[2:0]] <= memory_result[15:0];
                        retire_o <= 1; retire_pc_o <= instruction_pc; retire_opcode_o <= opcode; state <= BOUNDARY;
                    end
                end
                MULDIV_WAIT: if (md_done && !md_busy) begin
                    if (md_fault) begin enter_event(0,instruction_ip,1'b0,1'b1,1'b0,16'd0); state<=EVENT_START; retire_o<=0; end
                    else begin
                        if (immediate_imul) gpr[modrm[5:3]]<=md_ax;
                        else begin gpr[0]<=md_ax; if (wide) gpr[2]<=md_dx; end
                        flags<=md_flags; state<=BOUNDARY;
                        if (aam_op) begin
                            gpr[0]<={md_ax[7:0],md_ax[15:8]};
                            flags[7]<=md_ax[15]; flags[6]<=md_ax[15:8]==0; flags[2]<=~^md_ax[15:8];
                        end
                        retire_o<=1; retire_pc_o<=instruction_pc; retire_opcode_o<=opcode;
                    end
                end
                FAR_CS_DONE: memory_start(1'b1, 2, pending_sp, 24'd0, 1'b1, 1'b0, 2, {16'h0,pending_ip}, FAR_CALL_DONE);
                FAR_CALL_DONE: begin
                    gpr[4]<=pending_sp; ip<=far_ip; cs<=far_cs; cs_base<={4'h0,far_cs,4'h0}; state<=BOUNDARY;
                    cache_limits[31:16]<=16'hffff; cache_access[15:8]<=8'h93; cache_valid[1]<=1; cs_trusted<=1;
                    retire_o<=1; retire_pc_o<=instruction_pc; retire_opcode_o<=opcode;
                end
                FAR_RETURN_DONE: begin
                    if (msw[0] && opcode==8'hcf) begin
                        if (flags[14] || memory_result[31:30]!=cs[1:0] || memory_result[31:18]==0) begin
                            protected_iret_active<=0; state<=STOPPED; fault_code_o<=3; ip<=instruction_ip; retire_o<=0;
                        end else begin
                            iret_saved_ip<=memory_result[15:0]; iret_saved_cs<=memory_result[31:16];
                            iret_saved_flags<=memory_result[47:32]; iret_saved_sp<=gpr[4]+16'd6;
                            protected_iret_active<=1; retire_o<=0; state<=IRET_CODE_START;
                        end
                    end else if (msw[0]) begin
                        state<=STOPPED; fault_code_o<=3; ip<=instruction_ip; retire_o<=0;
                    end else begin
                        ip<=memory_result[15:0]; cs<=memory_result[31:16]; cs_base<={4'h0,memory_result[31:16],4'h0};
                        cache_limits[31:16]<=16'hffff; cache_access[15:8]<=8'h93; cache_valid[1]<=1; cs_trusted<=1;
                        gpr[4]<=gpr[4]+(opcode==8'hcf ? 16'd6 : 16'd4)+(opcode==8'hca ? immediate[15:0] : 16'd0);
                        if (opcode==8'hcf) flags<=(flags&16'h7000)|(memory_result[47:32]&16'h0fd5)|16'h0002;
                        state<=BOUNDARY; retire_o<=1; retire_pc_o<=instruction_pc; retire_opcode_o<=opcode;
                    end
                end
                IRET_CODE_START: if (owner_cpu_grant) begin
                    code_load_target<=2; state<=CODE_LOAD_WAIT; retire_o<=0;
                end
                IRET_COMMIT: begin
                    ip<=iret_saved_ip; cs<=code_load_selector; cs_base<=iret_target_base;
                    cache_limits[31:16]<=iret_target_limit; cache_access[15:8]<=iret_target_access;
                    cache_valid[1]<=1; cs_trusted<=1; gpr[4]<=iret_saved_sp;
                    flags<=(flags&16'h7000)|(iret_saved_flags&16'h0fd5)|16'h0002;
                    protected_iret_active<=0; state<=BOUNDARY;
                    retire_o<=1; retire_pc_o<=instruction_pc; retire_opcode_o<=opcode;
                end
                EVENT_START: begin
                    if (event_packet.protected_mode) begin
                        if (event_vector_o!=8'd13 || !event_packet.error_present ||
                            event_packet.error_code!=16'd0 ||
                            ({6'h0,event_vector_o,3'b000}+17'd7)>{1'b0,idt_limit} ||
                            event_packet.saved_sp<8) begin
                            // Only the scoped restartable #GP(0) path is
                            // enabled. Other vectors/escalation cannot fall
                            // through to the real-mode IVT or a partial frame.
                            event_delivery_active<=0; state<=STOPPED; fault_code_o<=3;
                            retire_o<=0; ip<=event_packet.saved_ip;
                        end else begin
                            event_delivery_active<=1; event_gate<=0;
                            memory_start(1'b0,2'd0,16'd0,
                                idt_base+{13'h0,event_vector_o,3'b000},1'b0,1'b0,3'd6,0,EVENT_GATE_TAIL);
                        end
                    end else if (({7'h0,event_vector_o,2'b00}+17'd3)>{1'b0,idt_limit}) begin
                        // Intel 5.2.3: real-mode vector-limit exception, not PM #DF.
                        if (event_vector_o==8) begin
                            state<=STOPPED; fault_code_o<=2; retire_o<=0;
                            ip<=event_packet.instruction_retired ? instruction_ip : event_packet.saved_ip;
                            event_packet.instruction_retired<=0;
                        end else begin
                            event_packet.saved_ip<=event_packet.instruction_retired ? instruction_ip : event_packet.saved_ip;
                            event_packet.instruction_retired<=0;
                            event_packet.vector<=8;
                            event_packet.restartable<=0;
                            event_packet.error_present<=0;
                            event_packet.error_code<=0;
                            retire_o<=0;
                        end
                    end else memory_start(1'b0, 2'd0, 16'd0, idt_base+{14'h0,event_vector_o,2'b00}, 1'b0, 1'b0, 4, 0, EVENT_VECTOR);
                end
                EVENT_VECTOR: begin
                    if (event_packet.saved_sp[0] && event_packet.saved_sp<6) begin state<=STOPPED; fault_code_o<=2; ip<=event_packet.saved_ip; end
                    else begin
                        event_pointer<=memory_result[31:0];
                        memory_start(1'b1, 2, (event_packet.saved_sp-16'd2), 24'd0, 1'b1, 1'b0, 2, {16'h0,event_packet.saved_flags}, EVENT_FLAGS);
                    end
                end
                EVENT_FLAGS: memory_start(1'b1, 2, (event_packet.saved_sp-16'd4), 24'd0, 1'b1, 1'b0, 2, {16'h0,event_packet.saved_cs}, EVENT_CS);
                EVENT_CS: memory_start(1'b1, 2, (event_packet.saved_sp-16'd6), 24'd0, 1'b1, 1'b0, 2, {16'h0,event_packet.saved_ip}, EVENT_COMMIT);
                EVENT_GATE_TAIL: begin
                    event_gate[47:0]<=memory_result;
                    memory_start(1'b0,2'd0,16'd0,
                        idt_base+{13'h0,event_vector_o,3'b000}+24'd6,
                        1'b0,1'b0,3'd2,0,EVENT_GATE_VALIDATE);
                end
                EVENT_GATE_VALIDATE: begin
                    event_gate<={memory_result[15:0],event_gate[47:0]};
                    state<=EVENT_GATE_CHECK;
                end
                EVENT_GATE_CHECK: begin
                    if (event_gate[39:32]!=0 || event_gate[44] ||
                        event_gate[43:40]!=4'h6 || !event_gate[47] || event_gate[63:48]!=0) begin
                        event_delivery_active<=0; state<=STOPPED; fault_code_o<=3;
                        retire_o<=0; ip<=event_packet.saved_ip;
                    end else begin
                        // Exception delivery ignores the gate DPL check. This
                        // slice accepts only a present 286 interrupt gate.
                        event_pointer<={event_gate[31:16],event_gate[15:0]};
                        state<=EVENT_CODE_START; retire_o<=0;
                    end
                end
                EVENT_CODE_START: if (owner_event_grant) begin
                    code_load_target<=1; state<=CODE_LOAD_WAIT; retire_o<=0;
                end
                EVENT_FRAME_CHECK: if (owner_event_grant) begin
                    if (event_packet.saved_sp<8) begin
                        event_delivery_active<=0; state<=STOPPED; fault_code_o<=3;
                        retire_o<=0; ip<=event_packet.saved_ip;
                    end else begin
                        memory_start(1'b1,2,event_packet.saved_sp-16'd8,24'd0,
                            1'b1,1'b0,3'd1,0,EVENT_FRAME_READY);
                        memory_precheck_only<=1; memory_span_delta<=16'd7;
                    end
                end
                EVENT_FRAME_READY: if (owner_event_grant) begin
                    memory_start(1'b1,2,event_packet.saved_sp-16'd2,24'd0,
                        1'b1,1'b0,3'd2,{16'h0,event_packet.saved_flags},EVENT_FRAME_FLAGS);
                end
                EVENT_FRAME_FLAGS: memory_start(1'b1,2,event_packet.saved_sp-16'd4,24'd0,
                    1'b1,1'b0,3'd2,{16'h0,event_packet.saved_cs},EVENT_FRAME_CS);
                EVENT_FRAME_CS: memory_start(1'b1,2,event_packet.saved_sp-16'd6,24'd0,
                    1'b1,1'b0,3'd2,{16'h0,event_packet.saved_ip},EVENT_FRAME_IP);
                EVENT_FRAME_IP: begin
                    if (event_packet.error_present)
                        memory_start(1'b1,2,event_packet.saved_sp-16'd8,24'd0,
                            1'b1,1'b0,3'd2,{16'h0,event_packet.error_code},EVENT_FRAME_ERROR);
                    else state<=EVENT_PROTECTED_COMMIT;
                end
                EVENT_FRAME_ERROR: state<=EVENT_PROTECTED_COMMIT;
                EVENT_PROTECTED_COMMIT: begin
                    ip<=event_pointer[15:0]; cs<=event_target_selector; cs_base<=event_target_base;
                    cache_limits[31:16]<=event_target_limit; cache_access[15:8]<=event_target_access;
                    cache_valid[1]<=1; cs_trusted<=1;
                    flags<=event_packet.saved_flags&16'hfcff; gpr[4]<=pending_sp;
                    event_delivery_active<=0; state<=BOUNDARY; event_o<=1;
                    retire_o<=event_packet.instruction_retired;
                    retire_pc_o<=instruction_pc; retire_opcode_o<=opcode;
                end
                EVENT_COMMIT: begin
                    ip<=event_pointer[15:0]; cs<=event_pointer[31:16]; cs_base<={4'h0,event_pointer[31:16],4'h0};
                    cache_limits[31:16]<=16'hffff; cache_access[15:8]<=8'h93; cache_valid[1]<=1; cs_trusted<=1;
                    flags<=event_packet.saved_flags&16'hfcff; gpr[4]<=pending_sp; state<=BOUNDARY; event_o<=1;
                    retire_o<=event_packet.instruction_retired; retire_pc_o<=instruction_pc; retire_opcode_o<=opcode;
                end
                ALL_NEXT: begin
                    if (opcode==8'h61) all_values[3'd7-all_index]<=memory_result[15:0];
                    if (all_index==7) state<=ALL_COMMIT;
                    else if (opcode==8'h60) begin
                        all_index<=all_index+3'd1;
                        memory_start(1'b1, 2, (stack_origin-({12'h0,all_index,1'b0}+16'd4)), 24'd0, 1'b1, 1'b0, 2, {16'h0,all_values[all_index+3'd1]}, ALL_NEXT);
                    end else if (all_index==2) begin
                        all_index<=4;
                        memory_start(1'b1, 2, (stack_origin+16'd8), 24'd0, 1'b0, 1'b0, 2, 0, ALL_NEXT);
                    end else begin
                        all_index<=all_index+3'd1;
                        memory_start(1'b1, 2, (stack_origin+({12'h0,all_index,1'b0}+16'd2)), 24'd0, 1'b0, 1'b0, 2, 0, ALL_NEXT);
                    end
                end
                ALL_COMMIT: begin
                    if (opcode==8'h61) for (integer r=0;r<8;r=r+1) if (r!=4) gpr[r]<=all_values[r];
                    gpr[4]<=opcode==8'h60 ? stack_origin-16'd16 : stack_origin+16'd16;
                    state<=BOUNDARY; retire_o<=1; retire_pc_o<=instruction_pc; retire_opcode_o<=opcode;
                end
                ENTER_FIRST: begin
                    if (frame_level==0) state<=ENTER_COMMIT;
                    else if (frame_level==1) begin
                        frame_sp<=frame_sp-16'd2;
                        memory_start(1'b1, 2, (frame_sp-16'd2), 24'd0, 1'b1, 1'b0, 2, {16'h0,frame_pointer}, ENTER_COMMIT);
                    end else if (frame_source==16'hffff) begin state<=STOPPED; fault_code_o<=2; ip<=instruction_ip; end
                    else memory_start(1'b1, 2, frame_source, 24'd0, 1'b0, 1'b0, 2, 0, ENTER_READ);
                end
                ENTER_READ: begin
                    if (frame_sp-16'd2==16'hffff) begin state<=STOPPED; fault_code_o<=2; ip<=instruction_ip; end
                    else begin
                        frame_sp<=frame_sp-16'd2; frame_source<=frame_source-16'd2;
                        memory_start(1'b1, 2, (frame_sp-16'd2), 24'd0, 1'b1, 1'b0, 2, {16'h0,memory_result[15:0]}, ENTER_COPY);
                    end
                end
                ENTER_COPY: begin
                    if (frame_index==frame_level-5'd1) begin
                        frame_sp<=frame_sp-16'd2;
                        memory_start(1'b1, 2, (frame_sp-16'd2), 24'd0, 1'b1, 1'b0, 2, {16'h0,frame_pointer}, ENTER_COMMIT);
                    end else if (frame_source==16'hffff) begin state<=STOPPED; fault_code_o<=2; ip<=instruction_ip; end
                    else begin frame_index<=frame_index+5'd1; memory_start(1'b1, 2, frame_source, 24'd0, 1'b0, 1'b0, 2, 0, ENTER_READ); end
                end
                ENTER_COMMIT: begin
                    gpr[5]<=frame_pointer; gpr[4]<=frame_sp-immediate[15:0]; state<=BOUNDARY;
                    retire_o<=1; retire_pc_o<=instruction_pc; retire_opcode_o<=opcode;
                end
                LEAVE_DONE: begin
                    gpr[4]<=gpr[5]+16'd2; gpr[5]<=memory_result[15:0]; state<=BOUNDARY;
                    retire_o<=1; retire_pc_o<=instruction_pc; retire_opcode_o<=opcode;
                end
                STRING_START: begin
                    if (repeat_valid && gpr[1]==0) begin
                        state<=BOUNDARY; retire_o<=1; retire_pc_o<=instruction_pc; retire_opcode_o<=opcode;
                    end else if (opcode==8'h6c || opcode==8'h6d) begin
                        ins_precheck_active<=1;
                        memory_start(1'b1,0,gpr[7],24'd0,1'b1,1'b0,
                                     wide ? 3'd2 : 3'd1,0,STRING_FIRST);
                    end else if (wide && ((string_source && gpr[6]==16'hffff) ||
                                         (string_destination && gpr[7]==16'hffff)) &&
                        !(msw[0] && (opcode==8'ha4 || opcode==8'ha5 || opcode==8'haa ||
                                     opcode==8'hab || opcode==8'h6e || opcode==8'h6f ||
                                     opcode==8'ha6 || opcode==8'ha7))) begin
                        enter_event(13,instruction_ip,1'b0,1'b1,1'b1,16'd0); state<=EVENT_START;
                    end
                    else if (opcode==8'haa || opcode==8'hab)
                        memory_start(1'b1, 0, gpr[7], 24'd0, 1'b1, 1'b0, wide ? 3'd2 : 3'd1, {16'h0,gpr[0]}, STRING_COMMIT);
                    else if (string_compare)
                        // Intel 210498-005 defines CMPS flags from [SI]-[DI].
                        // ASSUMPTION A6: the functional model reads ES:DI first;
                        // native per-beat order still needs an independent trace.
                        memory_start(1'b1, 0, gpr[7], 24'd0, 1'b0, 1'b0, wide ? 3'd2 : 3'd1, 0, (opcode==8'ha6 || opcode==8'ha7) ? STRING_FIRST : STRING_COMMIT);
                    else memory_start(1'b1, override_valid ? override_segment : 2'd3, gpr[6], 24'd0, 1'b0, 1'b0, wide ? 3'd2 : 3'd1, 0, (opcode==8'hac || opcode==8'had) ? STRING_COMMIT : STRING_FIRST);
                end
                STRING_FIRST: begin
                    if (opcode==8'ha6 || opcode==8'ha7) begin
                        string_value<=memory_result[15:0];
                        memory_start(1'b1, override_valid ? override_segment : 2'd3, gpr[6], 24'd0, 1'b0, 1'b0, wide ? 3'd2 : 3'd1, 0, STRING_COMMIT);
                    end else if (opcode==8'h6e || opcode==8'h6f)
                        memory_start(1'b0, 2'd0, 16'd0, {8'h0,gpr[2]}, 1'b1, 1'b1, wide ? 3'd2 : 3'd1, {16'h0,memory_result[15:0]}, STRING_COMMIT);
                    else memory_start(1'b1, 0, gpr[7], 24'd0, 1'b1, 1'b0, wide ? 3'd2 : 3'd1, {16'h0,memory_result[15:0]}, STRING_COMMIT);
                end
                STRING_COMMIT: begin
                    element_o<=1;
                    if (string_source) gpr[6]<=gpr[6]+string_delta;
                    if (string_destination) gpr[7]<=gpr[7]+string_delta;
                    if (opcode==8'hac || opcode==8'had)
                        gpr[0]<=wide ? memory_result[15:0] : {gpr[0][15:8],memory_result[7:0]};
                    if (string_compare) flags<=alu_flags;
                    if (repeat_valid) gpr[1]<=gpr[1]-16'd1;
                    if (repeat_valid && gpr[1]!=1 && (!string_compare || alu_flags[6]!=repeat_ne)) state<=STRING_BOUNDARY;
                    else begin state<=BOUNDARY; retire_o<=1; retire_pc_o<=instruction_pc; retire_opcode_o<=opcode; end
                end
                HALTED: state<=BOUNDARY;
                STOPPED: begin end
                default: begin state <= STOPPED; fault_code_o <= 1; end
            endcase
        end
    end
`ifdef FORMAL
    `include "intel_80286_props.sv"
`endif
endmodule

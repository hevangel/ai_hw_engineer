module mos_6526_irq #(
    parameter bit TIMER_B_READ_LOSS = 1
) (
    input logic clk, rst_n, read_i, write_i,
    input logic [7:0] data_i,
    input logic [4:0] source_i,
    output logic [7:0] data_o, cycle_data_o,
    output logic irq_n, cycle_irq_n
);
    logic [4:0] pending_q, mask_q, mask_next;
    logic scheduled_q, d7_q, asserted_q, acknowledge_q;
    logic tb_loss_q, tb_loss_view;
    logic [4:0] read_sources, captured_sources;
    // The register bus includes reserved write bits with no state effect.
    logic unused_reserved_write_bits;
    assign unused_reserved_write_bits = ^data_i[6:5];
    always_comb begin
        mask_next = mask_q;
        if (write_i) begin
            if (data_i[7]) mask_next = mask_q | data_i[4:0];
            else mask_next = mask_q & ~data_i[4:0];
        end
    end
    assign data_o = {d7_q,2'b00,pending_q};
    // VICE cia_do_update_tb/ICR read and original Transactor detector.
    // A new B event replaces the old marker, even before this edge commits.
    // ASSUMPTION: all B count modes share this sampled window; independent
    // CNT/cascade physical traces remain required (specification ledger).
    assign tb_loss_view = TIMER_B_READ_LOSS && (source_i[1] ? acknowledge_q : tb_loss_q);
    always_comb begin
        read_sources = pending_q | source_i;
        captured_sources = source_i;
        // ASSUMPTION: a currently visible serial completion is consumed
        // by this read. Original cia-sdr-delay detects stale re-capture;
        // see the serial qualification ledger in spec/spec.md.
        if (read_i) captured_sources[3] = 0;
        if (read_i && tb_loss_view) begin
            read_sources[1] = 0;
            captured_sources[1] = 0;
        end
    end
    // Pre-acknowledgment bus view after this cycle's source/D7 catch-up.
    // ASSUMPTION: old-CIA event/D7 phases; independent Lorenz/VICE ledger.
    assign cycle_data_o = {(d7_q && !acknowledge_q) || scheduled_q,2'b00,read_sources};
    assign irq_n = !(rst_n && asserted_q && !read_i);
    assign cycle_irq_n = !(rst_n && (asserted_q || scheduled_q) && !read_i);
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            pending_q <= 0; mask_q <= 0; scheduled_q <= 0;
            d7_q <= 0; asserted_q <= 0; acknowledge_q <= 0;
            tb_loss_q <= 0;
        end else begin
            mask_q <= mask_next;
            pending_q <= (read_i ? 5'b0 : pending_q) | captured_sources;
            if (source_i[1]) tb_loss_q <= TIMER_B_READ_LOSS && acknowledge_q;
            if (read_i) tb_loss_q <= 0;
            // ASSUMPTION: sampled legacy latency; subcycle races still need captures.
            scheduled_q <= |(source_i & mask_q) ||
                (write_i && |(pending_q & mask_next));
            acknowledge_q <= read_i;
            if (acknowledge_q) d7_q <= 0;
            if (scheduled_q) begin d7_q <= 1; asserted_q <= 1; end
            if (read_i) asserted_q <= 0;
        end
    end
`ifdef FORMAL
    `include "mos_6526_irq_props.sv"
`endif
endmodule

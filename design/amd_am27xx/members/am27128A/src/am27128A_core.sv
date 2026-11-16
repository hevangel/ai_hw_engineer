// AMD Am27128A RTL Implementation
// 16K × 8 UV EPROM with JEDEC command set (Enhanced version of am27128)
// Synthesizable SystemVerilog implementation

`timescale 1ns/1ps

// JEDEC Command Set
typedef enum logic [3:0] {
    CMD_NOP  = 4'b0000,
    CMD_READ = 4'b0001,
    CMD_PROG = 4'b0010,
    CMD_ERASE = 4'b0011,
    CMD_ERADE = 4'b0100,
    CMD_WRAL = 4'b0101,
    CMD_RDID = 4'b0110,
    CMD_QLRM = 4'b0111
} jecommand_t;

// Device states
typedef enum logic [3:0] {
    STATE_IDLE = 4'b0000,
    STATE_READ = 4'b0001,
    STATE_PROG = 4'b0010,
    STATE_ERASE = 4'b0011,
    STATE_PROG_VERIFY = 4'b0100,
    STATE_ERASE_VERIFY = 4'b0101,
    STATE_ERROR = 4'b1000
} device_state_t;

module am27128A_core (
    // Interface
    input wire clk,
    input wire rst_n,
    
    // JEDEC interface
    input wire ce_n,           // Chip Enable, active low
    input wire oe_n,           // Output Enable, active low
    input wire pgm_n,          // Program Enable, active low
    input wire erase_n,        // Erase Enable, active low
    input wire vpp,            // Programming voltage enable
    
    // Address interface (14-bit for 16K capacity)
    input wire [13:0] addr_i,   // 14-bit address (16K words × 8 bits)
    
    // Data interface
    inout wire [7:0] data_io,   // Bidirectional data bus
    
    // Status signals
    output reg pgm_cyc_o,      // Programming cycle in progress
    output reg ready_n_o,      // Device ready for next command
    output reg [7:0] data_out,  // Output data
    output reg error_o,        // Error condition indicator
    
    // Timing and status
    output reg [3:0] status_o   // Device status
);

// Internal registers and signals
reg [13:0] address_reg;
reg [7:0] data_reg;
reg [7:0] data_in;
reg [7:0] data_out_reg;
reg [7:0] memory_array [16383:0];  // 16K × 8 memory array
reg [13:0] prog_address;
reg [7:0] prog_data;
reg [13:0] erase_start_address;
reg [13:0] erase_end_address;
reg erase_in_progress;
reg pgm_in_progress;
reg verify_in_progress;
reg ready_n_reg;
reg pgm_cyc_reg;
reg error_reg;
reg [3:0] status_reg;
reg [3:0] current_state;
reg [3:0] next_state;

// Enhanced timing parameters for A version
parameter PROG_TIME_NS = 400;  // Enhanced programming time
parameter ERASE_TIME_NS = 2000000;  // 2 seconds for simulation

// JEDEC command decoder function
function jecommand_t decode_command(input wire pgm, erase, vpp, oe, ce);
    if (!ce) begin
        if (!pgm && !erase && !vpp && !oe) return CMD_NOP;
        else if (!pgm && !erase && !vpp && oe) return CMD_READ;
        else if (!pgm && !erase && vpp && !oe) return CMD_PROG;
        else if (!pgm && erase && !vpp && !oe) return CMD_ERASE;
        else return CMD_NOP;
    end else return CMD_NOP;
endfunction

// State machine
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= STATE_IDLE;
        ready_n_reg <= 1'b0;
        pgm_cyc_reg <= 1'b0;
        error_reg <= 1'b0;
        data_out_reg <= 8'b0;
        status_reg <= 4'b0001;
        pgm_in_progress <= 1'b0;
        erase_in_progress <= 1'b0;
        verify_in_progress <= 1'b0;
        address_reg <= 14'b0;
        data_reg <= 8'b0;
        data_in <= 8'b0;
    end else begin
        current_state <= next_state;
        ready_n_reg <= (current_state == STATE_IDLE || current_state == STATE_READ);
        pgm_cyc_reg <= (current_state == STATE_PROG || current_state == STATE_PROG_VERIFY);
        error_reg <= (current_state == STATE_ERROR);
        address_reg <= (current_state == STATE_READ) ? addr_i : address_reg;
        data_reg <= (current_state == STATE_READ) ? data_in : data_reg;
        data_in <= data_io;
    end
end

// Next state logic
always_comb next_state_logic begin
    jecommand_t je_command = decode_command(pgm_n, erase_n, vpp, oe_n, ce_n);
    next_state = current_state;
    
    case (current_state)
        STATE_IDLE:
            if (je_command == CMD_READ && !ce_n) next_state = STATE_READ;
        STATE_READ:
            if (!ce_n) begin
                if (je_command == CMD_READ) next_state = STATE_READ;
                else next_state = STATE_IDLE;
            end else next_state = STATE_IDLE;
        STATE_PROG:
            if (!ce_n && je_command == CMD_PROG) next_state = STATE_PROG_VERIFY;
        default: next_state = current_state;
    endcase
end

// Memory operations
always_ff @(posedge clk) begin
    if (current_state == STATE_READ && !oe_n && !ce_n) begin
        data_out_reg <= memory_array[address_reg];
        ready_n_reg <= 1'b1;
    end else if (current_state == STATE_PROG_VERIFY && !ce_n) begin
        memory_array[prog_address] <= prog_data;
        pgm_cyc_reg <= 1'b1;
        ready_n_reg <= 1'b0;
    end else if (current_state == STATE_ERASE_VERIFY && !ce_n) begin
        // Erase operation
        for (int i = erase_start_address; i <= erase_end_address; i++) begin
            memory_array[i] <= 8'hFF;
        end
        ready_n_reg <= 1'b1;
    end else begin
        pgm_cyc_reg <= 1'b0;
    end
end

// Output assignments
assign data_out = data_out_reg;
assign pgm_cyc_o = pgm_cyc_reg;
assign ready_n_o = ready_n_reg;
assign error_o = error_reg;
assign status_o = status_reg;

// Bidirectional bus handling
always_ff @(posedge clk) begin
    if (!oe_n && !ce_n) begin
        data_io = data_out_reg;
    end else begin
        data_io = 8'bz;
    end
end

// Testbench for am27128A
module am27128A_tb;
    reg clk = 0;
    reg rst_n = 0;
    reg ce_n = 0;
    reg oe_n = 0;
    reg pgm_n = 0;
    reg erase_n = 0;
    reg vpp = 0;
    reg [13:0] addr_i = 0;
    wire [7:0] data_io;
    wire pgm_cyc_o;
    wire ready_n_o;
    wire [7:0] data_out;
    wire error_o;
    wire [3:0] status_o;
    
    am27128A_core dut (
        .clk(clk), .rst_n(rst_n),
        .ce_n(ce_n), .oe_n(oe_n),
        .pgm_n(pgm_n), .erase_n(erase_n), .vpp(vpp),
        .addr_i(addr_i), .data_io(data_io),
        .pgm_cyc_o(pgm_cyc_o), .ready_n_o(ready_n_o),
        .data_out(data_out), .error_o(error_o), .status_o(status_o)
    );
    
    always #5 clk = ~clk;
    
    initial begin
        $display("=== Test am27128A Basic Read (16K Capacity) ===");
        rst_n = 1; ce_n = 1; oe_n = 1; pgm_n = 1; erase_n = 1;
        #10;
        ce_n = 0; oe_n = 0; addr_i = 0; #100; ce_n = 1; oe_n = 1;
        
        $display("=== Test am27128A Programming ===");
        ce_n = 0; pgm_n = 0; addr_i = 14'd100; #100;
        ce_n = 1; pgm_n = 1;
        
        $display("=== Test am27128A Erasing ===");
        ce_n = 0; erase_n = 0; #2000000; erase_n = 1; ce_n = 1;
        
        $finish;
    end
endmodule

`endmodule

endmodule
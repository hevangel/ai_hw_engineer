// amd_am9518_defs.svh — command codes, register fields and status bits for
// the Am9518 Data Ciphering Processor reconstruction.
//
// All encodings are from the AMD Am9518/AmZ8068 datasheet (doc 00618B):
// Figure 1 (p. 2-467), Figure 2 (p. 2-467), Figure 4 (p. 2-468) and
// Figure 5 (p. 2-468).
//
// Include-based definitions (matching the zilog_z80 convention) because
// yosys does not reliably support package imports.

`ifndef AMD_AM9518_DEFS_SVH
`define AMD_AM9518_DEFS_SVH

    // --------------------------------------------------------------
    // Mode register fields (datasheet Figure 5).  M7 and M1M0 unused.
    // M6M5 cipher type, M4 encrypt/decrypt, M3M2 port configuration.
    // --------------------------------------------------------------
    localparam logic [1:0] CIPHER_ECB = 2'b00;   // reset default
    localparam logic [1:0] CIPHER_CFB = 2'b01;
    localparam logic [1:0] CIPHER_CBC = 2'b10;
    localparam logic [1:0] CIPHER_RSV = 2'b11;

    localparam logic [1:0] CFG_ME_SC  = 2'b00;   // dual: master enc, slave clear
    localparam logic [1:0] CFG_MC_SE  = 2'b01;   // dual: master clear, slave enc (default)
    localparam logic [1:0] CFG_SINGLE = 2'b10;   // single port, master only
    localparam logic [1:0] CFG_RSV    = 2'b11;   // reserved

    localparam logic [7:0] MODE_RESET = 8'h04;   // A1: ECB, config 01, M4=0

    // --------------------------------------------------------------
    // Status register bits (datasheet Figure 4).
    // --------------------------------------------------------------
    localparam int unsigned ST_START = 7;  // S7 start/stop entered
    localparam int unsigned ST_CP    = 6;  // S6 command pending
    localparam int unsigned ST_BSY   = 5;  // S5 busy
    localparam int unsigned ST_LPAR  = 4;  // S4 latched parity error
    localparam int unsigned ST_PAR   = 3;  // S3 parity error, latest byte
    localparam int unsigned ST_AFLG  = 2;  // S2 auxiliary port flag
    localparam int unsigned ST_SFLG  = 1;  // S1 slave port flag
    localparam int unsigned ST_MFLG  = 0;  // S0 master port flag

    // --------------------------------------------------------------
    // Master-port register select (latched MP2/MP1 with C/K=0),
    // datasheet Figure 1.
    // --------------------------------------------------------------
    localparam logic [2:0] SEL_NONE   = 3'b000;
    localparam logic [2:0] SEL_INPUT  = 3'b001;   // write
    localparam logic [2:0] SEL_OUTPUT = 3'b010;   // read
    localparam logic [2:0] SEL_CMD    = 3'b011;   // write
    localparam logic [2:0] SEL_STATUS = 3'b100;   // read
    localparam logic [2:0] SEL_MODE   = 3'b101;   // read/write

    // --------------------------------------------------------------
    // Command opcodes (datasheet Figure 2).
    // --------------------------------------------------------------
    localparam logic [7:0] CMD_RESET          = 8'h00;

    localparam logic [7:0] CMD_LOAD_E_CLEAR_MP  = 8'h11;
    localparam logic [7:0] CMD_LOAD_D_CLEAR_MP  = 8'h12;
    localparam logic [7:0] CMD_LOAD_E_ENC_MP    = 8'h31;
    localparam logic [7:0] CMD_LOAD_D_ENC_MP    = 8'h32;
    localparam logic [7:0] CMD_LOAD_M_CLEAR_AUX = 8'h91;
    localparam logic [7:0] CMD_LOAD_E_CLEAR_AUX = 8'h81;
    localparam logic [7:0] CMD_LOAD_D_CLEAR_AUX = 8'h92;
    localparam logic [7:0] CMD_LOAD_E_ENC_AUX   = 8'hB1;
    localparam logic [7:0] CMD_LOAD_D_ENC_AUX   = 8'hB2;

    localparam logic [7:0] CMD_LOAD_IVE_CLEAR = 8'h85;
    localparam logic [7:0] CMD_LOAD_IVD_CLEAR = 8'h84;
    localparam logic [7:0] CMD_LOAD_IVE_ENC   = 8'hA5;
    localparam logic [7:0] CMD_LOAD_IVD_ENC   = 8'hA4;
    localparam logic [7:0] CMD_READ_IVE_CLEAR = 8'h8D;
    localparam logic [7:0] CMD_READ_IVD_CLEAR = 8'h8C;
    localparam logic [7:0] CMD_READ_IVE_ENC   = 8'hA9;
    localparam logic [7:0] CMD_READ_IVD_ENC   = 8'hA8;

    localparam logic [7:0] CMD_ENCRYPT_MKEY = 8'h39;
    localparam logic [7:0] CMD_START_ENC    = 8'h41;
    localparam logic [7:0] CMD_START_DEC    = 8'h40;
    localparam logic [7:0] CMD_START        = 8'hC0;
    localparam logic [7:0] CMD_STOP         = 8'hE0;

    // --------------------------------------------------------------
    // Port-flag association (datasheet Figure 6).
    // bit0: 1 = Input Register flag drives SFLG (else MFLG).
    // bit1: 1 = Output Register flag drives SFLG (else MFLG).
    // --------------------------------------------------------------
    function automatic logic [1:0] f_flag_assoc(logic enc_dec,
                                                logic [1:0] cfg);
        case ({enc_dec, cfg})
            3'b0_00: f_flag_assoc = 2'b10;  // in=MFLG out=SFLG
            3'b0_01: f_flag_assoc = 2'b01;  // in=SFLG out=MFLG
            3'b0_10: f_flag_assoc = 2'b10;  // in=MFLG out=SFLG
            3'b1_00: f_flag_assoc = 2'b01;  // in=SFLG out=MFLG
            3'b1_01: f_flag_assoc = 2'b10;  // in=MFLG out=SFLG
            3'b1_10: f_flag_assoc = 2'b10;  // in=MFLG out=SFLG
            default: f_flag_assoc = 2'b10;  // reserved config
        endcase
    endfunction

    // --------------------------------------------------------------
    // Pipeline timing constants (datasheet p. 2-477).
    // --------------------------------------------------------------
    localparam int unsigned IN_BYTES       = 8;  // bytes per block
    localparam int unsigned FLAG_DELAY     = 5;  // in-flag holdoff after start
    localparam int unsigned RESET_BLACKOUT = 5;  // A11: post-reset blackout

`endif // AMD_AM9518_DEFS_SVH

// Generated from manufacturer commands.csv. {engine[1:0],fixed_op[2:0],status_mask[6:0]}.
function automatic [11:0] command_descriptor(input logic [6:0] command);
 case(command)
  7'h00: command_descriptor=12'h07f; // NOP
  7'h01: command_descriptor=12'hc7e; // SQRT
  7'h02: command_descriptor=12'hc60; // SIN
  7'h03: command_descriptor=12'hc60; // COS
  7'h04: command_descriptor=12'hc7e; // TAN
  7'h05: command_descriptor=12'hc7e; // ASIN
  7'h06: command_descriptor=12'hc7e; // ACOS
  7'h07: command_descriptor=12'hc60; // ATAN
  7'h08: command_descriptor=12'hc7e; // LOG
  7'h09: command_descriptor=12'hc7e; // LN
  7'h0a: command_descriptor=12'hc7e; // EXP
  7'h0b: command_descriptor=12'hc7e; // PWR
  7'h10: command_descriptor=12'h87e; // FADD
  7'h11: command_descriptor=12'h87e; // FSUB
  7'h12: command_descriptor=12'h87e; // FMUL
  7'h13: command_descriptor=12'h87e; // FDIV
  7'h15: command_descriptor=12'h060; // CHSF
  7'h17: command_descriptor=12'h060; // PTOF
  7'h18: command_descriptor=12'h060; // POPF
  7'h19: command_descriptor=12'h060; // XCHF
  7'h1a: command_descriptor=12'h060; // PUPI
  7'h1c: command_descriptor=12'h860; // FLTD
  7'h1d: command_descriptor=12'h860; // FLTS
  7'h1e: command_descriptor=12'h87e; // FIXD
  7'h1f: command_descriptor=12'h87e; // FIXS
  7'h2c: command_descriptor=12'h47f; // DADD
  7'h2d: command_descriptor=12'h4ff; // DSUB
  7'h2e: command_descriptor=12'h57e; // DMUL
  7'h2f: command_descriptor=12'h67e; // DDIV
  7'h34: command_descriptor=12'h6fe; // CHSD
  7'h36: command_descriptor=12'h5fe; // DMUU
  7'h37: command_descriptor=12'h060; // PTOD
  7'h38: command_descriptor=12'h060; // POPD
  7'h39: command_descriptor=12'h060; // XCHD
  7'h6c: command_descriptor=12'h47f; // SADD
  7'h6d: command_descriptor=12'h4ff; // SSUB
  7'h6e: command_descriptor=12'h57e; // SMUL
  7'h6f: command_descriptor=12'h67e; // SDIV
  7'h74: command_descriptor=12'h6fe; // CHSS
  7'h76: command_descriptor=12'h5fe; // SMUU
  7'h77: command_descriptor=12'h060; // PTOS
  7'h78: command_descriptor=12'h060; // POPS
  7'h79: command_descriptor=12'h060; // XCHS
  default: command_descriptor=0;
 endcase
endfunction

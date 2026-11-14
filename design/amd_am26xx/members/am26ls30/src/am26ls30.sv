`timescale 1ns/1ps
// Am26LS30 dual differential RS-422 party-line / quad single-ended
// RS-423 line driver (functional reconstruction).
//
// Contract: 1979 AMD Linear and Interface Data Book, pages 4-30 to 4-35
// (logic diagrams BLI-002/BLI-003 and connection diagram BLI-005 on
// page 4-30; FUNCTION TABLE on page 4-34). A MODE control pin (4)
// selects the configuration:
//
//   MODE = 1 (RS-423, quad single-ended): four independent non-inverting
//   drivers, always driven:
//     out_a = in_a; out_b = in_b; out_c = in_c; out_d = in_d
//
//   MODE = 0 (RS-422, dual differential party-line): two differential
//   driver pairs with complementary outputs and active-low enables on
//   the B/C pins:
//     out_a = !in_b ? in_a  : 'Z;  out_b = !in_b ? !in_a : 'Z
//     out_c = !in_c ? in_d  : 'Z;  out_d = !in_c ? !in_d : 'Z
//
// verified row-by-row against the published function table. The
// slew-rate-control pins are analog-only. The analog envelope (RS-422
// 100-ohm differential drive / RS-423 swing from VCC/VEE, slew-rate
// figures, three-state delays) is documented in the spec and not
// modeled.
module am26ls30 (
    input  logic in_a_i,       // INPUT A           pin 2
    input  logic in_b_i,       // INPUT/ENABLE B    pin 3
    input  logic mode_i,       // MODE              pin 4: 1 = RS-423
    input  logic in_c_i,       // INPUT/ENABLE C    pin 6
    input  logic in_d_i,       // INPUT D           pin 7
    output logic out_a_o,      // OUTPUT A          pin 15
    output logic out_b_o,      // OUTPUT B          pin 14
    output logic out_c_o,      // OUTPUT C          pin 11
    output logic out_d_o,      // OUTPUT D          pin 10
    input  logic sr_a_i,       // SLEW RATE CONTROL A pin 16 (unmodeled)
    input  logic sr_b_i,       // SLEW RATE CONTROL B pin 13 (unmodeled)
    input  logic sr_c_i,       // SLEW RATE CONTROL C pin 12 (unmodeled)
    input  logic sr_d_i        // SLEW RATE CONTROL D pin 9  (unmodeled)
);
  // Slew-rate-control pins are analog-only; documented unused inputs.
  logic _unused_sr = &{1'b1, sr_a_i, sr_b_i, sr_c_i, sr_d_i};

  logic out_a_422, out_b_422, out_c_422, out_d_422;
  assign out_a_422 = !in_b_i ? in_a_i  : 1'bz;
  assign out_b_422 = !in_b_i ? !in_a_i : 1'bz;
  assign out_c_422 = !in_c_i ? in_d_i  : 1'bz;
  assign out_d_422 = !in_c_i ? !in_d_i : 1'bz;

  logic out_a_423, out_b_423, out_c_423, out_d_423;
  assign out_a_423 = in_a_i;
  assign out_b_423 = in_b_i;
  assign out_c_423 = in_c_i;
  assign out_d_423 = in_d_i;

  assign out_a_o = mode_i ? out_a_423 : out_a_422;
  assign out_b_o = mode_i ? out_b_423 : out_b_422;
  assign out_c_o = mode_i ? out_c_423 : out_c_422;
  assign out_d_o = mode_i ? out_d_423 : out_d_422;
endmodule

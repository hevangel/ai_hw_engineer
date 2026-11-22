// Four-state behaviour: X and Z must survive, and case equality must see them.
// The test is self-checking: it $fatal's on the first wrong observation, so a
// pass is a real result and not just a clean exit.
`timescale 1ns/1ps
module four_state;
  reg        drive = 1'b0;
  wire       pad;
  reg [1:0]  x_value;
  reg        out_y;

  assign pad = drive ? 1'b1 : 1'bz;

  initial begin
    // X must propagate through a logic gate.
    x_value = 2'b1x;
    if (x_value === 2'b10) $fatal(1, "case equality matched an X value");
    if (x_value !== 2'b1x) $fatal(1, "X was not retained");
    $display("X state retained");

    // Z on a wire, driven low and released.
    #1;
    if (pad !== 1'bz) $fatal(1, "release did not produce Z");
    drive = 1'b1;
    #1;
    if (pad !== 1'b1) $fatal(1, "drive did not produce 1");

    // Bit-select and part-select preserve four states.
    x_value = 2'bz1;
    if (x_value[1] !== 1'bz) $fatal(1, "bit-select lost Z");

    $display("FOUR STATE PASS");
    $finish;
  end
endmodule
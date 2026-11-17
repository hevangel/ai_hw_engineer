// A deliberate fatal: compilation and elaboration must succeed, the run must
// exit nonzero, and the statements after $fatal must not execute.
`timescale 1ns/1ps
module fatal_case;
  initial begin
    $display("BEFORE FATAL");
    $fatal(1, "EXPECTED AUDIT FAILURE");
    $display("AFTER FATAL");
  end
endmodule
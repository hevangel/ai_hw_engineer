// Smallest design used to host the VPI module.
// A single initial block is enough: the VPI callback fires at start of
// simulation regardless of what the design does.
module vpi_host;
  initial begin
    $display("VPI HOST START");
  end
endmodule
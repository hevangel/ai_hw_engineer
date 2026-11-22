// Deliberately malformed: the module is never closed.
module broken;
  initial begin
    $display("never reached");
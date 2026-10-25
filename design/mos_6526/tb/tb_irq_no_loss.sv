`timescale 1ns/1ps
module tb_irq_no_loss;
    tb_irq #(.TIMER_B_READ_LOSS(0)) regression();
endmodule

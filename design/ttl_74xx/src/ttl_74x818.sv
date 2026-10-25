module ttl_74x818 (
    input logic [7:0] d_bus_in,y_bus_in,
    input logic dclk,pclk,mode,sdi,oe_y_n,
    output logic [7:0] d_out,y_out,
    output logic d_drive,y_drive,sdo
);
    logic [7:0] diagnostic,pipeline;
    always_ff @(posedge dclk) begin
        d_drive <= mode && sdi;
        if(!mode) diagnostic <= {diagnostic[6:0],sdi};
        else if(!sdi) diagnostic <= y_bus_in;
    end
    always_ff @(posedge pclk)
        pipeline <= mode?diagnostic:d_bus_in;
    assign y_drive=!oe_y_n;
    assign d_out=d_drive?diagnostic:8'd0;
    assign y_out=y_drive?pipeline:8'd0;
    assign sdo=mode?sdi:diagnostic[7];
endmodule

module tb_front_panel_transport;
    logic [107519:0] pixels='0;
    int f;
    initial begin
        f=$fopen("work/front_panel.keys","w");
        $fwrite(f,"A%c",8'h80); $fclose(f);
        if($a2_key()!=32'h141 || $a2_key()!=32'h180 || $a2_key()!=0)
            $fatal(1,"Host key ordering/EOF");
        f=$fopen("work/front_panel.keys","a");
        $fwrite(f,"B"); $fclose(f);
        if($a2_key()!=32'h142 || $a2_key()!=0) $fatal(1,"Host appended keys after EOF");
        pixels[0]=1; pixels[1]=1'bx; pixels[107519]=1;
        $a2_frame(pixels);
        f=$fopen("work/front_panel.reset","w"); $fwrite(f,"R"); $fclose(f);
        if($a2_reset()!=1 || $a2_reset()!=0) $fatal(1,"Independent Reset event");
        $display("PASS front panel transport ordered keys, reset marker, EOF recovery and frame");
        $finish;
    end
endmodule

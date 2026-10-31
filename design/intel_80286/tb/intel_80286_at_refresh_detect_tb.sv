module intel_80286_at_refresh_detect_tb;
    logic refresh, preset_n, detect, board_detect, board_expected;
    intel_80286_at_refresh_detect dut (
        .refresh_i(refresh), .preset_n_i(preset_n), .detect_o(detect)
    );
    // The IBM board ties preset inactive via R19; its power-up state is not
    // specified. Compare changes against the observed initial state.
    intel_80286_at_refresh_detect board_connection (
        .refresh_i(refresh), .preset_n_i(1'b1), .detect_o(board_detect)
    );

    initial begin
        refresh=0; preset_n=1;
        #1 preset_n=0;
        #1 assert(detect===1'b1) else $fatal(1,"asynchronous preset failed");
        board_expected=board_detect;
        preset_n=1;
        #1 assert(detect===1'b1) else $fatal(1,"release changed detection");
        for (int cycle=0; cycle<16; cycle++) begin
            refresh=1;
            board_expected=!board_expected;
            #1 assert(detect===(cycle[0] ? 1'b1 : 1'b0))
                else $fatal(1,"wrong detect after refresh rising edge %0d",cycle);
            assert(board_detect===board_expected)
                else $fatal(1,"board pull-up connection missed edge %0d",cycle);
            #1 assert(detect===(cycle[0] ? 1'b1 : 1'b0))
                else $fatal(1,"detect changed while refresh held high");
            refresh=0;
            #1 assert(detect===(cycle[0] ? 1'b1 : 1'b0))
                else $fatal(1,"detect changed on refresh falling edge");
            assert(board_detect===board_expected)
                else $fatal(1,"board connection changed on falling edge");
        end
        refresh=1;
        #1 assert(detect===1'b0) else $fatal(1,"setup edge failed");
        preset_n=0;
        #1 assert(detect===1'b1) else $fatal(1,"preset while clock high failed");
        assert(board_detect===!board_expected)
            else $fatal(1,"device-only preset affected the board connection");
        refresh=0;
        #1 refresh=1;
        #1 assert(detect===1'b1) else $fatal(1,"clock overrode asserted preset");
        preset_n=1;
        #1 assert(detect===1'b1) else $fatal(1,"preset release made an edge");
        refresh=0;
        #1 refresh=1;
        #1 assert(detect===1'b0) else $fatal(1,"clock did not resume after preset");
        $display("PASS: AT U118 detect toggles only on +REFRESH rising edges and asynchronously presets");
        $finish;
    end
endmodule

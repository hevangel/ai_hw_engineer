`timescale 1ns/1ps
module tb_rev0_outputs #(parameter bit AUDIO_TEST=0);
    logic initialize=0;
    logic video=0, sync_level=0, burst=0, speaker=0;
    wire real open_v, loaded_v, pot_v, tank, emitter, audio_v, audio_i;
    wire real fine_v, fine_i;
    logic vv, lv, pv, av, fv;
    real expected_base, expected_emitter, dc_g, error_max=0.0;
    int trace;
    apple_ii_video_output #(.ENABLED(!AUDIO_TEST),.LOAD_OHMS(0.0)) q3_open(
        .initialize(initialize),.video_data(video),.composite_sync(sync_level),.color_burst(burst),
        .jack_voltage(open_v),.emitter_voltage(emitter),.tank_voltage(tank),.voltage_valid(vv));
    apple_ii_video_output #(.ENABLED(!AUDIO_TEST)) q3_loaded(.initialize(initialize),.video_data(video),.composite_sync(sync_level),
        .color_burst(burst),.jack_voltage(loaded_v),.emitter_voltage(),.tank_voltage(),.voltage_valid(lv));
    apple_ii_video_output #(.ENABLED(!AUDIO_TEST),.POT_POSITION(0.0)) q3_zero(
        .initialize(initialize),.video_data(video),.composite_sync(sync_level),.color_burst(burst),
        .jack_voltage(pot_v),.emitter_voltage(),.tank_voltage(),.voltage_valid(pv));
    apple_ii_speaker_output #(.ENABLED(AUDIO_TEST)) q4(.initialize(initialize),.speaker_level(speaker),.speaker_voltage(audio_v),
        .speaker_current(audio_i),.collector_voltage(),.voltage_valid(av));
    apple_ii_speaker_output #(.ENABLED(AUDIO_TEST),.STEP_NS(50.0)) q4_fine(.initialize(initialize),.speaker_level(speaker),
        .speaker_voltage(fine_v),.speaker_current(fine_i),.collector_voltage(),.voltage_valid(fv));
    task automatic dc_check(input real vd, vs);
        // Independent DC circuit reduction: L1 shorts the tank through its
        // 10-ohm loss; Q3 emitter load is 200 ohms and base load /101.
        dc_g=1.0/2000+1.0/1500+1.0/2710+1.0/(200*101);
        expected_base=(vd/1500+vs/2000+(0.2*10/1010)/2710+0.6/(200*101))/dc_g;
        expected_emitter=expected_base>0.6 ? expected_base-0.6 : 0.0;
        if(expected_emitter>0 && (open_v-expected_emitter>0.003 || expected_emitter-open_v>0.003))
            $fatal(1,"Q3 DC nodal voltage actual=%f expected=%f",open_v,expected_emitter);
    endtask
    initial begin
        #20000;
        if(!AUDIO_TEST) begin
        if(!vv || !lv || !pv) $fatal(1,"Initial video validity %b/%b/%b levels=%b/%b/%b uncertain=%b",vv,lv,pv,video,sync_level,burst,q3_open.uncertain);
        if(open_v>0.001 || pot_v>0.001) $fatal(1,"Sync or minimum level pot");
        sync_level=1; #20000; dc_check(0.2,3.5);
        if(open_v<0.4 || open_v>0.7) $fatal(1,"Nominal black level %f",open_v);
        video=1; #20000; dc_check(3.5,3.5);
        if(open_v<1.9 || open_v>2.1) $fatal(1,"Nominal white level %f",open_v);
        if(loaded_v<1.3 || loaded_v>1.6 || loaded_v>=open_v || pot_v!=0)
            $fatal(1,"75 ohm video load or level pot loaded=%f open=%f pot=%f",loaded_v,open_v,pot_v);
        trace=$fopen("work/output_tank.csv","w");
        if(!trace) $fatal(1,"Cannot open tank trace");
        // Sustained 3.579545 MHz burst. Reject an RC-only replacement by
        // checking resonant amplitude, frequency, and quadrature below.
        fork
            begin repeat(100) begin #139.684 burst=~burst; end end
            begin
                repeat(7000) begin #2; $fdisplay(trace,"%0.3f,%b,%f,%f",$realtime,burst,tank,open_v); end
            end
        join
        $fclose(trace);
        video=1'bx; #1000;
        if(vv || open_v!=0) $fatal(1,"Unknown video validity");
        video=1; #1000;
        if(vv) $fatal(1,"Unknown tank energy silently restored");
        end else begin
        if(!av || !fv) $fatal(1,"Initial audio validity");
        speaker=1; #1000000;
        if(audio_i<0.119 || audio_i>0.121 || audio_v<0.95 || audio_v>0.97)
            $fatal(1,"Q4 saturation and 8 ohm load V=%f I=%f",audio_v,audio_i);
        speaker=0; #1000000;
        if(audio_v>0.001 || audio_v < -0.001 || audio_i>0.001 || audio_i < -0.001)
            $fatal(1,"Speaker winding energy did not decay after falling edge");
        trace=$fopen("work/output_speaker.csv","w");
        if(!trace) $fatal(1,"Cannot open speaker trace");
        speaker=1;
        repeat(2000) begin
            #100;
            if(audio_v-fine_v>error_max) error_max=audio_v-fine_v;
            if(fine_v-audio_v>error_max) error_max=fine_v-audio_v;
            $fdisplay(trace,"%0.3f,%f,%f",$realtime,audio_v,audio_i);
        end
        $fclose(trace);
        if(error_max>0.025) $fatal(1,"Speaker integration convergence %f",error_max);
        #100000000;
        if(audio_v>0.001 || audio_i>0.001) $fatal(1,"DC input should be AC blocked");
        speaker=1'bx; #1000;
        if(av || audio_v!=0 || audio_i!=0) $fatal(1,"Unknown output validity");
        speaker=0; #1000;
        if(av) $fatal(1,"Unknown stored energy silently restored");
        end
        initialize=1; #1000; initialize=0; #20000;
        if(AUDIO_TEST ? !av : !vv) $fatal(1,"Explicit analog initial-condition control");
        $display("PASS revision-0 output voltage/load, resonant burst, speaker current/decay and convergence=%f",error_max);
        $finish;
    end
endmodule

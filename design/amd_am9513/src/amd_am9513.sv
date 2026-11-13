// verilator lint_off UNUSED
// AMD Am9513 System Timing Controller - functional reconstruction.
module amd_am9513 #(
  parameter int NUM_COUNTERS = 5
)(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        cs_n,
  input  logic        rd_n,
  input  logic        wr_n,
  input  logic        c_d,        // 1 = control port, 0 = data port
  inout  tri   [15:0] db,
  input  logic [4:0]  gate,
  input  logic [4:0]  src,
  output logic [4:0]  out,
  output logic        fout
);
  logic [15:0] mmr;
  logic [15:0] cmr   [0:NUM_COUNTERS-1];
  logic [15:0] loadr [0:NUM_COUNTERS-1];
  logic [15:0] holdr [0:NUM_COUNTERS-1];
  logic [15:0] cnt   [0:NUM_COUNTERS-1];
  logic [15:0] alarm [0:1];

  logic        armed [0:NUM_COUNTERS-1];
  logic [5:0]  dptr;
  logic        byte_ptr;

  logic [15:0] rd_data;
  logic        drive_bus;

  assign db = drive_bus ? rd_data : 16'bz;

  function automatic [15:0] bcd_inc(input [15:0] v);
    logic [3:0] d0,d1,d2,d3;
    begin
      d0=v[3:0]; d1=v[7:4]; d2=v[11:8]; d3=v[15:12];
      d0=d0+1;
      if (d0==10) begin d0=0; d1=d1+1; if (d1==10) begin d1=0; d2=d2+1; if (d2==10) begin d2=0; d3=d3+1; if (d3==10) d3=0; end end end
      return {d3,d2,d1,d0};
    end
  endfunction
  function automatic [15:0] bcd_dec(input [15:0] v);
    logic [3:0] d0,d1,d2,d3;
    begin
      d0=v[3:0]; d1=v[7:4]; d2=v[11:8]; d3=v[15:12];
      if (d0==0) begin d0=9; if (d1==0) begin d1=9; if (d2==0) begin d2=9; if (d3==0) d3=9; else d3=d3-1; end else d2=d2-1; end else d1=d1-1; end else d0=d0-1;
      return {d3,d2,d1,d0};
    end
  endfunction

  function automatic int grp(input [5:0] p); return p[5:3]; endfunction
  function automatic int elm(input [5:0] p); return p[2:1]; endfunction

  task automatic write_reg(input [5:0] p, input [15:0] data);
    int g,e;
    begin
      g=grp(p); e=elm(p);
      if (g>=1 && g<=NUM_COUNTERS) begin
        case (e)
          0: cmr[g-1]=data;
          1: loadr[g-1]=data;
          2: holdr[g-1]=data;
          default: ;
        endcase
      end else if (g==7) begin
        case (e)
          0: alarm[0]=data;
          1: alarm[1]=data;
          2: mmr=data;
          default: ;
        endcase
      end
    end
  endtask

  function automatic [15:0] read_reg(input [5:0] p);
    int g,e;
    logic [15:0] s;
    begin
      g=grp(p); e=elm(p);
      if (g>=1 && g<=NUM_COUNTERS) begin
        case (e)
          0: return cmr[g-1];
          1: return loadr[g-1];
          2: return holdr[g-1];
          default: return 16'h0;
        endcase
      end else if (g==7) begin
        case (e)
          0: return alarm[0];
          1: return alarm[1];
          2: return mmr;
          3: begin
               s=16'h0;
               for (int i=0;i<NUM_COUNTERS;i++) s[i]=out[i];
               s[15]=byte_ptr;
               return s;
             end
          default: return 16'h0;
        endcase
      end
      return 16'h0;
    end
  endfunction

  task automatic inc_ptr();
    int g,e;
    begin
      if (!mmr[14]) begin
        g=grp(dptr); e=elm(dptr);
        if (g>=1 && g<=NUM_COUNTERS) begin
          if (e==0) dptr[2:1]=2'b01;
          else if (e==1) dptr[2:1]=2'b10;
          else begin
            dptr[2:1]=2'b00;
            if (g<NUM_COUNTERS) dptr[5:3]=g+1;
            else dptr[5:3]=1;
          end
        end else if (g==7) begin
          if (e==0) dptr[2:1]=2'b01;
          else if (e==1) dptr[2:1]=2'b10;
          else if (e==2) dptr[2:1]=2'b11;
          else dptr[2:1]=2'b00;
        end
      end
      byte_ptr=1'b1;
    end
  endtask

  // FOUT divider logic (simplified: source = clk)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fout <= 1'b0;
    end else begin
      // fout toggles based on mmr divider
      if (mmr[12]) begin
        fout <= 1'b0; // gated off
      end else begin
        // divide clk by (mmr[11:8]+1) (1..16)
        if (fout_cnt == (mmr[11:8])) begin
          fout_cnt <= 4'd0;
          fout <= ~fout;
        end else begin
          fout_cnt <= fout_cnt + 1;
        end
      end
    end
  end

  // Counter operation
  genvar gi;
  generate
    for (gi=0; gi<NUM_COUNTERS; gi++) begin : CTR
      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          cnt[gi] <= 16'h0;
          armed[gi] <= 1'b0;
          out[gi] <= 1'b0;
        end else begin
          logic do_count;
          logic gate_active;
          int mode;
          mode = {cmr[gi][15:13], cmr[gi][7:5]};
          // gate condition
          gate_active = 1'b1;
          if (mode == 3'b001) begin // mode B level gating
            gate_active = gate[gi] ^ cmr[gi][8]; // polarity
          end
          do_count = armed[gi] && gate_active;

          // default out
          out[gi] <= 1'b0;

          // counting
          if (do_count) begin
            if (!cmr[gi][0]) begin // up
              if (cmr[gi][1]) begin // BCD
                if (cnt[gi] == 16'h9999) begin
                  cnt[gi] <= loadr[gi];
                  out[gi] <= 1'b1;
                  if (mode == 3'b000) armed[gi] <= 1'b0; // mode A disarm on TC
                end else begin
                  cnt[gi] <= bcd_inc(cnt[gi]);
                end
              end else begin
                if (cnt[gi] == 16'hFFFF) begin
                  cnt[gi] <= loadr[gi];
                  out[gi] <= 1'b1;
                  if (mode == 3'b000) armed[gi] <= 1'b0;
                end else begin
                  cnt[gi] <= cnt[gi] + 1;
                end
              end
            end else begin // down
              if (cmr[gi][1]) begin
                if (cnt[gi] == 16'h0000) begin
                  cnt[gi] <= loadr[gi];
                  out[gi] <= 1'b1;
                  if (mode == 3'b000) armed[gi] <= 1'b0;
                end else begin
                  cnt[gi] <= bcd_dec(cnt[gi]);
                end
              end else begin
                if (cnt[gi] == 16'h0000) begin
                  cnt[gi] <= loadr[gi];
                  out[gi] <= 1'b1;
                  if (mode == 3'b000) armed[gi] <= 1'b0;
                end else begin
                  cnt[gi] <= cnt[gi] - 1;
                end
              end
            end
          end

          // alarm compare override for counters 0,1
          if (gi < 2 && mmr[2+gi]) begin // comparator enable MM2/MM3
            if (cnt[gi] == alarm[gi]) out[gi] <= 1'b1;
            else out[gi] <= 1'b0;
          end
        end
      end
    end
  endgenerate

  // Bus read/write
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      drive_bus <= 1'b0;
      rd_data <= 16'h0;
    end else begin
      if (!cs_n && !rd_n) begin
        drive_bus <= 1'b1;
        if (c_d) begin
          rd_data <= {8'h0, holdr[0][7:0]}; // simplified status? 
          // Actually status via control port: return status register
          rd_data <= read_reg(6'h3F); // control group status (g=7,e=3 => 11111? 7*8+3=59=0b111011) 
        end else begin
          rd_data <= read_reg(dptr);
          inc_ptr();
        end
      end else if (!cs_n && !wr_n) begin
        drive_bus <= 1'b0;
        if (c_d) begin
          logic [7:0] cmd;
          cmd = db[7:0];
          if (cmd == 8'h00) begin
            mmr <= 16'h0;
            dptr <= 6'h0; byte_ptr <= 1'b1;
            for (int i=0;i<NUM_COUNTERS;i++) begin cmr[i]<=16'h0; loadr[i]<=16'h0; holdr[i]<=16'h0; cnt[i]<=16'h0; armed[i]<=1'b0; out[i]<=1'b0; end
            alarm[0]<=16'h0; alarm[1]<=16'h0;
          end else if (cmd[7:6]==2'b00 && cmd[5:0]!=6'h0) begin
            dptr <= cmd[5:0]; byte_ptr <= 1'b1;
          end else begin
            logic [4:0] msk;
            msk = cmd[4:0];
            case (cmd[7:5])
              3'b001: for (int i=0;i<NUM_COUNTERS;i++) if (msk[i]) armed[i]<=1'b1;
              3'b010: for (int i=0;i<NUM_COUNTERS;i++) if (msk[i]) armed[i]<=1'b0;
              3'b011: for (int i=0;i<NUM_COUNTERS;i++) if (msk[i]) cnt[i]<=loadr[i];
              3'b100: for (int i=0;i<NUM_COUNTERS;i++) if (msk[i]) holdr[i]<=cnt[i];
              3'b101: for (int i=0;i<NUM_COUNTERS;i++) if (msk[i]) begin if (!cmr[i][0]) cnt[i]<= (cmr[i][1]? bcd_inc(cnt[i]) : cnt[i]+1); else cnt[i]<= (cmr[i][1]? bcd_dec(cnt[i]) : cnt[i]-1); end
              3'b110: for (int i=0;i<NUM_COUNTERS;i++) if (msk[i]) begin cnt[i]<=loadr[i]; armed[i]<=1'b1; end
              3'b111: for (int i=0;i<NUM_COUNTERS;i++) if (msk[i]) begin holdr[i]<=cnt[i]; armed[i]<=1'b0; end
              default: ;
            endcase
          end
        end else begin
          write_reg(dptr, db);
          inc_ptr();
        end
      end else begin
        drive_bus <= 1'b0;
      end
    end
  end

`ifdef FORMAL
  cover property (@(posedge clk) 1);
`endif
endmodule
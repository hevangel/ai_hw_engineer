// Explicit numeric cut for controller-only proofs. Classification stays real;
// conversion results are abstract data, with no conversion exceptions. These
// proofs make no claim about arithmetic, rounding, or conversion correctness.
localparam logic [79:0] FP_INDEF=80'hffffc000000000000000;
function automatic logic fp_zero(input logic [79:0] x);
    fp_zero=x[78:0]==0;
endfunction
function automatic logic fp_inf(input logic [79:0] x);
    fp_inf=x[78:64]==15'h7fff&&x[63:0]==64'h8000000000000000;
endfunction
function automatic logic fp_nan(input logic [79:0] x);
    fp_nan=x[78:64]==15'h7fff&&x[62:0]!=0;
endfunction
function automatic logic fp_bad(input logic [79:0] x);
    fp_bad=x[78:64]!=0&&!x[63];
endfunction
function automatic logic [1:0] fp_tag(input logic [79:0] x);
    if(fp_zero(x)) fp_tag=1;
    else if(x[78:64]==0||x[78:64]==15'h7fff) fp_tag=2;
    else fp_tag=0;
endfunction
function automatic logic [79:0] fp_integer(input logic [63:0] x);
    fp_integer={16'd0,x};
endfunction
function automatic logic [85:0] fp_load(input logic [79:0] x,input logic [2:0] fmt);
    fp_load={6'd0,x};
endfunction
function automatic logic [86:0] fp_store(input logic [79:0] x,input logic [2:0] fmt,input logic [1:0] rc);
    fp_store={7'd0,x};
endfunction

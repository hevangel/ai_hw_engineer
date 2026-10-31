`timescale 1ns/1ps
// Is a bit-select of a non-zero-based packed formal correct, with no loop involved?
module probe_sel;
    int bad_desc[1:12];
    int bad_asc[1:12];
    int bad_zero[0:11];
    int total;

    // descending range [12:1], constant selects
    function automatic logic d1 (input logic [12:1] a); return a[1];  endfunction
    function automatic logic d2 (input logic [12:1] a); return a[2];  endfunction
    function automatic logic d3 (input logic [12:1] a); return a[3];  endfunction
    function automatic logic d4 (input logic [12:1] a); return a[4];  endfunction
    function automatic logic d5 (input logic [12:1] a); return a[5];  endfunction
    function automatic logic d6 (input logic [12:1] a); return a[6];  endfunction
    function automatic logic d7 (input logic [12:1] a); return a[7];  endfunction
    function automatic logic d8 (input logic [12:1] a); return a[8];  endfunction
    function automatic logic d9 (input logic [12:1] a); return a[9];  endfunction
    function automatic logic d10(input logic [12:1] a); return a[10]; endfunction
    function automatic logic d11(input logic [12:1] a); return a[11]; endfunction
    function automatic logic d12(input logic [12:1] a); return a[12]; endfunction

    // ascending range [1:12], constant selects
    function automatic logic u1 (input logic [1:12] a); return a[1];  endfunction
    function automatic logic u2 (input logic [1:12] a); return a[2];  endfunction
    function automatic logic u3 (input logic [1:12] a); return a[3];  endfunction
    function automatic logic u4 (input logic [1:12] a); return a[4];  endfunction
    function automatic logic u5 (input logic [1:12] a); return a[5];  endfunction
    function automatic logic u6 (input logic [1:12] a); return a[6];  endfunction
    function automatic logic u7 (input logic [1:12] a); return a[7];  endfunction
    function automatic logic u8 (input logic [1:12] a); return a[8];  endfunction
    function automatic logic u9 (input logic [1:12] a); return a[9];  endfunction
    function automatic logic u10(input logic [1:12] a); return a[10]; endfunction
    function automatic logic u11(input logic [1:12] a); return a[11]; endfunction
    function automatic logic u12(input logic [1:12] a); return a[12]; endfunction

    initial begin
        total = 0;
        for (int k = 1; k <= 12; k++) begin bad_desc[k] = 0; bad_asc[k] = 0; end
        for (int k = 0; k <= 11; k++) bad_zero[k] = 0;

        for (int v = 0; v < 4096; v++) begin
            logic [11:0] b;
            logic [12:1] a;
            logic [1:12] u;
            b = v[11:0];
            a = b;          // a[12] = b[11] ... a[1] = b[0]
            u = b;
            total++;
            if (d1(a)  !== b[0])  bad_desc[1]++;
            if (d2(a)  !== b[1])  bad_desc[2]++;
            if (d3(a)  !== b[2])  bad_desc[3]++;
            if (d4(a)  !== b[3])  bad_desc[4]++;
            if (d5(a)  !== b[4])  bad_desc[5]++;
            if (d6(a)  !== b[5])  bad_desc[6]++;
            if (d7(a)  !== b[6])  bad_desc[7]++;
            if (d8(a)  !== b[7])  bad_desc[8]++;
            if (d9(a)  !== b[8])  bad_desc[9]++;
            if (d10(a) !== b[9])  bad_desc[10]++;
            if (d11(a) !== b[10]) bad_desc[11]++;
            if (d12(a) !== b[11]) bad_desc[12]++;

            if (u1(u)  !== b[11]) bad_asc[1]++;
            if (u2(u)  !== b[10]) bad_asc[2]++;
            if (u3(u)  !== b[9])  bad_asc[3]++;
            if (u4(u)  !== b[8])  bad_asc[4]++;
            if (u5(u)  !== b[7])  bad_asc[5]++;
            if (u6(u)  !== b[6])  bad_asc[6]++;
            if (u7(u)  !== b[5])  bad_asc[7]++;
            if (u8(u)  !== b[4])  bad_asc[8]++;
            if (u9(u)  !== b[3])  bad_asc[9]++;
            if (u10(u) !== b[2])  bad_asc[10]++;
            if (u11(u) !== b[1])  bad_asc[11]++;
            if (u12(u) !== b[0])  bad_asc[12]++;
        end

        $write("descending [12:1] per-index mismatches:");
        for (int k = 1; k <= 12; k++) $write(" %0d=%0d", k, bad_desc[k]);
        $write("\nascending [1:12] per-index mismatches:");
        for (int k = 1; k <= 12; k++) $write(" %0d=%0d", k, bad_asc[k]);
        $write("\n");
        $finish;
    end
endmodule

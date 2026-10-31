module ttl_74x817 (
    input logic ai,bi,oeab_n,oeba_n,
    output logic [1:0] bo,
    output logic [5:0] ao,
    output logic bo_drive,ao_drive
);
    assign bo_drive=!oeab_n;
    assign ao_drive=!oeba_n;
    assign bo={2{!ai && !oeab_n}};
    assign ao={6{!bi && !oeba_n}};
endmodule

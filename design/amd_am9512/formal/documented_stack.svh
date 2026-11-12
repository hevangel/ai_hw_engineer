// Independent stack/status model used only by the formal transport proof.
// It follows the 1980 Am9512 chapter's stack tables; the numerical result is
// supplied by the abstracted FPU model.

function automatic logic [127:0] documented_stack(
    input logic [6:0] op,
    input logic [127:0] stack,
    input logic [31:0] single_result,
    input logic [63:0] double_result
);
    logic [31:0] tos;
    logic [63:0] dtos;
    begin
        tos = stack[127:96];
        dtos = stack[127:64];
        case (op)
            AMD_AM9512_OP_SADD,
            AMD_AM9512_OP_SSUB,
            AMD_AM9512_OP_SMUL,
            AMD_AM9512_OP_SDIV:
                documented_stack = {single_result, stack[63:0], 32'd0};
            AMD_AM9512_OP_DADD,
            AMD_AM9512_OP_DSUB,
            AMD_AM9512_OP_DMUL,
            AMD_AM9512_OP_DDIV:
                documented_stack = {double_result, 64'd0};
            AMD_AM9512_OP_CLR:
                documented_stack = stack;
            AMD_AM9512_OP_CHSS: begin
                if (tos[30:23] == 8'd0)
                    documented_stack = {32'd0, stack[95:0]};
                else
                    documented_stack = {tos ^ 32'h8000_0000, stack[95:0]};
            end
            AMD_AM9512_OP_CHSD: begin
                if (dtos[62:52] == 11'd0)
                    documented_stack = {64'd0, stack[63:0]};
                else
                    documented_stack = {dtos ^ 64'h8000_0000_0000_0000,
                                        stack[63:0]};
            end
            AMD_AM9512_OP_PTOS: begin
                if (tos[30:23] == 8'd0)
                    documented_stack = {32'd0, tos, stack[95:32]};
                else
                    documented_stack = {tos, tos, stack[95:32]};
            end
            AMD_AM9512_OP_PTOD:
                documented_stack = {dtos, dtos};
            AMD_AM9512_OP_POPS:
                documented_stack = {stack[95:0], stack[127:96]};
            AMD_AM9512_OP_POPD:
                documented_stack = {stack[63:0], stack[127:64]};
            AMD_AM9512_OP_XCHS:
                documented_stack = {stack[95:64], stack[127:96], stack[63:0]};
            default:
                documented_stack = stack;
        endcase
    end
endfunction

function automatic logic [7:0] doc_flags(input logic [4:0] flags);
    begin
        doc_flags = {1'b0, flags[4], flags[3], 1'b0,
                     flags[0], flags[2], flags[1], 1'b0};
    end
endfunction

function automatic logic [7:0] doc_status_single(input logic [31:0] word);
    logic zero, sign;
    begin
        zero = (word[30:23] == 8'd0);
        sign = zero ? 1'b0 : word[31];
        doc_status_single = {1'b0, sign, zero, 5'd0};
    end
endfunction

function automatic logic [7:0] doc_status_double(input logic [63:0] word);
    logic zero, sign;
    begin
        zero = (word[62:52] == 11'd0);
        sign = zero ? 1'b0 : word[63];
        doc_status_double = {1'b0, sign, zero, 5'd0};
    end
endfunction

function automatic logic [7:0] documented_status(
    input logic [6:0] op,
    input logic [127:0] stack,
    input logic [4:0] single_flags,
    input logic [4:0] double_flags
);
    logic [31:0] word_s;
    logic [63:0] word_d;
    begin
        case (op)
            AMD_AM9512_OP_SADD,
            AMD_AM9512_OP_SSUB,
            AMD_AM9512_OP_SMUL,
            AMD_AM9512_OP_SDIV:
                documented_status = doc_flags(single_flags);
            AMD_AM9512_OP_DADD,
            AMD_AM9512_OP_DSUB,
            AMD_AM9512_OP_DMUL,
            AMD_AM9512_OP_DDIV:
                documented_status = doc_flags(double_flags);
            AMD_AM9512_OP_CLR:
                documented_status = 8'h00;
            AMD_AM9512_OP_CHSS: begin
                word_s = stack[127:96];
                if (word_s[30:23] == 8'd0)
                    word_s = 32'd0;
                else
                    word_s[31] = ~word_s[31];
                documented_status = doc_status_single(word_s);
            end
            AMD_AM9512_OP_CHSD: begin
                word_d = stack[127:64];
                if (word_d[62:52] == 11'd0)
                    word_d = 64'd0;
                else
                    word_d[63] = ~word_d[63];
                documented_status = doc_status_double(word_d);
            end
            AMD_AM9512_OP_PTOS: begin
                word_s = stack[127:96];
                if (word_s[30:23] == 8'd0)
                    word_s = 32'd0;
                documented_status = doc_status_single(word_s);
            end
            AMD_AM9512_OP_PTOD:
                documented_status = doc_status_double(stack[127:64]);
            AMD_AM9512_OP_POPS:
                documented_status = doc_status_single({stack[95:64]});
            AMD_AM9512_OP_POPD:
                documented_status = doc_status_double(stack[63:0]);
            AMD_AM9512_OP_XCHS:
                documented_status = doc_status_single({stack[95:64]});
            default:
                documented_status = 8'h00;
        endcase
    end
endfunction
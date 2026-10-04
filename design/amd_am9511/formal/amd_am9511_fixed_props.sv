// Manufacturer direct arithmetic and protocol invariants. Iterative multiply
// and divide numerical results are independent simulation obligations here.
logic past_valid=0;
logic [5:0] age;
logic [2:0] accepted_operation;
logic [31:0] expected_simple;
logic [6:0] expected_status;
logic signed [32:0] ga, gb, gv;
logic [32:0] unsigned_sum;
logic [31:0] golden_result;
logic golden_overflow, golden_carry;
always_comb begin
    ga=single_i ? {{17{a_i[15]}},a_i[15:0]} : {a_i[31],a_i};
    gb=single_i ? {{17{b_i[15]}},b_i[15:0]} : {b_i[31],b_i};
    gv=operation_i==0 ? ga+gb : operation_i==1 ? gb-ga : -ga;
    golden_result=single_i ? {16'd0,gv[15:0]} : gv[31:0];
    golden_overflow=single_i ? (gv>32767 || gv< -32768) : (gv>33'sd2147483647 || gv< -33'sd2147483648);
    if(operation_i==1 && ga==(single_i ? -33'sd32768 : -33'sd2147483648))golden_overflow=1;
    unsigned_sum=single_i ? {17'd0,a_i[15:0]}+{17'd0,b_i[15:0]} : {1'b0,a_i}+{1'b0,b_i};
    golden_carry=operation_i==0 ? (single_i ? unsigned_sum[16] : unsigned_sum[32]) :
        operation_i==1 ? (single_i ? b_i[15:0]<a_i[15:0] : b_i<a_i) : 1'b0;
end
always_ff @(posedge clk_i)begin
    past_valid<=1;
    if(!past_valid)assume(reset_i);
    if(reset_i)begin age<=0;accepted_operation<=7;expected_simple<=0;expected_status<=0;end
    else if(state==IDLE && start_i)begin
        age<=1;accepted_operation<=operation_i;
        expected_simple<=golden_result;
        expected_status<={single_i ? golden_result[15] : golden_result[31],golden_result==0,
                           3'b000,golden_overflow,golden_carry};
    end else if(busy_o)age<=age+6'd1;
    else age<=0;
    if(past_valid)begin
        assert(done_o==(state==COMPLETE));
        assert(!busy_o || done_o || age<=33);
        if($past(reset_i))assert(!busy_o && !done_o && status_o==0);
        if(!$past(reset_i))begin
            if($past(done_o))assert(!busy_o&&!done_o);
            if(done_o && (accepted_operation==0 || accepted_operation==1 || accepted_operation==5))begin
                assert(result_o==expected_simple);
                assert(status_o==expected_status);
            end
            if($past(state==IDLE&&!start_i))begin
                assert(!busy_o); assert(result_o==$past(result_o));assert(status_o==$past(status_o));
            end
        end
        if(state==MULTIPLY||state==DIVIDE)assert(remaining>=1 && remaining<=32);
    end
    cover(past_valid&&done_o&&accepted_operation==0&&status_o[0]);
    cover(past_valid&&done_o&&accepted_operation==1&&status_o[1]);
    cover(past_valid&&done_o&&accepted_operation==2&&age==33);
    cover(past_valid&&done_o&&accepted_operation==3&&age==17);
    cover(past_valid&&done_o&&accepted_operation==4&&age==33);
    cover(past_valid&&done_o&&accepted_operation==5&&status_o[1]);
    cover(past_valid&&reset_i&&busy_o&&!done_o);
    cover(past_valid&&done_o&&!result_defined_o);
end

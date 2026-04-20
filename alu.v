module alu(
    input [15:0]x, input [15:0]y,
    input issub,
    output cout, output [15:0]s,
    output iseq, output islt);

    wire [15:0]y_adjusted = issub ? ~y : y;
    wire [16:0]sum_ext = x + y_adjusted + issub;
    assign s = sum_ext[15:0];
    assign cout = sum_ext[16];
    assign iseq = s == 16'b0;
    assign islt = s[15];

endmodule


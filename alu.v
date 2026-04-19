module alu(
    input [7:0]x, input [7:0]y,
    input issub,
    output cout, output [7:0]s,
    output iseq, output islt);

    wire [7:0]y_adjusted = issub ? ~y : y;
    wire [8:0]sum_ext = x + y_adjusted + issub;
    assign s = sum_ext[7:0];
    assign cout = sum_ext[8];
    assign iseq = s == 8'b0;
    assign islt = s[7];

endmodule


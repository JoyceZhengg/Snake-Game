`timescale 1ns/1ps

module LFSR19(input clk, output randnum);
    integer i;
    //reg [18:0]seed = 19'b0110110110100001110;
    reg [18:0]cells = 19'b0110110110100001110;

    assign randnum = cells[18];

    /*initial begin
        for (i = 0; i < 19; i = i + 1) begin
            cells[i] <= seed[i];
        end
    end*/

    always @(posedge clk) begin
        for (i = 0; i < 18; i = i + 1) begin
            cells[i+1] <= cells[i];
        end
        cells[0] <= cells[18] ^ cells[17] ^ cells[16] ^ cells[13];
        //$write("rand: %b\n", randnum);
    end

endmodule

`timescale 1ns/1ps

module LFSR11(input clk, output randnum);
    integer i;
    //reg [10:0]seed = 11'b00001011101;
    reg [10:0]cells = 11'b00001011101;

    assign randnum = cells[10];

    /*initial begin
        for (i = 0; i < 11; i = i + 1) begin
            cells[i] <= seed[i];
        end
    end*/

    always @(posedge clk) begin
        for (i = 0; i < 10; i = i + 1) begin
            cells[i+1] <= cells[i];
        end
        cells[0] <= cells[10] ^ cells[8];
        //$write("rand: %b\n", randnum);
    end

endmodule

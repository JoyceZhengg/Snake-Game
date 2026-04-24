`timescale 1ns/1ps

module LFSR17(input clk, output randnum);
    integer i;
    //reg [16:0]seed = 17'b01011101110001110;
    reg [16:0]cells = 17'b01011101110001110;

    assign randnum = cells[16];

    /*initial begin
        for (i = 0; i < 17; i = i + 1) begin
            cells[i] <= seed[i];
        end
    end*/

    always @(posedge clk) begin
        for (i = 0; i < 16; i = i + 1) begin
            cells[i+1] <= cells[i];
        end
        cells[0] <= cells[16] ^ cells[13];
        //$write("rand: %b\n", randnum);
    end

endmodule

`timescale 1ns/1ps

module randgen(input clk, output[7:0]randnum_);
    wire bitA, bitB, bitC, randbit;
    LFSR11 LFSR11(clk, bitA);
    LFSR17 LFSR17(clk, bitB);
    LFSR19 LFSR19(clk, bitC);
    reg [7:0]randnum = 8'b00011010;

    assign randbit = bitC ? bitA : bitB;
    assign randnum_ = randnum;

    always @(posedge clk) begin
        //$write("A: %b, B: %b, C: %b\n", bitA, bitB, bitC);
        //$write("randbit: %b\n", randbit);
        randnum <= (randnum << 1) | randbit;
        //$write("%d\n", randnum);
    end

endmodule

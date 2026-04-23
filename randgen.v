`timescale 1ns/1ps

module randgen(input clk, output[15:0]randnum_);
    wire bitA, bitB, bitC, randbit;
    LFSR11 LFSR11(clk, bitA);
    LFSR17 LFSR17(clk, bitB);
    LFSR19 LFSR19(clk, bitC);
    reg [13:0]randnum = 14'b01011101110011;

    assign randbit = bitC ? bitA : bitB;
    assign randnum_ = {2'b0, randnum};

    always @(posedge clk) begin
        //$write("A: %b, B: %b, C: %b\n", bitA, bitB, bitC);
        //$write("randbit: %b\n", randbit);
        randnum <= (randnum << 1) | randbit;
        //$write("%d\n", randnum);
    end

endmodule

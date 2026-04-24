`timescale 1ns/1ps

module LFSR4(input clk, output randnum);
    integer i;
    //reg [3:0]seed = 4'b1001;
    reg [3:0]cells = 4'b1001;

    assign randnum = cells[3];

    /*initial begin
        for (i = 0; i < 4; i = i + 1) begin
            cells[i] <= seed[i];
        end
    end*/

    always @(posedge clk) begin
        for (i = 0; i < 3; i = i + 1) begin
            cells[i+1] <= cells[i];
        end
        cells[0] <= cells[3] ^ cells[2];
        //$write("rand: %d\n", randnum);
    end

endmodule

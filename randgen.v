`timescale 1ns/1ps

module randgen(input clk, output[7:0]randnum_);
    integer i;
    reg [3:0]seed = 4'b1001;
    reg cells[3:0];
    reg [7:0]randnum = 8'b00011010;

    assign randnum_ = randnum;

    initial begin
        for (i = 0; i < 4; i = i + 1) begin
            cells[i] <= seed[i];
        end
    end

    always @(posedge clk) begin
        for (i = 0; i < 3; i = i + 1) begin
            cells[i] <= cells[i+1];
        end
        cells[3] <= cells[3] ^ cells[0];
        randnum <= (randnum << 1) + cells[0];
        //$write("rand: %b\n", cells[0]);
        //$write("rand: %d\n", randnum);
    end

endmodule

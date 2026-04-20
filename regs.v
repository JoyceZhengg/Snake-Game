`timescale 1ns/1ps

module regs(input clk,
    input [2:0]raddr0_, output [7:0]rdata0,
    input [2:0]raddr1_, output [7:0]rdata1,
    input [2:0]raddr2_, output [7:0]rdata2,
    input wen, input [2:0]waddr, input [7:0]wdata);

    reg [7:0]data[0:7];

    reg [2:0]raddr0;
    reg [2:0]raddr1;
    reg [2:0]raddr2;

    assign rdata0 = data[raddr0];
    assign rdata1 = data[raddr1];
    assign rdata2 = data[raddr2];

    always @(posedge clk) begin
        raddr0 <= raddr0_;
        raddr1 <= raddr1_;
        raddr2 <= raddr2_;
        if (wen) begin
            data[waddr] <= wdata;
        end
    end

endmodule

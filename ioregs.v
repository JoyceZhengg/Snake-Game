`timescale 1ns/1ps
// A wrapper for the regs module that intercepts writes for r0 and handles them accordingly.
module ioregs(input clk,
    input [2:0]raddr0, output [15:0]rdata0,
    input [2:0]raddr1, output [15:0]rdata1,
    input [2:0]raddr2, output [15:0]rdata2,
    input wen, input [2:0]waddr, input [15:0]wdata);

    reg [2:0]raddr0_prev, raddr1_prev, raddr2_prev;

    wire [15:0]regrdata0, regrdata1, regrdata2;
    assign rdata0 = raddr0_prev == 0 ? 0 : regrdata0;
    assign rdata1 = raddr1_prev == 0 ? 0 : regrdata1;
    assign rdata2 = raddr2_prev == 0 ? 0 : regrdata2;

    wire [15:0]regwdata;
    assign regwdata = waddr == 0 ? 0 : wdata;

    regs regs(
        clk,
        raddr0, regrdata0,
        raddr1, regrdata1,
        raddr2, regrdata2,
        wen, waddr, regwdata);

    always @(posedge clk) begin
        if (wen && waddr == 0) begin
            $write("%c", wdata);
        end
        raddr0_prev <= raddr0;
        raddr1_prev <= raddr1;
        raddr2_prev <= raddr2;
    end

endmodule


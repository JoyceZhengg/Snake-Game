`timescale 1ns/1ps

module memcontroller(input clk,
    input [15:1]raddr0, output [15:0]rdata0,
    input [15:0]raddr1, output [7:0]rdata1,
    input wen, input [15:0]waddr, input [7:0]wdata);

    mem mem(clk, raddr0, rdata0, raddr1, rdata1, wen, waddr, wdata);

    /*always @(posedge clk) begin
        
    end*/

endmodule

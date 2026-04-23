`timescale 1ns/1ps

module memData(
    input wire clk,
    input wire [15:0] raddr,
    output reg [15:0] rdata,
    input wire wen,
    input wire [15:0] waddr,
    input wire [15:0] wdata
);
    // Upgraded from 8-bit to 16-bit wide memory!
    reg [15:0] memory [0:16383]; 

    // Convert the CPU's byte addresses (0x4000, 0x4002) 
    // to internal word indexes (0x2000, 0x2001)
    wire [13:0] safe_waddr = waddr[14:1];
    wire [13:0] safe_raddr = raddr[14:1];

    always @(posedge clk) begin
        if (wen) begin
            memory[safe_waddr] <= wdata;
        end
        rdata <= memory[safe_raddr];
    end

endmodule
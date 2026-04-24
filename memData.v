`timescale 1ns/1ps

module memData(
    input clk,
    input [15:0] raddr_, 
    output reg [15:0] rdata_,
    input wen, 
    input [15:0] waddr, 
    input [15:0] wdata
);
    // 16-bit wide memory array to prevent truncation
    reg [15:0] data [0:16383]; 

    // Convert byte addresses (0x4000) to word indexes (0x2000)
    wire [13:0] safe_waddr = waddr[14:1];
    wire [13:0] safe_raddr = raddr_[14:1]; // Use input address directly!

    always @(posedge clk) begin
        // 1-Cycle Read: Perfectly aligns with the CPU Writeback stage
        rdata_ <= data[safe_raddr];
        
        if (wen) begin
            data[safe_waddr] <= wdata;
        end
    end

endmodule
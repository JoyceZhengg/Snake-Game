`timescale 1ns/1ps

module memData(
    input clk,
    input [15:0] raddr_, 
    output reg [15:0] rdata_,
    input wen, 
    input [15:0] waddr, 
    input [15:0] wdata
);
    reg [15:0] data [0:16383]; 

    wire [13:0] safe_waddr = waddr[14:1];
    wire [13:0] safe_raddr = raddr_[14:1]; 

    always @(posedge clk) begin
        rdata_ <= data[safe_raddr];
        
        if (wen) begin
            data[safe_waddr] <= wdata;
        end
    end

endmodule
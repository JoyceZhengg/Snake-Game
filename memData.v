`timescale 1ns/1ps

module memData(
    input clk,
    input [15:0] raddr_, 
    output [15:0] rdata_,
    input wen, 
    input [15:0] waddr, 
    input [15:0] wdata
);
    // Upgraded to 16-bit wide memory array to prevent truncation
    reg [15:0] data [0:16383]; 

    reg [15:0] raddr;
    reg [15:0] rdata;

    assign rdata_ = rdata;

    // Convert byte addresses (0x4000) to word indexes (0x2000)
    wire [13:0] safe_waddr = waddr[14:1];
    wire [13:0] safe_raddr = raddr[14:1];

    always @(posedge clk) begin
        // Retaining your exact original pipeline delay
        raddr <= raddr_;
        rdata <= data[safe_raddr];
        
        if (wen) begin
            data[safe_waddr] <= wdata;
        end
    end

endmodule
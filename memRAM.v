`timescale 1ns/1ps

module memRAM(input clk,
    input [15:1]raddr_, output [15:0]rdata_);

    reg [15:0]data[0:16'h7fff];

    initial begin
        $readmemb("memRAM.bin",data);
    end

    reg [15:1]raddr;
    reg [15:0]rdata;

    assign rdata_ = rdata;

    always @(posedge clk) begin
        raddr <= raddr_;
        rdata <= data[raddr];
    end

endmodule

/*`timescale 1ns/1ps

module memFrameBuffer(input clk,
    input [15:0]raddr_, output [7:0]rdata_,
    input wen, input [15:0]waddr, input [7:0]wdata);

    reg [7:0]data[0:16'h7fff];

    // Simulation -- read initial content from file 
    initial begin
        $readmemb("memFrameBuffer.bin",data);
    end

    reg [15:0]raddr;
    reg [15:0]rdata;

    assign rdata_ = rdata;

    always @(posedge clk) begin
        raddr <= raddr_;
        rdata <= {data[raddr]};
        if (wen) begin
            data[waddr] <= wdata;
        end
    end

endmodule*/

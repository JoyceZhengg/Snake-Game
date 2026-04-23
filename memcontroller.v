`timescale 1ns/1ps

module memcontroller(input clk,
    input [15:1]raddr0, output [15:0]rdata0,            // CPU instruction read
    input [15:0]raddr1, output [15:0]rdata1,             // CPU button input / data read
    input wen, input [15:0]waddr, input [15:0]wdata,     // CPU data / frame buffer write
    input [3:0] buttons,                                // external button pins
    output [15:0]vga_raddr, input [7:0]vga_rdata,
    output vga_wen, output [15:0]vga_waddr, output [7:0]vga_wdata);

    // instructions
    memRAM RAM(clk, raddr0, rdata0);

    // data
    wire [15:0] data_out;
    wire data_wen;
    assign data_wen = (wen && waddr > 16'h3fff && waddr < 16'h8000);
    memData data(clk, raddr1, data_out, data_wen, waddr, wdata);

    // frame buffer
    /*wire fb_wen;
    assign fb_wen = (wen && waddr > 16'h7fff && waddr < 16'hd000);
    memFrameBuffer fb(clk, vga_raddr, vga_rdata, fb_wen, waddr, wdata);*/

    // button inputs (read only)
    wire [3:0] button_reg;
    wire ren = (raddr1 == 16'hd000);
    buttons_input b_input(clk, buttons, ren, button_reg);

    // cpu to vga frame buffer reads/writes
    assign vga_raddr = raddr1;
    assign vga_wen = (wen && waddr >= 16'h8000 && waddr < 16'hcaff);
    assign vga_waddr = waddr;
    assign vga_wdata = wdata[7:0];

    reg [15:0] raddr1_ = 0;
    reg [15:0] raddr1__ = 0;
    always @(posedge clk) begin
        raddr1_ <= raddr1;
        raddr1__ <= raddr1_;
    end

    assign rdata1 = raddr1__ < 16'h8000 ? data_out :
                    raddr1__ < 16'hcaff ? {8'b0, vga_rdata} :
                    raddr1__ == 16'd000 ? {12'b0, button_reg} : 16'b0; // 0 for undefined memory

endmodule

/*reg ren__;
    reg ren___;
    wire ren = ren___;

    wire [7:0] button_reg_;
    assign button_reg_[7:4] = 0;
    reg [7:0] button_reg__;
    reg [7:0] button_reg___;
    wire [7:0] button_reg = button_reg___;

    always @(posedge clk) begin
        ren__ <= ren_;
        ren___ <= ren__;

        button_reg__ <= button_reg_;
        button_reg___ <= button_reg__;
    end*/

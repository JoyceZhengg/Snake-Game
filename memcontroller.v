`timescale 1ns/1ps

module memcontroller(input clk,
    input [15:1]raddr0, output [15:0]rdata0,            //instruction read
    input [15:0]raddr1, output [7:0]rdata1,             //data/button/frame buffer read
    input wen, input [15:0]waddr, input [7:0]wdata,     //data write
    input [3:0] buttons);                               //external button pins

    // instructions or data
    wire [7:0] mem_out;
    wire mem_wen = wen && (waddr < 16'h8000);
    mem mem(clk, raddr0, rdata0, raddr1, mem_out, mem_wen, waddr, wdata);

    // vga -- frame buffer
    wire [7:0] vga_out;
    wire vga_wen = wen && (waddr > 16'h7fff && waddr < 16'hcacf);
    vga_controller vga(raddr1, vga_out, vga_wen, waddr, wdata);

    // button inputs (read only)
    buttons_input b_input(clk, buttons, ren, button_reg_[3:0]);

    // 2-cycle delay for button reads
    wire ren_ = raddr1 == 16'hd000;
    reg ren__;
    reg ren___;
    wire ren = ren___;

    wire [7:0] button_reg_;
    assign button_reg_[7:4] = 0;
    reg [7:0] button_reg__;
    reg [7:0] button_reg___;
    wire button_reg = button_reg___;

    always @(posedge clk) begin
        ren__ <= ren_;
        ren___ <= ren__;

        button_reg__ <= button_reg_;
        button_reg___ <= button_reg__;
    end

    assign rdata1 = raddr1 < 16'h8000 ? mem_out :
                    raddr1 > 16'h7fff && raddr1 < 16'hcacf ? vga_out : 
                    raddr1 == 16'hd000 ? button_reg : 8'h00; // 0 for undefined memory

endmodule

`timescale 1ns/1ps

module memcontroller(input clk,
    input [15:1]raddr0, output [15:0]rdata0,            //instruction read
    input [15:0]raddr1, output [15:0]rdata1,             //data/button/frame buffer read
    input wen, input [15:0]waddr, input [15:0]wdata,     //data write
    input [3:0] buttons);                               //external button pins

    // instructions or data
    wire [15:0] mem_out;
    wire mem_wen = wen && (waddr < 16'h8000);
    mem mem(clk, raddr0, rdata0, raddr1, mem_out, mem_wen, waddr, wdata);

    // vga -- frame buffer
    wire [7:0] vga_out;
    wire vga_wen = wen && (waddr > 16'h7fff && waddr < 16'hcacf);
    //vga_controller vga(raddr1, vga_out, vga_wen, waddr, wdata);
        // The VGA controller has an internal dual-port RAM. 
    // Port A is driven by the CPU wires below. Port B drives the screen.
    /*vga_controller my_vga (
        .clk_50mhz(CLOCK_50),
        .reset(!buttons[0]), // Assuming buttons[0] is used as a system reset
        
        // --- CPU Write Inputs ---
        .cpu_we(mem_wen),           // High when the CPU executes a STORE
        .cpu_addr(wb_str_addr),     // The target memory address
        .cpu_data(wb_str_data),     // The 8-bit color data
        
        // --- Physical VGA Outputs ---
        .vga_hsync(VGA_HS),
        .vga_vsync(VGA_VS),
        .vga_r(VGA_R),
        .vga_g(VGA_G),
        .vga_b(VGA_B),
        .vga_blank_n(VGA_BLANK_N),
        .vga_sync_n(VGA_SYNC_N),
        .vga_clk(VGA_CLK)
    );*/


    // button inputs (read only)
    wire [7:0] button_reg;
    assign button_reg[7:4] = 0;
    buttons_input b_input(clk, buttons, ren, button_reg[3:0]);

    // 2-cycle delay for button reads
    wire ren_ = raddr1 == 16'hd000;
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

    assign rdata1 = raddr1 < 16'h8000 ? mem_out :
                    raddr1 > 16'h7fff && raddr1 < 16'hcacf ? vga_out : 
                    raddr1 == 16'hd000 ? button_reg : 0; // 0 for undefined memory

endmodule

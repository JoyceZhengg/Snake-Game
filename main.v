`timescale 1ns/1ps

module main(
    input wire CLOCK_50,       // Physical 50 MHz clock pin
    input wire [3:0] buttons,  // Physical buttons

    // --- VGA Physical Output Pins ---
    output wire VGA_HS,        // Horizontal Sync
    output wire VGA_VS,        // Vertical Sync
    output wire [1:0] VGA_R,   // 2-bit Red
    output wire [1:0] VGA_G,   // 2-bit Green
    output wire [1:0] VGA_B    // 2-bit Blue
    );

    /*wire CLOCK_25;

    pll pll_inst (
        CLOCK_50, 1'b0, CLOCK_25
    );*/

    wire [15:0] vga_waddr;
    wire [7:0] vga_wdata;
    wire vga_wen;
    wire [15:0] vga_raddr;
    wire [7:0] vga_rdata;

    cpu cpu_inst (
        CLOCK_50, buttons, 
        vga_waddr, vga_wdata, vga_wen,
        vga_raddr, vga_rdata
    );

    vga_controller vga_inst (
        .clk_50mhz  (CLOCK_50), 
        .reset      (1'b0),      
        .cpu_wen    (vga_wen),
        .cpu_waddr  (vga_waddr),
        .cpu_wdata  (vga_wdata),
        .cpu_raddr  (vga_raddr),
        .cpu_rdata  (vga_rdata),
        .vga_hsync  (VGA_HS),
        .vga_vsync  (VGA_VS),
        .vga_r      (VGA_R),
        .vga_g      (VGA_G),
        .vga_b      (VGA_B)
    );

endmodule
`timescale 1ns/1ps

module tb_main();
    // Inputs to the system
    reg clk_50;
    reg [3:0] test_buttons;

    // Outputs from the system
    wire vga_hs, vga_vs;
    wire [1:0] vga_r, vga_g, vga_b;

    main uut (
        .CLOCK_50(clk_50),
        .buttons(test_buttons),
        .VGA_HS(vga_hs),
        .VGA_VS(vga_vs),
        .VGA_R(vga_r),
        .VGA_G(vga_g),
        .VGA_B(vga_b)
    );

    initial clk_50 = 0;
    always #10 clk_50 = ~clk_50;

    initial begin
        test_buttons = 4'b1111; 
        
        $display("Starting Simulation...");
        
        #2000;
        
        $display("Simulating Button Press on Button 0...");
        test_buttons = 4'b1110; 
        
        #500; 
        
        $display("Releasing Button...");
        test_buttons = 4'b1111; 
        
        #5000;
        
        $display("Simulation Finished.");
        $finish;
    end

    initial begin
        $dumpfile("button_test.vcd");
        $dumpvars(0, tb_main);
    end

endmodule
`timescale 1ns/1ps

module tb_main();
    // Inputs to the system
    reg clk_50;
    reg [3:0] test_buttons;

    // Outputs from the system
    wire vga_hs, vga_vs;
    wire [1:0] vga_r, vga_g, vga_b;

    // 1. Instantiate your Top Level Module
    main uut (
        .CLOCK_50(clk_50),
        .buttons(test_buttons),
        .VGA_HS(vga_hs),
        .VGA_VS(vga_vs),
        .VGA_R(vga_r),
        .VGA_G(vga_g),
        .VGA_B(vga_b)
    );

    // 2. Generate 50MHz Clock (20ns period)
    initial clk_50 = 0;
    always #10 clk_50 = ~clk_50;

    // 3. Simulated User Interaction
    initial begin
        // Initialize: FPGA buttons are usually pulled HIGH (1) when not pressed
        test_buttons = 4'b1111; 
        
        $display("Starting Simulation...");
        
        // Wait for 2000ns (allow CPU to execute initial MOVL/MOVH instructions)
        #2000;
        
        $display("Simulating Button Press on Button 0...");
        test_buttons = 4'b1110; // Press button 0 (logic 0)
        
        #500; // Hold for 500ns
        
        $display("Releasing Button...");
        test_buttons = 4'b1111; // Release (logic 1)
        
        // Run for a bit longer to see the CPU process the input
        #5000;
        
        $display("Simulation Finished.");
        $finish;
    end

    // 4. Waveform Generation (for GTKWave)
    initial begin
        $dumpfile("button_test.vcd");
        $dumpvars(0, tb_main);
    end

endmodule
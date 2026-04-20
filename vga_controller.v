module vga_controller (
    // CPU inputs
    input wire clk_50mhz,  // 50 MHz system clock
    input wire reset,  // Active high reset
    input wire cpu_we,  // Write Enable signal from the CPU
    input wire [15:0] cpu_addr,  // 16-bit address bus from the CPU
    input wire [7:0] cpu_data,  // 8-bit data bus from the CPU (RGB 3-3-2 color)
    
    // --- Physical VGA Output Pins (Cyclone V DAC) ---
    output reg  vga_hsync,   
    output reg  vga_vsync,   
    output wire [7:0] vga_r,       // 8-bit Red Channel
    output wire [7:0] vga_g,       // 8-bit Green Channel
    output wire [7:0] vga_b,       // 8-bit Blue Channel
    output wire  vga_blank_n, // DAC Blanking pin
    output wire  vga_sync_n,  // DAC Sync pin
    output wire  vga_clk      // DAC Clock pin
);

    // --- VGA timing parameters for 640x480 @ 60Hz ---
    parameter H_DISPLAY = 640;
    parameter H_FRONT_PORCH = 16;
    parameter H_SYNC = 96;
    parameter H_BACK_PORCH  = 48;
    parameter H_TOTAL = 800;

    parameter V_DISPLAY = 480;
    parameter V_FRONT_PORCH = 10;
    parameter V_SYNC = 2;
    parameter V_BACK_PORCH = 33;
    parameter V_TOTAL = 525;

    // Clock divider (50MHz -> 25 MHz)
    reg pixel_clk;
    always @(posedge clk_50mhz or posedge reset) begin
        if (reset) pixel_clk <= 0;
        else pixel_clk <= ~pixel_clk; 
    end
    assign vga_clk = pixel_clk; // Send pixel clock to the physical DAC

    // Horizontal and vertical counters
    reg [9:0] h_count;
    reg [9:0] v_count;

    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 0;
                if (v_count == V_TOTAL - 1) v_count <= 0;
                else v_count <= v_count + 1;
            end else begin
                h_count <= h_count + 1;
            end
        end
    end

    // Sync pulse generation, active low 
    always @(posedge pixel_clk) begin
        vga_hsync <= ~( (h_count >= H_DISPLAY + H_FRONT_PORCH) && 
                        (h_count < H_DISPLAY + H_FRONT_PORCH + H_SYNC) );
                        
        vga_vsync <= ~( (v_count >= V_DISPLAY + V_FRONT_PORCH) && 
                        (v_count < V_DISPLAY + V_FRONT_PORCH + V_SYNC) );
    end

    // Framebuffer Logic & Memory Inference
    wire video_on = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
    
    // We use a 160x120 logical grid to save memory (4x4 pixel blocks)
    // 160 * 120 = 19,200 total addresses needed.
    reg [7:0] frame_buffer [0:19199]; 
    reg [7:0] current_pixel_color;

    // CPU Port logic: Address offset & Bounds checking
    // 0x8000 is decimal 32,768. The valid range is 0x8000 to 0xCB1F (32768 + 19199).
    wire valid_cpu_vram_write = cpu_we && (cpu_addr >= 16'h8000) && (cpu_addr < 16'hCB20);
    wire [14:0] cpu_ram_index = cpu_addr - 16'h8000;

    // VGA Port logic: 4x4 Scaling and Read Address Calculation
    wire [7:0] scaled_x = h_count[9:2]; // Drop bottom 2 bits to divide by 4
    wire [7:0] scaled_y = v_count[9:2];
    
    // Address = (Y * 160) + X  => (Y * 128) + (Y * 32) + X
    wire [14:0] vga_read_addr = (scaled_y << 7) + (scaled_y << 5) + scaled_x;

    // The Dual-Port M10K Block RAM
    always @(posedge clk_50mhz) begin
        // Port A: CPU Write
        if (valid_cpu_vram_write) begin
            frame_buffer[cpu_ram_index] <= cpu_data;
        end
        
        // Port B: VGA Read
        if (vga_read_addr < 19200) begin
            current_pixel_color <= frame_buffer[vga_read_addr];
        end
    end

    // color lookup table
    // Translates the 1-byte game codes into 24-bit physical VGA colors.
    reg [7:0] lut_r;
    reg [7:0] lut_g;
    reg [7:0] lut_b;

    always @(*) begin
        case (current_pixel_color)
            8'h00: begin // Background -> GREEN
                lut_r = 8'h00;
                lut_g = 8'hFF; // Full intensity
                lut_b = 8'h00;
            end
            8'h01: begin // Snake -> BLUE
                lut_r = 8'h00;
                lut_g = 8'h00;
                lut_b = 8'hFF; // Full intensity
            end
            8'h10: begin // Banana -> YELLOW (Red + Green)
                lut_r = 8'hFF; // Full intensity
                lut_g = 8'hFF; // Full intensity
                lut_b = 8'h00;
            end
            default: begin // Unmapped Memory -> BLACK (Safety default)
                lut_r = 8'h00;
                lut_g = 8'h00;
                lut_b = 8'h00;
            end
        endcase
    end

    // --- Output Assignment ---
    // If the beam is in the visible area, output the LUT color.
    // If it is in the blanking porch, force output to 0 to not confuse the monitor.
    assign vga_r = video_on ? lut_r : 8'h00;
    assign vga_g = video_on ? lut_g : 8'h00;
    assign vga_b = video_on ? lut_b : 8'h00;

    assign vga_blank_n = video_on; 
    assign vga_sync_n = 1'b0; // Standard tie-off for the Cyclone V DAC

endmodule
module vga_controller (
    input wire clk_50mhz,  // 50 MHz system clock
    //input wire clk_25mhz.  // 25 MHz vga clock --> set this in Quartus through PLL
    input wire reset,      // Bypassed

    // --- CPU Memory Interface (Shared Port A) ---
    input wire cpu_wen,           // Write Enable from memcontroller
    input wire [15:0] cpu_waddr,  // Store Address (wb_str_addr)
    input wire [7:0] cpu_wdata,   // Store Data (wb_str_data)
    input wire [15:0] cpu_raddr,  // Load Address (ld_addr)
    output reg [7:0] cpu_rdata,   // Load Data back to memcontroller
    
    // --- Physical VGA Output Pins (Breadboard 6-bit DAC) ---
    output reg  vga_hsync,   
    output reg  vga_vsync,   
    output wire [1:0] vga_r,      // 2-bit Red
    output wire [1:0] vga_g,      // 2-bit Green
    output wire [1:0] vga_b       // 2-bit Blue
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

    // Clock divider (50MHz -> 25 MHz) - Reset bypassed
    reg pixel_clk = 0;
    always @(posedge clk_50mhz) begin
        pixel_clk <= ~pixel_clk; 
    end

    // Horizontal and vertical counters - Reset bypassed
    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;

    always @(posedge pixel_clk) begin
        if (h_count == H_TOTAL - 1) begin
            h_count <= 0;
            if (v_count == V_TOTAL - 1) v_count <= 0;
            else v_count <= v_count + 1;
        end else begin
            h_count <= h_count + 1;
        end
    end

    // Sync pulse generation, active low 
    always @(posedge pixel_clk) begin
        vga_hsync <= ~( (h_count >= H_DISPLAY + H_FRONT_PORCH) && 
                        (h_count < H_DISPLAY + H_FRONT_PORCH + H_SYNC) );
                        
        vga_vsync <= ~( (v_count >= V_DISPLAY + V_FRONT_PORCH) && 
                        (v_count < V_DISPLAY + V_FRONT_PORCH + V_SYNC) );
    end

    wire video_on = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
    
    // 160 * 120 = 19,200 total addresses needed.
    reg [7:0] frame_buffer [0:19199]; 
    reg [7:0] current_pixel_color;

    // ========================================================
    // MEMORY PORT MULTIPLEXING
    // ========================================================
    // If Write Enable is high, Port A uses the Write Address. 
    // Otherwise, Port A uses the Read Address.
    wire [15:0] active_cpu_addr = cpu_we ? cpu_waddr : cpu_raddr;
    wire valid_cpu_access = (active_cpu_addr >= 16'h8000) && (active_cpu_addr < 16'hCB00);
    wire [14:0] cpu_ram_index = active_cpu_addr - 16'h8000;

    wire [7:0] scaled_x = h_count[9:2]; 
    wire [7:0] scaled_y = v_count[9:2];
    wire [14:0] vga_read_addr = (scaled_y << 7) + (scaled_y << 5) + scaled_x;

    always @(posedge clk_50mhz) begin
        // PORT A: CPU Access (Reads and Writes)
        if (valid_cpu_access) begin
            if (cpu_we) begin
                frame_buffer[cpu_ram_index] <= cpu_wdata;
            end
            cpu_rdata <= frame_buffer[cpu_ram_index];
        end else begin
            cpu_rdata <= 8'h00; // Output 0 if the CPU looks outside VRAM
        end
        
        // PORT B: VGA Display Read
        if (vga_read_addr < 19200) begin
            current_pixel_color <= frame_buffer[vga_read_addr];
        end
    end

    // Translates the 1-byte game codes into physical VGA colors.
    reg [7:0] lut_r;
    reg [7:0] lut_g;
    reg [7:0] lut_b;

    always @(*) begin
        case (current_pixel_color)
            8'h00: begin lut_r = 8'h00; lut_g = 8'hFF; lut_b = 8'h00; end // GREEN
            8'h01: begin lut_r = 8'h00; lut_g = 8'h00; lut_b = 8'hFF; end // BLUE
            8'h10: begin lut_r = 8'hFF; lut_g = 8'hFF; lut_b = 8'h00; end // YELLOW
            default: begin lut_r = 8'h00; lut_g = 8'h00; lut_b = 8'h00; end // BLACK
        endcase
    end

    // Extract only the top 2 bits [7:6] to send to the breadboard resistors
    assign vga_r = video_on ? lut_r[7:6] : 2'b00;
    assign vga_g = video_on ? lut_g[7:6] : 2'b00;
    assign vga_b = video_on ? lut_b[7:6] : 2'b00;

endmodule
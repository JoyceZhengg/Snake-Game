module vga_controller (
    input wire clk_50mhz,  
    input wire reset,  

    // cpu to mem interfacing
    input wire cpu_wen,  
    input wire [15:0] cpu_waddr,  
    input wire [7:0] cpu_wdata,   
    input wire [15:0] cpu_raddr,  
    output reg [7:0] cpu_rdata,  
    
    // vga output pins
    output reg  vga_hsync,   
    output reg  vga_vsync,   
    output wire [1:0] vga_r,  
    output wire [1:0] vga_g, 
    output wire [1:0] vga_b  
);

    // vga timing params
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
    reg pixel_clk = 0;
    always @(posedge clk_50mhz) begin
        pixel_clk <= ~pixel_clk; 
    end

    // Horizontal and vertical counters 
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
    
    reg [7:0] frame_buffer [0:19199]; 

    integer row, col;
    initial begin
        for (row = 0; row < 120; row = row + 1) begin
            for (col = 0; col < 160; col = col + 1) begin
                frame_buffer[row * 160 + col] = 8'h00; // Initialize to Green
            end
        end
    end
    reg [7:0] current_pixel_color;

    // mem port muxing
    wire [15:0] active_cpu_addr = cpu_wen ? cpu_waddr : cpu_raddr; 
    wire valid_cpu_access = (active_cpu_addr >= 16'h8000) && (active_cpu_addr < 16'hCB00);

    wire [7:0] scaled_x = h_count[9:2]; 
    wire [7:0] scaled_y = v_count[9:2];
    wire [14:0] raw_vga_addr = (scaled_y << 7) + (scaled_y << 5) + scaled_x;

    wire [14:0] safe_cpu_index = valid_cpu_access ? (active_cpu_addr - 16'h8000) : 15'd0;
    wire [14:0] safe_vga_index = (raw_vga_addr < 19200) ? raw_vga_addr : 15'd0;

    reg [7:0] raw_cpu_rdata;

    always @(posedge clk_50mhz) begin
        // PORT A: Unconditional Read/Write
        if (cpu_wen && valid_cpu_access) begin
            frame_buffer[safe_cpu_index] <= cpu_wdata;
        end
        raw_cpu_rdata <= frame_buffer[safe_cpu_index]; 
        
        // PORT B: Unconditional Read
        current_pixel_color <= frame_buffer[safe_vga_index];
    end

    always @(*) begin
        cpu_rdata = raw_cpu_rdata; 
    end

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

    // Extract only the top 2 bits [7:6] to send to DAC resistors
    assign vga_r = video_on ? lut_r[7:6] : 2'b00;
    assign vga_g = video_on ? lut_g[7:6] : 2'b00;
    assign vga_b = video_on ? lut_b[7:6] : 2'b00;

endmodule
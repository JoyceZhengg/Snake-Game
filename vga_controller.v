module vga_controller (
    input wire clk_50mhz, // 50 Mhz system clock
    input wire reset,  // active high reset
    
    // vga output pins
    output reg vga_hsync,  // horizontal sync pulse
    output reg vga_vsync,  // vertical sync pulse
    output wire video_on,  
    
    // frame buffer coordinate outputs
    output wire [9:0] pixel_x, // from 0-640
    output wire [9:0] pixel_y  // from 0-480
);

    // VGA timing parameters for 640x480 @ 60Hz
    // horizontal (in pixel clocks)
    parameter H_DISPLAY = 640;
    parameter H_FRONT_PORCH = 16;
    parameter H_SYNC = 96;
    parameter H_BACK_PORCH = 48;
    parameter H_TOTAL = 800;

    // Vertical (in horizontal lines)
    parameter V_DISPLAY = 480;
    parameter V_FRONT_PORCH = 10;
    parameter V_SYNC = 2;
    parameter V_BACK_PORCH = 33;
    parameter V_TOTAL = 525;

    // clock divider (50MHz -> 25 MHz)
    reg pixel_clk;
    always @(posedge clk_50mhz or posedge reset) begin
        if (reset)
            pixel_clk <= 0;
        else
            pixel_clk <= ~pixel_clk; 
    end

    // horizontal and vertical counters
    reg [9:0] h_count;
    reg [9:0] v_count;

    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 0;
                if (v_count == V_TOTAL - 1)
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
            end else begin
                h_count <= h_count + 1;
            end
        end
    end

    // sync pulse generation, active low
    always @(posedge pixel_clk) begin
        vga_hsync <= ~( (h_count >= H_DISPLAY + H_FRONT_PORCH) && 
                        (h_count < H_DISPLAY + H_FRONT_PORCH + H_SYNC) );
                        
        vga_vsync <= ~( (v_count >= V_DISPLAY + V_FRONT_PORCH) && 
                        (v_count < V_DISPLAY + V_FRONT_PORCH + V_SYNC) );
    end

    // output assignments
    assign video_on = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
    
    // output current coords for frame buffer
    assign pixel_x = (video_on) ? h_count : 10'd0;
    assign pixel_y = (video_on) ? v_count : 10'd0;

endmodule

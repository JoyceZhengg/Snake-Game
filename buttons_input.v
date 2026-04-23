`timescale 1ns/1ps

module buttons_input(input clk, input [3:0] buttons, input ren, output [3:0] button_reg_); 

    // synchronizer
    reg [3:0] sync1 = 0;
    reg [3:0] sync2 = 0;

    always @(posedge clk) begin
        sync1 <= ~buttons; //active low
        sync2 <= sync1;
    end 

    // debouncer
    wire [3:0] debounced_signal;
    debouncer b1(clk, sync2[0], debounced_signal[0]);
    debouncer b2(clk, sync2[1], debounced_signal[1]);
    debouncer b3(clk, sync2[2], debounced_signal[2]);
    debouncer b4(clk, sync2[3], debounced_signal[3]);

    // edge detector 
    reg [3:0] prev_state = 0;

    always @(posedge clk) begin
        prev_state <= debounced_signal;
    end

    wire [3:0] pulse;
    assign pulse = debounced_signal & ~prev_state; //pulse = 1 only when debounced_signal = 1 and prev_state = 0

    // input register
    reg [3:0] button_reg = 0;

    always @(posedge clk) begin
        if (ren) begin
            button_reg <= pulse; //clear old value of input_reg
        end else begin
            button_reg <= button_reg | pulse; 
        end
    end

    reg [3:0] button_reg1 = 0;
    reg [3:0] button_reg2 = 0;
    assign button_reg_ = button_reg2;

    // 2-cycle delay
    always @(posedge clk) begin
        button_reg1 <= button_reg;
        button_reg2 <= button_reg1;
    end

endmodule
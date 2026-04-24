`timescale 1ns/1ps

module debouncer(input clk, 
                 input signal_in, output signal_out_);

    reg [18:0] threshhold = 0;

    reg signal_out = 0;
    assign signal_out_ = signal_out;

    always @(posedge clk) begin
        if (signal_in == 1) begin
            if (threshhold < 50000) begin
                threshhold <= threshhold + 1;
            end else begin
                signal_out <= 1;
            end
        end else begin
            threshhold <= 0;
            signal_out <= 0;
        end
    end

endmodule
module led_on (
    output [7:0] LEDR // 8 Red LEDs on C5G Board
);

    // Active Low LEDs: 8'h00 turns all LEDs on, 8'hFF turns them off
    assign LEDR = 8'h00; 

endmodule

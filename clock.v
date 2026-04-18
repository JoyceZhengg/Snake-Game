/* clock */
`timescale 1ns/1ps
module clock(output clk);
    reg theClock = 1;

    assign clk = theClock;
    
    always begin
        #10;
        theClock = !theClock;
    end
endmodule

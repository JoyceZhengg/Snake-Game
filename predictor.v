`timescale 1ns/1ps

module predictor(input clk, input [15:1]pc, output [15:1]prediction, 
                input branched, input [15:1]branched_pc, input [15:1]branched_target,
                input mispredict, input jumped);
    reg [1:0]belief[0:511];
    reg [15:1]targets[0:511];

    // Belief: 0th bit represents whether a jump is predicted, 1st bit represents confidence

    integer i;
    initial begin
        for (i = 0; i < 512; i = i + 1) begin
            belief[i] = 0;
        end
    end

    wire will_jmp = belief[pc[9:1]][0];
    assign prediction = will_jmp ? targets[pc[9:1]] : pc + 1;

    wire correct = jumped == belief[branched_pc][0];

    always @(posedge clk) begin
        if (branched) begin
            targets[branched_pc] <= branched_target;
        end
        if (mispredict) begin
            belief[branched_pc][1] <= correct;
            belief[branched_pc][0] <= (!belief[branched_pc][1] & !correct) ? !belief[branched_pc][0] : belief[branched_pc][0];
        end
    end

endmodule

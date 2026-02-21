`timescale 1ns / 1ps
module tb;

    reg clk;
    reg rst;
    reg [31:0] instr;
    wire [31:0] alu_out;

    // Instantiate DUT
    top_module DUT (
        .clk(clk),
        .rst(rst),
        .instr(instr),
        .alu_out(alu_out)
    );

    // Clock generation (10ns period)
    always #5 clk = ~clk;

    // Instruction generation
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb);

        clk = 0;
        rst = 1;
        instr = 0;

        #20;
        rst = 0;
    
    #25;  // after reset is released
    DUT.RB.regfile[1] = 10;
    DUT.RB.regfile[2] = 20;


        // ADD x3, x1, x2
        instr = 32'b0000000_00010_00001_000_00011_0110011;
        #10;

        // SUB x4, x1, x2
        instr = 32'b0100000_00010_00001_000_00100_0110011;
        #10;

        // XOR x5, x1, x2
        instr = 32'b0000000_00010_00001_100_00101_0110011;
        #10;

        instr = 32'b0;

        #100;
        $finish;
    end

    initial begin
        $monitor("Time=%0t | ALU_OUT=%0d", $time, alu_out);
    end

endmodule   
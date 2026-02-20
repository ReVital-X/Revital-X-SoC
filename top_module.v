`timescale 1ns / 1ps

module top_module(
    input clk,rst,
    output [31:0] alu_out
    );
    
    // -------------------- Instruction Fetch -------------------- 
    wire [31:0] pc;
    wire [31:0] instr;
    instruction_fetch IF(
        .clk(clk),
        .rst(rst),
        .pc(pc)
    );
    
    // -------------------- Decoder unit -------------------- 
    wire [4:0] rd, rs1, rs2;
    wire [3:0] alu_op;
    wire reg_write;
    Decoder_Rtype DEC(
            .instr(instr),
            .rd(rd),
            .rs1(rs1),
            .rs2(rs2),
            .alu_op(alu_op),
            .reg_write(reg_write)
        );
        
    // -------------------- Register Bank -------------------- 
    wire [31:0] rd_value, rs1_value, rs2_value;    
    register_bank RB(
        .clk(clk),
        .rst(rst),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .reg_write(reg_write),
        .rd_value(rd_value),
        .rs1_value(rs1_value),
        .rs2_value(rs2_value)
    );
    
    // -------------------- ALU -------------------- 
    wire zero;
    alu ALU(
            .rs1_value(rs1_value),
            .rs2_value(rs2_value),
            .alu_op(alu_op),
            .zero(zero),
            .rd_value(rd_value)
    );

    assign alu_out = rd_value;
    
endmodule

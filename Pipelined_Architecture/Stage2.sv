module Stage2(
    input logic clk,
    input logic rst,
    input logic [31:0] pc_in_2,
    input logic [31:0] imm,
    input logic [31:0] rs1_value,
    input logic [31:0] rs2_value,
    input logic [4:0] rs1,
    input logic [4:0] rs2,
    input logic [4:0] rd,
    input logic [14:0] ctrl_s1,
    output logic [31:0] exec_result,
    output logic [4:0] rd_out,
    output logic [31:0] rs2_value_out,
    output logic branch_flush,
    output logic [4:0] ctrl_s2,
    output logic [31:0] BranchAddr,
    output logic [31:0] ALUResult,
    output logic [31:0] pc_out_s2,
    //output logic stall_pipeline,
    output logic Jump
);
    logic compare_out;
    logic [31:0] alu_result;
    logic [31:0] mul_result;
    logic [31:0] alu_in1;
    logic [31:0] alu_in2;
    logic [3:0] ALUControl;
    logic [1:0] MemtoReg;
    logic RegWrite, MemWrite, MemRead, ALUSrc, Lui, Branch, Mul, M_ctrl;

    assign {RegWrite,MemtoReg,MemWrite,MemRead,ALUSrc,Lui,ALUControl,Jump,Branch,Mul,M_ctrl} = ctrl_s1;
/*    if (Mul) begin
        stall_pipeline = 1; // Stall the pipeline when multiplication is in progress
    end
    else begin
        stall_pipeline = 0; // No stall when not multiplying
    end
*/
alu_in1_mux mux1 (
    .rs1(rs1_value),
    .imm(imm),
    .Lui(Lui),
    .alu_in1(alu_in1)
);

alu_in2_mux mux2 (
    .rs2(rs2_value),
    .imm(imm),
    .pc(pc_in_2),
    .Lui(Lui),
    .ALUSrc(ALUSrc),
    .alu_in2(alu_in2)
);

alu alu (
    .a(alu_in1),
    .b(alu_in2),
    .Control(ALUControl),
    .branch(Branch),
    .result(alu_result),
    .compare_out(compare_out)
);

Pipelined_M multi (
    .A(rs1_value),
    .B(rs2_value),
    .clk(clk),
    .rst(rst),
    .P_32(mul_result),
    .M_ctrl(M_ctrl)
);

alu_mul_mux mux3 (
    .alu_result(alu_result),
    .mul_result(mul_result),
    .Mul(Mul),
    .exec_result(exec_result)
);

    assign branch_flush = compare_out & Branch;
    assign BranchAddr = pc_in_2 + imm;
    assign ctrl_s2 = {MemRead,MemWrite,MemtoReg,RegWrite};
    assign rd_out = rd;
    assign ALUResult = alu_result;
    assign rs2_value_out = rs2_value; 
    assign pc_out_s2 = pc_in_2;

endmodule
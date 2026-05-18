module Stage2(
    input logic [31:0] pc,
    input logic [31:0] imm,
    input logic [31:0] rs1_value,
    input logic [31:0] rs2_value,
    input logic [4:0] rs1,
    input logic [4:0] rs2,
    input logic [4:0] rd,
    input logic [13:0] ctrl_s1,
    output logic [31:0] exec_result,
    output logic [4:0] rd_out,
    output logic [31:0] rs2_value_out,
    output logic branch_flush,
    output logic [5:0] ctrl_s2,
    output logic [31:0] BranchAddr,
    output logic [31:0] ALUResult
);
    logic compare_out;
    logic [31:0] alu_result;
    logic [31:0] mul_result;
    logic [31:0] alu_in1;
    logic [31:0] alu_in2;
    logic [3:0] ALUControl;
    logic [1:0] MemtoReg;
    logic RegWrite, MemWrite, MemRead, ALUSrc, Lui, Jump, Branch, Mul;

    assign {RegWrite,MemtoReg,MemWrite,MemRead,ALUSrc,Lui,ALUControl,Jump,Branch,Mul} = ctrl_s1;
    
alu_in1_mux mux1 (
    .rs1(rs1_value),
    .imm(imm),
    .Lui(Lui),
    .alu_in1(alu_in1)
);

alu_in2_mux mux2 (
    .rs2(rs2_value),
    .imm(imm),
    .pc(pc),
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

multiplier multi (
    .a(),
    .b(),
    .clk(),
    .mul_result(),
    .stall_pipeline()
);

alu_mul_mux mux3 (
    .alu_result(alu_result),
    .mul_result(mul_result),
    .Mul(Mul),
    .exec_result(exec_result)
);

    assign branch_flush = compare_out & Branch;
    assign BranchAddr = pc + imm;
    assign ctrl_s2 = {MemRead,MemWrite,MemtoReg,Jump,RegWrite};
    assign rd_out = rd;
    assign ALUResult = alu_result;
    assign rs2_value_out = rs2_value; 

endmodule
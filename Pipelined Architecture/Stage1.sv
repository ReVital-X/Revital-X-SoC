module Stage1(
    input logic clk,
    input logic rst,
    input logic pc_stall,
    input logic RegWrite_wb,
    input logic [4:0] rd,
    input logic [31:0] wb_data,
    input logic [1:0] PCSrc,
    input logic [31:0] BranchAddr,
    input logic [31:0] ALUResult,
    output logic [31:0] PC,
    output logic [31:0] rs1_value,
    output logic [31:0] rs2_value,
    output logic [4:0] rs1,
    output logic [4:0] rs2,
    output logic [31:0] imm,
    output logic [13:0] ctrl

);
logic [31:0] instr;
logic [31:0] PC_Addr_to_PC_Mux;
pc_mux mux1 (
    .pc_plus4(PC_Addr_to_PC_Mux), // Connect to PC + 4 logic
    .branch_addr(BranchAddr),
    .alu_result(ALUResult),
    .pcsrc(PCSrc),
    .pc_in(PC) // Connect to PC input
);
pc_adder_mux mux2 (
    .pc_stall(pc_stall),
    .pc(PC),
    .pc_plus4(PC_Addr_to_PC_Mux) // Connect to PC + 4 logic
);
register_file rf (
    .clk(clk),
    .rst(rst),
    .rs1(instr[19:15]),
    .rs2(instr[24:20]),
    .rd(rd),
    .rd_value(wb_data),
    .regwrite(RegWrite_wb),
    .rs1_value(rs1_value), 
    .rs2_value(rs2_value)
);
logic [3:0] ALUControl;
logic [1:0] MemtoReg;
logic RegWrite, MemWrite, MemRead, ALUSrc, Lui, Jump, Branch, Mul;
Control_Unit cu (
    .opcode(instr[6:0]),
    .funct3(instr[14:12]),
    .funct7_5(instr[30]),
    .funct7_0(instr[25]),
    .RegWrite(RegWrite),
    .MemtoReg(MemtoReg),
    .MemWrite(MemWrite),
    .MemRead(MemRead),
    .ALUSrc(ALUSrc),
    .Lui(Lui),
    .ALUControl(ALUControl),
    .Jump(Jump),
    .Branch(Branch),
    .Mul(Mul)
);
assign ctrl = {RegWrite, MemtoReg, MemWrite, MemRead, ALUSrc, Lui, ALUControl, Jump, Branch, Mul};

immediate_generator imm_gen (
    .instr(instr),
    .imm_out(imm)
);

instr_rom instr_mem (
    .pc(PC),
    .instr(instr)
);
assign rs1 = instr[19:15];
assign rs2 = instr[24:20];
endmodule
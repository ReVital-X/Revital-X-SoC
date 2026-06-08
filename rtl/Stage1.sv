`timescale 1ns / 1ps
module Stage1 #(
    parameter ADDR_WIDTH = 8
)(
    input logic clk,
    input logic rst,
    input logic pc_stall,
    input logic RegWrite_wb,
    input logic [4:0] rd,
    output logic [4:0] rd_s12,
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
    output logic [17:0] ctrl,
    // From LSU Stage 
    input  logic                   en_mem,
    input  logic [ADDR_WIDTH-1:0]  addr_mem,
    input  logic [31:0]            wdata_mem,
    output logic [31:0]            rdata_mem,
    input  logic                   we_mem,
    input  logic [3:0]             be_mem
);
logic [31:0] instr;
logic [31:0] mux_out;

//Control signals for Stage 1 
logic [3:0] ALUControl;
logic [1:0] MemtoReg;
logic [1:0] lsu_type;
logic RegWrite, ALUSrc, Lui, Jump, Branch, Mul, M_ctrl, lsu_req, lsu_we, lsu_sign_ext;
pc_mux mux1 (
    .branch_addr(BranchAddr),
    .alu_result(ALUResult),
    .pcsrc(PCSrc),
    .pc_in(mux_out), // Connect to PC input
    .PC(PC),
    .pc_stall(pc_stall)
);
always_ff @(posedge clk) begin
    if (rst) PC <= 32'b0;
    else     PC <= mux_out; // Update PC with the output of the mux
end

instr_ram #(
    .ADDR_WIDTH(ADDR_WIDTH)
)instr_mem(
    .clk(clk),
    .en_a_i(!pc_stall),
    .addr_a_i(PC[ADDR_WIDTH+1:2]),
    .wdata_a_i(32'b0),
    .rdata_a_o(instr),
    .we_a_i(1'b0),
    .be_a_i(4'b0),
    .en_b_i(en_mem),
    .addr_b_i(addr_mem),
    .wdata_b_i(wdata_mem),
    .rdata_b_o(rdata_mem),
    .we_b_i(we_mem),
    .be_b_i(be_mem)
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

Control_Unit cu (
    .opcode(instr[6:0]),
    .funct3(instr[14:12]),
    .funct7_5(instr[30]),
    .funct7_0(instr[25]),
    .RegWrite(RegWrite),
    .MemtoReg(MemtoReg),
    .ALUSrc(ALUSrc),
    .Lui(Lui),
    .ALUControl(ALUControl),
    .Jump(Jump),
    .Branch(Branch),
    .Mul(Mul),
    .M_ctrl(M_ctrl),
    .lsu_req(lsu_req),
    .lsu_we(lsu_we),
    .lsu_type(lsu_type),
    .lsu_sign_ext(lsu_sign_ext)
);

assign ctrl = {
    RegWrite,        // 1 (17)
    MemtoReg,        // 2 (16:15)
    ALUSrc,          // 1 (14)
    Lui,             // 1 (13)
    ALUControl,      // 4 (12:9)
    Jump,            // 1 (8)
    Branch,          // 1 (7)
    Mul,             // 1 (6)
    M_ctrl,          // 1 (5)
    lsu_req,         // 1 (4)
    lsu_we,          // 1 (3)
    lsu_type,        // 2 (2:1)
    lsu_sign_ext     // 1 (0)
                     // 18 bits total
};

immediate_generator imm_gen (
    .instr(instr),
    .imm_out(imm)
);

assign rs1 = instr[19:15];
assign rs2 = instr[24:20];
assign rd_s12 = instr[11:7];
endmodule

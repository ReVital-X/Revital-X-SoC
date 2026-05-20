module CoreRV(
    input logic clk,
    input logic rst
);
typedef struct packed {
    logic [31:0] PC;
    logic [31:0] rs1_value;
    logic [31:0] rs2_value;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [4:0] rd_s12;
    logic [31:0] imm;
    logic [14:0] ctrl;  // changed to 15 bits for M_ctrl
} s1_buffer;

typedef struct packed {
    logic [31:0] exec_result;
    logic [4:0] rd_out;
    logic [31:0] rs2_value_out;
    logic [4:0] ctrl_s2;
    logic [31:0] pc_out_s2;
} s2_buffer;

logic Reg_wb, branch_flush, Jump;
logic [4:0] rd_out;
logic [31:0] wb_mux_out;
logic [31:0] BranchAddr;
logic [31:0] ALUResult;
logic [31:0] PC_S12, rs1_value_S12, rs2_value_S12;
logic [4:0] rs1_S12, rs2_S12;
logic [31:0] imm;
logic [14:0] ctrl;
logic m_stall;
logic [4:0] rd_s12;
Stage1 s1(
    .clk(clk),
    .rst(rst),
    .pc_stall(m_stall),
    .RegWrite_wb(Reg_wb),
    .rd(rd_out),
    .rd_s12(rd_s12),
    .wb_data(wb_mux_out),
    .PCSrc({Jump,branch_flush}),
    .BranchAddr(BranchAddr),
    .ALUResult(ALUResult),
    .PC(PC_S12),
    .rs1_value(rs1_value_S12),
    .rs2_value(rs2_value_S12),
    .rs1(rs1_S12),
    .rs2(rs2_S12),
    .imm(imm),
    .ctrl(ctrl)
);
s1_buffer s1_buf;
s2_buffer s2_buf;
always_ff @(posedge clk) begin
    if (rst || branch_flush) begin
        s1_buf.PC <= 32'b0;
        s1_buf.rs1_value <= 32'b0;
        s1_buf.rs2_value <= 32'b0;
        s1_buf.rs1 <= 5'b0;
        s1_buf.rs2 <= 5'b0;
        s1_buf.imm <= 32'b0;
        s1_buf.ctrl <= 15'b0;
        s1_buf.rd_s12 <= 5'b0;
    end
    else if (m_stall) begin
        s1_buf <= s1_buf; // Hold the current values in the buffer
    end
    else begin
        s1_buf.PC <= PC_S12;  
        s1_buf.rs1_value <= rs1_value_S12;
        s1_buf.rs2_value <= rs2_value_S12;
        s1_buf.rs1 <= rs1_S12;
        s1_buf.rs2 <= rs2_S12;
        s1_buf.imm <= imm;
        s1_buf.ctrl <= ctrl;
        s1_buf.rd_s12 <= rd_s12;
    end
end
logic [31:0] exec_result;
logic [4:0] rd_S23;
logic [31:0] rs2_value_S23;
logic [4:0] ctrl_s2;
logic [31:0] pc_out_s2;
Stage2 s2(
    .clk(clk),
    .rst(rst),
    .pc_in_2(s1_buf.PC),
    .imm(s1_buf.imm),
    .rs1_value(s1_buf.rs1_value),
    .rs2_value(s1_buf.rs2_value),
    .rs1(s1_buf.rs1),
    .rs2(s1_buf.rs2),
    .rd(s1_buf.rd_s12),
    .ctrl_s1(s1_buf.ctrl),
    .exec_result(exec_result),
    .rd_out(rd_S23),
    .rs2_value_out(rs2_value_S23),
    .branch_flush(branch_flush),
    .ctrl_s2(ctrl_s2),
    .BranchAddr(BranchAddr),
    .ALUResult(ALUResult),
    .pc_out_s2(pc_out_s2),
    .stall_pipeline(m_stall),
    .Jump(Jump)
);

always_ff @(posedge clk) begin
    if (rst || branch_flush) begin
        s2_buf.exec_result <= 32'b0;
        s2_buf.rd_out <= 5'b0;
        s2_buf.rs2_value_out <= 32'b0;
        s2_buf.ctrl_s2 <= 5'b0;
        s2_buf.pc_out_s2 <= 32'b0;
    end
    else if (m_stall) begin
        s2_buf <= s2_buf; // Hold the current values in the buffer
    end
    else begin
        s2_buf.exec_result <= exec_result;
        s2_buf.rd_out <= rd_S23;
        s2_buf.rs2_value_out <= rs2_value_S23;
        s2_buf.ctrl_s2 <= ctrl_s2;
        s2_buf.pc_out_s2 <= pc_out_s2;
    end
end

Stage3 s3(
    .clk(clk),
    .pc_in_s3(s2_buf.pc_out_s2),
    .exec_result_s2(s2_buf.exec_result),
    .rs2(s2_buf.rs2_value_out),
    .ctrl_s2(s2_buf.ctrl_s2),
    .rd(s2_buf.rd_out),
    .rd_out(rd_out),
    .wb_mux_out(wb_mux_out),
    .RegWrite_wb(Reg_wb)
);
endmodule
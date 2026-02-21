`timescale 1ns / 1ps

module top_module(
    input clk,
    input rst,
    input[31:0] instr, 
    output [31:0] alu_out
);

// ==========================================================
// -------------------- IF STAGE ----------------------------
// ==========================================================

wire [31:0] pc;


instruction_fetch IF(
    .clk(clk),
    .rst(rst),
    .pc(pc)
);


// ==========================================================
// ---------------- IF/ID PIPELINE REGISTER -----------------
// ==========================================================

reg [31:0] if_id_ir;
reg [31:0] if_id_pc;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        if_id_ir <= 0;
        if_id_pc <= 0;
    end
    else begin
        if_id_ir <= instr;
        if_id_pc <= pc;
    end
end


// ==========================================================
// -------------------- ID STAGE ----------------------------
// ==========================================================

wire [4:0] rd, rs1, rs2;
wire [3:0] alu_op;
wire reg_write;

decoder DEC(
    .instr(if_id_ir),   // ✔ Using pipeline register
    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .alu_op(alu_op),
    .reg_write(reg_write)
);


// ---------------- Register Bank ----------------------------

wire [31:0] rd_value;
wire [31:0] rs1_value;
wire [31:0] rs2_value;

register_bank RB(
    .clk(clk),
    .rst(rst),
    .rs1(rs1),
    .rs2(rs2),
    .rd(id_ex_rd),                // writeback from EX stage
    .regwrite(id_ex_reg_write),  // pipelined control
    .rd_value(rd_value),
    .rs1_value(rs1_value),
    .rs2_value(rs2_value)
);


// ==========================================================
// ---------------- ID/EX PIPELINE REGISTER -----------------
// ==========================================================

reg [31:0] id_ex_rs1_value;
reg [31:0] id_ex_rs2_value;
reg [3:0]  id_ex_alu_op;
reg [4:0]  id_ex_rd;
reg        id_ex_reg_write;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        id_ex_rs1_value <= 0;
        id_ex_rs2_value <= 0;
        id_ex_alu_op    <= 0;
        id_ex_rd        <= 0;
        id_ex_reg_write <= 0;
    end
    else begin
        id_ex_rs1_value <= rs1_value;
        id_ex_rs2_value <= rs2_value;
        id_ex_alu_op    <= alu_op;
        id_ex_rd        <= rd;
        id_ex_reg_write <= reg_write;
    end
end


// ==========================================================
// -------------------- EX STAGE ----------------------------
// ==========================================================

wire zero;

alu ALU(
    .rs1_value(id_ex_rs1_value),  // ✔ using pipeline values
    .rs2_value(id_ex_rs2_value),
    .alu_op(id_ex_alu_op),
    .zero(zero),
    .rd_value(rd_value)
);


// ==========================================================
// -------------------- OUTPUT ------------------------------
// ==========================================================

assign alu_out = rd_value;

endmodule
`timescale 1ns / 1ps
module CoreRV #(
    parameter BOOT_ADDR = 32'h0000_0000,
    parameter INSTR_ADDR = 32'h0000_8000,
    parameter DATA_ADDR = 32'h0001_0000,
    parameter EXTERNAL_ADDR = 32'h0002_0000
)(
    input logic clk,
    input logic rst,
    
    output logic [31:0] data_addr_o,
    output logic [31:0] data_wdata_o,
    output logic data_we_o,
    output logic data_req_o,
    output logic [3:0] data_be_o,
    input logic [31:0] data_rdata_i,
    input logic data_gnt_i,
    input logic data_rvalid_i
);
typedef struct packed {
    logic [4:0] rd_s12;
    logic [31:0] PC;
    logic [31:0] rs1_value;
    logic [31:0] rs2_value;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [31:0] imm;
    logic [17:0] ctrl;
    logic [31:0] rdata_mem;
} s1_buffer;

//Stage 1 Signals
logic Reg_wb, branch_flush, redirect_flush, redirect_flush_d, Jump;
logic [4:0] rd_out;
logic [31:0] data_wb;
logic [31:0] BranchAddr;
logic [31:0] ALUResult;
logic [31:0] instr_PC_S12, rs1_value_S12, rs2_value_S12;
logic [4:0] rs1_S12, rs2_S12;
logic [31:0] imm;
logic [17:0] ctrl;
logic m_stall;
logic [4:0] rd_s12;
logic [1:0] PCSrc;
logic M_over;
assign PCSrc = {Jump,branch_flush};
assign redirect_flush = branch_flush | Jump;

//Instruction memory Signals
logic en_mem;
logic [7:0] addr_mem;
logic [31:0] wdata_mem;
logic [31:0] rdata_mem;
logic we_mem;
logic [3:0] be_mem;

//Stage 2 Signals
logic [31:0] exec_result;
logic [4:0] rd_S23;
logic [31:0] rs2_value_S23;
logic [7:0] ctrl_s2;
logic [31:0] pc_out_s2;
logic [1:0] ForwardA, ForwardB;
logic mul_start;

// Memory Stage Signals
logic dram_en_i;
logic [7:0] dram_addr_i;
logic [31:0] dram_wdata_i;
logic [31:0] dram_rdata_i;
logic dram_we_i;
logic [3:0] dram_be_i;
logic [1:0] mem_select;
logic lsu_we_i;
logic [1:0] lsu_type_i;
logic [31:0] lsu_wdata_i;
logic lsu_sign_ext_i;
logic lsu_req_i;
logic [31:0] adder_result_ex_i;
logic [31:0] lsu_rdata_o;
logic lsu_rdata_valid_o;
logic busy_o;

// WB signals
logic [31:0] alu_result_wb;
logic [31:0] pc_wb;
logic [1:0] memtoreg_wb;
logic [4:0] rd_wb;
logic       regwrite_wb;

// Mem to WB BUFFER
logic [31:0] alu_result_buf;
logic [31:0] mem_data_buf;
logic [31:0] pc_buf;
logic [1:0] memtoreg_buf;
logic [4:0] rd_buf;
logic       regwrite_buf;

Stage1 #(
    .ADDR_WIDTH(8)
) s1(
    .clk(clk),
    .rst(rst),
    .pc_stall(m_stall),
    .RegWrite_wb(Reg_wb),
    .rd(rd_out),
    .rd_s12(rd_s12),
    .wb_data(data_wb),
    .PCSrc(PCSrc),
    .BranchAddr(BranchAddr),
    .ALUResult(ALUResult),
    .instr_PC(instr_PC_S12),
    .rs1_value(rs1_value_S12),
    .rs2_value(rs2_value_S12),
    .rs1(rs1_S12),
    .rs2(rs2_S12),
    .imm(imm),
    .ctrl(ctrl),
    .redirect_flush(redirect_flush),
    .redirect_flush_d(redirect_flush_d),
    // From LSU Stage 
    .en_mem(en_mem),
    .addr_mem(addr_mem),
    .wdata_mem(wdata_mem),
    .rdata_mem(rdata_mem),
    .we_mem(we_mem),
    .be_mem(be_mem)
);
// Buffer to hold Stage 1 outputs for use in Stage 2
s1_buffer s1_buf;

// The instruction RAM has a registered output. After a branch or jump,
// outstanding wrong-path read arrives one cycle after the redirect, so keep
// the Stage 1/2 buffer invalid for that additional cycle.
always_ff @(posedge clk) begin
    if (rst)
        redirect_flush_d <= 1'b0;
    else
        redirect_flush_d <= redirect_flush;
end

always_ff @(posedge clk) begin
    if (rst || redirect_flush || redirect_flush_d) begin
        s1_buf.PC <= 32'b0;
        s1_buf.rs1_value <= 32'b0;
        s1_buf.rs2_value <= 32'b0;
        s1_buf.rs1 <= 5'b0;
        s1_buf.rs2 <= 5'b0;
        s1_buf.imm <= 32'b0;
        s1_buf.ctrl <= 18'b0;
        s1_buf.rd_s12 <= 5'b0;
        s1_buf.rdata_mem <= 32'b0;
    end
    else if (m_stall) begin
        s1_buf <= s1_buf; // Hold the current values in the buffer
    end
    else begin
        s1_buf.PC <= instr_PC_S12;
        s1_buf.rs1_value <= rs1_value_S12;
        s1_buf.rs2_value <= rs2_value_S12;
        s1_buf.rs1 <= rs1_S12;
        s1_buf.rs2 <= rs2_S12;
        s1_buf.imm <= imm;
        s1_buf.ctrl <= ctrl;
        s1_buf.rd_s12 <= rd_s12;
        s1_buf.rdata_mem <= rdata_mem;
    end
end

Stage2 s2 (
    .clk(clk),
    .rst(rst),
    .pc_in_2(s1_buf.PC),
    .imm(s1_buf.imm),
    .rs1_value(s1_buf.rs1_value),
    .rs2_value(s1_buf.rs2_value),
    .rd(s1_buf.rd_s12),
    .ctrl_s1(s1_buf.ctrl),
    .ForwardA(ForwardA),
    .ForwardB(ForwardB),
    .Fwd_rd_value1(data_wb),
    .Fwd_rd_value2(alu_result_wb),
    .mul_start(mul_start),
    .exec_result(exec_result),
    .rd_out(rd_S23),
    .rs2_value_out(rs2_value_S23),
    .branch_flush(branch_flush),
    .ctrl_s2(ctrl_s2),
    .BranchAddr(BranchAddr),
    .ALUResult(ALUResult),
    .pc_out_s2(pc_out_s2),
    .M_over(M_over),
    .Jump(Jump)
);

always_comb begin
    mem_select = 2'b00;

    en_mem = 0;
    addr_mem = 0;
    wdata_mem = 0;
    we_mem = 0;
    be_mem = 0;

    dram_en_i = 0;
    dram_addr_i = 0;
    dram_wdata_i = 0;
    dram_we_i = 0;
    dram_be_i = 0;

    lsu_we_i = 0;
    lsu_type_i = 0;
    lsu_wdata_i = 0;
    lsu_sign_ext_i = 0;
    lsu_req_i = 0;
    adder_result_ex_i = 0;

    if(exec_result >= INSTR_ADDR && exec_result < DATA_ADDR)  begin
        // Handle instruction memory access
        mem_select = 2'b01;
        en_mem = ctrl_s2[4];
        addr_mem = exec_result[9:2];
        wdata_mem = rs2_value_S23;
        we_mem = ctrl_s2[3];
        unique case (ctrl_s2[2:1])
            2'b00: be_mem = 4'b1111; //word
            2'b01: begin // half-word
                unique case (exec_result[1:0])
                2'b00: be_mem = 4'b0011; // lower half-word
                2'b01: be_mem = 4'b0110; // 
                2'b10: be_mem = 4'b1100; // upper half-word 
                2'b11: be_mem = 4'b1001; // 
                default: be_mem = 4'b0011;
                endcase
            end
            2'b10: begin // byte
                unique case (exec_result[1:0])
                2'b00: be_mem = 4'b0001; // byte 0 (lowest)
                2'b01: be_mem = 4'b0010; // byte 1
                2'b10: be_mem = 4'b0100; // byte 2
                2'b11: be_mem = 4'b1000; // byte 3
                default: be_mem = 4'b0001;
                endcase
            end
            default: be_mem = 4'b1111;
        endcase
    end
    else if(exec_result >= DATA_ADDR && exec_result < EXTERNAL_ADDR) begin
        mem_select = 2'b00;
        dram_en_i = ctrl_s2[4];
        dram_addr_i = exec_result[9:2];
        dram_wdata_i = rs2_value_S23;
        dram_we_i = ctrl_s2[3];
        unique case (ctrl_s2[2:1])
            2'b00: dram_be_i = 4'b1111; //word
            2'b01: begin // half-word
                unique case (exec_result[1:0])
                2'b00: dram_be_i = 4'b0011; // lower half-word
                2'b01: dram_be_i = 4'b0110; // 
                2'b10: dram_be_i = 4'b1100; // upper half-word 
                2'b11: dram_be_i = 4'b1001; // 
                default: dram_be_i = 4'b0011;
                endcase
            end
            2'b10: begin // byte
                unique case (exec_result[1:0])
                2'b00: dram_be_i = 4'b0001; // byte 0 (lowest)
                2'b01: dram_be_i = 4'b0010; // byte 1
                2'b10: dram_be_i = 4'b0100; // byte 2
                2'b11: dram_be_i = 4'b1000; // byte 3
                default: dram_be_i = 4'b0001;
                endcase
            end
            default: dram_be_i = 4'b1111;
        endcase
    end
    else if(exec_result >= EXTERNAL_ADDR) begin
        // Handle external I/O access (e.g., UART, GPIO)
        mem_select = 2'b10;
        lsu_we_i = ctrl_s2[3];
        lsu_type_i = ctrl_s2[2:1];
        lsu_wdata_i = rs2_value_S23;
        lsu_sign_ext_i = ctrl_s2[0];
        lsu_req_i = ctrl_s2[4];
        adder_result_ex_i = exec_result;
    end
end

stall_controller stall_ctrl (
    .clk(clk),
    .rst(rst),
    .rs1E(s1_buf.rs1),
    .rs2E(s1_buf.rs2),
  .rdW(rd_buf),
    .RegWriteW(Reg_wb),
    .RegWriteM(regwrite_wb),
    .ForwardAE(ForwardA),
    .ForwardBE(ForwardB),
    .mul_req(s1_buf.ctrl[6]),
    .mul_start(mul_start),
    .M_over(M_over),
    .lsu_busy(busy_o),
    .pipe_stall(m_stall),
    .rdM(rd_wb)
);

LSU_RVX lsu(
  .clk(clk),
  .rst(rst),

  // data interface
  .data_req_o(data_req_o),
  .data_gnt_i(data_gnt_i),
  .data_rvalid_i(data_rvalid_i),

  .data_addr_o(data_addr_o),
  .data_we_o(data_we_o),
  .data_be_o(data_be_o),
  .data_wdata_o(data_wdata_o),
  .data_rdata_i(data_rdata_i),

  // ID/EX inputs
  .lsu_we_i(lsu_we_i),
  .lsu_type_i(lsu_type_i),
  .lsu_wdata_i(lsu_wdata_i),
  .lsu_sign_ext_i(lsu_sign_ext_i),
  .lsu_req_i(lsu_req_i),
  .adder_result_ex_i(adder_result_ex_i),

  // outputs to WB / pipeline control
  .lsu_rdata_o(lsu_rdata_o),
  .lsu_rdata_valid_o(lsu_rdata_valid_o),
  .busy_o(busy_o)
);

data_ram #(
    .ADDR_WIDTH(8),
    .DATA_WIDTH(32),
    .NUM_WORDS(256)
) dram(
    .clk(clk),
    .en_i(dram_en_i),
    .addr_i(dram_addr_i),
    .wdata_i(dram_wdata_i),
    .rdata_o(dram_rdata_i),
    .we_i(dram_we_i),
    .be_i(dram_be_i)
);
// EXE-MEM stage buffer
always_ff @(posedge clk) begin
    if (rst) begin
        alu_result_wb <= 32'd0;
        pc_wb         <= 32'd0;
        memtoreg_wb   <= 2'b00;
        rd_wb         <= 5'd0;
        regwrite_wb   <= 1'b0;
    end
    else if (m_stall) begin
        alu_result_wb <= alu_result_wb; // Hold the current values in the buffer
        pc_wb         <= pc_wb;
        memtoreg_wb   <= memtoreg_wb;
        rd_wb         <= rd_wb;
        regwrite_wb   <= regwrite_wb;
    end
    else begin
        alu_result_wb <= exec_result;
        pc_wb         <= pc_out_s2;
        memtoreg_wb   <= ctrl_s2[7:6];
        rd_wb         <= rd_S23;
        regwrite_wb   <= ctrl_s2[5];
    end
end
logic [31:0] mem_data_wb;

always_comb begin
    mem_data_wb = 32'd0;
    if(lsu_rdata_valid_o) begin
    case(mem_select)
        2'b00: mem_data_wb = dram_rdata_i;
        2'b01: mem_data_wb = rdata_mem;
        2'b10: mem_data_wb = lsu_rdata_o;
        default: mem_data_wb = 32'd0;
    endcase
    end
end
//MEM-WB stage buffer
always_ff @(posedge clk) begin
    if (rst) begin
        alu_result_buf <= 32'd0;
        pc_buf         <= 32'd0;
        memtoreg_buf   <= 2'b00;
        mem_data_buf    <= 32'd0;
        rd_buf          <= 5'd0;
        regwrite_buf    <= 1'b0;
    end
    else begin
        alu_result_buf <= alu_result_wb;
        pc_buf         <= pc_wb;
        memtoreg_buf   <= memtoreg_wb;
        mem_data_buf    <= mem_data_wb;
        rd_buf          <= rd_wb;
        regwrite_buf    <= regwrite_wb;
    end
end
//WB Mux
memtoreg_mux mux_wb (
    .alu_result (alu_result_buf),
    .mem_data   (mem_data_buf),
    .pc         (pc_buf),
    .MemtoReg   (memtoreg_buf),
    .wb_data    (data_wb)
);
assign rd_out = rd_buf;
assign Reg_wb = regwrite_buf;

endmodule

/* verilator lint_off TIMESCALEMOD */
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

logic Reg_wb, branch_flush, Jump;
logic [4:0] rd_out;
logic [31:0] data_wb;
logic [31:0] BranchAddr;
logic [31:0] ALUResult;
logic [31:0] PC_S12, rs1_value_S12, rs2_value_S12;
logic [4:0] rs1_S12, rs2_S12;
logic [31:0] imm;
logic [17:0] ctrl;
logic m_stall;
logic [4:0] rd_s12;
logic [1:0] PCSrc;
logic M_over;
assign PCSrc = {Jump,branch_flush};
assign m_stall = ~M_over & ctrl[6];

logic en_mem;
logic [7:0] addr_mem;
logic [31:0] wdata_mem;
logic [31:0] rdata_mem;
logic we_mem;
logic [3:0] be_mem;

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
    .PC(PC_S12),
    .rs1_value(rs1_value_S12),
    .rs2_value(rs2_value_S12),
    .rs1(rs1_S12),
    .rs2(rs2_S12),
    .imm(imm),
    .ctrl(ctrl),
    // From LSU Stage 
    .en_mem(en_mem),
    .addr_mem(addr_mem),
    .wdata_mem(wdata_mem),
    .rdata_mem(rdata_mem),
    .we_mem(we_mem),
    .be_mem(be_mem)
);
s1_buffer s1_buf;
always_ff @(posedge clk) begin
    if (rst || branch_flush) begin
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
        s1_buf.PC <= PC_S12;  
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
logic [31:0] exec_result;
logic [4:0] rd_S23;
logic [31:0] rs2_value_S23;
logic [7:0] ctrl_s2;
logic [31:0] pc_out_s2;
logic ForwardA, ForwardB;

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
    .Fwd_rd_value(data_wb),
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
    .rdW(rd_wb),
    .RegWriteW(Reg_wb),
    .ForwardAE(ForwardA),
    .ForwardBE(ForwardB),
    .mul_start(s1_buf.ctrl[6]),
    .M_over(M_over),
    .lsu_busy(busy_o),
    .pipe_stall(m_stall)
);

logic [31:0] lsu_rdata_o;
logic lsu_rdata_valid_o;
logic busy_o;

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

logic [31:0] alu_result_wb;
logic [31:0] pc_wb;
logic [1:0] memtoreg_wb;
logic [4:0] rd_wb;
logic       regwrite_wb;

always_ff @(posedge clk) begin
    if (rst) begin
        alu_result_wb <= 32'd0;
        pc_wb         <= 32'd0;
        memtoreg_wb   <= 2'b00;
        rd_wb         <= 5'd0;
        regwrite_wb   <= 1'b0;
    end
    else begin
        alu_result_wb <= ALUResult;
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

memtoreg_mux mux_wb (
    .alu_result (alu_result_wb),
    .mem_data   (mem_data_wb),
    .pc         (pc_wb),
    .MemtoReg   (memtoreg_wb),
    .wb_data    (data_wb)
);
assign rd_out = rd_wb;
assign Reg_wb = regwrite_wb;

endmodule

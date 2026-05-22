module Stage3(
    input logic clk,
    input logic [31:0] pc_in_s3,
    input logic [31:0] exec_result_s2,
    input logic [31:0] rs2,
    input logic [4:0] ctrl_s2,
    input logic [4:0] rd,
    output logic [4:0] rd_out,
    output logic [31:0] wb_mux_out,
    output logic RegWrite_wb
);
    logic MemRead,MemWrite;
    logic [1:0] MemtoReg;
    logic [31:0] read_data;
    logic [31:0] pc_4;


    assign pc_4 = pc_in_s3 + 4;
    assign {MemRead,MemWrite,MemtoReg,RegWrite_wb} = ctrl_s2;
    assign rd_out = rd;

    data_ram data_ram (
        .clk(clk),
        .address(exec_result_s2),
        .write_data(rs2),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .read_data(read_data)
    );

    memtoreg_mux mux1 (
        .alu_result(exec_result_s2),
        .mem_data(read_data),
        .pc_4(pc_4),
        .MemtoReg(MemtoReg),
        .wb_data(wb_mux_out)
    );

endmodule
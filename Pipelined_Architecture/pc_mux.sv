module pc_mux (
    input  logic [31:0] pc_plus4,
    input  logic [31:0] branch_addr,
    input  logic [31:0] alu_result,
    input  logic [1:0]  pcsrc,
    output logic [31:0] pc_in
);

always_comb begin
    case (pcsrc)
        2'b10: pc_in = alu_result;     // JALR
        2'b01: pc_in = branch_addr;    // Branch
        default: pc_in = pc_plus4;     // PC + 4
    endcase
end

endmodule
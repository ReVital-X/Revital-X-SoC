`timescale 1ns / 1ps
module pc_mux (
    input  logic [31:0] branch_addr,
    input  logic [31:0] alu_result,
    input  logic [1:0]  pcsrc,
    input  logic        pc_stall,
    output logic [31:0] pc_in,
    input logic [31:0] PC
);

always_comb begin
    if(!pc_stall) begin
    case (pcsrc)
        2'b10: pc_in = alu_result;     // JALR
        2'b01: pc_in = branch_addr;    // Branch
        default: pc_in = PC + 4;     // PC + 4
    endcase
    end
    else begin
        pc_in = PC; // Hold PC steady during stall
    end
end
endmodule

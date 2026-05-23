module Lw_Hazard_Unit(
    input logic [4:0] rs1,
    input logic [4:0] rs2,
    input logic [4:0] rdE,
    input logic MemReadE,
    output logic lw_stall
);

always_comb begin
    if (MemReadE && ((rdE == rs1) || (rdE == rs2)) && rdE != 0) begin
        lw_stall = 1; // Stall the pipeline
    end else begin
        lw_stall = 0; // No stall
    end
end
endmodule
module pc_adder_mux (
    input  logic        pc_stall,
    input  logic [31:0] pc,
    output logic [31:0] pc_plus4
);

logic [31:0] mux_out;

always_comb begin
    if (pc_stall)
        mux_out = 32'd0;
    else
        mux_out = 32'd4;
end

assign pc_plus4 = pc + mux_out;

endmodule
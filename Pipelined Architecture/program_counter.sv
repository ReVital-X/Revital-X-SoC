module program_counter (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] pc_in,
    output logic [31:0] pc_out
);

always_ff @(posedge clk or posedge rst) begin
    if (rst)
        pc_out <= 32'd0;
    else
        pc_out <= pc_in;
end

endmodule
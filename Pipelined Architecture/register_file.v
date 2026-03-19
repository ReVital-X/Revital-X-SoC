`timescale 1ns/1ps

module register_file (
    input  logic        clk, rst,          // Clock and asynchronous reset
    input  logic [4:0]  rs1, rs2, rd,      // Register addresses (32 registers → 5 bits)
    input  logic [31:0] rd_value,          // Data to be written into destination register
    input  logic        regwrite,          // Write enable signal
    output logic [31:0] rs1_value,         // Read data from rs1
    output logic [31:0] rs2_value          // Read data from rs2
);

    // 32 registers, each 32-bit wide

    logic [31:0] regfile [31:0];


    // WRITE + RESET LOGIC (Sequential)
 
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            foreach (regfile[i]) begin
                regfile[i] <= 32'b0;
            end
        end
        else if (regwrite && (rd != 5'd0)) begin
            // Write operation (x0 is always zero, so ignore rd = 0)
            regfile[rd] <= rd_value;
        end
    end

  
    // READ LOGIC (Combinational)

assign rs1_value = (rs1 == 0) ? 32'd0 : regfile[rs1];
assign rs2_value = (rs2 == 0) ? 32'd0 : regfile[rs2];

endmodule
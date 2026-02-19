`timescale 1ns / 1ps

module alu(
    input [31:0] rs1_value,rs2_value,
    input [3:0] alu_operation,
  
    output wire zero,
    output wire [31:0] rd_value
);
reg [31:0] rd_reg;
always@(*) begin
 
    case (alu_operation)
         4'b0000 : rd_reg = rs1_value + rs2_value; // add
         4'b0001 : rd_reg = rs1_value - rs2_value; // sub
         4'b0010 : rd_reg = rs1_value ^ rs2_value; // xor
         4'b0011 : rd_reg = rs1_value | rs2_value; // or
         4'b0100 : rd_reg = rs1_value & rs2_value; // and
         4'b0101 : rd_reg = rs1_value << rs2_value[4:0]; // shift left logical
         4'b0110 : rd_reg = rs1_value >> rs2_value[4:0]; // shift right logical
         4'b0111 : rd_reg = $signed(rs1_value) >>> rs2_value[4:0]; // shift right arithmetic
         4'b1000 : rd_reg = ($signed(rs1_value) < $signed(rs2_value) )? 1 : 0; // set less than
         4'b1101 : rd_reg = (rs1_value < rs2_value )? 1 : 0; // set less than unsigned
         default : rd_reg = 32'bx;
    endcase
    
end


assign rd_value = rd_reg;
assign zero = (rd_value == 32'b0) ? 1'b1 : 1'b0;

endmodule

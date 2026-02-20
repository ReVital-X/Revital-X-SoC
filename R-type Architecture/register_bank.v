`timescale 1ns / 1ps

module register_bank(
   input clk,rst,
   input [4:0] rs1,rs2,rd,
   input reg_write,
   input [31:0] rd_value,
   output [31:0] rs1_value,rs2_value
);

   reg [31:0] regfile [31:0];
   integer i; //Loop for reset initialization
   
   always@(posedge clk or posedge rst) begin 
   
        if(rst) begin
            for(i=0;i<32;i=i+1) begin 
                regfile[i] <= 32'b0;
            end
        end
        
        else if (reg_write && rd != 5'b00000) begin //To maintain x0 register as zero always
            regfile[rd] <= rd_value;
        end
        
   end
   
   assign rs1_value = (rs1 == 5'b00000)? 32'h0 : regfile[rs1]; 
   assign rs2_value = (rs2 == 5'b00000)? 32'h0 : regfile[rs2]; 
        
endmodule

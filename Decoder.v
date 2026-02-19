module Decoder (
    input  [31:0] instr,
    output [4:0]  rd,
    output [4:0]  rs1,
    output [4:0]  rs2,
    output reg [31:0] imm,
    output reg [3:0]  alu_op,
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_to_reg,
    output reg        jalr
);

assign rd  = instr[11:7];
assign rs1 = instr[19:15];
assign rs2 = instr[24:20];

wire [6:0] opcode = instr[6:0];
wire [2:0] funct3 = instr[14:12];
wire [6:0] funct7 = instr[31:25];

localparam
    ALU_ADD  = 4'd0,
    ALU_SUB  = 4'd1,
    ALU_XOR  = 4'd2,
    ALU_OR   = 4'd3,
    ALU_AND  = 4'd4,
    ALU_SLL  = 4'd5,
    ALU_SRL  = 4'd6,
    ALU_SRA  = 4'd7,
    ALU_SLT  = 4'd8,
    ALU_SLTU = 4'd9;

always @(*) begin
        alu_op     = 0;
        imm        = 0;
        reg_write  = 0;
        mem_read   = 0;
        mem_to_reg = 0;
        jalr       = 0;
    case (opcode)
        // R-type
        7'b0110011: begin
            reg_write = 1;
            case ({funct7, funct3})
                {7'b0000000,3'b000}: alu_op = ALU_ADD;
                {7'b0100000,3'b000}: alu_op = ALU_SUB;
                {7'b0000000,3'b100}: alu_op = ALU_XOR;
                {7'b0000000,3'b110}: alu_op = ALU_OR;
                {7'b0000000,3'b111}: alu_op = ALU_AND;
                {7'b0000000,3'b001}: alu_op = ALU_SLL;
                {7'b0000000,3'b101}: alu_op = ALU_SRL;
                {7'b0100000,3'b101}: alu_op = ALU_SRA;
                {7'b0000000,3'b010}: alu_op = ALU_SLT;
                {7'b0000000,3'b011}: alu_op = ALU_SLTU;
            endcase
        end
        // I-type
        7'b0010011: begin
            reg_write = 1;
            imm = {{20{instr[31]}}, instr[31:20]};
            case (funct3)
                3'b000: alu_op = ALU_ADD;
                3'b100: alu_op = ALU_XOR;
                3'b110: alu_op = ALU_OR;
                3'b111: alu_op = ALU_AND;
                3'b010: alu_op = ALU_SLT;
                3'b011: alu_op = ALU_SLTU;
                3'b001: begin alu_op = ALU_SLL; imm = {27'b0, instr[24:20]}; end
                3'b101: begin
                    if (funct7 == 7'b0100000)
                        alu_op = ALU_SRA;
                    else
                        alu_op = ALU_SRL;
                    imm = {27'b0, instr[24:20]};
                end
            endcase
        end
        // Load
        7'b0000011: begin
            reg_write  = 1;
            mem_read   = 1;
            mem_to_reg = 1;
            alu_op     = ALU_ADD;
            imm        = {{20{instr[31]}}, instr[31:20]};
        end
        // Jump and Link Register
        7'b1100111: begin
            reg_write = 1;
            jalr      = 1;
            alu_op    = ALU_ADD;
            imm       = {{20{instr[31]}}, instr[31:20]};
        end

    endcase
end

endmodule
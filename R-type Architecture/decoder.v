module decoder(
    input  [31:0] instr,
    output [4:0]  rd,
    output [4:0]  rs1,
    output [4:0]  rs2,
    output reg [3:0]  alu_op,
    output reg        reg_write
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
        reg_write  = 0;
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
                default: alu_op = ALU_ADD;
            endcase
        end
        
    endcase
end

endmodule
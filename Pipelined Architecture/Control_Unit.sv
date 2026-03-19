module Control_Unit (
    input  logic [6:0] opcode,        // opcode
    input  logic [2:0] funct3,
    input  logic       funct7_5,  // Instr[30]
    input  logic       funct7_0,  // Instr[25] (M extension)

    // Control Outputs
    output logic       RegWrite,
    output logic [1:0] MemtoReg,
    output logic       MemWrite,
    output logic       MemRead,
    output logic       ALUSrc,
    output logic       Lui,
    output logic [3:0] ALUControl,
    output logic       Jump,
    output logic       Branch,
    output logic       Mul
);

    // Internal signals
    logic [1:0] ALUOp;

    // =========================
    // MAIN DECODER
    // =========================
    always_comb begin
        // Default values (avoid latches)
        RegWrite   = 0;
        MemWrite   = 0;
        MemRead    = 0;
        ALUSrc     = 0;
        Lui        = 0;
        MemtoReg   = 2'b00;
        Jump       = 0;
        Branch     = 0;
        ALUOp      = 2'b00;

        case (opcode)

            // LOAD (lw)
            7'b0000011: begin
                RegWrite  = 1;
                MemWrite  = 0;
                MemRead   = 1;
                ALUSrc    = 1;
                Lui       = 0;
                MemtoReg  = 2'b01;
                Jump      = 0;
                Branch    = 0;
                ALUOp     = 2'b00;
            end

            // STORE (sw)
            7'b0100011: begin
                RegWrite  = 0;
                MemWrite  = 1;
                MemRead   = 0;
                ALUSrc    = 1;
                Lui       = 0;
                MemtoReg  = 2'b11;
                Jump      = 0;
                Branch    = 0;
                ALUOp     = 2'b00;
            end

            // R-TYPE // MUL (M extension)
            7'b0110011: begin
                RegWrite  = 1;
                MemWrite  = 0;
                MemRead   = 0;
                ALUSrc    = 0;
                Lui       = 0;
                MemtoReg  = 2'b00;
                Jump      = 0;
                Branch    = 0;
                ALUOp     = 2'b10;
            end

            // BRANCH 
            7'b1100011: begin
                RegWrite  = 0;
                MemWrite  = 0;
                MemRead   = 0;
                ALUSrc    = 0;
                Lui       = 0;
                MemtoReg  = 2'b11;
                Jump      = 0;
                Branch    = 1;
                ALUOp     = 2'b01;
            end

            // I-TYPE ALU
            7'b0010011: begin
                RegWrite  = 1;
                MemWrite  = 0;
                MemRead   = 0;
                ALUSrc    = 1;
                Lui       = 0;
                MemtoReg  = 2'b00;
                Jump      = 0;
                Branch    = 0;
                ALUOp     = 2'b10;
            end

            // JAL
            7'b1101111: begin
                RegWrite  = 1;
                MemWrite  = 0;
                MemRead   = 0;
                ALUSrc    = 0; 
                Lui       = 0;
                MemtoReg  = 2'b10; // rd = PC + 4
                Jump      = 1;
                Branch    = 0;
                ALUOp     = 2'b00;
            end
            // JALR
            7'b1100111: begin
                RegWrite  = 1;
                MemWrite  = 0;
                MemRead   = 0;
                ALUSrc    = 1; // PC = rs1 + imm occurs in ALU and is sent to PC mux when Jump = 1
                Lui       = 0;
                MemtoReg  = 2'b10; // rd = PC + 4
                Jump      = 1;
                Branch    = 0;
                ALUOp     = 2'b00;
            end
            // LUI
            7'b0110111: begin
                RegWrite  = 1;
                MemWrite  = 0;
                MemRead   = 0;
                ALUSrc    = 0; 
                Lui       =  1;
                MemtoReg  = 2'b00; // ALU will be configured to pass imm directly to rd
                Jump      = 0;
                Branch    = 0;
                ALUOp     = 2'b00;
            end
            // AUIPC
            7'b0010111: begin
                RegWrite  = 1;
                MemWrite  = 0;
                MemRead   = 0;
                ALUSrc    = 1;
                Lui       = 1; 
                MemtoReg  = 2'b00; // ALU will be configured to add imm to PC and pass result to rd
                Jump      = 0;
                Branch    = 0;
                ALUOp     = 2'b00;
            end

            default: begin
                RegWrite   = 0;
                MemWrite   = 0;
                MemRead    = 0;
                ALUSrc     = 0;
                Lui        = 0;
                MemtoReg   = 2'b11;
                Jump       = 0;
                Branch     = 0;
                ALUOp      = 2'b00;
            end

        endcase
    end


    // =========================
    // ALU DECODER
    // =========================
    always_comb begin

        ALUControl = 4'b0000;
        Mul = 0;
        case (ALUOp)

            // ADD (lw, sw, JAL, JALR, LUI, AUIPC etc)
            2'b00: begin 
                ALUControl = 4'b0000;
                Mul = 0;
            end  

            // Branch use funct3 directly to determine the type of branch
            2'b01: begin
                ALUControl = {1'b0, funct3};
                Mul = 0;
            end
            // R-type / I-type ALU ops / MUL (M extension)
            2'b10: begin
                ALUControl = {funct7_5, funct3};
                // Using same ALUControl for M-EXT Multiplier to reduce pipeline registers.
                Mul = funct7_0;
            end
            // Use funct7 bit 5 to distinguish between ADD/SUB
            // Use funct7 bit 0 to distinguish between MUL and other R-type ops (M extension)
            default: begin 
                ALUControl = 4'b0000;
                Mul = 0;
            end
        endcase
    end

endmodule


// Documentation of control signals:
/*
ALUSrc = 1 meaning we load imm not rs2
ALUSrc = 0 meaning we load rs2
MemtoReg {
    00: ALU result
    01: Memory data (for lw)
    10: PC + 4 (for JAL)
    11: Don't care (for sw, branches) meaning no writeback to rd
}


*/
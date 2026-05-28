/*
===============================================================================
Module Name : Control_Unit
===============================================================================

Description:
------------
This module implements the Main Control Unit and ALU Decoder
for a RISC-V RV32I/RV32M processor.

The Control Unit decodes instruction fields and generates
all required datapath control signals.

Supported Features:
-------------------
    - RV32I Base Integer ISA
    - RV32M Multiplication Extension
    - Branch and Jump Instructions
    - Load/Store Unit (LSU) Control
    - Signed/Unsigned Load Support

The module is divided into:
    1. Main Decoder
    2. ALU Decoder

------------------------------------------------------------------------------
1. MAIN DECODER
------------------------------------------------------------------------------
The Main Decoder uses the instruction opcode to generate:

    - Register write control
    - ALU source selection
    - Memory/LSU control
    - Branch and jump control
    - Write-back source selection

It also generates:
        ALUOp

which is later used by the ALU Decoder.

------------------------------------------------------------------------------
2. ALU DECODER
------------------------------------------------------------------------------
The ALU Decoder generates:

    - ALUControl
    - Mul
    - M_ctrl

using:
    - ALUOp
    - funct3
    - funct7[5]
    - funct7[0]

fields from the instruction.

Inputs:
-------
    opcode :
        Instruction opcode field

    funct3 :
        Instruction funct3 field

    funct7_5 :
        Instruction bit Instr[30]
        Used for:
            ADD/SUB
            SRL/SRA differentiation

    funct7_0 :
        Instruction bit Instr[25]
        Used to detect RV32M multiplication instructions

Outputs:
--------
    RegWrite :
        Register file write enable

    MemtoReg :
        Write-back source select signal

    ALUSrc :
        ALU operand-2 select signal

    Lui :
        Special datapath control for LUI/AUIPC/JAL

    ALUControl :
        4-bit ALU operation select signal

    Jump :
        Jump instruction enable

    Branch :
        Branch instruction enable

    Mul :
        Multiplier datapath enable

    M_ctrl :
        Multiplier result select control

    lsu_req :
        Load/Store request enable

    lsu_we :
        Load/Store write enable

    lsu_type :
        Memory access size control

    lsu_sign_ext :
        Signed/Unsigned load control

------------------------------------------------------------------------------
ALUOp Encoding
------------------------------------------------------------------------------
    ALUOp      Purpose
    -------------------------
      00       ADD operations
      01       Branch comparisons
      10       R-Type / I-Type / MUL operations

------------------------------------------------------------------------------
MemtoReg Encoding
------------------------------------------------------------------------------
    MemtoReg     Write-back Source
    -----------------------------------------
      00         ALU result
      01         Memory read data
      10         PC + 4
      11         Reserved / don't care

------------------------------------------------------------------------------
ALUSrc Encoding
------------------------------------------------------------------------------
    ALUSrc      ALU Operand-2 Source
    -----------------------------------------
      0          rs2 register value
      1          Immediate value

------------------------------------------------------------------------------
LSU Type Encoding
------------------------------------------------------------------------------
    lsu_type     Access Type
    --------------------------------
      00         Word  (32-bit)
      01         Halfword (16-bit)
      10         Byte (8-bit)

------------------------------------------------------------------------------
LSU Sign Extension Control
------------------------------------------------------------------------------
    lsu_sign_ext
    ----------------
      1          Signed load
      0          Unsigned load

------------------------------------------------------------------------------
ALUControl Encoding
------------------------------------------------------------------------------
    ALUControl     Operation
    --------------------------------
      0000         ADD
      1000         SUB / BEQ
      1001         BNE
      1100         BLT
      1101         BGE / SRA
      1110         BLTU
      1111         BGEU
      0100         XOR
      0110         OR
      0111         AND
      0001         SLL
      0101         SRL
      0010         SLT
      0011         SLTU

------------------------------------------------------------------------------
Supported Instructions
------------------------------------------------------------------------------
    - LOAD
    - STORE
    - R-Type ALU
    - I-Type ALU
    - BRANCH
    - JAL
    - JALR
    - LUI
    - AUIPC
    - MUL (RV32M)

Special Notes:
--------------
    - Branch instructions use funct3 directly
      to determine branch comparison type

    - funct7[5] differentiates:
            ADD / SUB
            SRL / SRA

    - funct7[0] identifies RV32M multiplication instructions

    - JAL uses:
            alu_in1 = immediate
            alu_in2 = PC
      allowing ALU to compute:
            PC + immediate

    - Same ALUControl encoding is reused for multiplier operations
      to reduce additional pipeline/control complexity

===============================================================================
*/

module Control_Unit (
    input  logic [6:0] opcode,        // opcode
    input  logic [2:0] funct3,
    input  logic       funct7_5,  // Instr[30]
    input  logic       funct7_0,  // Instr[25] (M extension)

    // Control Outputs
    output logic       RegWrite,
    output logic [1:0] MemtoReg,
    output logic       ALUSrc,
    output logic       Lui,
    output logic [3:0] ALUControl,
    output logic       Jump,
    output logic       Branch,
    output logic       Mul,
    output logic       M_ctrl,
    output logic       lsu_req,
    output logic       lsu_we,
    output logic [1:0] lsu_type,
    output logic       lsu_sign_ext
);

    // Internal signals
    logic [1:0] ALUOp;

    // =========================
    // MAIN DECODER
    // =========================
    always_comb begin
        // Default values (avoid latches)
        RegWrite   = 0;
        ALUSrc     = 0;
        Lui        = 0;
        MemtoReg   = 2'b00;
        Jump       = 0;
        Branch     = 0;
        ALUOp      = 2'b00;
        lsu_req    = 0;
        lsu_we     = 0;
        lsu_type   = 2'b00;
        lsu_sign_ext = 0;
        case (opcode)

            // LOAD (lw)
            7'b0000011: begin
                RegWrite  = 1;
                ALUSrc    = 1;
                Lui       = 0;
                MemtoReg  = 2'b01;
                Jump      = 0;
                Branch    = 0;
                ALUOp     = 2'b00;
                lsu_req    = 1;
                lsu_we     = 0;
                case(funct3)
                3'b000: begin
                    lsu_type   = 2'b10;
                    lsu_sign_ext = 1;
                end
                3'b001: begin
                    lsu_type   = 2'b01;
                    lsu_sign_ext = 1;
                end
                3'b010: begin
                    lsu_type   = 2'b00;
                    lsu_sign_ext = 1;
                end
                3'b100: begin
                    lsu_type   = 2'b10;
                    lsu_sign_ext = 0;
                end
                3'b101: begin
                    lsu_type   = 2'b01;
                    lsu_sign_ext = 0;
                end
                default :begin
                    lsu_type   = 2'b00;
                    lsu_sign_ext = 1;
                end
                endcase
            end

            // STORE (sw)
            7'b0100011: begin
                RegWrite  = 0;
                ALUSrc    = 1;
                Lui       = 0;
                MemtoReg  = 2'b11;
                Jump      = 0;
                Branch    = 0;
                ALUOp     = 2'b00;
                lsu_req    = 1;
                lsu_we     = 1;
                case(funct3)
                3'b000:
                    lsu_type   = 2'b10;
                3'b001: 
                    lsu_type   = 2'b01;
                3'b010: 
                    lsu_type   = 2'b00;
                default:
                    lsu_type   = 2'b00;
            endcase
            end

            // R-TYPE // MUL (M extension)
            7'b0110011: begin
                RegWrite  = 1;
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
                ALUSrc    = 1; // PC= PC + imm ccurs in ALU and is sent to PC mux when Jump = 1
                Lui       = 1;
                MemtoReg  = 2'b10; // rd = PC + 4
                Jump      = 1;
                Branch    = 0;
                ALUOp     = 2'b00;
            end
            // JALR
            7'b1100111: begin
                RegWrite  = 1;
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
                ALUSrc    = 1;
                Lui       = 1; 
                MemtoReg  = 2'b00; // ALU will be configured to add imm to PC and pass result to rd
                Jump      = 0;
                Branch    = 0;
                ALUOp     = 2'b00;
            end

            default: begin
                RegWrite   = 0;
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
        M_ctrl = 0;
        case (ALUOp)

            // ADD (lw, sw, JAL, JALR, LUI, AUIPC etc)
            2'b00: begin 
                ALUControl = 4'b0000;
                Mul = 0;
                M_ctrl = 0;
            end  

            // Branch use funct3 directly to determine the type of branch
            2'b01: begin
                ALUControl = {1'b1, funct3};
                Mul = 0;
                M_ctrl = 0;
            end
            // R-type / I-type ALU ops / MUL (M extension)
            2'b10: begin
                
                ALUControl = {funct7_5, funct3};
                // Using same ALUControl for M-EXT Multiplier to reduce pipeline registers.
                if (opcode == 7'b0010011) begin 
                    Mul = 0;
                    M_ctrl = 0;
                end
                else if (opcode == 7'b0110011) begin
                    Mul = funct7_0;
                    M_ctrl = funct3[0] | funct3[1];
                end
            end
            // Use funct7 bit 5 to distinguish between ADD/SUB
            // Use funct7 bit 0 to distinguish between MUL and other R-type ops (M extension)
            default: begin 
                ALUControl = 4'b0000;
                Mul = 0;
                M_ctrl = 0;
            end
        endcase
    end

endmodule


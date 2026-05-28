/*
===============================================================================
Module Name : immediate_generator
===============================================================================

Description:
------------
This module implements the Immediate Generator for a RISC-V RV32IM processor.

The Immediate Generator extracts and sign-extends immediate values from
different instruction formats based on the instruction opcode.

Supported Instruction Types:
----------------------------
    1. I-Type  → ALU Immediate, LOAD, JALR
    2. S-Type  → STORE instructions
    3. B-Type  → BRANCH instructions
    4. U-Type  → LUI, AUIPC
    5. J-Type  → JAL

Functionality:
--------------
    - Decodes instruction opcode
    - Extracts immediate field according to instruction format
    - Performs sign extension when required
    - Outputs 32-bit immediate value

Immediate Formats:
------------------
    I-Type :
        imm[11:0] = instr[31:20]

    S-Type :
        imm[11:5] = instr[31:25]
        imm[4:0]  = instr[11:7]

    B-Type :
        imm[12]   = instr[31]
        imm[11]   = instr[7]
        imm[10:5] = instr[30:25]
        imm[4:1]  = instr[11:8]
        imm[0]    = 0

    U-Type :
        imm[31:12] = instr[31:12]
        imm[11:0]  = 0

    J-Type :
        imm[20]    = instr[31]
        imm[19:12] = instr[19:12]
        imm[11]    = instr[20]
        imm[10:1]  = instr[30:21]
        imm[0]     = 0

Special Notes:
--------------
    - B-Type and J-Type immediates are shifted left by 1 bit
      because branch/jump addresses are aligned.

    - Sign extension is performed using instruction MSB (instr[31])

===============================================================================
*/

`timescale 1ns / 1ps

module immediate_generator (
    input  logic [31:0] instr,      // 32-bit instruction input
    output logic [31:0] imm_out     // Generated immediate output
);

    // ------------------------------------------------------------------------
    // Opcode Extraction
    // Opcode determines instruction format
    // ------------------------------------------------------------------------
    logic [6:0] opcode;
    assign opcode = instr[6:0];


    // ------------------------------------------------------------------------
    // Immediate Generation Logic
    // Generates immediate based on instruction type
    // ------------------------------------------------------------------------
    always_comb begin

        unique case (opcode)

            // ----------------------------------------------------------------
            // I-Type Instructions
            // ALU Immediate, LOAD, JALR
            // ----------------------------------------------------------------
            7'b0010011,
            7'b0000011,
            7'b1100111: begin
                imm_out = {{20{instr[31]}}, instr[31:20]};
            end


            // ----------------------------------------------------------------
            // S-Type Instructions
            // STORE operations
            // ----------------------------------------------------------------
            7'b0100011: begin
                imm_out = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            end


            // ----------------------------------------------------------------
            // B-Type Instructions
            // Conditional BRANCH operations
            // ----------------------------------------------------------------
            7'b1100011: begin
                imm_out = {
                    {19{instr[31]}},
                    instr[31],
                    instr[7],
                    instr[30:25],
                    instr[11:8],
                    1'b0
                };
            end


            // ----------------------------------------------------------------
            // U-Type Instructions
            // LUI and AUIPC
            // ----------------------------------------------------------------
            7'b0110111,
            7'b0010111: begin
                imm_out = {instr[31:12], 12'b0};
            end


            // ----------------------------------------------------------------
            // J-Type Instructions
            // JAL operation
            // ----------------------------------------------------------------
            7'b1101111: begin
                imm_out = {
                    {11{instr[31]}},
                    instr[31],
                    instr[19:12],
                    instr[20],
                    instr[30:21],
                    1'b0
                };
            end


            // ----------------------------------------------------------------
            // Default Case
            // Unsupported opcode
            // ----------------------------------------------------------------
            default: begin
                imm_out = 32'd0;
            end

        endcase
    end

endmodule
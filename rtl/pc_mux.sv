/*
===============================================================================
Module Name : pc_mux
===============================================================================

Description:
------------
This module implements the Program Counter (PC) selection multiplexer
for a RISC-V processor datapath.

The module selects the next value of the Program Counter (`pc_in`)
based on the control signal `pcsrc`.

The multiplexer supports:
    1. Sequential execution      (PC + 4)
    2. Branch / Jump target      (branch_addr)
    3. JALR target address       (alu_result)

Inputs:
-------
    pc_plus4 :
        Next sequential instruction address

    branch_addr :
        Branch or jump target address

    alu_result :
        ALU-generated target address
        (Used in JALR instruction)

    pcsrc :
        Control signal selecting next PC source

Selection Logic:
----------------
    pcsrc     pc_in Output
    ----------------------------
     00       pc_plus4
     01       branch_addr
     10       alu_result
     11       pc_plus4 (default)

Operation:
----------
    - For normal instruction flow:
            PC ← PC + 4

    - For branch/jump instructions:
            PC ← branch target address

    - For JALR instruction:
            PC ← ALU computed address

Special Note:
-------------
    The default case selects `pc_plus4`
    to ensure safe sequential execution.

===============================================================================
*/

module pc_mux (
    input  logic [31:0] pc_plus4,      // Sequential next PC
    input  logic [31:0] branch_addr,   // Branch/jump target address
    input  logic [31:0] alu_result,    // ALU computed target address (JALR)
    input  logic [1:0]  pcsrc,         // PC source select control signal
    output logic [31:0] pc_in          // Selected next PC value
);

    // ------------------------------------------------------------------------
    // PC Selection Multiplexer
    // Selects next PC based on pcsrc control signal
    // ------------------------------------------------------------------------
    always_comb begin

        case (pcsrc)

            // ----------------------------------------------------------------
            // JALR Instruction
            // PC ← ALU computed address
            // ----------------------------------------------------------------
            2'b10: pc_in = alu_result;


            // ----------------------------------------------------------------
            // Branch / Jump Instruction
            // PC ← Branch target address
            // ----------------------------------------------------------------
            2'b01: pc_in = branch_addr;


            // ----------------------------------------------------------------
            // Default Sequential Execution
            // PC ← PC + 4
            // ----------------------------------------------------------------
            default: pc_in = pc_plus4;

        endcase
    end

endmodule
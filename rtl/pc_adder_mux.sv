/*
===============================================================================
Module Name : pc_adder_mux
===============================================================================

Description:
------------
This module generates the next sequential Program Counter increment value
for a RISC-V processor.

Normally, the Program Counter increments by 4 bytes because each RV32IM
instruction is 32 bits (4 bytes) wide.

This module also supports PC stalling functionality.

Functionality:
--------------
    - If `pc_stall = 0`
            → PC increments normally by 4

    - If `pc_stall = 1`
            → PC increment becomes 0
            → PC remains unchanged (stall condition)

Purpose:
--------
    This logic is commonly used in:
        - Pipeline hazard handling
        - Instruction stalls
        - Cache miss handling
        - Dependency resolution

Inputs:
-------
    pc :
        Current Program Counter value

    pc_stall :
        Stall control signal

Outputs:
--------
    pc_plus4 :
        Next sequential PC value

Operation:
----------
    Normal Execution:
        pc_plus4 = pc + 4

    Stall Condition:
        pc_plus4 = pc + 0

Special Note:
-------------
    Using an increment value of 0 effectively freezes the PC,
    preventing instruction fetch from advancing.

===============================================================================
*/

module pc_adder_mux (
    input  logic        pc_stall,   // PC stall control signal
    input  logic [31:0] pc,         // Current Program Counter
    output logic [31:0] pc_plus4    // Next sequential PC value
);

    // ------------------------------------------------------------------------
    // Internal MUX Output
    // Selects either 4 or 0 based on stall condition
    // ------------------------------------------------------------------------
    logic [31:0] mux_out;


    // ------------------------------------------------------------------------
    // PC Increment Selection Logic
    // ------------------------------------------------------------------------
    always_comb begin

        // --------------------------------------------------------------------
        // Stall Condition
        // PC increment = 0
        // --------------------------------------------------------------------
        if (pc_stall)
            mux_out = 32'd0;

        // --------------------------------------------------------------------
        // Normal Execution
        // PC increment = 4
        // --------------------------------------------------------------------
        else
            mux_out = 32'd4;

    end


    // ------------------------------------------------------------------------
    // PC Adder Logic
    // Generates next sequential PC value
    // ------------------------------------------------------------------------
    assign pc_plus4 = pc + mux_out;

endmodule
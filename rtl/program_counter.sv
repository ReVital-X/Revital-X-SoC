/*
===============================================================================
Module Name : program_counter
===============================================================================

Description:
------------
This module implements the Program Counter (PC) register in a RISC-V datapath.

The Program Counter stores the address of the current instruction being
executed. On every clock cycle, the PC is updated with the next instruction
address provided through `pc_in`.

Features:
---------
1. Synchronous PC update on rising edge of clock
2. Asynchronous reset support
3. Stores 32-bit instruction address

Operation:
----------
    Reset Condition:
    ----------------
    If `rst = 1`
        → PC is reset to 0x00000000

    Normal Operation:
    -----------------
    If `rst = 0`
        → PC loads the value from `pc_in`
        → Updated on positive edge of `clk`

===============================================================================
*/

module program_counter (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] pc_in,
    output logic [31:0] pc_out
);

    // ------------------------------------------------------------------------
    // Program Counter Register Logic
    // Updates PC on every rising clock edge
    // Resets PC to zero when reset is asserted
    // ------------------------------------------------------------------------
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            pc_out <= 32'd0;
        else
            pc_out <= pc_in;
    end

endmodule
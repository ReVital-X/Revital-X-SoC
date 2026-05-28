/*
===============================================================================
Module Name : register_file
===============================================================================

Description:
------------
This module implements a 32 × 32-bit Register File for a RISC-V processor.

The register file contains 32 general-purpose registers:
    x0 → x31

Each register is 32 bits wide.

Features:
---------
1. Two asynchronous read ports
2. One synchronous write port
3. Register x0 is hardwired to zero
4. Reset initializes all registers to zero

Ports:
------
    rs1, rs2 :
        Source register addresses for reading data

    rd :
        Destination register address for write operation

    rd_value :
        Data to be written into destination register

    regwrite :
        Write enable control signal

    rs1_value, rs2_value :
        Output data from source registers

Operation:
----------
    Write Operation:
    ----------------
    - Occurs on rising edge of `clk`
    - Write happens only when:
            regwrite = 1
            AND rd != 0
    - x0 register is never modified

    Reset Operation:
    ----------------
    - When `rst = 1`
        → All registers are cleared to zero

    Read Operation:
    ---------------
    - Reads are combinational (asynchronous)
    - Output updates immediately when rs1/rs2 changes
    - If rs1 or rs2 = 0
        → Output is forced to zero

===============================================================================
*/

`timescale 1ns/1ps

module register_file (
    input  logic        clk, rst,          // Clock and asynchronous reset
    input  logic [4:0]  rs1, rs2, rd,      // Register addresses (32 registers → 5 bits)
    input  logic [31:0] rd_value,          // Data to be written into destination register
    input  logic        regwrite,          // Write enable signal
    output logic [31:0] rs1_value,         // Read data from rs1
    output logic [31:0] rs2_value          // Read data from rs2
);

    // ------------------------------------------------------------------------
    // Register File Declaration
    // 32 registers, each 32-bit wide
    // ------------------------------------------------------------------------
    logic [31:0] regfile [31:0];


    // ------------------------------------------------------------------------
    // WRITE + RESET LOGIC (Sequential)
    // Writes data on positive clock edge
    // Reset clears all registers
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < 32; i++)
                regfile[i] <= 32'b0;
        end
        else if (regwrite && (rd != 5'd0)) begin

            // Write operation
            // x0 is hardwired to zero, so writes to x0 are ignored
            regfile[rd] <= rd_value;

        end
    end


    // ------------------------------------------------------------------------
    // READ LOGIC (Combinational)
    // Provides asynchronous read access
    // x0 always returns zero
    // ------------------------------------------------------------------------
    assign rs1_value = (rs1 == 0) ? 32'd0 : regfile[rs1];
    assign rs2_value = (rs2 == 0) ? 32'd0 : regfile[rs2];

endmodule
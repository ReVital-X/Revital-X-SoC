/*
===============================================================================
Module Name : data_ram
===============================================================================

Description:
------------
This module implements a simple synchronous Data Memory (RAM) block for a
RISC-V processor datapath.

The memory supports:
    1. Read operation
    2. Write operation

The RAM contains 1024 words of 32-bit memory locations.

Memory Organization:
--------------------
    Total Entries  : 1024
    Word Size      : 32 bits
    Addressing     : Word-aligned

Address Mapping:
----------------
    address[11:2] is used as memory index.

Reason:
-------
    - Each memory word is 32 bits (4 bytes)
    - Lower 2 bits are ignored because addresses are word-aligned

Example:
--------
    Address = 0x00000004
    Memory Index = 1

    Address = 0x00000008
    Memory Index = 2

Operations:
-----------
    Read Operation:
    ----------------
    If MemRead = 1
        → Data is read from memory
        → Output appears on `read_data`

    Write Operation:
    -----------------
    If MemWrite = 1
        → `write_data` is written into memory location

Timing:
-------
    - Read operation is synchronous
    - Write operation is synchronous
    - Both occur on positive edge of clock

Special Note:
-------------
    If both MemRead and MemWrite are enabled simultaneously,
    both operations execute during the same clock cycle.

===============================================================================
*/

module data_ram (
    input logic        clk,          // System clock
    input logic [31:0] address,      // Memory address
    input logic [31:0] write_data,   // Data to be written into memory
    input logic        MemRead,      // Memory read enable
    input logic        MemWrite,     // Memory write enable
    output logic [31:0] read_data    // Data read from memory
);

    // ------------------------------------------------------------------------
    // Memory Declaration
    // 1024 locations, each 32-bit wide
    // ------------------------------------------------------------------------
    logic [31:0] mem [0:1023];


    // ------------------------------------------------------------------------
    // Memory Access Logic
    // Performs synchronous read and write operations
    // ------------------------------------------------------------------------
    always_ff @ (posedge clk) begin

        // --------------------------------------------------------------------
        // Read Operation
        // --------------------------------------------------------------------
        if (MemRead) begin
            read_data <= mem[address[11:2]];
        end


        // --------------------------------------------------------------------
        // Write Operation
        // --------------------------------------------------------------------
        if (MemWrite) begin
            mem[address[11:2]] <= write_data;
        end

    end

endmodule
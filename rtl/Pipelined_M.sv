/*
===============================================================================
Module Name : Pipelined_M
===============================================================================

Description:
------------
This module implements a 32-bit signed pipelined multiplier
for a RISC-V RV32M processor.

The multiplier uses:
    1. Radix-4 Modified Booth Encoding
    2. Wallace Tree Compression
    3. Hierarchical 64-bit Carry Lookahead Adder (CLA)

The design is optimized for:
    - Reduced partial products
    - Faster multiplication
    - Pipelined execution

Architecture:
-------------
    Stage 1 :
        Booth Partial Product Generation

    Stage 2 :
        Wallace Tree Compression

    Stage 3 :
        Final 64-bit CLA Addition

Features:
---------
    - Signed multiplication support
    - 3-stage pipelined architecture
    - RV32M extension compatible
    - Supports MUL/MULH style operations
    - Valid signal propagation using pipeline control

Inputs:
-------
    clk :
        System clock

    rst :
        Synchronous reset

    start :
        Starts multiplication operation

    A, B :
        Signed 32-bit multiplication operands

    M_ctrl :
        Result select control

Outputs:
--------
    P_32 :
        Selected 32-bit multiplication result

    M_over :
        Multiplication completion signal

Operation:
----------
    M_ctrl = 0 :
        Lower 32 bits of multiplication result
        → MUL operation

    M_ctrl = 1 :
        Upper 32 bits of multiplication result
        → MULH-type operation

Pipeline Latency:
-----------------
    Multiplication result becomes valid
    after pipeline propagation.

        start → v1 → v2 → M_over

Special Notes:
--------------
    - Booth encoding reduces number of partial products
    - Wallace tree reduces carry propagation delay
    - CLA improves final addition speed
    - Pipeline registers improve timing performance

===============================================================================
*/

`timescale 1ns / 1ps

module Pipelined_M(
    input clk,
    input rst,
    input logic start,
    output logic M_over,
    input  signed [31:0] A,
    input  signed [31:0] B,
    output signed [31:0] P_32,
    input logic M_ctrl
);

    // ------------------------------------------------------------------------
    // Partial Products
    // ------------------------------------------------------------------------
    wire signed [63:0] pp [0:16];
    reg  signed [63:0] pp_next [0:16];

    // Booth Partial Product Generator
    M1 multi1(
        .A(A),
        .B(B),
        .pp(pp)
    );

    integer i;

    // ------------------------------------------------------------------------
    // Pipeline Valid Signals
    // ------------------------------------------------------------------------
    logic v1, v2;

    always @(posedge clk) begin
        if (rst) begin
            v1 <= 0;
            v2 <= 0;
        end
        else begin
            v1 <= start;
            v2 <= v1;
        end
    end


    // ------------------------------------------------------------------------
    // Pipeline Stage-1 Register
    // Stores Booth partial products
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 17; i = i + 1)
                pp_next[i] <= 0;
        end
        else if (start) begin
            for (i = 0; i < 17; i = i + 1)
                pp_next[i] <= pp[i];
        end
    end


    // ------------------------------------------------------------------------
    // Wallace Compression Outputs
    // ------------------------------------------------------------------------
    wire signed [63:0] s6;
    wire signed [64:0] c6;

    reg signed [63:0] s6_next;
    reg signed [64:0] c6_next;

    // Wallace Tree Compression
    M2 multi2(
        .pp(pp_next),
        .s6(s6),
        .c6(c6)
    );


    // ------------------------------------------------------------------------
    // Pipeline Stage-2 Register
    // Stores Wallace compression outputs
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            s6_next <= 0;
            c6_next <= 0;
        end
        else if (v1) begin
            s6_next <= s6;
            c6_next <= c6;
        end
    end


    // ------------------------------------------------------------------------
    // Final CLA Addition Stage
    // ------------------------------------------------------------------------
    wire signed [63:0] P;
    wire cz;

    cla64 Final_Add(
        .a   (s6_next),
        .b   (c6_next[63:0]),
        .cin (1'b0),
        .sum (P),
        .cout(cz)
    );

    // Unused carry-out suppression
    logic _unused;
    assign _unused = cz;


    // ------------------------------------------------------------------------
    // Result Selection
    // ------------------------------------------------------------------------
    assign P_32 = M_ctrl ? P[63:32] : P[31:0];


    // ------------------------------------------------------------------------
    // Multiplication Completion Signal
    // ------------------------------------------------------------------------
    assign M_over = v2;

endmodule



/*
===============================================================================
Module Name : M1
===============================================================================

Description:
------------
This module generates Booth-encoded partial products
for the Radix-4 Modified Booth multiplier.

The multiplier operand B is divided into overlapping
3-bit Booth groups.

Each Booth group generates:
    0, +A, -A, +2A, or -2A

The generated partial products are:
    - Sign extended
    - Shifted appropriately
    - Sent to Wallace tree compression stage

Booth Encoding Table:
---------------------
    Booth Bits      Operation
    --------------------------------
      000           0
      001          +A
      010          +A
      011         +2A
      100         -2A
      101          -A
      110          -A
      111           0

===============================================================================
*/

module M1(
    input  signed [31:0] A,
    input  signed [31:0] B,
    output reg signed [63:0] pp [0:16]
);

    // ------------------------------------------------------------------------
    // Booth Partial Product Generation
    // ------------------------------------------------------------------------
    genvar i;

    generate

        for(i=0;i<17;i=i+1) begin : BOOTH_PP_GEN

            wire [2:0] booth_bits;
            wire signed [2:0] code;

            // ------------------------------------------------------------
            // Booth Bit Selection
            // ------------------------------------------------------------
            if(i == 0) begin : GEN_I0
                assign booth_bits = {B[1], B[0], 1'b0};
            end
            else if(i == 16) begin : GEN_I16
                assign booth_bits = {B[31], B[31], B[31]};
            end
            else begin : GEN_MID
                assign booth_bits = {B[2*i+1], B[2*i], B[2*i-1]};
            end


            // ------------------------------------------------------------
            // Booth Encoder
            // ------------------------------------------------------------
            booth_encoder ENC(
                .y(booth_bits),
                .code(code)
            );


            // ------------------------------------------------------------
            // Partial Product Generation
            // ------------------------------------------------------------
            reg signed [63:0] temp;

            always @(*) begin

                case(code)

                    0:  temp = 64'd0;

                    1:  temp = {{32{A[31]}},A};

                   -1:  temp = -({{32{A[31]}},A});

                    2:  temp = ({{32{A[31]}},A} <<< 1);

                   -2:  temp = -(({{32{A[31]}},A}) <<< 1);

                    default: temp = 64'd0;

                endcase
            end

            // Shift partial product
            assign pp[i] = $signed(temp) <<< (2*i);

        end

    endgenerate

endmodule
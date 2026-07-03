`timescale 1ns/1ps
module csr_register_file (
    input logic clk,
    input logic rst,

    // Read Port
    input logic [11:0] csr_addr,
    output logic [31:0] csr_rdata,

    // Write Port
    input logic csr_we,
    input logic [11:0] csr_waddr,
    input logic [31:0] csr_wdata

 /*   // Trap Controller
    input logic trap_we,

    input logic [31:0] mepc_new,
    input logic [31:0] mcause_new,
    input logic [31:0] mstatus_new */
);
logic [31:0] mstatus;
logic [31:0] mie;
logic [31:0] mtvec;
logic [31:0] mepc;
logic [31:0] mcause;
logic [31:0] mip;
logic [31:0] mscratch;
    always_comb begin
        case (csr_addr)
            12'h300: csr_rdata = mstatus;
            12'h304: csr_rdata = mie;
            12'h305: csr_rdata = mtvec;
            12'h340: csr_rdata = mscratch;
            12'h341: csr_rdata = mepc;
            12'h342: csr_rdata = mcause;
            12'h344: csr_rdata = mip;
            default: csr_rdata = 32'd0; // Default value for unimplemented CSRs
        endcase
    end
    always_ff @(posedge clk) begin
        if (rst) begin
            mstatus <= 32'd0;
            mie <= 32'd0;
            mtvec <= 32'd0; //Needed to set the trap vector base address
            mepc <= 32'd0;
            mcause <= 32'd0;
            mip <= 32'd0;
            mscratch <= 32'd0;
        end /* else begin
            if (trap_we) begin
                mepc <= mepc_new;
                mcause <= mcause_new;
                mstatus <= mstatus_new;
            end */ else if (csr_we) begin
                case (csr_waddr)
                    12'h300: mstatus <= csr_wdata;
                    12'h304: mie <= csr_wdata;
                    12'h305: mtvec <= csr_wdata;
                    12'h340: mscratch <= csr_wdata;
                    12'h341: mepc <= csr_wdata;
                    12'h342: mcause <= csr_wdata;
                    12'h344: mip <= csr_wdata;
                    default: ; // (After exception, add illegal instruction signal)
                endcase
            end
        end
endmodule
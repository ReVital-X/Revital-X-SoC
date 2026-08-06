`timescale 1ns / 1ps
module instr_ram
  #(
    parameter INSTR_ADDR_WIDTH = 8,
    parameter BOOT_ADDR_WIDTH  = 8,
    parameter INSTR_WORDS      = 256,
    parameter BOOT_WORDS       = 256
  )(
    // Clock and Reset
    input  logic clk,
    input logic boot_mode,

    input  logic                   en_a_i,
    input  logic [BOOT_ADDR_WIDTH-1:0]  addr_boot_a_i,
    input  logic [INSTR_ADDR_WIDTH-1:0]  addr_instr_a_i,
    input  logic [31:0]            wdata_a_i,
    output logic [31:0]            rdata_a_o,
    input  logic                   we_a_i,
    input  logic [3:0]             be_a_i,

    input  logic                   en_b_i,
    input  logic [INSTR_ADDR_WIDTH-1:0]  addr_b_i,
    input  logic [31:0]            wdata_b_i,
    output logic [31:0]            rdata_b_o,
    input  logic                   we_b_i,
    input  logic [3:0]             be_b_i,
    input  logic                   sign_ext_b_i
  );
logic en_1_i, we_1_i;
logic [BOOT_ADDR_WIDTH-1:0] addr_1_i;
logic [31:0] wdata_1_i, rdata_1_o;
logic [3:0] be_1_i;

logic en_2_i, we_2_i;
logic [INSTR_ADDR_WIDTH-1:0] addr_2_i;
logic [31:0] wdata_2_i, rdata_2_o;
logic [3:0] be_2_i;
logic [3:0] be_b_i_reg;
logic sign_ext_b_i_reg;
always_ff @(posedge clk) begin
    be_b_i_reg <= be_b_i;
    sign_ext_b_i_reg <= sign_ext_b_i;
end
always_comb begin
  en_1_i    = 1'b0;
  addr_1_i  = '0;
  wdata_1_i = '0;
  we_1_i    = 1'b0;
  be_1_i    = '0;

  en_2_i    = 1'b0;
  addr_2_i  = '0;
  wdata_2_i = '0;
  we_2_i    = 1'b0;
  be_2_i    = '0;

  rdata_a_o = 32'b0;
  rdata_b_o = 32'b0;

  if (boot_mode) begin
    // Fetch from boot memory
    en_1_i    = en_a_i;
    addr_1_i  = addr_boot_a_i;
    wdata_1_i = wdata_a_i;
    we_1_i    = we_a_i;
    be_1_i    = be_a_i;
    rdata_a_o = rdata_1_o;

    // MEM stage can access instruction memory
    en_2_i    = en_b_i;
    addr_2_i  = addr_b_i;
    wdata_2_i = wdata_b_i;
    we_2_i    = we_b_i;
    be_2_i    = be_b_i;
    if(sign_ext_b_i_reg) begin
      case (be_b_i_reg)
      // byte loads/stores
        4'b0001: rdata_b_o = {{24{rdata_2_o[7]}}, rdata_2_o[7:0]};
        4'b0010: rdata_b_o = {{24{rdata_2_o[15]}}, rdata_2_o[15:8]};
        4'b0100: rdata_b_o = {{24{rdata_2_o[23]}}, rdata_2_o[23:16]};
        4'b1000: rdata_b_o = {{24{rdata_2_o[31]}}, rdata_2_o[31:24]};
      // halfword loads/stores
        4'b0011: rdata_b_o = {{16{rdata_2_o[15]}}, rdata_2_o[15:0]};
        4'b0110: rdata_b_o = {{16{rdata_2_o[23]}}, rdata_2_o[23:8]};
        4'b1100: rdata_b_o = {{16{rdata_2_o[31]}}, rdata_2_o[31:16]};
        4'b1001: rdata_b_o = {{16{rdata_2_o[31]}}, rdata_2_o[31:24], rdata_2_o[7:0]};
        default: rdata_b_o = rdata_2_o;
      endcase
    end else begin
      case (be_b_i_reg)
      // byte loads/stores
        4'b0001: rdata_b_o = {24'b0, rdata_2_o[7:0]};
        4'b0010: rdata_b_o = {24'b0, rdata_2_o[15:8]};
        4'b0100: rdata_b_o = {24'b0, rdata_2_o[23:16]};
        4'b1000: rdata_b_o = {24'b0, rdata_2_o[31:24]};
      // halfword loads/stores
        4'b0011: rdata_b_o = {16'b0, rdata_2_o[15:0]};
        4'b0110: rdata_b_o = {16'b0, rdata_2_o[23:8]};
        4'b1100: rdata_b_o = {16'b0, rdata_2_o[31:16]};
        4'b1001: rdata_b_o = {16'b0, rdata_2_o[31:24], rdata_2_o[7:0]};
        default: rdata_b_o = rdata_2_o;
      endcase
    end
  end else begin
    // Fetch from instruction memory
    en_2_i    = en_a_i;
    addr_2_i  = addr_instr_a_i;
    wdata_2_i = wdata_a_i;
    we_2_i    = we_a_i;
    be_2_i    = be_a_i;
    rdata_a_o = rdata_2_o;

    // Boot memory inaccessible, MEM port disabled
    rdata_b_o = 32'b0;
  end
end
   // 64x32 boot memory
   logic [31:0] BWEB_i_1;
   assign BWEB_i_1[31:24] = be_1_i[3] ? 8'h00 : 8'hFF;
   assign BWEB_i_1[23:16] = be_1_i[2] ? 8'h00 : 8'hFF;
   assign BWEB_i_1[15:8]  = be_1_i[1] ? 8'h00 : 8'hFF;
   assign BWEB_i_1[7:0]   = be_1_i[0] ? 8'h00 : 8'hFF;
   TS1N28HPCPHVTB64X32M4SWBASO ram1(
            .SLP(0),
            .SD(0),
            .CLK(clk), .CEB(!en_1_i), .WEB(!we_1_i),
            .CEBM(1), .WEBM(1),
            .AWT(0),
            .A(addr_1_i), .D(wdata_1_i),
            .BWEB(BWEB_i_1),
            .AM(6'd0), .DM(32'd0), 
            .BWEBM(32'd0),
            .BIST(0),
            .Q(rdata_1_o));

   // 64x32 instruction memory
   logic [31:0] BWEB_i_2;
   assign BWEB_i_2[31:24] = be_2_i[3] ? 8'h00 : 8'hFF;
   assign BWEB_i_2[23:16] = be_2_i[2] ? 8'h00 : 8'hFF;
   assign BWEB_i_2[15:8]  = be_2_i[1] ? 8'h00 : 8'hFF;
   assign BWEB_i_2[7:0]   = be_2_i[0] ? 8'h00 : 8'hFF;
   TS1N28HPCPHVTB64X32M4SWBASO ram3(
            .SLP(0),
            .SD(0),
            .CLK(clk), .CEB(!en_2_i), .WEB(!we_2_i),
            .CEBM(1), .WEBM(1),
            .AWT(0),
            .A(addr_2_i), .D(wdata_2_i),
            .BWEB(BWEB_i_2),
            .AM(6'd0), .DM(32'd0), 
            .BWEBM(32'd0),
            .BIST(0),
            .Q(rdata_2_o));


endmodule

`timescale 1ns / 1ps
module data_ram
  #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter NUM_WORDS  = 256
  )(
    // Clock and Reset
    input  logic                    clk,

    input  logic                    en_i,
    input  logic [ADDR_WIDTH-1:0]   addr_i,
    input  logic [DATA_WIDTH-1:0]   wdata_i,
    output logic [DATA_WIDTH-1:0]   rdata_o,
    input  logic                    we_i,
    input  logic [DATA_WIDTH/8-1:0] be_i,
    input logic sign_ext_i
  );
logic [31:0] rdata_o1;
logic sign_ext_i_reg;
logic [DATA_WIDTH/8-1:0] be_i_reg;

// 64x32 DATA RAM
logic [31:0] BWEB_i;
   assign BWEB_i[31:24] = be_i[3] ? 8'h00 : 8'hFF;
   assign BWEB_i[23:16] = be_i[2] ? 8'h00 : 8'hFF;
   assign BWEB_i[15:8]  = be_i[1] ? 8'h00 : 8'hFF;
   assign BWEB_i[7:0]   = be_i[0] ? 8'h00 : 8'hFF;

TS1N28HPCPHVTB64X32M4SWBASO ram2(
            .SLP(0),
            .SD(0),
            .CLK(clk), .CEB(!en_i), .WEB(!we_i),
            .CEBM(1), .WEBM(1),
            .AWT(0),
            .A(addr_i), .D(wdata_i),
            .BWEB(BWEB_i),
            .AM(6'd0), .DM(32'd0), 
            .BWEBM(32'd0),
            .BIST(0),
            .Q(rdata_o1));

always_ff @(posedge clk) begin
    be_i_reg <= be_i;
    sign_ext_i_reg <= sign_ext_i;
end
// load access for lb/lh/lw with sign/zero extension
always_comb begin
  if(sign_ext_i_reg) begin
    case (be_i_reg)
    // byte loads/stores
      4'b0001: rdata_o = {{24{rdata_o1[7]}}, rdata_o1[7:0]};
      4'b0010: rdata_o = {{24{rdata_o1[15]}}, rdata_o1[15:8]};
      4'b0100: rdata_o = {{24{rdata_o1[23]}}, rdata_o1[23:16]};
      4'b1000: rdata_o = {{24{rdata_o1[31]}}, rdata_o1[31:24]};
    // halfword loads/stores
      4'b0011: rdata_o = {{16{rdata_o1[15]}}, rdata_o1[15:0]};
      4'b0110: rdata_o = {{16{rdata_o1[23]}}, rdata_o1[23:8]};
      4'b1100: rdata_o = {{16{rdata_o1[31]}}, rdata_o1[31:16]};
      4'b1001: rdata_o = {{16{rdata_o1[31]}}, rdata_o1[31:24], rdata_o1[7:0]};
      default: rdata_o = rdata_o1;
    endcase
  end else begin
    case (be_i_reg)
    // byte loads/stores
      4'b0001: rdata_o = {24'b0, rdata_o1[7:0]};
      4'b0010: rdata_o = {24'b0, rdata_o1[15:8]};
      4'b0100: rdata_o = {24'b0, rdata_o1[23:16]};
      4'b1000: rdata_o = {24'b0, rdata_o1[31:24]};
    // halfword loads/stores
      4'b0011: rdata_o = {16'b0, rdata_o1[15:0]};
      4'b0110: rdata_o = {16'b0, rdata_o1[23:8]};
      4'b1100: rdata_o = {16'b0, rdata_o1[31:16]};
      4'b1001: rdata_o = {16'b0, rdata_o1[31:24], rdata_o1[7:0]};
      default: rdata_o = rdata_o1;
    endcase
  end
end
endmodule

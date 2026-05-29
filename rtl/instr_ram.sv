module instr_ram
  #(
    parameter ADDR_WIDTH = 8
  )(
    // Clock and Reset
    input  logic clk,

    input  logic                   en_a_i,
    input  logic [ADDR_WIDTH-1:0]  addr_a_i,
    input  logic [31:0]            wdata_a_i,
    output logic [31:0]            rdata_a_o,
    input  logic                   we_a_i,
    input  logic [3:0]             be_a_i,

    input  logic                   en_b_i,
    input  logic [ADDR_WIDTH-1:0]  addr_b_i,
    input  logic [31:0]            wdata_b_i,
    output logic [31:0]            rdata_b_o,
    input  logic                   we_b_i,
    input  logic [3:0]             be_b_i
  );

   dp_ram ram1(
    .clk(clk),
    .en_a_i(en_a_i),
    .addr_a_i(addr_a_i),
    .wdata_a_i(wdata_a_i),
    .rdata_a_o(rdata_a_o),
    .we_a_i(we_a_i),
    .be_a_i(be_a_i),

    .en_b_i(en_b_i),
    .addr_b_i(addr_b_i),
    .wdata_b_i(wdata_b_i),
    .rdata_b_o(rdata_b_o),
    .we_b_i(we_b_i),
    .be_b_i(be_b_i)
   );

endmodule

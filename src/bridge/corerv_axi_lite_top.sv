module corerv_axi_lite_top (
  input logic clk,
  input logic rst,
  AXI_LITE.Master core_axi_lite_master
);
  logic [31:0] data_addr, data_wdata, data_rdata;
  logic        data_we, data_req, data_gnt, data_rvalid, data_err;
  logic [3:0]  data_be;

  CoreRV #(
    .DATA_SIZE    (32'h0000_1000),
    .EXTERNAL_ADDR(32'h4000_0000)
  ) core_i (
    .clk(clk), .rst(rst),
    .data_addr_o(data_addr), .data_wdata_o(data_wdata), .data_we_o(data_we),
    .data_req_o(data_req), .data_be_o(data_be),
    .data_rdata_i(data_rdata), .data_gnt_i(data_gnt), .data_rvalid_i(data_rvalid)
  );

  core2axi_lite i_obi_to_axi_lite (
    .clk_i(clk), .rst_ni(~rst),
    .data_req_i(data_req), .data_gnt_o(data_gnt),
    .data_rvalid_o(data_rvalid), .data_rdata_o(data_rdata),
    .data_addr_i(data_addr), .data_we_i(data_we), .data_be_i(data_be),
    .data_wdata_i(data_wdata), .data_err_o(data_err),
    .master(core_axi_lite_master)
  );

  // TODO: Connect data_err to a CoreRV synchronous bus-error exception once
  // the CPU exception interface is defined.
endmodule

module soc_top_axi_lite_apb
  import addr_map_pkg::*;
(
  input  logic clk,
  input  logic rst,

  input  logic [31:0] gpio_in_i,
  output logic [31:0] gpio_out_o,
  output logic [31:0] gpio_dir_o,
  output logic [31:0] gpio_in_sync_o,

  output logic       spi_flash_clk_o,
  output logic       spi_flash_csn_o,
  output logic [1:0] spi_flash_mode_o,
  output logic [3:0] spi_flash_sdo_o,
  input  logic [3:0] spi_flash_sdi_i,

  input  logic scl_pad_i,
  output logic scl_pad_o,
  output logic scl_padoen_o,
  input  logic sda_pad_i,
  output logic sda_pad_o,
  output logic sda_padoen_o,

  output logic [7:0] periph_irq_o
);

  AXI_LITE #(
    .AXI_ADDR_WIDTH(32),
    .AXI_DATA_WIDTH(32))
  core_lite_bus();

  corerv_axi_lite_top corerv_i (
    .clk(clk),
    .rst(rst),
    .core_axi_lite_master(core_lite_bus)
  );

  addr_rule_t [3:0] addr_map;
  assign addr_map[0] = GPIO_RULE;
  assign addr_map[1] = TIMER_RULE;
  assign addr_map[2] = SPI_RULE;
  assign addr_map[3] = I2C_RULE;

  logic [31:0] paddr, pwdata;
  logic [2:0]  pprot;
  logic [3:0]  pselx, pready, pslverr;
  logic [3:0][31:0] prdata;
  logic penable, pwrite;
  logic [3:0] pstrb;

  axi_lite_to_apb_intf #(
    .NoApbSlaves(4),
    .NoRules(4),
    .AddrWidth(32),
    .DataWidth(32),
    .rule_t(addr_rule_t)
  )
  i_axi_lite_to_apb (
    .clk_i(clk),
    .rst_ni(~rst),
    .slv(core_lite_bus),
    .paddr_o(paddr),
    .pprot_o(pprot),
    .pselx_o(pselx),
    .penable_o(penable),
    .pwrite_o(pwrite),
    .pwdata_o(pwdata),
    .pstrb_o(pstrb),
    .pready_i(pready),
    .prdata_i(prdata),
    .pslverr_i(pslverr),
    .addr_map_i(addr_map)
  );

  logic gpio_irq, i2c_irq;
  logic [3:0] timer_irq;
  logic [1:0] spi_events;
  assign periph_irq_o = {timer_irq, spi_events, i2c_irq, gpio_irq};

  apb_gpio i_gpio (
    .HCLK(clk),
    .HRESETn(~rst),
    .PADDR(paddr[11:0]),
    .PWDATA(pwdata),
    .PWRITE(pwrite),
    .PSEL(pselx[0]),
    .PENABLE(penable),
    .PRDATA(prdata[0]),
    .PREADY(pready[0]),
    .PSLVERR(pslverr[0]),
    .gpio_in(gpio_in_i),
    .gpio_in_sync(gpio_in_sync_o),   // now exported instead of left open
    .gpio_out(gpio_out_o),
    .gpio_dir(gpio_dir_o),
    .gpio_padcfg(),
    .interrupt(gpio_irq)
  );

  apb_timer i_timer (
    .HCLK(clk),
    .HRESETn(~rst),
    .PADDR(paddr[11:0]),
    .PWDATA(pwdata),
    .PWRITE(pwrite),
    .PSEL(pselx[1]),
    .PENABLE(penable),
    .PRDATA(prdata[1]),
    .PREADY(pready[1]),
    .PSLVERR(pslverr[1]),
    .irq_o(timer_irq)
  );

  apb_spi_master i_spi (
    .HCLK(clk),
    .HRESETn(~rst),
    .PADDR(paddr[11:0]),
    .PWDATA(pwdata),
    .PWRITE(pwrite),
    .PSEL(pselx[2]),
    .PENABLE(penable),
    .PRDATA(prdata[2]),
    .PREADY(pready[2]),
    .PSLVERR(pslverr[2]),
    .events_o(spi_events),
    .spi_clk(spi_flash_clk_o),
    .spi_csn0(spi_flash_csn_o),
    .spi_csn1(),   // unused: only one flash device on this bus
    .spi_csn2(),
    .spi_csn3(),
    .spi_mode(spi_flash_mode_o),
    .spi_sdo0(spi_flash_sdo_o[0]),
    .spi_sdo1(spi_flash_sdo_o[1]),
    .spi_sdo2(spi_flash_sdo_o[2]),
    .spi_sdo3(spi_flash_sdo_o[3]),
    .spi_sdi0(spi_flash_sdi_i[0]),
    .spi_sdi1(spi_flash_sdi_i[1]),
    .spi_sdi2(spi_flash_sdi_i[2]),
    .spi_sdi3(spi_flash_sdi_i[3])
  );

  apb_i2c i_i2c (
    .HCLK(clk),
    .HRESETn(~rst),
    .PADDR(paddr[11:0]),
    .PWDATA(pwdata),
    .PWRITE(pwrite),
    .PSEL(pselx[3]),
    .PENABLE(penable),
    .PRDATA(prdata[3]),
    .PREADY(pready[3]),
    .PSLVERR(pslverr[3]),
    .interrupt_o(i2c_irq),
    .scl_pad_i(scl_pad_i),
    .scl_pad_o(scl_pad_o),
    .scl_padoen_o(scl_padoen_o),
    .sda_pad_i(sda_pad_i),
    .sda_pad_o(sda_pad_o),
    .sda_padoen_o(sda_padoen_o)
  );

endmodule

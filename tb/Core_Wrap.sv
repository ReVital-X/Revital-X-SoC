module Core_Wrap
#(
  parameter DATA_RAM_SIZE  = 32
)
(
  input  logic clk,
  input  logic rst_
);

  localparam DATA_ADDR_WIDTH = $clog2(DATA_RAM_SIZE);
  // LSU <-> RAM signals
  logic         core_data_req;
  logic         core_data_gnt;
  logic         core_data_rvalid;
  logic [31:0]  core_data_addr;
  logic         core_data_we;
  logic [3:0]   core_data_be;
  logic [31:0]  core_data_rdata;
  logic [31:0]  core_data_wdata;

  // RAM signals
  logic                        data_mem_en;
  logic [DATA_ADDR_WIDTH-1:0]  data_mem_addr;
  logic                        data_mem_we;
  logic [3:0]                  data_mem_be;
  logic [31:0]                 data_mem_rdata;
  logic [31:0]                 data_mem_wdata;
  // ------------------------------------------------------------
  // LSU
  // ------------------------------------------------------------
  CoreRV core1 (
    .clk              ( clk                ),
    .rst              ( rst_               ),


    .data_gnt_i       ( core_data_gnt      ),
    .data_rvalid_i    ( core_data_rvalid   ),
    .data_rdata_i     ( core_data_rdata    ),

    .data_req_o       ( core_data_req      ),
    .data_addr_o      ( core_data_addr     ),
    .data_we_o        ( core_data_we       ),
    .data_be_o        ( core_data_be       ),
    .data_wdata_o     ( core_data_wdata    )
  );
  // ------------------------------------------------------------
  // SIMPLE SRAM HANDSHAKE (NO AXI, NO MUX)
  // ------------------------------------------------------------

  assign data_mem_en    = core_data_req;
  assign data_mem_addr = core_data_addr;
  assign data_mem_we    = core_data_we;
  assign data_mem_be    = core_data_be;
  assign data_mem_wdata = core_data_wdata;

  assign core_data_rdata  = data_mem_rdata;

  // ALWAYS GRANT + 1-cycle latency model
  logic req_accepted;
logic req_accepted_d;

// Grant immediately
assign core_data_gnt = core_data_req;

// Track accepted request
assign req_accepted = core_data_req & core_data_gnt;

// 1-cycle latency response
always_ff @(posedge clk) begin
  if (rst_)
    req_accepted_d <= 1'b0;
  else
    req_accepted_d <= req_accepted;
end

assign core_data_rvalid = req_accepted_d;

  // ------------------------------------------------------------
  // SRAM
  // ------------------------------------------------------------

  sp_ram
  #(
    .NUM_WORDS   ( DATA_RAM_SIZE ),
    .DATA_WIDTH ( 32 ),
	.ADDR_WIDTH(DATA_ADDR_WIDTH)
  )
  ext_mem (
    .clk         ( clk            ),
    .en_i        ( data_mem_en    ),
    .addr_i      ( data_mem_addr  ),
    .wdata_i     ( data_mem_wdata ),
    .rdata_o     ( data_mem_rdata ),
    .we_i        ( data_mem_we    ),
    .be_i        ( data_mem_be    )
  );

endmodule
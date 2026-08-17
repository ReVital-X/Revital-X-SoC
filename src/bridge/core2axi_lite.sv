// Single-outstanding-request adapter:
// CoreRV's OBI-style data port -> AXI4-Lite master port.
module core2axi_lite (
  input  logic        clk_i,
  input  logic        rst_ni,

  input  logic        data_req_i,
  output logic        data_gnt_o,
  output logic        data_rvalid_o,
  output logic [31:0] data_rdata_o,
  input  logic [31:0] data_addr_i,
  input  logic        data_we_i,
  input  logic [3:0]  data_be_i,
  input  logic [31:0] data_wdata_i,
  output logic        data_err_o,

  AXI_LITE.Master     master
);
  typedef enum logic [2:0] {IDLE, WRITE, WRITE_RESP, READ, READ_RESP} state_t;
  state_t state_q;

  logic [31:0] addr_q, wdata_q;
  logic [3:0]  strb_q;
  logic        aw_done_q, w_done_q;

  always_comb begin
    data_gnt_o    = 1'b0;
    data_rvalid_o = 1'b0;
    data_rdata_o  = master.r_data;
    data_err_o    = 1'b0;

    master.aw_addr  = addr_q;
    master.aw_prot  = '0;
    master.aw_valid = 1'b0;
    master.w_data   = wdata_q;
    master.w_strb   = strb_q;
    master.w_valid  = 1'b0;
    master.b_ready  = 1'b0;
    master.ar_addr  = addr_q;
    master.ar_prot  = '0;
    master.ar_valid = 1'b0;
    master.r_ready  = 1'b0;

    unique case (state_q)
      IDLE: begin
        // The core request is accepted only when its metadata is captured.
        data_gnt_o = data_req_i;
      end
      WRITE: begin
        // AXI-Lite AW and W are independent channels; keep either VALID high
        // until that individual handshake completes.
        master.aw_valid = ~aw_done_q;
        master.w_valid  = ~w_done_q;
      end
      WRITE_RESP: begin
        master.b_ready  = 1'b1;
        data_rvalid_o   = master.b_valid; // completion indication to CoreRV
        data_err_o      = master.b_valid && (master.b_resp != axi_pkg::RESP_OKAY);
      end
      READ: begin
        master.ar_valid = 1'b1;
      end
      READ_RESP: begin
        master.r_ready  = 1'b1;
        data_rvalid_o   = master.r_valid;
        data_err_o      = master.r_valid && (master.r_resp != axi_pkg::RESP_OKAY);
      end
      default: ;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q   <= IDLE;
      addr_q    <= '0;
      wdata_q   <= '0;
      strb_q    <= '0;
      aw_done_q <= 1'b0;
      w_done_q  <= 1'b0;
    end else begin
      unique case (state_q)
        IDLE: if (data_req_i) begin
          addr_q    <= data_addr_i;
          wdata_q   <= data_wdata_i;
          strb_q    <= data_be_i;
          aw_done_q <= 1'b0;
          w_done_q  <= 1'b0;
          state_q   <= data_we_i ? WRITE : READ;
        end
        WRITE: begin
          if (master.aw_valid && master.aw_ready) aw_done_q <= 1'b1;
          if (master.w_valid  && master.w_ready ) w_done_q  <= 1'b1;
          if ((aw_done_q || master.aw_ready) && (w_done_q || master.w_ready))
            state_q <= WRITE_RESP;
        end
        WRITE_RESP: if (master.b_valid) state_q <= IDLE;
        READ:       if (master.ar_ready) state_q <= READ_RESP;
        READ_RESP:  if (master.r_valid) state_q <= IDLE;
        default: state_q <= IDLE;
      endcase
    end
  end
endmodule

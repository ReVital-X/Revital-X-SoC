`timescale 1ns / 1ps
module LSU_RVX (
  input  logic         clk,
  input  logic         rst,

  // data interface
  output logic         data_req_o,
  input  logic         data_gnt_i,
  input  logic         data_rvalid_i,

  output logic [31:0]  data_addr_o,
  output logic         data_we_o,
  output logic [3:0]   data_be_o,
  output logic [31:0]  data_wdata_o,
  input  logic [31:0]  data_rdata_i,

  // ID/EX inputs
  input  logic         lsu_we_i,
  input  logic [1:0]   lsu_type_i,
  input  logic [31:0]  lsu_wdata_i,
  input  logic         lsu_sign_ext_i,
  input  logic         lsu_req_i,
  input  logic [31:0]  adder_result_ex_i,

  // outputs to WB / pipeline control
  output logic [31:0]  lsu_rdata_o,
  output logic         lsu_rdata_valid_o,
  output logic         busy_o
);

  logic [31:0] data_addr;
  logic [31:0] data_addr_w_aligned;

  logic        addr_update;
  logic        ctrl_update;
  logic        rdata_update;

  logic [31:8] rdata_q;
  logic [1:0]  rdata_offset_q;
  logic [1:0]  data_type_q;
  logic        data_sign_ext_q;
  logic        data_we_q;

  logic [1:0]  data_offset;
  logic [3:0]  data_be;
  logic [31:0] data_wdata;

  logic [31:0] data_rdata_ext;
  logic [31:0] rdata_w_ext;
  logic [31:0] rdata_h_ext;
  logic [31:0] rdata_b_ext;

  logic        split_misaligned_access;
  logic        handle_misaligned_q, handle_misaligned_d;

  typedef enum logic [2:0] {
    IDLE,
    WAIT_GNT_MIS,
    WAIT_RVALID_MIS,
    WAIT_GNT,
    WAIT_RVALID_MIS_GNTS_DONE
  } ls_fsm_e;

  ls_fsm_e ls_fsm_cs, ls_fsm_ns;

  assign data_addr   = adder_result_ex_i;
  assign data_offset = data_addr[1:0];

  //-----------------------------------
  // Byte Enable generation
  //-----------------------------------

  always_comb begin
    unique case (lsu_type_i)
      2'b00: begin
        if (!handle_misaligned_q) begin
          unique case (data_offset)
            2'b00: data_be = 4'b1111;
            2'b01: data_be = 4'b1110;
            2'b10: data_be = 4'b1100;
            2'b11: data_be = 4'b1000;
          endcase
        end else begin
          unique case (data_offset)
            2'b00: data_be = 4'b0000;
            2'b01: data_be = 4'b0001;
            2'b10: data_be = 4'b0011;
            2'b11: data_be = 4'b0111;
          endcase
        end
      end

      2'b01: begin
        if (!handle_misaligned_q) begin
          unique case (data_offset)
            2'b00: data_be = 4'b0011;
            2'b01: data_be = 4'b0110;
            2'b10: data_be = 4'b1100;
            2'b11: data_be = 4'b1000;
          endcase
        end else begin
          data_be = 4'b0001;
        end
      end

      default: begin
        unique case (data_offset)
          2'b00: data_be = 4'b0001;
          2'b01: data_be = 4'b0010;
          2'b10: data_be = 4'b0100;
          2'b11: data_be = 4'b1000;
        endcase
      end
    endcase
  end

  //-----------------------------------
  // Write Data Alignment
  //-----------------------------------

  always_comb begin
    unique case (data_offset)
      2'b00: data_wdata = lsu_wdata_i;
      2'b01: data_wdata = {lsu_wdata_i[23:0], lsu_wdata_i[31:24]};
      2'b10: data_wdata = {lsu_wdata_i[15:0], lsu_wdata_i[31:16]};
      2'b11: data_wdata = {lsu_wdata_i[7:0],  lsu_wdata_i[31:8]};
      default: data_wdata = lsu_wdata_i;
    endcase
  end

  //-----------------------------------
  // RDATA capture
  //-----------------------------------

  always_ff @(posedge clk) begin
    if (rst)
      rdata_q <= '0;
    else if (rdata_update)
      rdata_q <= data_rdata_i[31:8];
  end

  //-----------------------------------
  // control registers
  //-----------------------------------

  always_ff @(posedge clk) begin
    if (rst) begin
      rdata_offset_q  <= '0;
      data_type_q     <= '0;
      data_sign_ext_q <= '0;
      data_we_q       <= '0;
    end else if (ctrl_update) begin
      rdata_offset_q  <= data_offset;
      data_type_q     <= lsu_type_i;
      data_sign_ext_q <= lsu_sign_ext_i;
      data_we_q       <= lsu_we_i;
    end
  end

  //-----------------------------------
  // load alignment
  //-----------------------------------

  always_comb begin
    unique case (rdata_offset_q)
      2'b00: rdata_w_ext = data_rdata_i;
      2'b01: rdata_w_ext = {data_rdata_i[7:0],  rdata_q};
      2'b10: rdata_w_ext = {data_rdata_i[15:0], rdata_q[31:16]};
      2'b11: rdata_w_ext = {data_rdata_i[23:0], rdata_q[31:24]};
      default: rdata_w_ext = data_rdata_i;
    endcase
  end

  always_comb begin
    case (data_type_q)
      2'b00: data_rdata_ext = rdata_w_ext;
      2'b01: begin
        case (rdata_offset_q)
          2'b00: data_rdata_ext = data_sign_ext_q ? {{16{data_rdata_i[15]}},data_rdata_i[15:0]} : {16'b0,data_rdata_i[15:0]};
          2'b01: data_rdata_ext = data_sign_ext_q ? {{16{data_rdata_i[23]}},data_rdata_i[23:8]} : {16'b0,data_rdata_i[23:8]};
          2'b10: data_rdata_ext = data_sign_ext_q ? {{16{data_rdata_i[31]}},data_rdata_i[31:16]} : {16'b0,data_rdata_i[31:16]};
          default:
            data_rdata_ext = data_sign_ext_q ?
              {{16{data_rdata_i[7]}}, data_rdata_i[7:0], rdata_q[31:24]} :
              {16'b0, data_rdata_i[7:0], rdata_q[31:24]};
        endcase
      end

      default: begin
        case (rdata_offset_q)
          2'b00: data_rdata_ext = data_sign_ext_q ? {{24{data_rdata_i[7]}},data_rdata_i[7:0]} : {24'b0,data_rdata_i[7:0]};
          2'b01: data_rdata_ext = data_sign_ext_q ? {{24{data_rdata_i[15]}},data_rdata_i[15:8]} : {24'b0,data_rdata_i[15:8]};
          2'b10: data_rdata_ext = data_sign_ext_q ? {{24{data_rdata_i[23]}},data_rdata_i[23:16]} : {24'b0,data_rdata_i[23:16]};
          2'b11: data_rdata_ext = data_sign_ext_q ? {{24{data_rdata_i[31]}},data_rdata_i[31:24]} : {24'b0,data_rdata_i[31:24]};
        endcase
      end
    endcase
  end

  //-----------------------------------
  // misaligned detection
  //-----------------------------------

  assign split_misaligned_access =
      ((lsu_type_i == 2'b00) && (data_offset != 2'b00)) ||
      ((lsu_type_i == 2'b01) && (data_offset == 2'b11));

  //-----------------------------------
  // FSM
  //-----------------------------------

  always_comb begin
    ls_fsm_ns = ls_fsm_cs;

    data_req_o = 1'b0;
    handle_misaligned_d = handle_misaligned_q;

    addr_update  = 1'b0;
    ctrl_update  = 1'b0;
    rdata_update = 1'b0;

    case (ls_fsm_cs)

      IDLE: begin
        if (lsu_req_i) begin
          data_req_o = 1'b1;

          if (data_gnt_i) begin
            ctrl_update = 1'b1;
            addr_update = 1'b1;
            handle_misaligned_d = split_misaligned_access;
            ls_fsm_ns = split_misaligned_access ? WAIT_RVALID_MIS : IDLE;
          end else begin
            ls_fsm_ns = split_misaligned_access ? WAIT_GNT_MIS : WAIT_GNT;
          end
        end
      end

      WAIT_GNT_MIS: begin
        data_req_o = 1'b1;
        if (data_gnt_i) begin
          ctrl_update = 1'b1;
          addr_update = 1'b1;
          handle_misaligned_d = 1'b1;
          ls_fsm_ns = WAIT_RVALID_MIS;
        end
      end

      WAIT_RVALID_MIS: begin
        data_req_o = 1'b1;

        if (data_rvalid_i) begin
          rdata_update = ~data_we_q;
          ls_fsm_ns = data_gnt_i ? IDLE : WAIT_GNT;
          handle_misaligned_d = ~data_gnt_i;
        end else if (data_gnt_i) begin
          ls_fsm_ns = WAIT_RVALID_MIS_GNTS_DONE;
          handle_misaligned_d = 1'b0;
        end
      end

      WAIT_GNT: begin
        data_req_o = 1'b1;
        if (data_gnt_i) begin
          ctrl_update = 1'b1;
          handle_misaligned_d = 1'b0;
          ls_fsm_ns = IDLE;
        end
      end

      WAIT_RVALID_MIS_GNTS_DONE: begin
        if (data_rvalid_i) begin
          rdata_update = ~data_we_q;
          ls_fsm_ns = IDLE;
        end
      end

      default: ls_fsm_ns = IDLE;
    endcase
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      ls_fsm_cs <= IDLE;
      handle_misaligned_q <= 1'b0;
    end else begin
      ls_fsm_cs <= ls_fsm_ns;
      handle_misaligned_q <= handle_misaligned_d;
    end
  end

  //-----------------------------------
  // outputs
  //-----------------------------------

  assign lsu_rdata_o       = data_rdata_ext;
  assign lsu_rdata_valid_o = (ls_fsm_cs == IDLE) & data_rvalid_i & ~data_we_q;

  assign data_addr_w_aligned = {data_addr[31:2], 2'b00};

  assign data_addr_o =
      handle_misaligned_q ?
      (data_addr_w_aligned + 32'd4) :
      data_addr_w_aligned;

  assign data_we_o    = data_we_q;
  assign data_be_o    = data_be;
  assign data_wdata_o = data_wdata;

  assign busy_o = lsu_req_i | (ls_fsm_cs != IDLE);

endmodule
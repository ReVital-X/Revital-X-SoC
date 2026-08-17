// ============================================================
// compat_wrappers.sv
// Translator modules: old common_cells names -> your cc_-prefixed clone
// Add this as ONE file/tab. Do not edit the borrowed axi/common_cells files.
// All five confirmed against actual source in your repo.
// ============================================================

module fifo_v3 #(
    parameter bit          FALL_THROUGH = 1'b0,
    parameter int unsigned DEPTH        = 8,
    parameter type         dtype        = logic
)(
    input  logic clk_i, rst_ni,
    input  logic flush_i, testmode_i,
    output logic full_o, empty_o,
    output logic [cc_pkg::cnt_width(DEPTH)-1:0] usage_o,
    input  dtype data_i,
    input  logic push_i,
    output dtype data_o,
    input  logic pop_i
);
    cc_fifo #(
        .FallThrough ( FALL_THROUGH ),
        .Depth       ( DEPTH        ),
        .data_t      ( dtype        )
    ) i_cc_fifo (
        .clk_i, .rst_ni,
        .clr_i   ( 1'b0    ),
        .flush_i ( flush_i ),
        .full_o, .empty_o, .usage_o,
        .data_i, .push_i, .data_o, .pop_i
    );
endmodule


module addr_decode #(
    parameter int unsigned NoIndices = 0,
    parameter int unsigned NoRules   = 1,
    parameter type         addr_t    = logic,
    parameter int unsigned IdxWidth  = cc_pkg::idx_width(NoIndices),
    parameter type         idx_t     = logic [IdxWidth-1:0],
    parameter type         rule_t    = logic
)(
    input  addr_t               addr_i,
    input  rule_t [NoRules-1:0] addr_map_i,
    output idx_t                idx_o,
    output logic                dec_valid_o,
    output logic                dec_error_o,
    input  logic                en_default_idx_i,
    input  idx_t                default_idx_i
);
    cc_addr_decode #(
        .NoIndices ( NoIndices ),
        .NoRules   ( NoRules   ),
        .addr_t    ( addr_t    ),
        .idx_t     ( idx_t     ),
        .rule_t    ( rule_t    )
    ) i_cc_addr_decode (
        .addr_i, .addr_map_i, .idx_o,
        .dec_valid_o, .dec_error_o,
        .en_default_idx_i, .default_idx_i
    );
endmodule


module spill_register #(
    parameter type T      = logic,
    parameter bit  Bypass = 1'b0
)(
    input  logic clk_i, rst_ni,
    input  logic valid_i,
    output logic ready_o,
    input  T     data_i,
    output logic valid_o,
    input  logic ready_i,
    output T     data_o
);
    cc_spill_register #(
        .data_t ( T      ),
        .Bypass ( Bypass )
    ) i_cc_spill_register (
        .clk_i, .rst_ni,
        .clr_i  ( 1'b0 ),
        .valid_i, .ready_o,
        .data_i, .valid_o, .ready_i, .data_o
    );
endmodule


module fall_through_register #(
    parameter type T = logic
)(
    input  logic clk_i, rst_ni,
    input  logic clr_i, testmode_i,
    input  logic valid_i,
    output logic ready_o,
    input  T     data_i,
    output logic valid_o,
    input  logic ready_i,
    output T     data_o
);
    cc_fall_through_register #(
        .data_t ( T )
    ) i_cc_fall_through_register (
        .clk_i, .rst_ni, .clr_i,
        .valid_i, .ready_o,
        .data_i, .valid_o, .ready_i, .data_o
    );
endmodule


module rr_arb_tree #(
    parameter int unsigned NumIn     = 64,
    parameter type         DataType  = logic,
    parameter bit          ExtPrio   = 1'b0,
    parameter bit          AxiVldRdy = 1'b0,
    parameter bit          LockIn    = 1'b0,
    localparam int unsigned IdxWidth = (NumIn > 1) ? $clog2(NumIn) : 1,
    localparam type         idx_t    = logic [IdxWidth-1:0]
)(
    input  logic                clk_i,
    input  logic                rst_ni,
    input  logic                flush_i,
    input  idx_t                rr_i,
    input  logic    [NumIn-1:0] req_i,
    output logic    [NumIn-1:0] gnt_o,
    input  DataType [NumIn-1:0] data_i,
    output logic                req_o,
    input  logic                gnt_i,
    output DataType              data_o,
    output idx_t                idx_o
);
    cc_rr_arb_tree #(
        .NumIn     ( NumIn     ),
        .data_t    ( DataType  ),
        .ExtPrio   ( ExtPrio   ),
        .AxiVldRdy ( AxiVldRdy ),
        .LockIn    ( LockIn    )
    ) i_cc_rr_arb_tree (
        .clk_i, .rst_ni,
        .clr_i ( flush_i ),
        .rr_i, .req_i, .gnt_o, .data_i,
        .req_o, .gnt_i, .data_o, .idx_o
    );
  
endmodule

// in compat_wrapper.sv
module onehot_to_bin #(
    parameter int unsigned ONEHOT_WIDTH = 32
) (
    input  logic [ONEHOT_WIDTH-1:0]         onehot,
    output logic [$clog2(ONEHOT_WIDTH)-1:0] bin
);

  cc_onehot_to_bin #(
      .OnehotWidth ( ONEHOT_WIDTH )
  ) i_cc_onehot_to_bin (
      .onehot_i ( onehot ),
      .bin_o    ( bin )
  );

endmodule

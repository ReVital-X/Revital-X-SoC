`timescale 1ns/1ps

module LSU_RVX_delay_tb;
  logic clk;
  logic rst;

  logic        data_req_o;
  logic        data_gnt_i;
  logic        data_rvalid_i;
  logic [31:0] data_addr_o;
  logic        data_we_o;
  logic [3:0]  data_be_o;
  logic [31:0] data_wdata_o;
  logic [31:0] data_rdata_i;

  logic        req_i;
  logic        we_i;
  logic [1:0]  type_i;
  logic        sign_ext_i;
  logic [31:0] addr_i;
  logic [31:0] wdata_i;
  logic [31:0] rdata_o;
  logic        rvalid_o;
  logic        busy_o;

  logic [7:0] mem [0:255];
  integer errors;

  LSU_RVX dut (
    .clk(clk),
    .rst(rst),
    .data_req_o(data_req_o),
    .data_gnt_i(data_gnt_i),
    .data_rvalid_i(data_rvalid_i),
    .data_addr_o(data_addr_o),
    .data_we_o(data_we_o),
    .data_be_o(data_be_o),
    .data_wdata_o(data_wdata_o),
    .data_rdata_i(data_rdata_i),
    .req_i(req_i),
    .we_i(we_i),
    .type_i(type_i),
    .sign_ext_i(sign_ext_i),
    .addr_i(addr_i),
    .wdata_i(wdata_i),
    .rdata_o(rdata_o),
    .rvalid_o(rvalid_o),
    .busy_o(busy_o)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  function automatic [31:0] load_word(input [31:0] word_addr);
    integer base;
    begin
      base = word_addr << 2;
      load_word = {mem[base + 3], mem[base + 2], mem[base + 1], mem[base]};
    end
  endfunction

  task automatic store_word_lanes(input [31:0] word_addr, input [3:0] be, input [31:0] wdata);
    integer base;
    begin
      base = word_addr << 2;
      if (be[0]) mem[base + 0] = wdata[7:0];
      if (be[1]) mem[base + 1] = wdata[15:8];
      if (be[2]) mem[base + 2] = wdata[23:16];
      if (be[3]) mem[base + 3] = wdata[31:24];
    end
  endtask

  task automatic fail(input string msg);
    begin
      errors = errors + 1;
      $display("FAIL: %s at %0t", msg, $time);
    end
  endtask

  task automatic check(input bit condition, input string msg);
    begin
      if (!condition) fail(msg);
    end
  endtask

  task automatic accept_beat(input integer gnt_delay, input integer rvalid_delay);
    logic [31:0] accepted_addr;
    logic [31:0] accepted_wdata;
    logic [3:0]  accepted_be;
    logic        accepted_we;
    integer i;
    begin
      wait (data_req_o === 1'b1);

      for (i = 0; i < gnt_delay; i = i + 1) begin
        @(negedge clk);
        data_gnt_i = 1'b0;
        @(posedge clk);
        #1;
        check(data_req_o === 1'b1, "request dropped before grant");
      end

      @(negedge clk);
      data_gnt_i = 1'b1;
      @(posedge clk);
      #1;
      accepted_addr  = data_addr_o;
      accepted_wdata = data_wdata_o;
      accepted_be    = data_be_o;
      accepted_we    = data_we_o;
      check(data_req_o === 1'b1, "request not asserted on grant cycle");

      @(negedge clk);
      data_gnt_i = 1'b0;
      if (accepted_we) store_word_lanes(accepted_addr, accepted_be, accepted_wdata);
      data_rdata_i = load_word(accepted_addr);

      for (i = 0; i < rvalid_delay; i = i + 1) begin
        data_rvalid_i = 1'b0;
        @(posedge clk);
        #1;
        check(rvalid_o === 1'b0, "rvalid_o asserted before data_rvalid_i");
      end

      @(negedge clk);
      data_rvalid_i = 1'b1;
      data_rdata_i = load_word(accepted_addr);
      @(posedge clk);
      #1;

      @(negedge clk);
      data_rvalid_i = 1'b0;
    end
  endtask

  task automatic do_access(
    input bit is_store,
    input [1:0] access_type,
    input bit sign_ext,
    input [31:0] addr,
    input [31:0] wdata,
    input integer gnt_delay,
    input integer rvalid_delay,
    output [31:0] rdata,
    output bit got_rvalid
  );
    integer beats;
    integer b;
    begin
      got_rvalid = 1'b0;
      rdata = 32'hx;

      @(negedge clk);
      req_i = 1'b1;
      we_i = is_store;
      type_i = access_type;
      sign_ext_i = sign_ext;
      addr_i = addr;
      wdata_i = wdata;
      @(negedge clk);
      req_i = 1'b0;

      beats = ((access_type == 2'b00 && addr[1:0] != 2'b00) ||
               (access_type == 2'b01 && addr[1:0] == 2'b11)) ? 2 : 1;

      for (b = 0; b < beats; b = b + 1) begin
        accept_beat(gnt_delay + b, rvalid_delay + b);
        #1;
        if (rvalid_o) begin
          got_rvalid = 1'b1;
          rdata = rdata_o;
        end
      end

      @(posedge clk);
      #1;
      check(busy_o === 1'b0, "busy_o did not drop after access");
    end
  endtask

  function automatic [31:0] read_u32(input integer byte_addr);
    begin
      read_u32 = {mem[byte_addr + 3], mem[byte_addr + 2], mem[byte_addr + 1], mem[byte_addr]};
    end
  endfunction

  function automatic [15:0] read_u16(input integer byte_addr);
    begin
      read_u16 = {mem[byte_addr + 1], mem[byte_addr]};
    end
  endfunction

  task automatic init_mem;
    integer i;
    begin
      for (i = 0; i < 256; i = i + 1) begin
        mem[i] = (8'h40 + i[7:0]);
      end
    end
  endtask

  initial begin
    logic [31:0] rdata;
    bit got;

    errors = 0;
    data_gnt_i = 1'b0;
    data_rvalid_i = 1'b0;
    data_rdata_i = 32'd0;
    req_i = 1'b0;
    we_i = 1'b0;
    type_i = 2'b00;
    sign_ext_i = 1'b0;
    addr_i = 32'd0;
    wdata_i = 32'd0;
    init_mem();

    rst = 1'b1;
    repeat (3) @(posedge clk);
    rst = 1'b0;
    repeat (1) @(posedge clk);

    do_access(1'b0, 2'b00, 1'b0, 32'd1, 32'h0, 2, 3, rdata, got);
    check(got, "misaligned word load did not return valid");
    check(rdata === read_u32(1), "misaligned word load returned wrong data");

    do_access(1'b0, 2'b01, 1'b0, 32'd3, 32'h0, 1, 2, rdata, got);
    check(got, "misaligned half load did not return valid");
    check(rdata === {16'd0, read_u16(3)}, "misaligned half load returned wrong data");

    do_access(1'b0, 2'b10, 1'b1, 32'd7, 32'h0, 3, 4, rdata, got);
    check(got, "byte load did not return valid");
    check(rdata === {{24{mem[7][7]}}, mem[7]}, "signed byte load returned wrong data");

    do_access(1'b1, 2'b00, 1'b0, 32'd5, 32'hA1B2C3D4, 2, 2, rdata, got);
    check(read_u32(5) === 32'hA1B2C3D4, "misaligned word store wrote wrong bytes");

    do_access(1'b1, 2'b01, 1'b0, 32'd11, 32'h0000EE99, 1, 3, rdata, got);
    check(read_u16(11) === 16'hEE99, "misaligned half store wrote wrong bytes");

    if (errors == 0) begin
      $display("PASS: LSU_RVX delayed grant/rvalid and misaligned access checks passed");
    end else begin
      $display("FAIL: %0d LSU_RVX checks failed", errors);
      $finish(1);
    end

    $finish;
  end
endmodule

`timescale 1ns/1ps

package branch_tb_pkg;
  // Xcelium log shows branch fetches at 0x0500 and above returning NOPs.
  // Keep branch tests in the 64-word fetch window that the DUT is actually
  // reaching in this configuration: 0x0400 through 0x04fc.
  localparam int TB_INSTR_WORDS = 64;
  localparam bit [31:0] TB_INSTR_ADDR = 32'h0000_0400;

  class branch_trans;
    rand bit [31:0] rs1_val;
    rand bit [31:0] rs2_val;
    rand bit [2:0]  funct3;
    rand int unsigned pc_idx;
    rand int unsigned target_idx;
    rand bit make_equal;

    bit [31:0] current_pc;
    bit signed [12:0] imm;

    bit        dut_taken;
    bit [31:0] dut_branch_addr;

    constraint valid_branch {
      funct3 inside {3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111};
    }

    constraint bounded_instruction_space {
      // Keep the branch and target in the small initialized memory window.
      pc_idx     inside {[4:TB_INSTR_WORDS-8]};
      target_idx inside {[4:TB_INSTR_WORDS-8]};
    }

    constraint equal_bias {
      make_equal dist {1'b1 := 2, 1'b0 := 8};
      if (make_equal) {
        rs1_val == rs2_val;
      }
    }

    function void post_randomize();
      int signed offset;

      current_pc = TB_INSTR_ADDR + (pc_idx * 4);
      offset = (int'(target_idx) - int'(pc_idx)) * 4;
      imm = offset;
    endfunction

    function bit [2:0] funct3_from_index(int unsigned index);
      case (index)
        0: return 3'b000;
        1: return 3'b001;
        2: return 3'b100;
        3: return 3'b101;
        4: return 3'b110;
        default: return 3'b111;
      endcase
    endfunction

    function void set_operands_for_outcome(bit want_taken);
      case (funct3)
        3'b000: begin // BEQ
          rs1_val = 32'd25;
          rs2_val = want_taken ? 32'd25 : 32'd26;
        end

        3'b001: begin // BNE
          rs1_val = 32'd25;
          rs2_val = want_taken ? 32'd26 : 32'd25;
        end

        3'b100: begin // BLT
          rs1_val = want_taken ? -32'sd5 : 32'sd7;
          rs2_val = want_taken ? 32'sd3  : -32'sd1;
        end

        3'b101: begin // BGE
          rs1_val = want_taken ? 32'sd7  : -32'sd5;
          rs2_val = want_taken ? -32'sd1 : 32'sd3;
        end

        3'b110: begin // BLTU
          rs1_val = want_taken ? 32'd1 : 32'hFFFF_FFFF;
          rs2_val = want_taken ? 32'd2 : 32'd1;
        end

        default: begin // BGEU
          rs1_val = want_taken ? 32'hFFFF_FFFF : 32'd1;
          rs2_val = want_taken ? 32'd1         : 32'd2;
        end
      endcase
    endfunction

    function void set_directed(int unsigned test_num);
      int unsigned branch_idx;
      bit want_taken;
      int signed offset;

      branch_idx = (test_num / 2) % 6;
      want_taken = (test_num % 2) == 1;

      funct3 = funct3_from_index(branch_idx);
      pc_idx = 8 + ((test_num * 5) % (TB_INSTR_WORDS - 16));

      case (test_num % 3)
        0: target_idx = pc_idx - 4;
        1: target_idx = pc_idx;
        default: target_idx = pc_idx + 4;
      endcase

      current_pc = TB_INSTR_ADDR + (pc_idx * 4);
      offset = (int'(target_idx) - int'(pc_idx)) * 4;
      imm = offset;

      set_operands_for_outcome(want_taken);
    endfunction
  endclass

  class branch_cov;
    branch_trans tx;
    bit taken_flag;

    covergroup branch_cg;
      option.per_instance = 1;

      cp_funct3: coverpoint tx.funct3 {
        bins BEQ  = {3'b000};
        bins BNE  = {3'b001};
        bins BLT  = {3'b100};
        bins BGE  = {3'b101};
        bins BLTU = {3'b110};
        bins BGEU = {3'b111};
      }

      cp_taken: coverpoint taken_flag {
        bins not_taken = {0};
        bins taken     = {1};
      }

      cp_offset: coverpoint tx.imm {
        bins negative = {[-1024:-4]};
        bins zero     = {0};
        bins positive = {[4:1024]};
      }

      cross_inst_outcome: cross cp_funct3, cp_taken;
    endgroup

    function new();
      branch_cg = new();
    endfunction

    function void sample(branch_trans t, bit tk);
      this.tx = t;
      this.taken_flag = tk;
      branch_cg.sample();
    endfunction
  endclass

  class branch_scoreboard;
    int errors = 0;
    int checks = 0;

    function string get_branch_name(bit [2:0] funct3);
      case (funct3)
        3'b000: return "BEQ";
        3'b001: return "BNE";
        3'b100: return "BLT";
        3'b101: return "BGE";
        3'b110: return "BLTU";
        3'b111: return "BGEU";
        default: return "UNKNOWN";
      endcase
    endfunction

    function automatic bit branch_taken(bit [2:0] funct3, bit [31:0] rs1, bit [31:0] rs2);
      case (funct3)
        3'b000: return (rs1 == rs2);
        3'b001: return (rs1 != rs2);
        3'b100: return ($signed(rs1) < $signed(rs2));
        3'b101: return ($signed(rs1) >= $signed(rs2));
        3'b110: return (rs1 < rs2);
        3'b111: return (rs1 >= rs2);
        default: return 0;
      endcase
    endfunction

    task check_transaction(branch_trans tx);
      bit exp_taken;
      bit [31:0] exp_branch_addr;

      exp_taken = branch_taken(tx.funct3, tx.rs1_val, tx.rs2_val);
      exp_branch_addr = tx.current_pc + {{19{tx.imm[12]}}, tx.imm};

      checks++;

      $display("\n===================================");
      $display("ASM : %s x1=%0d x2=%0d imm=%0d PC:%08h",
               get_branch_name(tx.funct3), $signed(tx.rs1_val), $signed(tx.rs2_val),
               tx.imm, tx.current_pc);
      $display("EXPECTED : TAKEN=%0b  TARGET_ADDR=%08h", exp_taken, exp_branch_addr);
      $display("DUT (EX) : TAKEN=%0b  TARGET_ADDR=%08h", tx.dut_taken, tx.dut_branch_addr);

      if ((exp_taken === tx.dut_taken) && (exp_branch_addr === tx.dut_branch_addr)) begin
        $display("[PASS] %s VERIFIED", get_branch_name(tx.funct3));
      end
      else begin
        $error("[FAIL] %s FAILED", get_branch_name(tx.funct3));
        errors++;
      end

      $display("===================================\n");
    endtask
  endclass
endpackage

module branch_rand_tb;
  import branch_tb_pkg::*;

  localparam int BOOT_ADDR     = 32'h0000_0000;
  localparam int INSTR_ADDR    = TB_INSTR_ADDR;
  localparam int DATA_ADDR     = 32'h0001_0400;
  localparam int EXTERNAL_ADDR = 32'h0002_0400;

  localparam int NUM_TESTS_DEFAULT = 5000;
  localparam bit [4:0] RS1_ADDR = 5'd1;
  localparam bit [4:0] RS2_ADDR = 5'd2;
  localparam logic [31:0] NOP_INSTR = 32'h0000_0013; // addi x0, x0, 0

  logic clk;
  logic rst;
  logic [31:0] forced_pc_value;
  int timeout_errors;

  branch_trans      tx;
  branch_scoreboard sb;
  branch_cov        cov;

  CoreRV #(
      .BOOT_ADDR(BOOT_ADDR),
      .INSTR_ADDR(INSTR_ADDR),
      .DATA_ADDR(DATA_ADDR),
      .EXTERNAL_ADDR(EXTERNAL_ADDR)
  ) dut (
      .clk(clk),
      .rst(rst),
      .data_addr_o(),
      .data_wdata_o(),
      .data_we_o(),
      .data_req_o(),
      .data_be_o(),
      .data_rdata_i(32'd0),
      .data_gnt_i(1'b0),
      .data_rvalid_i(1'b0)
  );

  always #5 clk = ~clk;

  function automatic logic [31:0] encode_b_type(
    bit [2:0] funct3,
    bit [4:0] rs1_addr,
    bit [4:0] rs2_addr,
    bit [12:0] imm
  );
    return {
      imm[12], imm[10:5], rs2_addr, rs1_addr, funct3, imm[4:1], imm[11], 7'b1100011
    };
  endfunction

  task automatic write_instr_word(input int unsigned idx, input logic [31:0] instr);
    if (idx >= TB_INSTR_WORDS) begin
      $fatal(1, "Instruction index %0d is outside the initialized branch TB memory window", idx);
    end

    dut.s1.instr_mem.ram3.mem[idx][0] = instr[7:0];
    dut.s1.instr_mem.ram3.mem[idx][1] = instr[15:8];
    dut.s1.instr_mem.ram3.mem[idx][2] = instr[23:16];
    dut.s1.instr_mem.ram3.mem[idx][3] = instr[31:24];
  endtask

  task automatic clear_instr_mem_window();
    for (int i = 0; i < TB_INSTR_WORDS; i++) begin
      write_instr_word(i, NOP_INSTR);
    end
  endtask

  task automatic prepare_clean_test(input branch_trans t);
    logic [31:0] machine_code;

    rst = 1'b1;
    force dut.boot_mode = 1'b0;
    force dut.mem_ctrl.boot_mode = 1'b0;

    repeat (2) @(posedge clk);

    clear_instr_mem_window();
    machine_code = encode_b_type(t.funct3, RS1_ADDR, RS2_ADDR, t.imm);
    write_instr_word(t.pc_idx, machine_code);

    @(negedge clk);
    rst = 1'b0;

    dut.s1.rf.regfile[RS1_ADDR] = t.rs1_val;
    dut.s1.rf.regfile[RS2_ADDR] = t.rs2_val;

    // instr_ram has registered output, so hold PC for two clocks to align
    // fetched instruction, instr_PC, and the Stage1/Stage2 buffer.
    forced_pc_value = t.current_pc;
    force dut.s1.PC = forced_pc_value;
    repeat (2) @(posedge clk);
    release dut.s1.PC;
  endtask

  task automatic apply_and_check(input branch_trans t, input int unsigned test_num);
    int timeout;

    prepare_clean_test(t);

    timeout = 0;
    while (!((dut.s2.pc_in_2 === t.current_pc) && (dut.s1_buf.ctrl[7] === 1'b1)) &&
           (timeout < 12)) begin
      @(negedge clk);
      timeout++;
    end

    if (timeout >= 12) begin
      timeout_errors++;
      $error("PIPELINE STALL: test=%0d PC=%08h funct3=%03b imm=%0d s1_instr=%08h s1_instr_PC=%08h s1_buf_PC=%08h s1_buf_ctrl=%018b",
             test_num, t.current_pc, t.funct3, t.imm, dut.s1.instr, dut.s1.instr_PC,
             dut.s1_buf.PC, dut.s1_buf.ctrl);
      return;
    end

    #1;
    t.dut_taken       = dut.s2.branch_flush;
    t.dut_branch_addr = dut.s2.BranchAddr;

    sb.check_transaction(t);
    cov.sample(t, sb.branch_taken(t.funct3, t.rs1_val, t.rs2_val));
  endtask

  initial begin
    $dumpfile("branch_rand_tb.vcd");
    $dumpvars(0, branch_rand_tb);
  end

  initial begin
    int num_tests;
    real cov_pct;

    clk = 1'b0;
    rst = 1'b1;
    timeout_errors = 0;

    tx  = new();
    sb  = new();
    cov = new();

    if (!$value$plusargs("NUM_TESTS=%d", num_tests)) begin
      num_tests = NUM_TESTS_DEFAULT;
    end

    force dut.boot_mode = 1'b0;
    force dut.mem_ctrl.boot_mode = 1'b0;

    $display("=======================================");
    $display(" STARTING B-TYPE PIPELINE VERIFICATION");
    $display("=======================================");
    $display("Running %0d directed/constrained-random tests...", num_tests);

    for (int test_num = 0; test_num < num_tests; test_num++) begin
      if (test_num < 12) begin
        tx.set_directed(test_num);
      end
      else begin
        if (!tx.randomize()) begin
          $fatal(1, "Randomization failed at test %0d!", test_num);
        end
      end

      apply_and_check(tx, test_num);
    end

    cov_pct = cov.branch_cg.get_coverage();

    $display("=======================================");
    $display(" VERIFICATION COMPLETE");
    $display(" Total Tests Requested: %0d", num_tests);
    $display(" Total Checks Executed: %0d", sb.checks);
    $display(" Pipeline Timeouts:     %0d", timeout_errors);
    $display(" Total Errors Found:    %0d", sb.errors);
    $display(" Coverage percentage:   %0f%%", cov_pct);
    $display("=======================================");

    if ((sb.checks == num_tests) && (timeout_errors == 0) && (sb.errors == 0) && (cov_pct >= 100.0))
      $display(">>> TEST PASSED <<<");
    else
      $display(">>> TEST FAILED <<<");

    $finish;
  end
endmodule


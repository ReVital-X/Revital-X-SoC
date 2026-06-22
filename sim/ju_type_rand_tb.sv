`timescale 1ns/1ps

// =========================================================
// TRANSACTION & ENUMS
// =========================================================

typedef enum logic [6:0] {
    OP_LUI   = 7'b0110111,
    OP_AUIPC = 7'b0010111,
    OP_JAL   = 7'b1101111,
    OP_JALR  = 7'b1100111
} opcode_e;

class ju_trans;
  rand opcode_e op;
  rand bit [4:0]  rd;
  rand bit [4:0]  rs1;
  rand bit [31:0] rs1_val;
  rand bit [31:0] current_pc;

  // Immediates
  rand bit [19:0]        u_imm; // LUI, AUIPC (Upper 20 bits)
  rand bit signed [20:0] j_imm; // JAL (20-bit signed, scaled by 2)
  rand bit signed [11:0] i_imm; // JALR (12-bit signed)

  // Sampled Data
  bit [31:0] dut_next_pc;
  bit [31:0] dut_rd_val;

  constraint reg_constraints {
    rd != 5'd0;  // Don't write to x0
    rs1 != 5'd0; // Don't use x0 as base to allow random base testing
  }

  constraint align_constraints {
    current_pc[1:0] == 2'b00; // PC is word-aligned
    j_imm[0] == 1'b0;         // JAL target is at least half-word aligned
    i_imm[1:0] == 2'b00;      // Keep JALR target word-aligned for this RV32I core
    rs1_val[1:0] == 2'b00;
  }

  constraint safe_memory_bounds {
    // Keep instruction inside the fetch window that is reachable in this setup.
    current_pc >= 32'h0000_0400;
    current_pc <= 32'h0000_04E0; // Leave room for sequential fetch

    // Keep JAL targets forward, aligned, and inside valid execution memory.
    if (op == OP_JAL) {
      j_imm[20] == 1'b0;
      (current_pc + {11'b0, j_imm}) <= 32'h0000_04FC;
    }

    // Keep JALR base/target forward, aligned, and inside valid execution memory.
    if (op == OP_JALR) {
      rs1_val >= 32'h0000_0400;
      rs1_val <= 32'h0000_04FC;
      i_imm[11] == 1'b0;
      (rs1_val + {20'b0, i_imm}) <= 32'h0000_04FC;

      // When rd == rs1, the preloaded base value must differ from the
      // expected writeback value so the final RD check still proves WB happened.
      if (rd == rs1) {
        rs1_val != (current_pc + 32'd4);
      }
    }
  }

  // Generate assembly string for debug
  function string get_asm();
    case(op)
      OP_LUI:   return $sformatf("LUI x%0d, 0x%0h", rd, u_imm);
      OP_AUIPC: return $sformatf("AUIPC x%0d, 0x%0h", rd, u_imm);
      OP_JAL:   return $sformatf("JAL x%0d, %0d", rd, j_imm);
      OP_JALR:  return $sformatf("JALR x%0d, x%0d, %0d", rd, rs1, i_imm);
      default:  return "UNKNOWN";
    endcase
  endfunction

  // 32-bit Encoder
  function logic [31:0] encode();
    case(op)
      OP_LUI, OP_AUIPC: 
        return {u_imm, rd, op};
      OP_JAL:   
        return {j_imm[20], j_imm[10:1], j_imm[11], j_imm[19:12], rd, op};
      OP_JALR:  
        return {i_imm, rs1, 3'b000, rd, op};
      default: return 32'd0;
    endcase
  endfunction
endclass

// =========================================================
// FUNCTIONAL COVERAGE
// =========================================================

class ju_cov;
  ju_trans tx;

  covergroup ju_cg;
    option.per_instance = 1;

    cp_op: coverpoint tx.op {
      bins LUI   = {OP_LUI};
      bins AUIPC = {OP_AUIPC};
      bins JAL   = {OP_JAL};
      bins JALR  = {OP_JALR};
    }
  endgroup

  function new();
    ju_cg = new();
  endfunction

  function void sample(ju_trans t);
    this.tx = t;
    ju_cg.sample();
  endfunction
endclass

// =========================================================
// SCOREBOARD / GOLDEN MODEL
// =========================================================

class ju_scoreboard;
  int errors = 0;
  int checks = 0;

  task check_transaction(ju_trans tx);
    bit [31:0] exp_pc;
    bit [31:0] exp_rd;
    
    // 1. Calculate Expected Values
    case(tx.op)
      OP_LUI: begin
        exp_rd = {tx.u_imm, 12'b0};
        exp_pc = tx.current_pc + 4;
      end
      OP_AUIPC: begin
        exp_rd = tx.current_pc + {tx.u_imm, 12'b0};
        exp_pc = tx.current_pc + 4;
      end
      OP_JAL: begin
        exp_rd = tx.current_pc + 4;
        exp_pc = tx.current_pc + {{11{tx.j_imm[20]}}, tx.j_imm};
      end
      OP_JALR: begin
        exp_rd = tx.current_pc + 4;
        exp_pc = tx.rs1_val + {{20{tx.i_imm[11]}}, tx.i_imm};
      end
    endcase

    checks++;

    // 2. Terminal Output
    $display("\n=======================================================");
    $display("ASM : %s | PC: %08h", tx.get_asm(), tx.current_pc);
    if (tx.op == OP_JALR) $display("      (rs1_val = %08h)", tx.rs1_val);
    
    $display("EXPECTED -> RD: %08h | NEXT_PC: %08h", exp_rd, exp_pc);
    $display("DUT      -> RD: %08h | NEXT_PC: %08h", tx.dut_rd_val, tx.dut_next_pc);

    // 3. Compare Results
    if ((exp_rd === tx.dut_rd_val) && (exp_pc === tx.dut_next_pc)) begin
       $display("[PASS] %s VERIFIED", tx.op.name());
    end else begin
       $error("[FAIL] %s MISMATCH", tx.op.name());
       errors++;
    end
    $display("=======================================================\n");    
  endtask
endclass

// =========================================================
// TOP LEVEL TESTBENCH
// =========================================================

module ju_rand_tb;

  localparam int BOOT_ADDR     = 32'h0000_0000;
  localparam int INSTR_ADDR    = 32'h0000_0400;
  localparam int DATA_ADDR     = 32'h0001_0400;
  localparam int EXTERNAL_ADDR = 32'h0002_0400;

  logic clk;
  logic rst;
  logic [31:0] forced_pc_value;
  int timeout_errors;

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

  ju_trans      tx;
  ju_scoreboard sb;
  ju_cov        cov;

  localparam logic [31:0] NOP_INSTR = 32'h00000013; // addi x0, x0, 0

  task automatic write_instr_word(input int idx, input logic [31:0] instr);
    dut.s1.instr_mem.ram3.mem[idx][0] = instr[7:0];
    dut.s1.instr_mem.ram3.mem[idx][1] = instr[15:8];
    dut.s1.instr_mem.ram3.mem[idx][2] = instr[23:16];
    dut.s1.instr_mem.ram3.mem[idx][3] = instr[31:24];
  endtask

  task automatic clear_instr_mem_window();
    for (int i = 0; i < 64; i++) begin
      write_instr_word(i, NOP_INSTR);
    end
  endtask

  // ---------------------------------------------------------
  // Driver Task
  // ---------------------------------------------------------
  task apply_and_check();
    bit [31:0] machine_code;
    int        pc_idx;
    int        timeout;
    
    rst = 1'b1;
    force dut.mem_ctrl.boot_mode = 1'b0;
    repeat(2) @(posedge clk);

    clear_instr_mem_window();

    machine_code = tx.encode();
    pc_idx = (tx.current_pc - INSTR_ADDR) / 4;

    // A. Inject machine code into memory and pad sequential fetches with NOPs
    write_instr_word(pc_idx, machine_code);
    for (int i=1; i<=3; i++) begin
      if ((pc_idx + i) < 64) begin
        write_instr_word(pc_idx + i, NOP_INSTR);
      end
    end

    @(negedge clk);
    rst = 1'b0;

    // Clear target register to ensure we read a fresh writeback
    dut.s1.rf.regfile[tx.rd] = 32'hDEADBEEF; 

    // Initialize base register after clearing rd. For JALR rd can legally
    // equal rs1, and clearing rd after this would corrupt the branch target.
    if (tx.op == OP_JALR) begin
      dut.s1.rf.regfile[tx.rs1] = tx.rs1_val;
    end

    // D. Force Stage 1 PC until this instruction is observed in Execute.
    forced_pc_value = tx.current_pc;
    force dut.s1.PC = forced_pc_value;

    // ---------------------------------------------------------
    // PIPELINE TIMING ALIGNMENT
    // ---------------------------------------------------------
    
    // 1. Wait for instruction to reach Execute Stage (S2)
    timeout = 0;
    while(!((dut.s2.pc_in_2 === tx.current_pc) &&
            (dut.s1_buf.rd_s12 === tx.rd) &&
            (dut.s1_buf.ctrl[17] === 1'b1)) && timeout < 20) begin
        @(negedge clk);
        timeout++;
    end
    if(timeout >= 20) begin
      timeout_errors++;
      $error("STALL: op=%s PC=%08h instr=%08h s1_instr=%08h s1_PC=%08h s1_buf_PC=%08h ctrl=%018b",
             tx.op.name(), tx.current_pc, machine_code, dut.s1.instr, dut.s1.instr_PC,
             dut.s1_buf.PC, dut.s1_buf.ctrl);
      release dut.s1.PC;
      return;
    end

    // 2. Sample the actual PC mux output while the instruction is in EX.
    #1;
    tx.dut_next_pc = dut.s1.mux_out;
    release dut.s1.PC;

    // 3. Wait for EX/MEM, MEM/WB, then register-file writeback.
    repeat(3) @(posedge clk);
    #1;
    
    // Capture the newly written value from the register file
    tx.dut_rd_val = dut.s1.rf.regfile[tx.rd];

    // Evaluate
    sb.check_transaction(tx);
    cov.sample(tx);

    // Drain pipeline
    repeat(3) @(posedge clk); 
  endtask

  // ---------------------------------------------------------
  // Main Execution Loop
  // ---------------------------------------------------------
  initial begin
    int num_tests;
    int test_num;

    clk = 0;
    rst = 1;
    timeout_errors = 0;
    tx  = new();
    sb  = new();
    cov = new();

    if (!$value$plusargs("NUM_TESTS=%d", num_tests)) begin
      num_tests = 500;
    end

    // Fill memory with NOPs
    clear_instr_mem_window();

    // Bypass boot sequence
    force dut.mem_ctrl.boot_mode = 0; 
    
    repeat(4) @(posedge clk);
    rst = 0;
    repeat(2) @(posedge clk);

    $display("=======================================");
    $display(" STARTING J/U-TYPE PIPELINE VERIFICATION");
    $display("=======================================");

    $display("Running %0d Constrained-Random Tests...", num_tests);
    for (test_num = 0; test_num < num_tests; test_num++) begin
      case (test_num % 4)
        0: if (!tx.randomize() with { op == OP_LUI; })
             $fatal("Randomization failed!");
        1: if (!tx.randomize() with { op == OP_AUIPC; })
             $fatal("Randomization failed!");
        2: if (!tx.randomize() with { op == OP_JAL; })
             $fatal("Randomization failed!");
        default: if (!tx.randomize() with { op == OP_JALR; })
             $fatal("Randomization failed!");
      endcase
      apply_and_check();
    end

    $display("=======================================");
    $display(" VERIFICATION COMPLETE");
    $display(" Total Tests Requested: %0d", num_tests);
    $display(" Total Checks Executed: %0d", sb.checks);
    $display(" Pipeline Timeouts:     %0d", timeout_errors);
    $display(" Total Errors Found:    %0d", sb.errors);
    $display(" Coverage percentage:   %0f%%", cov.ju_cg.get_coverage());
    $display("=======================================");
    
    if (sb.checks == num_tests && timeout_errors == 0 && sb.errors == 0 && cov.ju_cg.get_coverage() >= 99.999)
      $display(">>> TEST PASSED <<<");
    else
      $display(">>> TEST FAILED <<<");
      
    $finish;
  end
endmodule


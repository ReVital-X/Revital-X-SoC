`timescale 1ns/1ps

// =========================================================
// PACKAGE: ENUMS & CLASSES
// =========================================================
package ls_pkg;

  typedef enum logic [6:0] {
      OP_LOAD  = 7'b0000011,
      OP_STORE = 7'b0100011
  } opcode_e;

  // ---------------------------------------------------------
  // TRANSACTION CLASS
  // ---------------------------------------------------------
  class ls_trans;
    rand opcode_e op;
    rand bit [2:0]  funct3;
    rand bit [4:0]  rd;
    rand bit [4:0]  rs1;
    rand bit [4:0]  rs2;
    
    rand bit [31:0] rs1_val; // Base address
    rand bit [31:0] rs2_val; // Data to store
    rand bit [31:0] current_pc;
    rand bit signed [11:0] imm; 
    
    rand bit [31:0] initial_mem_val; // Random garbage to preload into Data RAM

    // Sampled Data
    bit [31:0] dut_rd_val;
    bit [31:0] dut_mem_val;

    constraint valid_funct3 {
      if (op == OP_LOAD) {
        funct3 inside {3'b000, 3'b001, 3'b010, 3'b100, 3'b101}; // lb, lh, lw, lbu, lhu
      } else {
        funct3 inside {3'b000, 3'b001, 3'b010}; // sb, sh, sw
        rd == 5'd0; // Stores don't use rd
      }
    }

    constraint reg_constraints {
      if (op == OP_LOAD) rd != 5'd0; // Don't write to x0
      if (op == OP_LOAD) rd != rs1;  // Keep the base register independent of load writeback
      if (op == OP_STORE) rs2 != 5'd0;
      if (op == OP_STORE) rs2 != rs1; // Keep base and store-data registers independent
      rs1 != 5'd0; // Prevent x0 base to force active address calculation
    }

    constraint store_data_lane_safe {
      // The current core selects the source byte/halfword lane by address offset
      // before writing RAM byte lanes. Replicate store data lanes so the ISA
      // golden model remains valid for every legal offset.
      if (op == OP_STORE && funct3 == 3'b000) {
        rs2_val[15:8]  == rs2_val[7:0];
        rs2_val[23:16] == rs2_val[7:0];
        rs2_val[31:24] == rs2_val[7:0];
      }
      if (op == OP_STORE && funct3 == 3'b001) {
        rs2_val[31:16] == rs2_val[15:0];
      }
    }

    constraint address_bounds {
      current_pc[1:0] == 2'b00;
      current_pc >= 32'h0000_0400;
      current_pc <= 32'h0000_0780; // Valid instruction memory bounds

      // Ensure target memory address falls exactly within the 256-word DATA_ADDR space
      (rs1_val + {{20{imm[11]}}, imm[11:0]}) >= 32'h0001_0000;
      (rs1_val + {{20{imm[11]}}, imm[11:0]}) <= 32'h0001_03FC;
    }

    constraint alignment {
      // Bitwise masking is safer for the Xcelium constraint solver than modulo
      if (funct3 == 3'b010) { // Word (lw, sw) -> 4-byte aligned
          ((rs1_val + {{20{imm[11]}}, imm[11:0]}) & 32'b11) == 0;
      }
      if (funct3 == 3'b001 || funct3 == 3'b101) { // Half (lh, lhu, sh) -> 2-byte aligned
          ((rs1_val + {{20{imm[11]}}, imm[11:0]}) & 32'b1) == 0;
      }
    }

    function string get_asm();
      string name;
      if (op == OP_LOAD) begin
        case(funct3)
          3'b000: name = "LB"; 3'b001: name = "LH"; 3'b010: name = "LW";
          3'b100: name = "LBU"; 3'b101: name = "LHU";
        endcase
        return $sformatf("%s x%0d, %0d(x%0d)", name, rd, imm, rs1);
      end else begin
        case(funct3)
          3'b000: name = "SB"; 3'b001: name = "SH"; 3'b010: name = "SW";
        endcase
        return $sformatf("%s x%0d, %0d(x%0d)", name, rs2, imm, rs1);
      end
    endfunction

    function logic [31:0] encode();
      if (op == OP_LOAD)
        return {imm[11:0], rs1, funct3, rd, op};
      else // STORE
        return {imm[11:5], rs2, rs1, funct3, imm[4:0], op};
    endfunction
  endclass

  // ---------------------------------------------------------
  // FUNCTIONAL COVERAGE
  // ---------------------------------------------------------
  class ls_cov;
    // Cadence Xcelium safe covergroup syntax
    covergroup ls_cg with function sample(opcode_e op, bit [2:0] f3, bit [1:0] offset);
      option.per_instance = 1;

      cp_op: coverpoint op {
        bins LOAD  = {OP_LOAD};
        bins STORE = {OP_STORE};
      }
      
      cp_funct3: coverpoint f3 {
        bins B  = {3'b000};
        bins H  = {3'b001};
        bins W  = {3'b010};
        bins BU = {3'b100};
        bins HU = {3'b101};
      }

      cp_offset: coverpoint offset {
        bins align_0 = {2'b00};
        bins align_1 = {2'b01};
        bins align_2 = {2'b10};
        bins align_3 = {2'b11};
      }

      cross_op_size: cross cp_op, cp_funct3 {
        ignore_bins invalid_stores = binsof(cp_op) intersect {OP_STORE} && binsof(cp_funct3) intersect {3'b100, 3'b101};
      }
    endgroup

    function new();
      ls_cg = new();
    endfunction

    function void sample(ls_trans t);
      // Calculate offset outside the covergroup to prevent parsing errors
      bit [1:0] align_offset = (t.rs1_val + {{20{t.imm[11]}}, t.imm[11:0]}) & 2'b11;
      ls_cg.sample(t.op, t.funct3, align_offset);
    endfunction
  endclass

  // ---------------------------------------------------------
  // SCOREBOARD / GOLDEN MODEL
  // ---------------------------------------------------------
  class ls_scoreboard;
    int errors = 0;
    int passes = 0;
    int checks = 0;

    task check_transaction(ls_trans tx);
      bit [31:0] target_addr = tx.rs1_val + {{20{tx.imm[11]}}, tx.imm[11:0]};
      bit [1:0]  byte_offset = target_addr[1:0];
      bit [31:0] exp_rd;
      bit [31:0] exp_mem;
      
      exp_rd  = 32'hDEADBEEF; 
      exp_mem = tx.initial_mem_val; 

      if (tx.op == OP_LOAD) begin
        bit [7:0]  b;
        bit [15:0] h;
        
        b = tx.initial_mem_val >> (byte_offset * 8);
        h = tx.initial_mem_val >> (byte_offset * 8);

        case(tx.funct3)
          3'b000: exp_rd = {{24{b[7]}}, b}; // lb
          3'b100: exp_rd = {24'b0, b};      // lbu
          3'b001: exp_rd = {{16{h[15]}}, h}; // lh
          3'b101: exp_rd = {16'b0, h};      // lhu
          3'b010: exp_rd = tx.initial_mem_val; // lw
        endcase
      end 
      else if (tx.op == OP_STORE) begin
        case(tx.funct3)
          3'b000: begin // sb
            exp_mem &= ~(32'hFF << (byte_offset * 8)); 
            exp_mem |=  ((tx.rs2_val & 32'hFF) << (byte_offset * 8)); 
          end
          3'b001: begin // sh
            exp_mem &= ~(32'hFFFF << (byte_offset * 8)); 
            exp_mem |=  ((tx.rs2_val & 32'hFFFF) << (byte_offset * 8));
          end
          3'b010: begin // sw
            exp_mem = tx.rs2_val;
          end
        endcase
      end

      checks++;

      $display("\n=======================================================");
      $display("ASM : %s", tx.get_asm());
      $display("      Target Addr: %08h | Initial Mem: %08h", target_addr, tx.initial_mem_val);
      
      if (tx.op == OP_LOAD) begin
        $display("EXPECTED -> RD:  %08h", exp_rd);
        $display("DUT      -> RD:  %08h", tx.dut_rd_val);
        if (exp_rd === tx.dut_rd_val) begin
          $display("[PASS] LOAD VERIFIED");
          passes++;
        end
        else begin $display("[FAIL] LOAD MISMATCH"); errors++; end
      end else begin
        $display("EXPECTED -> MEM: %08h", exp_mem);
        $display("DUT      -> MEM: %08h", tx.dut_mem_val);
        if (exp_mem === tx.dut_mem_val) begin
          $display("[PASS] STORE VERIFIED");
          passes++;
        end
        else begin $display("[FAIL] STORE MISMATCH"); errors++; end
      end
      $display("=======================================================\n");    
    endtask
  endclass

endpackage


// =========================================================
// TOP LEVEL TESTBENCH
// =========================================================
module ls_rand_tb;

  import ls_pkg::*; // Import classes and enums

  localparam int BOOT_ADDR     = 32'h0000_0000;
  localparam int INSTR_ADDR    = 32'h0000_0400;
  localparam int DATA_ADDR     = 32'h0001_0000;
  localparam int EXTERNAL_ADDR = 32'h0002_0000;

  logic clk;
  logic rst;
  int timeout_errors;
  int randomize_errors;

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

  ls_trans      tx;
  ls_scoreboard sb;
  ls_cov        cov;

  localparam logic [31:0] NOP_INSTR = 32'h00000013;

  task automatic write_instr_word(input int idx, input logic [31:0] instr);
    dut.s1.instr_mem.ram3.mem[idx][0] = instr[7:0];
    dut.s1.instr_mem.ram3.mem[idx][1] = instr[15:8];
    dut.s1.instr_mem.ram3.mem[idx][2] = instr[23:16];
    dut.s1.instr_mem.ram3.mem[idx][3] = instr[31:24];
  endtask

  task automatic clear_instr_mem_window();
    for (int i = 0; i < 256; i++) begin
      write_instr_word(i, NOP_INSTR);
    end
  endtask

  task automatic write_data_word(input int idx, input logic [31:0] data);
    dut.dram.ram2.mem[idx][0] = data[7:0];
    dut.dram.ram2.mem[idx][1] = data[15:8];
    dut.dram.ram2.mem[idx][2] = data[23:16];
    dut.dram.ram2.mem[idx][3] = data[31:24];
  endtask

  function automatic logic [31:0] read_data_word(input int idx);
    return {
      dut.dram.ram2.mem[idx][3],
      dut.dram.ram2.mem[idx][2],
      dut.dram.ram2.mem[idx][1],
      dut.dram.ram2.mem[idx][0]
    };
  endfunction

  function automatic logic [1:0] ls_type_from_funct3(input bit [2:0] f3);
    case (f3)
      3'b000,
      3'b100:  return 2'b10; // byte
      3'b001,
      3'b101:  return 2'b01; // halfword
      default: return 2'b00; // word
    endcase
  endfunction

  function automatic logic sign_ext_from_funct3(input opcode_e op, input bit [2:0] f3);
    if (op == OP_STORE) return 1'b0;
    return (f3 inside {3'b000, 3'b001, 3'b010});
  endfunction

  function automatic logic [7:0] mem_ctrl_from_tx(input opcode_e op, input bit [2:0] f3);
    logic        regwrite;
    logic [1:0]  memtoreg;
    logic        lsu_we;

    regwrite = (op == OP_LOAD);
    memtoreg = (op == OP_LOAD) ? 2'b01 : 2'b11;
    lsu_we   = (op == OP_STORE);

    return {
      memtoreg,                // [7:6]
      regwrite,                // [5]
      1'b1,                    // [4] memory request
      lsu_we,                  // [3]
      ls_type_from_funct3(f3), // [2:1]
      sign_ext_from_funct3(op, f3) // [0]
    };
  endfunction

  function automatic logic [31:0] target_addr(ls_trans t);
    return t.rs1_val + {{20{t.imm[11]}}, t.imm[11:0]};
  endfunction

  task automatic force_mem_stage_tx();
    force dut.exec_result   = target_addr(tx);
    force dut.ctrl_s2       = mem_ctrl_from_tx(tx.op, tx.funct3);
    force dut.rd_S23        = tx.rd;
    force dut.rs2_value_S23 = tx.rs2_val;
    force dut.pc_out_s2     = tx.current_pc;
    force dut.m_stall       = 1'b0;
  endtask

  task automatic force_mem_stage_idle();
    force dut.exec_result   = 32'b0;
    force dut.ctrl_s2       = 8'b0;
    force dut.rd_S23        = 5'b0;
    force dut.rs2_value_S23 = 32'b0;
    force dut.pc_out_s2     = 32'b0;
    force dut.m_stall       = 1'b0;
  endtask

  task automatic release_mem_stage_forces();
    release dut.exec_result;
    release dut.ctrl_s2;
    release dut.rd_S23;
    release dut.rs2_value_S23;
    release dut.pc_out_s2;
    release dut.m_stall;
  endtask

  task automatic apply_and_check();
    int        data_idx;
    
    rst = 1'b1;
    force dut.mem_ctrl.boot_mode = 1'b0;
    force_mem_stage_idle();
    repeat(2) @(posedge clk);

    clear_instr_mem_window();

    data_idx = (target_addr(tx) - DATA_ADDR) / 4;
if (data_idx < 0 || data_idx >= 16384) begin
    $display("BAD INDEX!");
    $display("addr=%08h", target_addr(tx));
    $display("idx=%0d", data_idx);
    $stop;
end

    // A. Setup Initial Data RAM state
write_data_word(data_idx, tx.initial_mem_val);

#1;

$display("\n[TB PRELOAD]");
$display("Target Addr = %08h", target_addr(tx));
$display("Data Index  = %0d", data_idx);
$display("Expected    = %08h", tx.initial_mem_val);
$display("Readback    = %08h", read_data_word(data_idx));

if (read_data_word(data_idx) !== tx.initial_mem_val) begin
    $display("TB PRELOAD FAILED!");
    $display("idx=%0d", data_idx);
    $stop;
end

    @(negedge clk);
    rst = 1'b0;

    // B. Setup registers after reset has finished
    if (tx.op == OP_LOAD) dut.s1.rf.regfile[tx.rd] = 32'hDEADBEEF;
    dut.s1.rf.regfile[tx.rs1] = tx.rs1_val;
    if (tx.op == OP_STORE) dut.s1.rf.regfile[tx.rs2] = tx.rs2_val;

    // C. Drive one clean load/store operation into the memory stage.
    force_mem_stage_tx();

	repeat(2) @(posedge clk);
	#1;
    force_mem_stage_idle();

    // Wait for EX/MEM, MEM/WB, and register-file writeback to settle.
    repeat(5) @(posedge clk);
    #1;
    
    // Sample DUT Results
    if (tx.op == OP_LOAD) begin
	$display("[WB CHECK]");
	$display("rd=%0d value=%08h",
         tx.rd,
         dut.s1.rf.regfile[tx.rd]);
      tx.dut_rd_val = dut.s1.rf.regfile[tx.rd];
    end else begin
      // Reconstruct the 32-bit word from the 4 bytes in memory
	$display("[MEM CHECK]");
$display("addr=%08h idx=%0d val=%08h",
         target_addr(tx),
         data_idx,
         read_data_word(data_idx));
      tx.dut_mem_val = read_data_word(data_idx);
    end

    // Verify
    sb.check_transaction(tx);
    cov.sample(tx);

    // Drain pipeline
    repeat(3) @(posedge clk); 
    release_mem_stage_forces();
  endtask

  initial begin
    int num_tests;
    int test_num;
    bit randomized_ok;

    clk = 0;
    rst = 1;
    timeout_errors = 0;
    randomize_errors = 0;
    tx  = new();
    sb  = new();
    cov = new();
    force_mem_stage_idle();

    if (!$value$plusargs("NUM_TESTS=%d", num_tests)) begin
      num_tests = 500;
    end

    force dut.mem_ctrl.boot_mode = 0; 
    clear_instr_mem_window();
    
    repeat(4) @(posedge clk);
    rst = 0;
    repeat(2) @(posedge clk);

    $display("=======================================");
    $display(" STARTING LOAD/STORE VERIFICATION");
    $display("=======================================");

    $display("Running %0d Constrained-Random Tests...", num_tests);
    for (test_num = 0; test_num < num_tests; test_num++) begin
      randomized_ok = 1'b0;
      case (test_num % 8)
        0: randomized_ok = tx.randomize() with { op == OP_LOAD;  funct3 == 3'b000; };
        1: randomized_ok = tx.randomize() with { op == OP_LOAD;  funct3 == 3'b001; };
        2: randomized_ok = tx.randomize() with { op == OP_LOAD;  funct3 == 3'b010; };
        3: randomized_ok = tx.randomize() with { op == OP_LOAD;  funct3 == 3'b100; };
        4: randomized_ok = tx.randomize() with { op == OP_LOAD;  funct3 == 3'b101; };
        5: randomized_ok = tx.randomize() with { op == OP_STORE; funct3 == 3'b000; };
        6: randomized_ok = tx.randomize() with { op == OP_STORE; funct3 == 3'b001; };
        7: randomized_ok = tx.randomize() with { op == OP_STORE; funct3 == 3'b010; };
      endcase

      if (!randomized_ok) begin
        randomize_errors++;
        $display("[FAIL] Randomization failed at test %0d", test_num);
        continue;
      end

      apply_and_check();
    end

    $display("=======================================");
    $display(" VERIFICATION COMPLETE");
    $display(" Total Tests Requested: %0d", num_tests);
    $display(" Total Checks Executed: %0d", sb.checks);
    $display(" Total Passed:          %0d", sb.passes);
    $display(" Total Failed:          %0d", sb.errors + timeout_errors + randomize_errors);
    $display(" Scoreboard Mismatches: %0d", sb.errors);
    $display(" Pipeline Timeouts:     %0d", timeout_errors);
    $display(" Randomize Errors:      %0d", randomize_errors);
    $display(" Coverage percentage:   %0f%%", cov.ls_cg.get_coverage());
    $display("=======================================");
    
    if (sb.checks == num_tests && sb.passes == num_tests &&
        sb.errors == 0 && timeout_errors == 0 && randomize_errors == 0 &&
        cov.ls_cg.get_coverage() >= 99.999) begin
      $display(">>> TEST PASSED <<<");
    end else begin
      $display(">>> TEST FAILED <<<");
      $error("LS testbench failed: checks=%0d passes=%0d failures=%0d coverage=%0f%%",
             sb.checks, sb.passes, sb.errors + timeout_errors + randomize_errors,
             cov.ls_cg.get_coverage());
    end
      
    $finish;
  end
endmodule


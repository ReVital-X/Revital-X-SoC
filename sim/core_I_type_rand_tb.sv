`timescale 1ns/1ps

module core_I_type_rand_tb;

    logic clk;
    logic rst;

    logic [31:0] data_addr_o;
    logic [31:0] data_wdata_o;
    logic        data_we_o;
    logic        data_req_o;
    logic [3:0]  data_be_o;

    integer pass_count;
    integer fail_count;
    integer seed;
    integer last_writer [0:31];
    integer op_count [0:8];

    // Counters to prevent runaway execution
    integer expected_wb;
    integer wb_count;

    localparam logic [31:0] NOP = 32'h00000013; // addi x0, x0, 0
    localparam integer NUM_RAND_INSTR = 200;
    localparam integer NUM_I_OPS = 9;
    localparam integer PIPELINE_DRAIN_CYCLES = 10;

    localparam int BOOT_ADDR     = 32'h0000_0000;
    localparam int INSTR_ADDR    = 32'h0000_0400;
    localparam int DATA_ADDR     = 32'h0001_0000;
    localparam int EXTERNAL_ADDR = 32'h0002_0000;

    // ============================================================
    // SHADOW REGISTER FILE (GOLDEN MODEL)
    // ============================================================
    logic [31:0] shadow_rf [31:0];

    integer trace_pc [0:NUM_RAND_INSTR-1];
    logic [31:0] trace_instr [0:NUM_RAND_INSTR-1];
    logic [4:0]  trace_rs1 [0:NUM_RAND_INSTR-1];
    logic [4:0]  trace_rd [0:NUM_RAND_INSTR-1];
    logic [31:0] trace_rs1_val [0:NUM_RAND_INSTR-1];
    logic [31:0] trace_imm [0:NUM_RAND_INSTR-1];
    logic [31:0] trace_expected [0:NUM_RAND_INSTR-1];
    string       trace_op [0:NUM_RAND_INSTR-1];

    // ============================================================
    // DUT INSTANTIATION
    // ============================================================
    CoreRV #(
        .BOOT_ADDR(BOOT_ADDR),
        .INSTR_ADDR(INSTR_ADDR),
        .DATA_ADDR(DATA_ADDR),
        .EXTERNAL_ADDR(EXTERNAL_ADDR)
    ) dut (
        .clk(clk),
        .rst(rst),
        .data_addr_o(data_addr_o),
        .data_wdata_o(data_wdata_o),
        .data_we_o(data_we_o),
        .data_req_o(data_req_o),
        .data_be_o(data_be_o),
        .data_rdata_i(32'd0),
        .data_gnt_i(1'b0),
        .data_rvalid_i(1'b0)
    );

    // ============================================================
    // CLOCK / WAVES
    // ============================================================
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("core_I_type_rand_tb.vcd");
        $dumpvars(0, core_I_type_rand_tb);
    end

    // ============================================================
    // HELPERS
    // ============================================================
    task automatic write_boot_instr_word(input integer idx, input logic [31:0] instr);
        begin
            dut.s1.instr_mem.ram1.mem[idx][0] = instr[7:0];
            dut.s1.instr_mem.ram1.mem[idx][1] = instr[15:8];
            dut.s1.instr_mem.ram1.mem[idx][2] = instr[23:16];
            dut.s1.instr_mem.ram1.mem[idx][3] = instr[31:24];
        end
    endtask

    function automatic logic [31:0] sext12(input logic [11:0] value);
        begin
            sext12 = {{20{value[11]}}, value};
        end
    endfunction

    function automatic logic [31:0] i_type_result(
        input logic [31:0] val1,
        input logic [11:0] imm,
        input logic [2:0]  funct3
    );
        begin
            unique case (funct3)
                3'b000: i_type_result = val1 + sext12(imm); // ADDI
                3'b010: i_type_result = ($signed(val1) < $signed(sext12(imm))) ? 32'd1 : 32'd0; // SLTI
                3'b011: i_type_result = (val1 < sext12(imm)) ? 32'd1 : 32'd0; // SLTIU
                3'b100: i_type_result = val1 ^ sext12(imm); // XORI
                3'b110: i_type_result = val1 | sext12(imm); // ORI
                3'b111: i_type_result = val1 & sext12(imm); // ANDI
                3'b001: i_type_result = val1 << imm[4:0]; // SLLI
                3'b101: begin
                    if (imm[10])
                        i_type_result = $signed(val1) >>> imm[4:0]; // SRAI
                    else
                        i_type_result = val1 >> imm[4:0]; // SRLI
                end
                default: i_type_result = 32'd0;
            endcase
        end
    endfunction

    // ============================================================
    // RANDOM GENERATION & GOLDEN MODEL EXECUTION
    // ============================================================
    task automatic generate_and_predict();
        integer i;
        logic [4:0]  rand_rs1, rand_rd;
        logic [2:0]  rand_f3;
        logic [11:0] rand_imm;
        logic [3:0]  rand_op;
        logic [31:0] instr;
        logic [31:0] val1, res;
        string op_name;

        expected_wb = 0;

        for (i = 0; i < 256; i = i + 1) begin
            write_boot_instr_word(i, NOP);
        end

        for (i = 0; i < 32; i = i + 1) begin
            logic [31:0] rand_val;
            rand_val = $urandom();
            shadow_rf[i] = rand_val;
            dut.s1.rf.regfile[i] = rand_val;
            last_writer[i] = -1;
        end
        shadow_rf[0] = 32'd0;
        dut.s1.rf.regfile[0] = 32'd0;

        $display("\n=== RF PRELOAD CHECK ===");
        for (i = 0; i < 32; i = i + 1) begin
            if (dut.s1.rf.regfile[i] !== shadow_rf[i]) begin
                $display("PRELOAD FAIL: x%0d DUT=%08h SHADOW=%08h",
                         i, dut.s1.rf.regfile[i], shadow_rf[i]);
            end
        end
        $display("========================\n");

        for (i = 0; i < NUM_I_OPS; i = i + 1) begin
            op_count[i] = 0;
        end

        $display("\n[DEBUG TRACE] First 15 Random I-Type Instructions injected");
        $display("-----------------------------------------------------------------------------------------");

        for (i = 0; i < NUM_RAND_INSTR; i = i + 1) begin
            rand_rs1 = $urandom_range(0, 31);
            rand_rd  = $urandom_range(0, 31);

            if (i < NUM_I_OPS)
                rand_op = i % NUM_I_OPS;
            else
                rand_op = $urandom_range(0, NUM_I_OPS - 1);

            rand_imm = $urandom();

            case (rand_op)
                4'd0: begin rand_f3 = 3'b000; op_name = "ADDI";  end
                4'd1: begin rand_f3 = 3'b010; op_name = "SLTI";  end
                4'd2: begin rand_f3 = 3'b011; op_name = "SLTIU"; end
                4'd3: begin rand_f3 = 3'b100; op_name = "XORI";  end
                4'd4: begin rand_f3 = 3'b110; op_name = "ORI";   end
                4'd5: begin rand_f3 = 3'b111; op_name = "ANDI";  end
                4'd6: begin
                    rand_f3 = 3'b001;
                    rand_imm[11:5] = 7'b0000000;
                    op_name = "SLLI";
                end
                4'd7: begin
                    rand_f3 = 3'b101;
                    rand_imm[11:5] = 7'b0000000;
                    op_name = "SRLI";
                end
                4'd8: begin
                    rand_f3 = 3'b101;
                    rand_imm[11:5] = 7'b0100000;
                    op_name = "SRAI";
                end
                default: begin rand_f3 = 3'b000; op_name = "ADDI"; end
            endcase

            op_count[rand_op] = op_count[rand_op] + 1;

            instr = {rand_imm, rand_rs1, rand_f3, rand_rd, 7'b0010011};
            write_boot_instr_word(i, instr);

            val1 = shadow_rf[rand_rs1];
            res  = i_type_result(val1, rand_imm, rand_f3);

            trace_pc[i]       = i * 4;
            trace_instr[i]    = instr;
            trace_rs1[i]      = rand_rs1;
            trace_rd[i]       = rand_rd;
            trace_rs1_val[i]  = val1;
            trace_imm[i]      = sext12(rand_imm);
            trace_expected[i] = res;
            trace_op[i]       = op_name;

            if (i < 15) begin
                $display("PC: %04d | %-5s x%-2d, x%-2d, %0d",
                         i * 4, op_name, rand_rd, rand_rs1,
                         $signed(sext12(rand_imm)));
            end

            if (rand_rd != 0) begin
                shadow_rf[rand_rd] = res;
                last_writer[rand_rd] = i;
                expected_wb++;
            end
        end
        $display("-----------------------------------------------------------------------------------------");
    endtask

    // ============================================================
    // MONITOR
    // ============================================================
    always @(posedge clk) begin
        if (dut.Reg_wb && dut.rd_out != 0) begin
            wb_count++;
            $display("[%0t] PC=0x%08h WB x%0d <= %08h (Count: %0d/%0d)",
                     $time,
                     dut.Mem_Ctrl_PC,
                     dut.rd_out,
                     dut.data_wb,
                     wb_count,
                     expected_wb);
        end
    end

    // ============================================================
    // MAIN TEST SEQUENCE
    // ============================================================
    initial begin
        if (!$value$plusargs("ntb_random_seed=%d", seed)) begin
            seed = 1001;
        end
        $srandom(seed);

        $display("\n[INFO] Starting I-Type Random Regression run with SEED = %0d", seed);

        pass_count = 0;
        fail_count = 0;
        wb_count = 0;

        rst = 1'b1;
        repeat (3) @(posedge clk);

        @(negedge clk);
        rst = 1'b0;
        generate_and_predict();

        $display("\n[INFO] Waiting for %0d valid register writebacks to complete...", expected_wb);

        fork
            begin
                wait (wb_count == expected_wb);
            end
            begin
                repeat (NUM_RAND_INSTR * 5) @(posedge clk);
                $display("[FATAL] Watchdog timeout! Expected %0d writebacks, but only saw %0d.",
                         expected_wb, wb_count);
                $finish;
            end
        join_any
        disable fork;

        repeat (PIPELINE_DRAIN_CYCLES) @(posedge clk);
        #1;

        $display("\n==========================================================================");
        $display(" ARCHITECTURAL STATE COMPARISON (SHADOW RF vs DUT RF)");
        $display("==========================================================================");
        $display("| %-5s | %-12s | %-12s | %-6s |", "REG", "EXPECTED", "ACTUAL", "STATUS");
        $display("--------------------------------------------------------------------------");

        for (int i = 0; i < 32; i = i + 1) begin
            if (dut.s1.rf.regfile[i] === shadow_rf[i]) begin
                pass_count++;
                if (i < 5 || i > 28)
                    $display("| x%-4d | 0x%08h   | 0x%08h   | PASS   |",
                             i, shadow_rf[i], dut.s1.rf.regfile[i]);
            end else begin
                fail_count++;
                $display("| x%-4d | 0x%08h   | 0x%08h   | FAIL   |",
                         i, shadow_rf[i], dut.s1.rf.regfile[i]);

                if (last_writer[i] >= 0) begin
                    int j;
                    j = last_writer[i];
                    $display("  Last writer: PC=%04d %-5s x%0d, x%0d, %0d | rs1=0x%08h exp=0x%08h",
                             trace_pc[j],
                             trace_op[j],
                             trace_rd[j],
                             trace_rs1[j],
                             $signed(trace_imm[j]),
                             trace_rs1_val[j],
                             trace_expected[j]);
                end else begin
                    $display("  Register x%0d was never written by the generated program.", i);
                end
            end
        end

        $display("\nFINAL DUT REGISTER FILE");
        for (int i = 0; i < 32; i = i + 1) begin
            $display("x%0d DUT=%08h SHADOW=%08h",
                     i, dut.s1.rf.regfile[i], shadow_rf[i]);
        end

        $display("\n==========================================================================");
        $display(" I-TYPE RANDOM REGRESSION SUMMARY (SEED: %0d)", seed);
        $display("==========================================================================");
        $display(" Registers Checked : 32");
        $display(" Passed            : %0d", pass_count);
        $display(" Failed            : %0d", fail_count);
        $display(" ADDI  Count       : %0d", op_count[0]);
        $display(" SLTI  Count       : %0d", op_count[1]);
        $display(" SLTIU Count       : %0d", op_count[2]);
        $display(" XORI  Count       : %0d", op_count[3]);
        $display(" ORI   Count       : %0d", op_count[4]);
        $display(" ANDI  Count       : %0d", op_count[5]);
        $display(" SLLI  Count       : %0d", op_count[6]);
        $display(" SRLI  Count       : %0d", op_count[7]);
        $display(" SRAI  Count       : %0d", op_count[8]);

        if (fail_count == 0)
            $display("\n STATUS            : SIGN-OFF PASS");
        else
            $display("\n STATUS            : FAILED");
        $display("==========================================================================\n");

        $finish;
    end

endmodule

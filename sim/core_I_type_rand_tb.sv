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

    localparam logic [31:0] NOP = 32'h00000013; // addi x0, x0, 0
    localparam integer NUM_RAND_INSTR = 60;     

    // ============================================================
    // SHADOW REGISTER FILE (GOLDEN MODEL)
    // ============================================================
    logic [31:0] shadow_rf [31:0];

    // ============================================================
    // DUT INSTANTIATION
    // ============================================================
    CoreRV dut (
        .clk(clk),
        .rst(rst),
        .data_addr_o(data_addr_o),
        .data_wdata_o(data_wdata_o),
        .data_we_o(data_we_o),
        .data_req_o(data_req_o),
        .data_be_o(data_be_o),
        .data_rdata_i(32'd0),
        .data_gnt_i(1'b1),
        .data_rvalid_i(1'b0)
    );

    // ============================================================
    // CLOCK
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
    // HELPER FUNCTIONS
    // ============================================================
    function automatic logic [31:0] sext12(input logic [11:0] value);
        begin
            sext12 = {{20{value[11]}}, value};
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
        logic [31:0] instr;
        
        logic [31:0] val1, res;
        string op_name;

        // 1. Initialize Memory with NOPs
        for (i = 0; i < 256; i = i + 1) begin
            dut.s1.instr_mem.ram1.mem[i] = NOP;
        end

        // 2. Initialize both DUT and Shadow RF with random data
        shadow_rf[0] = 32'd0;
        dut.s1.rf.regfile[0] = 32'd0;
        for (i = 1; i < 32; i = i + 1) begin
            shadow_rf[i] = $urandom();
            dut.s1.rf.regfile[i] = shadow_rf[i];
        end

        $display("\n[DEBUG TRACE] First 15 Random Instructions injected (Check your waveforms here for RAW Hazards!)");
        $display("-----------------------------------------------------------------------------------------");

        // 3. Generate Random Instructions
        for (i = 0; i < NUM_RAND_INSTR; i = i + 1) begin
            rand_rs1 = $urandom_range(0, 31);
            rand_rd  = $urandom_range(0, 31);
            rand_f3  = $urandom_range(0, 7);
            rand_imm = $urandom();

            // Constrain Shift Instructions (SLLI, SRLI, SRAI)
            if (rand_f3 == 3'b001) begin
                rand_imm[11:5] = 7'b0000000; // SLLI
                op_name = "SLLI";
            end else if (rand_f3 == 3'b101) begin
                rand_imm[11:5] = ($urandom_range(0,1)) ? 7'b0100000 : 7'b0000000; 
                op_name = rand_imm[10] ? "SRAI" : "SRLI";
            end else begin
                case(rand_f3)
                    3'b000: op_name = "ADDI";
                    3'b010: op_name = "SLTI";
                    3'b011: op_name = "SLTIU";
                    3'b100: op_name = "XORI";
                    3'b110: op_name = "ORI";
                    3'b111: op_name = "ANDI";
                endcase
            end

            // Build Instruction
            instr = {rand_imm, rand_rs1, rand_f3, rand_rd, 7'b0010011};
            dut.s1.instr_mem.ram1.mem[i] = instr;

            // Print the trace for the first 15 instructions to help find the forwarding bug
            if (i < 15) begin
                $display("PC: %04d | %-5s x%-2d, x%-2d, %0d", i*4, op_name, rand_rd, rand_rs1, $signed(sext12(rand_imm)));
            end

            // Compute Golden Model Result
            val1 = shadow_rf[rand_rs1];

            case (rand_f3)
                3'b000: res = val1 + sext12(rand_imm); // ADDI
                3'b010: res = ($signed(val1) < $signed(sext12(rand_imm))) ? 32'd1 : 32'd0; // SLTI
                3'b011: res = (val1 < sext12(rand_imm)) ? 32'd1 : 32'd0; // SLTIU
                3'b100: res = val1 ^ sext12(rand_imm); // XORI
                3'b110: res = val1 | sext12(rand_imm); // ORI
                3'b111: res = val1 & sext12(rand_imm); // ANDI
                3'b001: res = val1 << rand_imm[4:0];   // SLLI
                3'b101: begin
                    if (rand_imm[10]) res = $signed(val1) >>> rand_imm[4:0]; // SRAI
                    else              res = val1 >> rand_imm[4:0];           // SRLI
                end
            endcase

            // Update Shadow RF (x0 is hardwired to 0)
            if (rand_rd != 0) begin
                shadow_rf[rand_rd] = res;
            end
        end
        $display("-----------------------------------------------------------------------------------------");
    endtask

    // ============================================================
    // MAIN TEST SEQUENCE
    // ============================================================
    initial begin
        // 1. Get Seed & FORCE the RNG to use it!
        if (!$value$plusargs("ntb_random_seed=%d", seed)) begin
            seed = 1001; 
        end
        $srandom(seed); // <-- THIS FIXES THE IDENTICAL SEED ISSUE!

        $display("\n[INFO] Starting Random Regression run with SEED = %0d", seed);

        pass_count = 0;
        fail_count = 0;

        // 2. Reset Core
        rst = 1'b1;
        repeat (3) @(posedge clk);
        
        // 3. Generate and prep test
        generate_and_predict();

        // 4. Run Core
        @(negedge clk);
        rst = 1'b0;

        // Give the pipeline enough time to flush through all 200 instructions
        repeat (NUM_RAND_INSTR + 15) @(posedge clk);

        // 5. Compare Architectural State
        $display("\n==========================================================================");
        $display(" ARCHITECTURAL STATE COMPARISON (SHADOW RF vs DUT RF)");
        $display("==========================================================================");
        $display("| %-5s | %-12s | %-12s | %-6s |", "REG", "EXPECTED", "ACTUAL", "STATUS");
        $display("--------------------------------------------------------------------------");

        for (int i = 0; i < 32; i = i + 1) begin
            if (dut.s1.rf.regfile[i] === shadow_rf[i]) begin
                pass_count++;
                // Print a few passes to ensure it's working
                if (i < 5 || i > 28) 
                    $display("| x%-4d | 0x%08h   | 0x%08h   | PASS   |", i, shadow_rf[i], dut.s1.rf.regfile[i]);
            end else begin
                fail_count++;
                $display("| x%-4d | 0x%08h   | 0x%08h   | FAIL   |", i, shadow_rf[i], dut.s1.rf.regfile[i]);
            end
        end

        // 6. Report Results
        $display("\n==========================================================================");
        $display(" I-TYPE RANDOM REGRESSION SUMMARY (SEED: %0d)", seed);
        $display("==========================================================================");
        $display(" Registers Checked : 32");
        $display(" Passed            : %0d", pass_count);
        $display(" Failed            : %0d", fail_count);
        
        if (fail_count == 0)
            $display("\n STATUS            : SIGN-OFF PASS");
        else
            $display("\n STATUS            : FAILED (Hint: Check your Forwarding/Data Hazard Logic)");
        $display("==========================================================================\n");

        $finish;
    end

endmodule

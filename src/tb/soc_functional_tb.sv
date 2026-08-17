`timescale 1ns/1ps

// System-level smoke test for the direct path:
// CoreRV -> core2axi_lite -> AXI-Lite -> AXI-Lite-to-APB -> four peripherals.
//
// This version adds:
//   1) AXI-Lite VALID-stability protocol checks
//   2) APB SETUP/ACCESS phase protocol checks
//   3) Per-peripheral, per-transaction latency measurement (AXI-Lite start -> APB done,
//      and APB-only setup+access duration)
//   4) Stuck-write / non-advancing-PC early detector

module soc_functional_tb;
  logic clk = 1'b0;
  logic rst = 1'b1;

  logic [31:0] gpio_in = '0;
  logic [31:0] gpio_out, gpio_dir, gpio_in_sync;

  logic       spi_clk, spi_csn;
  logic [1:0] spi_mode;
  logic [3:0] spi_sdo;
  logic [3:0] spi_sdi = '0;

  // I²C lines are released and therefore read high due to pull-ups.
  logic scl_i = 1'b1;
  logic scl_o, scl_oe_n;
  logic sda_i = 1'b1;
  logic sda_o, sda_oe_n;

  logic [7:0] periph_irq;

  int unsigned gpio_write_count, gpio_read_count;
  int unsigned timer_write_count, timer_read_count;
  int unsigned spi_write_count, spi_read_count;
  int unsigned i2c_write_count, i2c_read_count;

  always #5 clk = ~clk;

    soc_top_axi_lite_apb dut (
    .clk              (clk),
    .rst              (rst),

    .gpio_in_i        (gpio_in),
    .gpio_out_o       (gpio_out),
    .gpio_dir_o       (gpio_dir),
    .gpio_in_sync_o   (gpio_in_sync),

    .spi_flash_clk_o  (spi_clk),
    .spi_flash_csn_o  (spi_csn),
    .spi_flash_mode_o (spi_mode),
    .spi_flash_sdo_o  (spi_sdo),
    .spi_flash_sdi_i  (spi_sdi),

    .scl_pad_i        (scl_i),
    .scl_pad_o        (scl_o),
    .scl_padoen_o     (scl_oe_n),
    .sda_pad_i        (sda_i),
    .sda_pad_o        (sda_o),
    .sda_padoen_o     (sda_oe_n),

    .periph_irq_o     (periph_irq)
  );

  // ===========================================================================
  // Boot program (fetched into CoreRV instruction RAM)
  //
  // Address map used by the current soc_top_axi_lite_apb:
  // GPIO=0x4000_0000, Timer=0x4000_1000, SPI=0x4000_2000, I2C=0x4000_3000.
  // Each peripheral receives one safe register write followed by a readback.
  // ===========================================================================
  initial begin
    #1;
    dut.corerv_i.core_i.s1.instr_mem.ram1.mem[ 0] = 32'h4000_00b7; // lui  x1, 0x40000
    dut.corerv_i.core_i.s1.instr_mem.ram1.mem[ 1] = 32'h0080_8093; // addi x1, x1, 8
    dut.corerv_i.core_i.s1.instr_mem.ram1.mem[ 2] = 32'h0aa0_0113; // addi x2, x0, 0xaa
    dut.corerv_i.core_i.s1.instr_mem.ram1.mem[ 3] = 32'h0020_a023; // sw   x2, 0(x1)
    dut.corerv_i.core_i.s1.instr_mem.ram1.mem[ 4] = 32'h0000_a183; // lw   x3, 0(x1)
    dut.corerv_i.core_i.s1.instr_mem.ram1.mem[ 5] = 32'h4000_1237; // lui  x4, 0x40001 (Timer)
    dut.corerv_i.core_i.s1.instr_mem.ram1.mem[ 6] = 32'h0000_0013; // nop: isolate address dependency
    dut.corerv_i.core_i.s1.instr_mem.ram1.mem[ 7] = 32'h0010_0593; // addi x11, x0, 1
    dut.corerv_i.core_i.s1.instr_mem.ram1.mem[ 8] = 32'h00b2_2223; // sw   x11, 4(x4): Timer CTRL
    dut.corerv_i.core_i.s1.instr_mem.ram1.mem[ 9] = 32'h0042_2283; // lw   x5, 4(x4): Timer CTRL
    dut.corerv_i.core_i.s1.instr_mem.ram1.mem[10] = 32'h4000_2337; // lui  x6, 0x40002 (SPI)
    dut.corerv_i.core_i.s1.instr_mem.ram1.mem[11] = 32'h0000_0013; // nop: isolate address dependency
    dut.corerv_i.core_i.s1.instr_mem.ram1.mem[12] = 32'h0023_2223; // sw   x2, 4(x6): SPI CLKDIV
    dut.corerv_i.core_i.s1.instr_mem.ram1.mem[13] = 32'h0043_2383; // lw   x7, 4(x6): SPI CLKDIV
    dut.corerv_i.core_i.s1.instr_mem.ram1.mem[14] = 32'h4000_3437; // lui  x8, 0x40003 (I2C)
    dut.corerv_i.core_i.s1.instr_mem.ram1.mem[15] = 32'h0000_0013; // nop: isolate address dependency
    dut.corerv_i.core_i.s1.instr_mem.ram1.mem[16] = 32'h0024_2023; // sw   x2, 0(x8): I2C prescaler
    dut.corerv_i.core_i.s1.instr_mem.ram1.mem[17] = 32'h0004_2483; // lw   x9, 0(x8): I2C prescaler
    dut.corerv_i.core_i.s1.instr_mem.ram1.mem[18] = 32'h0000_006f; // jal  x0, 0

    #39 rst = 1'b0;
  end

  // ===========================================================================
  // APB transfer counter + basic legality checks
  // Only PENABLE=1 with PREADY=1 is a completed APB access phase; PSEL with
  // PENABLE=0 is the preceding SETUP phase and is not counted here.
  // ===========================================================================
  always @(posedge clk) begin
    if (!rst && (dut.pselx != '0) && dut.penable && dut.pready) begin
      assert (!$isunknown(dut.pselx) && $onehot(dut.pselx))
        else $fatal(1, "APB selection must be one-hot: pselx=%b", dut.pselx);
      assert (!dut.pslverr)
        else $fatal(1, "Peripheral returned PSLVERR: pselx=%b addr=%h", dut.pselx, dut.paddr);

      unique case (dut.pselx)
        4'b0001: if (dut.pwrite) gpio_write_count++;  else gpio_read_count++;
        4'b0010: if (dut.pwrite) timer_write_count++; else timer_read_count++;
        4'b0100: if (dut.pwrite) spi_write_count++;   else spi_read_count++;
        4'b1000: if (dut.pwrite) i2c_write_count++;   else i2c_read_count++;
        default: $fatal(1, "Invalid APB selection: %b", dut.pselx);
      endcase
    end
  end

  // ===========================================================================
  // AXI-Lite activity monitor (raw handshake trace)
  // ===========================================================================
  always @(posedge clk) begin
    if (!rst && (dut.core_lite_bus.aw_valid || dut.core_lite_bus.w_valid ||
                 dut.core_lite_bus.ar_valid || dut.core_lite_bus.b_valid ||
                 dut.core_lite_bus.r_valid)) begin
      $display("[T=%0t] AXI-Lite AW=%b/%b W=%b/%b AR=%b/%b B=%b/%b R=%b/%b",
        $time,
        dut.core_lite_bus.aw_valid, dut.core_lite_bus.aw_ready,
        dut.core_lite_bus.w_valid,  dut.core_lite_bus.w_ready,
        dut.core_lite_bus.ar_valid, dut.core_lite_bus.ar_ready,
        dut.core_lite_bus.b_valid,  dut.core_lite_bus.b_ready,
        dut.core_lite_bus.r_valid,  dut.core_lite_bus.r_ready);
    end
  end

  // ===========================================================================
  // 1) AXI-Lite VALID-stability protocol checks
  //    Spec rule: once VALID is asserted, it must not be deasserted until the
  //    matching READY is observed in the same cycle.
  // ===========================================================================
  logic aw_valid_q, w_valid_q, ar_valid_q;
  always @(posedge clk) begin
    if (rst) begin
      aw_valid_q <= 0; w_valid_q <= 0; ar_valid_q <= 0;
    end else begin
      if (aw_valid_q && !dut.core_lite_bus.aw_ready)
        assert (dut.core_lite_bus.aw_valid)
          else $error("[T=%0t] AXI-Lite VIOLATION: AW_VALID dropped without AW_READY", $time);
      if (w_valid_q && !dut.core_lite_bus.w_ready)
        assert (dut.core_lite_bus.w_valid)
          else $error("[T=%0t] AXI-Lite VIOLATION: W_VALID dropped without W_READY", $time);
      if (ar_valid_q && !dut.core_lite_bus.ar_ready)
        assert (dut.core_lite_bus.ar_valid)
          else $error("[T=%0t] AXI-Lite VIOLATION: AR_VALID dropped without AR_READY", $time);

      aw_valid_q <= dut.core_lite_bus.aw_valid && !dut.core_lite_bus.aw_ready;
      w_valid_q  <= dut.core_lite_bus.w_valid  && !dut.core_lite_bus.w_ready;
      ar_valid_q <= dut.core_lite_bus.ar_valid && !dut.core_lite_bus.ar_ready;
    end
  end

  // ===========================================================================
  // 2) APB SETUP -> ACCESS phase protocol checks
  //    Spec rule: PENABLE must be low the cycle PSEL first asserts (SETUP),
  //    then go high the following cycle (ACCESS). Control signals must stay
  //    stable through ACCESS until PREADY.
  // ===========================================================================
  logic psel_q;
  always @(posedge clk) begin
    if (rst) begin
      psel_q <= 0;
    end else begin
      if (dut.pselx != '0 && !psel_q)
        assert (!dut.penable)
          else $error("[T=%0t] APB VIOLATION: PENABLE high same cycle PSEL asserted (SETUP phase broken)", $time);

      if (dut.penable && !dut.pready) begin
        assert ($stable(dut.pselx) && $stable(dut.paddr) && $stable(dut.pwrite))
          else $error("[T=%0t] APB VIOLATION: control signals changed mid-ACCESS before PREADY", $time);
      end

      psel_q <= (dut.pselx != '0);
    end
  end

  // ===========================================================================
  // 3) Per-peripheral, per-transaction latency measurement
  //    "AXI-Lite->done"  = cycles from core's AXI-Lite request acceptance
  //                        through APB completion (full bridge + peripheral path)
  //    "APB-only"        = cycles from APB SETUP phase start through PREADY
  //                        (isolates peripheral-side latency from bridge latency)
  // ===========================================================================
  function automatic string periph_name(logic [3:0] sel);
    case (sel)
      4'b0001: return "GPIO ";
      4'b0010: return "TIMER";
      4'b0100: return "SPI  ";
      4'b1000: return "I2C  ";
      default:  return "UNK  ";
    endcase
  endfunction

  int unsigned cycle_count;
  always @(posedge clk) begin
    if (rst) cycle_count <= 0;
    else     cycle_count <= cycle_count + 1;
  end

  int unsigned wr_axi_start, wr_apb_start;
  int unsigned rd_axi_start, rd_apb_start;
  logic wr_pending, rd_pending;
  logic apb_access_prev;

  always @(posedge clk) begin
    if (rst) begin
      wr_pending <= 0; rd_pending <= 0; apb_access_prev <= 0;
    end else begin
      // Latch AXI-Lite write start once AW and W are both accepted
      if (dut.core_lite_bus.aw_valid && dut.core_lite_bus.aw_ready &&
          dut.core_lite_bus.w_valid  && dut.core_lite_bus.w_ready && !wr_pending) begin
        wr_axi_start <= cycle_count;
        wr_pending   <= 1'b1;
      end
      // Latch AXI-Lite read start once AR is accepted
      if (dut.core_lite_bus.ar_valid && dut.core_lite_bus.ar_ready && !rd_pending) begin
        rd_axi_start <= cycle_count;
        rd_pending   <= 1'b1;
      end

      // Latch APB SETUP-phase start (pselx just asserted, penable still 0)
      if (dut.pselx != '0 && !apb_access_prev && !dut.penable) begin
        if (dut.pwrite) wr_apb_start <= cycle_count;
        else             rd_apb_start <= cycle_count;
      end
      apb_access_prev <= (dut.pselx != '0);

      // APB transfer completes -> print latency, clear pending flag
      if ((dut.pselx != '0) && dut.penable && dut.pready) begin
        if (dut.pwrite && wr_pending) begin
          $display("[LATENCY] %s WRITE  addr=%h | AXI-Lite->done: %0d cyc | APB-only: %0d cyc",
                    periph_name(dut.pselx), dut.paddr,
                    cycle_count - wr_axi_start, cycle_count - wr_apb_start + 1);
          wr_pending <= 1'b0;
        end else if (!dut.pwrite && rd_pending) begin
          $display("[LATENCY] %s READ   addr=%h | AXI-Lite->done: %0d cyc | APB-only: %0d cyc",
                    periph_name(dut.pselx), dut.paddr,
                    cycle_count - rd_axi_start, cycle_count - rd_apb_start + 1);
          rd_pending <= 1'b0;
        end
      end
    end
  end

  // ===========================================================================
  // 4) Stuck-write / non-advancing-PC early detector
  //    Fires a warning as soon as the same APB write (same addr+data) repeats
  //    10 times in a row, instead of waiting for the full run to time out.
  // ===========================================================================
  logic [31:0] last_waddr, last_wdata;
  int unsigned same_write_repeats;

  always @(posedge clk) begin
    if (rst) begin
      same_write_repeats <= 0;
    end else if ((dut.pselx != '0) && dut.penable && dut.pready && dut.pwrite) begin
      if (dut.paddr == last_waddr && dut.pwdata == last_wdata) begin
        same_write_repeats <= same_write_repeats + 1;
        if (same_write_repeats == 10)
          $display("[WARN T=%0t] Same write (addr=%h data=%h) repeated 10x — PC is likely not advancing.",
                    $time, dut.paddr, dut.pwdata);
      end else begin
        same_write_repeats <= 0;
      end
      last_waddr <= dut.paddr;
      last_wdata <= dut.pwdata;
    end
  end

  // ===========================================================================
  // Main sequence: dump waves, run, check final results
  // ===========================================================================
  initial begin
    // EDA Playground/EPWave detects the conventional dump.vcd filename.
    $dumpfile("dump.vcd");
    // Level 0 captures every signal below this testbench, including CoreRV,
    // the AXI-Lite interface, APB bridge, peripheral registers, and IRQ bus.
    $dumpvars(0, soc_functional_tb);
    #20_000;

    assert (gpio_write_count == 1)
      else $fatal(1, "Expected one GPIO write, got %0d", gpio_write_count);
    assert (gpio_read_count == 1)
      else $fatal(1, "Expected one GPIO read, got %0d", gpio_read_count);
    assert (timer_write_count == 1 && timer_read_count == 1)
      else $fatal(1, "Expected one Timer read, got %0d", timer_read_count);
    assert (spi_write_count == 1 && spi_read_count == 1)
      else $fatal(1, "Expected one SPI read, got %0d", spi_read_count);
    assert (i2c_write_count == 1 && i2c_read_count == 1)
      else $fatal(1, "Expected one I2C read, got %0d", i2c_read_count);
    assert (dut.i_gpio.gpio_out == 32'h0000_00aa)
      else $fatal(1, "GPIO PADOUT is %h, expected 000000aa", dut.i_gpio.gpio_out);
    assert (dut.corerv_i.core_i.s1.rf.regfile[3] == 32'h0000_00aa)
      else $fatal(1, "GPIO load wrote x3=%h, expected 000000aa",
                  dut.corerv_i.core_i.s1.rf.regfile[3]);
    assert (dut.corerv_i.core_i.s1.rf.regfile[5] == 32'h0000_0001)
      else $fatal(1, "Timer CTRL readback x5=%h", dut.corerv_i.core_i.s1.rf.regfile[5]);
    assert (dut.corerv_i.core_i.s1.rf.regfile[7] == 32'h0000_00aa)
      else $fatal(1, "SPI CLKDIV readback x7=%h", dut.corerv_i.core_i.s1.rf.regfile[7]);
    assert (dut.corerv_i.core_i.s1.rf.regfile[9] == 32'h0000_00aa)
      else $fatal(1, "I2C prescaler readback x9=%h", dut.corerv_i.core_i.s1.rf.regfile[9]);

    $display("PASS: CoreRV completed APB read/write tests for GPIO, Timer, SPI, and I2C.");
    $finish;
  end
endmodule

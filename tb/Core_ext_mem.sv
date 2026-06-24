`timescale 1ns/1ps

module Core_ext_mem;

logic clk;
logic rst;

Core_Wrap dut(
    .clk(clk),
    .rst_(rst)
);

always #5 clk = ~clk;

initial begin
    clk = 1'b0;
    rst = 1'b1;
//   for (int i = 0; i < 256; i++) begin
//             dut.s1.instr_mem.ram1.mem[i] = 32'h00000013;
//   end
  dut.core1.s1.instr_mem.ram1.mem[0] = 32'h00000013; // nop
  dut.core1.s1.instr_mem.ram1.mem[1] = 32'h0030A023; // sw x3, 0(x1)
  dut.core1.s1.instr_mem.ram1.mem[2] = 32'h0050a223; // sw x5, 4(x1)
  //dut.s1.instr_mem.ram1.mem[1] = 32'h00309023; // sh x3, 0(x1)
//dut.s1.instr_mem.ram3.mem[2] = 32'h0000A103; // lw x2, 0(x1)
  //dut.s1.instr_mem.ram1.mem[2] = 32'h00009103; // lh x2, 0(x1)
  dut.core1.s1.instr_mem.ram1.mem[3] = 32'h00022103; // lw x2, 0(x4)
  //dut.s1.instr_mem.ram1.mem[2] = 32'h00218233; // nop
  //dut.s1.instr_mem.ram1.mem[4] = 32'h00000013; // nop
//dut.s1.instr_mem.ram1.mem[5] = 32'h00000013; // nop
  
  for (int i = 4; i < 64; i++)
            dut.core1.s1.instr_mem.ram1.mem[i] = 32'h00000013;

    repeat(4) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;
    // -------------------------------------------------
    // Register Initialization
    // -------------------------------------------------
  //dut.s1.rf.regfile[1]  = 32'h00010000;
  dut.core1.s1.rf.regfile[1]  = 32'h00000300;
  dut.core1.s1.rf.regfile[2]  = 2;

  dut.core1.s1.rf.regfile[3]  = 32'hAABBCCDD;
  dut.core1.s1.rf.regfile[4]  = 32'h00000302;
  dut.core1.s1.rf.regfile[5]  = 32'hEEFF1122;
  repeat(50) @(posedge clk);

  $display("x1=%0d", dut.core1.s1.rf.regfile[1]);
  $display("x2=%h", dut.core1.s1.rf.regfile[2]);

  $display("x3=%h", dut.core1.s1.rf.regfile[3]);
  $display("dram mem[0]=%h", dut.core1.dram.ram2.mem[0]);
  $display("iram mem[0]=%h", dut.core1.s1.instr_mem.ram3.mem[0]);
  $display("boot_mode=%0d", dut.core1.boot_mode);
  $display("sram_ext [0]=%h", dut.ext_mem.mem[0]);
  $display("sram_ext [1]=%h", dut.ext_mem.mem[1]);





  $finish;
end

initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, dut);
end
endmodule
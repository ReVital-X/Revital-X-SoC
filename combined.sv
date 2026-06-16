`timescale 1ns / 1ps
module alu_in1_mux #(
    parameter WIDTH = 32
)(
    input  logic [WIDTH-1:0] rs1,     // data from source register 1 from Register file
    input  logic [WIDTH-1:0] imm,     // Immediate value
    input  logic             Lui,     // control signal
    output logic [WIDTH-1:0] alu_in1  // First input for the ALU
);
    // MUX logic
    always_comb begin
        if (Lui)
            alu_in1 = imm;     // if Lui = 1 , then 12 bit shifted input is selected as 1st input for ALU
        else
            alu_in1 = rs1;    // if Lui = 0 , then source register 1 is selected as 1st input for ALU
    end

endmodule
/*
===============================================================================
Module Name : alu_in2_mux
===============================================================================

Description:
------------
This module implements a 4-to-1 multiplexer for selecting the second input
to the ALU (alu_in2) in a RISC-V datapath.

The selection is controlled by two control signals:
    1. Lui
    2. ALUSrc

These two signals together form a 2-bit select input:
    sel = {Lui, ALUSrc}

Selection Logic:
----------------
    Lui  ALUSrc   alu_in2 Output
    --------------------------------
     0     0      rs2       (Register value - R-type instructions)
     0     1      imm       (Immediate value - I-type instructions)
     1     0      0         (Used in LUI instruction)
     1     1      pc        (Used in AUIPC instruction)
===============================================================================
*/
`timescale 1ns / 1ps
module alu_in2_mux #(
    parameter WIDTH = 32   // Width of data bus (default = 32 bits)
)(
    input  logic [WIDTH-1:0] rs2,     // Register source 2
    input  logic [WIDTH-1:0] imm,     // Immediate value
    input  logic [WIDTH-1:0] pc,      // Program counter
    input  logic             Lui,     // Control signal for LUI/AUIPC
    input  logic             ALUSrc,  // Control signal for ALU source select
    output logic [WIDTH-1:0] alu_in2  // Output to ALU
);

    // ------------------------------------------------------------------------
    // Combinational MUX Logic
    // Selects one of the inputs based on {Lui, ALUSrc}
    // ------------------------------------------------------------------------
    always_comb begin
        alu_in2 = '0;
        case ({Lui, ALUSrc})

            // 00 → Select register value (rs2)
            2'b00: alu_in2 = rs2;

            // 01 → Select immediate value (imm)
            2'b01: alu_in2 = imm;

            // 10 → Select zero (used in LUI)
            2'b10: alu_in2 = '0;

            // 11 → Select program counter (pc) (used in AUIPC)
            2'b11: alu_in2 = pc;

        endcase
    end

endmodule
// module for selecting the output from alu or the multipler
`timescale 1ns / 1ps
module alu_mul_mux #(
    parameter WIDTH = 32                 // 32-bit
)(
    input  logic [WIDTH-1:0] alu_result, // output from alu
    input  logic [WIDTH-1:0] mul_result, // output from multiplier
    input  logic             Mul,        // select signal Mul from the control unit
    output logic [WIDTH-1:0] exec_result
);

    always_comb begin
        if (Mul)
            exec_result = mul_result;   // if Mul=1 the result of multiplier goes to execute stage
        else
            exec_result = alu_result;   // if Mul=0 the result of alu goes to execute stage
    end

endmodule
`timescale 1ns / 1ps
module alu(
    input  logic [31:0] a, b,
    input  logic [3:0]  Control,
    input  logic        branch,
    output logic [31:0] result,
    output logic        compare_out
);

always_comb begin
    result      = 32'd0;
    compare_out = 1'b0;

    if (branch) begin
        unique case (Control)
            4'b1000: compare_out = (a == b);                   // BEQ
            4'b1001: compare_out = (a != b);                   // BNE
            4'b1100: compare_out = ($signed(a) < $signed(b));  // BLT
            4'b1101: compare_out = ($signed(a) >= $signed(b)); // BGE
            4'b1110: compare_out = (a < b);                    // BLTU
            4'b1111: compare_out = (a >= b);                   // BGEU
            default: compare_out = 1'b0;
        endcase
    end 
    else begin
        unique case (Control)
            4'b0000: result = a + b;                           // ADD
            4'b1000: result = a - b;                           // SUB
            4'b0100: result = a ^ b;                           // XOR
            4'b0110: result = a | b;                           // OR
            4'b0111: result = a & b;                           // AND

            // Shift
            4'b0001: result = a << b[4:0];                     // SLL
            4'b0101: result = a >> b[4:0];                     // SRL
            4'b1101: result = $signed(a) >>> b[4:0];           // SRA

            // Set Less Than
            4'b0010: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // SLT
            4'b0011: result = (a < b) ? 32'd1 : 32'd0;                   // SLTU

            default: result = 32'd0;
        endcase
    end
end

endmodule
`timescale 1ns / 1ps
module immediate_generator (
    input  logic [31:0] instr,
    output logic [31:0] imm_out
);

    logic [6:0] opcode;
    assign opcode = instr[6:0];

    always_comb begin
        unique case (opcode)

            // I-Type (ALU, LOAD, JALR)
            7'b0010011,
            7'b0000011,
            7'b1100111: begin
                imm_out = {{20{instr[31]}}, instr[31:20]};
            end

            // S-Type (STORE)
            7'b0100011: begin 
                imm_out = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            end
            
            // B-Type (BRANCH)
            7'b1100011: begin
                imm_out = {{19{instr[31]}}, instr[31], instr[7],instr[30:25], instr[11:8], 1'b0};
            end

            // U-Type (LUI, AUIPC)
            7'b0110111,
            7'b0010111: begin
                imm_out = {instr[31:12], 12'b0}; 
            end

            // J-Type (JAL)
            7'b1101111: begin
                imm_out = {{11{instr[31]}}, instr[31], instr[19:12],instr[20], instr[30:21], 1'b0};
            end

            default: begin
                imm_out = 32'd0;
            end

        endcase
    end

endmodule
`timescale 1ns / 1ps
module pc_mux (
    input  logic [31:0] branch_addr,
    input  logic [31:0] alu_result,
    input  logic [1:0]  pcsrc,
    input  logic        pc_stall,
    output logic [31:0] pc_in,
    input logic [31:0] PC
);

always_comb begin
    case (pcsrc)
        2'b10: pc_in = alu_result;     // JALR
        2'b01: pc_in = branch_addr;    // Branch
        default: begin
            if (pc_stall)
                pc_in = PC;
            else
                pc_in = PC + 4;
        end
    endcase
end
endmodule
/*
===============================================================================
Module Name : memtoreg_mux
===============================================================================

It selects the data that should be written back to the register file (wb_data)
based on the control signal `MemtoReg`.

The control signal is 2 bits wide and determines the data source.

Selection Logic:
    --------------------------------
    MemtoReg   wb_data Output
    --------------------------------
      00       alu_result   (ALU operations)
      01       mem_data     (Load instructions - lw)
      10       pc_4         (Jump instructions - jal/jalr)
      11       0            (Default / safe value)

Usage:
------
- R-type / I-type ALU instructions:
    write ALU result → MemtoReg = 00

- Load instructions (e.g., lw):
    write memory data → MemtoReg = 01

- Jump instructions (jal, jalr):
    write return address (PC + 4) → MemtoReg = 10

- Default / unused case:
    output zero
===============================================================================
*/
`timescale 1ns / 1ps
module memtoreg_mux #(
    parameter WIDTH = 32   // Data width (default = 32-bit RISC-V)
)(
    input  logic [WIDTH-1:0] alu_result, // Result from ALU
    input  logic [WIDTH-1:0] mem_data,   // Data read from memory
    input  logic [WIDTH-1:0] pc,       // PC 
    input  logic [1:0]       MemtoReg,   // Control signal (2-bit select)
    output logic [WIDTH-1:0] wb_data     // Data written back to register file
);
    // ------------------------------------------------------------------------
    // Combinational MUX Logic
    // Selects which data goes to the register file
    // ------------------------------------------------------------------------
    always_comb begin
        wb_data = '0;
        case (MemtoReg)
            // 00 → ALU result (normal arithmetic/logical instructions)
            2'b00: wb_data = alu_result;
            // 01 → Memory data (load instructions like lw)
            2'b01: wb_data = mem_data;
            // 10 → PC + 4 (used in jal/jalr for return address)
            2'b10: wb_data = pc+4;
            // 11 → Default
            default: wb_data = '0;
        endcase
    end
endmodule
`timescale 1ns/1ps
module register_file (
    input  logic        clk, rst,          // Clock and asynchronous reset
    input  logic [4:0]  rs1, rs2, rd,      // Register addresses (32 registers → 5 bits)
    input  logic [31:0] rd_value,          // Data to be written into destination register
    input  logic        regwrite,          // Write enable signal
    output logic [31:0] rs1_value,         // Read data from rs1
    output logic [31:0] rs2_value          // Read data from rs2
);

    // 32 registers, each 32-bit wide

    logic [31:0] regfile [31:0];


    // WRITE + RESET LOGIC (Sequential)
    
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++)
                regfile[i] <= 32'b0;
        end
        else if (regwrite && (rd != 5'd0)) begin
            // Write operation (x0 is always zero, so ignore rd = 0)
            regfile[rd] <= rd_value;
        end
    end

  
    // This combinational logic implements the read ports with bypassing for the current write.
    //     addi x5, x0, 10
    //     addi x6, x0, 20
    //     addi x7, x0, 30
    //     ori  x8, x5, 1 (The value of x5 should be 10, not the previous value, even though the write to x5 happens in the same cycle as the read for x5)

assign rs1_value =(rs1 == 5'd0) ? 32'd0 :(regwrite && (rd != 5'd0) && (rs1 == rd)) ? rd_value : regfile[rs1];

assign rs2_value =(rs2 == 5'd0) ? 32'd0 :(regwrite && (rd != 5'd0) && (rs2 == rd)) ? rd_value : regfile[rs2];

endmodule  
`timescale 1ns / 1ps
module sp_ram
  #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter NUM_WORDS  = 256
  )(
    // Clock and Reset
    input  logic                    clk,

    input  logic                    en_i,
    input  logic [ADDR_WIDTH-1:0]   addr_i,
    input  logic [DATA_WIDTH-1:0]   wdata_i,
    output logic [DATA_WIDTH-1:0]   rdata_o,
    input  logic                    we_i,
    input  logic [DATA_WIDTH/8-1:0] be_i
  );

  localparam int words = NUM_WORDS;

  logic [DATA_WIDTH/8-1:0][7:0] mem[words];
  logic [DATA_WIDTH/8-1:0][7:0] wdata;
  logic [ADDR_WIDTH-1:0] addr;

  integer i;


  assign addr = addr_i;


  always @(posedge clk)
  begin
    if (en_i && we_i)
    begin
      for (i = 0; i < DATA_WIDTH/8; i++) begin
        if (be_i[i])
          mem[addr][i] <= wdata[i];
      end
    end
    if(en_i)
      rdata_o <= mem[addr];
  end

  genvar w;
  generate for(w = 0; w < DATA_WIDTH/8; w++)
    begin
      assign wdata[w] = wdata_i[(w+1)*8-1:w*8];
    end
  endgenerate

endmodule
`timescale 1ns / 1ps
module dp_ram
  #(
    parameter ADDR_WIDTH = 8
  )(
    // Clock and Reset
    input  logic clk,

    input  logic                   en_a_i,
    input  logic [ADDR_WIDTH-1:0]  addr_a_i,
    input  logic [31:0]            wdata_a_i,
    output logic [31:0]            rdata_a_o,
    input  logic                   we_a_i,
    input  logic [3:0]             be_a_i,

    input  logic                   en_b_i,
    input  logic [ADDR_WIDTH-1:0]  addr_b_i,
    input  logic [31:0]            wdata_b_i,
    output logic [31:0]            rdata_b_o,
    input  logic                   we_b_i,
    input  logic [3:0]             be_b_i
  );

  localparam words = 2**ADDR_WIDTH;

  logic [3:0][7:0] mem[words];

  always @(posedge clk)
  begin
    if (en_a_i && we_a_i)
    begin
      if (be_a_i[0])
        mem[addr_a_i][0] <= wdata_a_i[7:0];
      if (be_a_i[1])
        mem[addr_a_i][1] <= wdata_a_i[15:8];
      if (be_a_i[2])
        mem[addr_a_i][2] <= wdata_a_i[23:16];
      if (be_a_i[3])
        mem[addr_a_i][3] <= wdata_a_i[31:24];
    end
  if (en_a_i)
    rdata_a_o <= mem[addr_a_i];

    if (en_b_i && we_b_i)
    begin
      if (be_b_i[0])
        mem[addr_b_i][0] <= wdata_b_i[7:0];
      if (be_b_i[1])
        mem[addr_b_i][1] <= wdata_b_i[15:8];
      if (be_b_i[2])
        mem[addr_b_i][2] <= wdata_b_i[23:16];
      if (be_b_i[3])
        mem[addr_b_i][3] <= wdata_b_i[31:24];
    end
  if (en_b_i)
    rdata_b_o <= mem[addr_b_i];
  end

endmodule
`timescale 1ns / 1ps
module data_ram
  #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter NUM_WORDS  = 256
  )(
    // Clock and Reset
    input  logic                    clk,

    input  logic                    en_i,
    input  logic [ADDR_WIDTH-1:0]   addr_i,
    input  logic [DATA_WIDTH-1:0]   wdata_i,
    output logic [DATA_WIDTH-1:0]   rdata_o,
    input  logic                    we_i,
    input  logic [DATA_WIDTH/8-1:0] be_i,
    input logic sign_ext_i
  );
logic [31:0] rdata_o1;
logic sign_ext_i_reg;
logic [DATA_WIDTH/8-1:0] be_i_reg;
sp_ram #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_WORDS(NUM_WORDS)
) ram2 (
    .clk(clk),
    .en_i(en_i),
    .addr_i(addr_i),
    .wdata_i(wdata_i),
    .rdata_o(rdata_o1),
    .we_i(we_i),
    .be_i(be_i)
);
always_ff @(posedge clk) begin
    be_i_reg <= be_i;
    sign_ext_i_reg <= sign_ext_i;
end
// load access for lb/lh/lw with sign/zero extension
always_comb begin
  if(sign_ext_i_reg) begin
    case (be_i_reg)
    // byte loads/stores
      4'b0001: rdata_o = {{24{rdata_o1[7]}}, rdata_o1[7:0]};
      4'b0010: rdata_o = {{24{rdata_o1[15]}}, rdata_o1[15:8]};
      4'b0100: rdata_o = {{24{rdata_o1[23]}}, rdata_o1[23:16]};
      4'b1000: rdata_o = {{24{rdata_o1[31]}}, rdata_o1[31:24]};
    // halfword loads/stores
      4'b0011: rdata_o = {{16{rdata_o1[15]}}, rdata_o1[15:0]};
      4'b0110: rdata_o = {{16{rdata_o1[23]}}, rdata_o1[23:8]};
      4'b1100: rdata_o = {{16{rdata_o1[31]}}, rdata_o1[31:16]};
      4'b1001: rdata_o = {{16{rdata_o1[31]}}, rdata_o1[31:24], rdata_o1[7:0]};
      default: rdata_o = rdata_o1;
    endcase
  end else begin
    case (be_i_reg)
    // byte loads/stores
      4'b0001: rdata_o = {24'b0, rdata_o1[7:0]};
      4'b0010: rdata_o = {24'b0, rdata_o1[15:8]};
      4'b0100: rdata_o = {24'b0, rdata_o1[23:16]};
      4'b1000: rdata_o = {24'b0, rdata_o1[31:24]};
    // halfword loads/stores
      4'b0011: rdata_o = {16'b0, rdata_o1[15:0]};
      4'b0110: rdata_o = {16'b0, rdata_o1[23:8]};
      4'b1100: rdata_o = {16'b0, rdata_o1[31:16]};
      4'b1001: rdata_o = {16'b0, rdata_o1[31:24], rdata_o1[7:0]};
      default: rdata_o = rdata_o1;
    endcase
  end
end
endmodule
`timescale 1ns / 1ps
module instr_ram
  #(
    parameter INSTR_ADDR_WIDTH = 8,
    parameter BOOT_ADDR_WIDTH  = 8,
    parameter INSTR_WORDS      = 256,
    parameter BOOT_WORDS       = 256
  )(
    // Clock and Reset
    input  logic clk,
    input logic boot_mode,

    input  logic                   en_a_i,
    input  logic [BOOT_ADDR_WIDTH-1:0]  addr_boot_a_i,
    input  logic [INSTR_ADDR_WIDTH-1:0]  addr_instr_a_i,
    input  logic [31:0]            wdata_a_i,
    output logic [31:0]            rdata_a_o,
    input  logic                   we_a_i,
    input  logic [3:0]             be_a_i,

    input  logic                   en_b_i,
    input  logic [INSTR_ADDR_WIDTH-1:0]  addr_b_i,
    input  logic [31:0]            wdata_b_i,
    output logic [31:0]            rdata_b_o,
    input  logic                   we_b_i,
    input  logic [3:0]             be_b_i,
    input  logic                   sign_ext_b_i
  );
logic en_1_i, we_1_i;
logic [BOOT_ADDR_WIDTH-1:0] addr_1_i;
logic [31:0] wdata_1_i, rdata_1_o;
logic [3:0] be_1_i;

logic en_2_i, we_2_i;
logic [INSTR_ADDR_WIDTH-1:0] addr_2_i;
logic [31:0] wdata_2_i, rdata_2_o;
logic [3:0] be_2_i;
logic [3:0] be_b_i_reg;
logic sign_ext_b_i_reg;
always_ff @(posedge clk) begin
    be_b_i_reg <= be_b_i;
    sign_ext_b_i_reg <= sign_ext_b_i;
end
always_comb begin
  en_1_i    = 1'b0;
  addr_1_i  = '0;
  wdata_1_i = '0;
  we_1_i    = 1'b0;
  be_1_i    = '0;

  en_2_i    = 1'b0;
  addr_2_i  = '0;
  wdata_2_i = '0;
  we_2_i    = 1'b0;
  be_2_i    = '0;

  rdata_a_o = 32'b0;
  rdata_b_o = 32'b0;

  if (boot_mode) begin
    // Fetch from boot memory
    en_1_i    = en_a_i;
    addr_1_i  = addr_boot_a_i;
    wdata_1_i = wdata_a_i;
    we_1_i    = we_a_i;
    be_1_i    = be_a_i;
    rdata_a_o = rdata_1_o;

    // MEM stage can access instruction memory
    en_2_i    = en_b_i;
    addr_2_i  = addr_b_i;
    wdata_2_i = wdata_b_i;
    we_2_i    = we_b_i;
    be_2_i    = be_b_i;
    if(sign_ext_b_i_reg) begin
      case (be_b_i_reg)
      // byte loads/stores
        4'b0001: rdata_b_o = {{24{rdata_2_o[7]}}, rdata_2_o[7:0]};
        4'b0010: rdata_b_o = {{24{rdata_2_o[15]}}, rdata_2_o[15:8]};
        4'b0100: rdata_b_o = {{24{rdata_2_o[23]}}, rdata_2_o[23:16]};
        4'b1000: rdata_b_o = {{24{rdata_2_o[31]}}, rdata_2_o[31:24]};
      // halfword loads/stores
        4'b0011: rdata_b_o = {{16{rdata_2_o[15]}}, rdata_2_o[15:0]};
        4'b0110: rdata_b_o = {{16{rdata_2_o[23]}}, rdata_2_o[23:8]};
        4'b1100: rdata_b_o = {{16{rdata_2_o[31]}}, rdata_2_o[31:16]};
        4'b1001: rdata_b_o = {{16{rdata_2_o[31]}}, rdata_2_o[31:24], rdata_2_o[7:0]};
        default: rdata_b_o = rdata_2_o;
      endcase
    end else begin
      case (be_b_i_reg)
      // byte loads/stores
        4'b0001: rdata_b_o = {24'b0, rdata_2_o[7:0]};
        4'b0010: rdata_b_o = {24'b0, rdata_2_o[15:8]};
        4'b0100: rdata_b_o = {24'b0, rdata_2_o[23:16]};
        4'b1000: rdata_b_o = {24'b0, rdata_2_o[31:24]};
      // halfword loads/stores
        4'b0011: rdata_b_o = {16'b0, rdata_2_o[15:0]};
        4'b0110: rdata_b_o = {16'b0, rdata_2_o[23:8]};
        4'b1100: rdata_b_o = {16'b0, rdata_2_o[31:16]};
        4'b1001: rdata_b_o = {16'b0, rdata_2_o[31:24], rdata_2_o[7:0]};
        default: rdata_b_o = rdata_2_o;
      endcase
    end
  end else begin
    // Fetch from instruction memory
    en_2_i    = en_a_i;
    addr_2_i  = addr_instr_a_i;
    wdata_2_i = wdata_a_i;
    we_2_i    = we_a_i;
    be_2_i    = be_a_i;
    rdata_a_o = rdata_2_o;

    // Boot memory inaccessible, MEM port disabled
    rdata_b_o = 32'b0;
  end
end
  // boot memory
   sp_ram #(
    .ADDR_WIDTH(BOOT_ADDR_WIDTH), // INSTR_ADDR - BOOT_ADDR Space
    .DATA_WIDTH(32),
    .NUM_WORDS(BOOT_WORDS)
   ) ram1(
    .clk(clk),
    .en_i(en_1_i),
    .addr_i(addr_1_i),
    .wdata_i(wdata_1_i),
    .rdata_o(rdata_1_o),
    .we_i(we_1_i),
    .be_i(be_1_i)
   );

   // instruction memory
   sp_ram #(
    .ADDR_WIDTH(INSTR_ADDR_WIDTH),  // DATA_ADDR - INSTR_ADDR Space
    .DATA_WIDTH(32),
    .NUM_WORDS(INSTR_WORDS)
   ) ram3(
    .clk(clk),
    .en_i(en_2_i),
    .addr_i(addr_2_i),
    .wdata_i(wdata_2_i),
    .rdata_o(rdata_2_o),
    .we_i(we_2_i),
    .be_i(be_2_i)
   );

endmodule
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
`timescale 1ns / 1ps
module Control_Unit (
    input  logic [6:0] opcode,        // opcode
    input  logic [2:0] funct3,
    input  logic       funct7_5,  // Instr[30]
    input  logic       funct7_0,  // Instr[25] (M extension)

    // Control Outputs
    output logic       RegWrite,
    output logic [1:0] MemtoReg,
    output logic       ALUSrc,
    output logic       Lui,
    output logic [3:0] ALUControl,
    output logic       Jump,
    output logic       Branch,
    output logic       Mul,
    output logic       M_ctrl,
    output logic       lsu_req,
    output logic       lsu_we,
    output logic [1:0] lsu_type,
    output logic       lsu_sign_ext
);

    // Internal signals
    logic [1:0] ALUOp;

    // =========================
    // MAIN DECODER
    // =========================
    always_comb begin
        // Default values (avoid latches)
        RegWrite   = 0;
        ALUSrc     = 0;
        Lui        = 0;
        MemtoReg   = 2'b00;
        Jump       = 0;
        Branch     = 0;
        ALUOp      = 2'b00;
        lsu_req    = 0;
        lsu_we     = 0;
        lsu_type   = 2'b00;
        lsu_sign_ext = 0;
        case (opcode)

            // LOAD (lw)
            7'b0000011: begin
                RegWrite  = 1;
                ALUSrc    = 1;
                Lui       = 0;
                MemtoReg  = 2'b01;
                Jump      = 0;
                Branch    = 0;
                ALUOp     = 2'b00;
                lsu_req    = 1;
                lsu_we     = 0;
                case(funct3)
                3'b000: begin
                    lsu_type   = 2'b10;
                    lsu_sign_ext = 1;
                end
                3'b001: begin
                    lsu_type   = 2'b01;
                    lsu_sign_ext = 1;
                end
                3'b010: begin
                    lsu_type   = 2'b00;
                    lsu_sign_ext = 1;
                end
                3'b100: begin
                    lsu_type   = 2'b10;
                    lsu_sign_ext = 0;
                end
                3'b101: begin
                    lsu_type   = 2'b01;
                    lsu_sign_ext = 0;
                end
                default :begin
                    lsu_type   = 2'b00;
                    lsu_sign_ext = 1;
                end
                endcase
            end

            // STORE (sw)
            7'b0100011: begin
                RegWrite  = 0;
                ALUSrc    = 1;
                Lui       = 0;
                MemtoReg  = 2'b11;
                Jump      = 0;
                Branch    = 0;
                ALUOp     = 2'b00;
                lsu_req    = 1;
                lsu_we     = 1;
                case(funct3)
                3'b000:
                    lsu_type   = 2'b10;
                3'b001: 
                    lsu_type   = 2'b01;
                3'b010: 
                    lsu_type   = 2'b00;
                default:
                    lsu_type   = 2'b00;
            endcase
            end

            // R-TYPE // MUL (M extension)
            7'b0110011: begin
                RegWrite  = 1;
                ALUSrc    = 0;
                Lui       = 0;
                MemtoReg  = 2'b00;
                Jump      = 0;
                Branch    = 0;
                ALUOp     = 2'b10;
            end

            // BRANCH 
            7'b1100011: begin
                RegWrite  = 0;
                ALUSrc    = 0;
                Lui       = 0;
                MemtoReg  = 2'b11;
                Jump      = 0;
                Branch    = 1;
                ALUOp     = 2'b01;
            end

            // I-TYPE ALU
            7'b0010011: begin
                RegWrite  = 1;
                ALUSrc    = 1;
                Lui       = 0;
                MemtoReg  = 2'b00;
                Jump      = 0;
                Branch    = 0;
                ALUOp     = 2'b10;
            end

            // JAL
            7'b1101111: begin
                RegWrite  = 1;
                ALUSrc    = 1; // PC= PC + imm ccurs in ALU and is sent to PC mux when Jump = 1
                Lui       = 1;
                MemtoReg  = 2'b10; // rd = PC + 4
                Jump      = 1;
                Branch    = 0;
                ALUOp     = 2'b00;
            end
            // JALR
            7'b1100111: begin
                RegWrite  = 1;
                ALUSrc    = 1; // PC = rs1 + imm occurs in ALU and is sent to PC mux when Jump = 1
                Lui       = 0;
                MemtoReg  = 2'b10; // rd = PC + 4
                Jump      = 1;
                Branch    = 0;
                ALUOp     = 2'b00;
            end
            // LUI
            7'b0110111: begin
                RegWrite  = 1;
                ALUSrc    = 0; 
                Lui       =  1;
                MemtoReg  = 2'b00; // ALU will be configured to pass imm directly to rd
                Jump      = 0;
                Branch    = 0;
                ALUOp     = 2'b00;
            end
            // AUIPC
            7'b0010111: begin
                RegWrite  = 1;
                ALUSrc    = 1;
                Lui       = 1; 
                MemtoReg  = 2'b00; // ALU will be configured to add imm to PC and pass result to rd
                Jump      = 0;
                Branch    = 0;
                ALUOp     = 2'b00;
            end

            default: begin
                RegWrite   = 0;
                ALUSrc     = 0;
                Lui        = 0;
                MemtoReg   = 2'b11;
                Jump       = 0;
                Branch     = 0;
                ALUOp      = 2'b00;
            end

        endcase
    end


    // =========================
    // ALU DECODER
    // =========================
    always_comb begin

        ALUControl = 4'b0000;
        Mul = 0;
        M_ctrl = 0;
        case (ALUOp)

            // ADD (lw, sw, JAL, JALR, LUI, AUIPC etc)
            2'b00: begin 
                ALUControl = 4'b0000;
                Mul = 0;
                M_ctrl = 0;
            end  

            // Branch use funct3 directly to determine the type of branch
            2'b01: begin
                ALUControl = {1'b1, funct3};
                Mul = 0;
                M_ctrl = 0;
            end
            // R-type / I-type ALU ops / MUL (M extension)
            2'b10: begin
                // Using same ALUControl for M-EXT Multiplier to reduce pipeline registers.
                if (opcode == 7'b0010011) begin 
                    if (funct3 == 3'b101)
                        ALUControl = {funct7_5, funct3};
                    else
                        ALUControl = {1'b0, funct3};
                Mul = 0;
                M_ctrl = 0;
                end
                else if (opcode == 7'b0110011) begin
                    ALUControl = {funct7_5, funct3};
                    Mul = funct7_0;
                    M_ctrl = funct3[0] | funct3[1];
                end
            end
            // Use funct7 bit 5 to distinguish between ADD/SUB
            // Use funct7 bit 0 to distinguish between MUL and other R-type ops (M extension)
            default: begin 
                ALUControl = 4'b0000;
                Mul = 0;
                M_ctrl = 0;
            end
        endcase
    end

endmodule


// Documentation of control signals:
/*
ALUSrc = 1 meaning we load imm not rs2
ALUSrc = 0 meaning we load rs2
MemtoReg {
    00: ALU result
    01: Memory data (for lw)
    10: PC + 4 (for JAL)
    11: Don't care (for sw, branches) meaning no writeback to rd
}


*/
`timescale 1ns / 1ps
module stall_controller (
    input  logic clk,
    input  logic rst,
    //Forwarding Unit Signals
    input logic [4:0] rs1E,rs2E,rdW,rdM,
    input logic RegWriteW,RegWriteM,
    output logic [1:0] ForwardAE,ForwardBE,
    // Load-use hazard
    input logic [4:0] rs1D,rs2D,rdE,
    input logic uses_rs1D,uses_rs2D,loadE,
    output logic load_hazard,
    // MUL
    input  logic mul_req,
    input  logic M_over,
    output logic mul_start,
    // LSU
    input  logic lsu_busy,
    // Final stall
    output logic pipe_stall
);
    always_comb begin
        ForwardAE = 2'b00;
        ForwardBE = 2'b00;

        if (!rst) begin
            // Memory-stage forwarding has priority over writeback forwarding.
            if ((rs1E == rdM) && RegWriteM && (rdM != 0))
                ForwardAE = 2'b10;
            else if ((rs1E == rdW) && RegWriteW && (rdW != 0))
                ForwardAE = 2'b01;

            if ((rs2E == rdM) && RegWriteM && (rdM != 0))
                ForwardBE = 2'b10;
            else if ((rs2E == rdW) && RegWriteW && (rdW != 0))
                ForwardBE = 2'b01;
        end
    end

    assign load_hazard = loadE && (rdE != 5'd0) &&((uses_rs1D && (rs1D == rdE)) ||(uses_rs2D && (rs2D == rdE)));

    logic M_busy;

    // A request starts only while idle.
    // for one cycle so the completed result and its controls advance together.
    assign mul_start = mul_req && !M_busy && !M_over && !rst;

    always_ff @(posedge clk) begin
        if (rst)
            M_busy <= 1'b0;
        else if (M_over)
            M_busy <= 1'b0;
        else if (mul_start)
            M_busy <= 1'b1;
    end

    assign pipe_stall = lsu_busy || mul_start || (M_busy && !M_over);

endmodule
`timescale 1ns / 1ps
module Stage1 #(
    parameter INSTR_ADDR_WIDTH = 8,
    parameter BOOT_ADDR_WIDTH  = 8,
    parameter INSTR_WORDS      = 256,
    parameter BOOT_WORDS       = 256,
    parameter BOOT_ADDR = 32'h0000_0000,
    parameter INSTR_ADDR = 32'h0000_8000
)(
    input logic clk,
    input logic rst,
    input logic pc_stall,
    input logic RegWrite_wb,
    input logic [4:0] rd,
    output logic [4:0] rd_s12,
    input logic [31:0] wb_data,
    input logic [1:0] PCSrc,
    input logic [31:0] BranchAddr,
    input logic [31:0] ALUResult,
    output logic [31:0] PC,
    output logic [31:0] instr_PC,
    output logic [31:0] rs1_value,
    output logic [31:0] rs2_value,
    output logic [4:0] rs1,
    output logic [4:0] rs2,
    output logic uses_rs1,
    output logic uses_rs2,
    output logic [31:0] imm,
    output logic [17:0] ctrl,
    input logic redirect_flush,
    input logic redirect_flush_d,
    // From MEM Stage 
    input  logic                   en_mem,
    input  logic [INSTR_ADDR_WIDTH-1:0]  addr_mem,
    input  logic [31:0]            wdata_mem,
    output logic [31:0]            rdata_mem,
    input  logic                   we_mem,
    input  logic [3:0]             be_mem,
    input  logic                   sign_ext_mem,

    input logic boot_mode
);
logic [31:0] instr;
logic [31:0] mux_out;
logic [31:0] instr_reg;
logic [31:0] instr_PC_reg;
//Control signals for Stage 1 
logic [3:0] ALUControl;
logic [1:0] MemtoReg;
logic [1:0] lsu_type;
logic RegWrite, ALUSrc, Lui, Jump, Branch, Mul, M_ctrl, lsu_req, lsu_we, lsu_sign_ext;
pc_mux mux1 (
    .branch_addr(BranchAddr),
    .alu_result(ALUResult),
    .pcsrc(PCSrc),
    .pc_in(mux_out), // Connect to PC input
    .PC(PC),
    .pc_stall(pc_stall)
);
always_ff @(posedge clk) begin
    if (rst) begin
        PC       <= 32'b0;
        instr_PC_reg <= 32'b0;
    end
    else begin
        PC <= mux_out; // Update PC with the output of the mux
        if (!pc_stall)
            instr_PC_reg <= PC;
    end
end
logic [BOOT_ADDR_WIDTH-1:0] boot_fetch_addr;
logic [INSTR_ADDR_WIDTH-1:0] instr_fetch_addr;

always_comb begin
    boot_fetch_addr  = '0;
    instr_fetch_addr = '0;

    if (boot_mode)
        boot_fetch_addr = (PC - BOOT_ADDR) >> 2;
    else
        instr_fetch_addr = (PC - INSTR_ADDR) >> 2;
end
instr_ram #(
    .INSTR_ADDR_WIDTH(INSTR_ADDR_WIDTH),
    .BOOT_ADDR_WIDTH(BOOT_ADDR_WIDTH),
    .INSTR_WORDS(INSTR_WORDS),
    .BOOT_WORDS(BOOT_WORDS)
)instr_mem(
    .clk(clk),
    .en_a_i(!pc_stall),
    .addr_boot_a_i(boot_fetch_addr),
    .addr_instr_a_i(instr_fetch_addr),
    .wdata_a_i(32'b0),
    .rdata_a_o(instr_reg),
    .we_a_i(1'b0),
    .be_a_i(4'b0),
    .en_b_i(en_mem),
    .addr_b_i(addr_mem),
    .wdata_b_i(wdata_mem),
    .rdata_b_o(rdata_mem),
    .we_b_i(we_mem),
    .be_b_i(be_mem),
    .sign_ext_b_i(sign_ext_mem),
    .boot_mode(boot_mode)
);
always_ff @(posedge clk) begin
    if (rst || redirect_flush || redirect_flush_d) begin
        instr <= 32'b0;
        instr_PC <= 32'b0;
    end
    else if (!pc_stall) begin
        instr <= instr_reg; // Update instruction register with the fetched instruction
        instr_PC <= instr_PC_reg; // Update instruction PC register with the current PC
    end
end
register_file rf (
    .clk(clk),
    .rst(rst),
    .rs1(instr[19:15]),
    .rs2(instr[24:20]),
    .rd(rd),
    .rd_value(wb_data),
    .regwrite(RegWrite_wb),
    .rs1_value(rs1_value), 
    .rs2_value(rs2_value)
);

Control_Unit cu (
    .opcode(instr[6:0]),
    .funct3(instr[14:12]),
    .funct7_5(instr[30]),
    .funct7_0(instr[25]),
    .RegWrite(RegWrite),
    .MemtoReg(MemtoReg),
    .ALUSrc(ALUSrc),
    .Lui(Lui),
    .ALUControl(ALUControl),
    .Jump(Jump),
    .Branch(Branch),
    .Mul(Mul),
    .M_ctrl(M_ctrl),
    .lsu_req(lsu_req),
    .lsu_we(lsu_we),
    .lsu_type(lsu_type),
    .lsu_sign_ext(lsu_sign_ext)
);

assign ctrl = {
    RegWrite,        // 1 (17)
    MemtoReg,        // 2 (16:15)
    ALUSrc,          // 1 (14)
    Lui,             // 1 (13)
    ALUControl,      // 4 (12:9)
    Jump,            // 1 (8)
    Branch,          // 1 (7)
    Mul,             // 1 (6)
    M_ctrl,          // 1 (5)
    lsu_req,         // 1 (4)
    lsu_we,          // 1 (3)
    lsu_type,        // 2 (2:1)
    lsu_sign_ext     // 1 (0)
                     // 18 bits total
};

immediate_generator imm_gen (
    .instr(instr),
    .imm_out(imm)
);

assign rs1 = instr[19:15];
assign rs2 = instr[24:20];
assign rd_s12 = instr[11:7];

always_comb begin
    uses_rs1 = 1'b0;
    uses_rs2 = 1'b0;

    unique case (instr[6:0])
        7'b0000011, // LOAD
        7'b0010011, // I-type ALU
        7'b1100111: // JALR
            uses_rs1 = 1'b1;

        7'b0100011, // STORE
        7'b0110011, // R-type / M extension
        7'b1100011: begin // BRANCH
            uses_rs1 = 1'b1;
            uses_rs2 = 1'b1;
        end

        default: begin
            uses_rs1 = 1'b0;
            uses_rs2 = 1'b0;
        end
    endcase
end
endmodule
`timescale 1ns / 1ps
module Stage2(
    input logic clk,
    input logic rst,
    input logic [31:0] pc_in_2,
    input logic [31:0] imm,
    input logic [31:0] rs1_value,
    input logic [31:0] rs2_value,
    input logic [4:0] rd,
    input logic [17:0] ctrl_s1,
    input logic [1:0] ForwardA,
    input logic [1:0] ForwardB,
    input logic [31:0] Fwd_rd_value1, //data_wb from Write Back stage
    input logic [31:0] Fwd_rd_value2, //alu_result_wb from Mem stage
    input logic mul_start,
    output logic [31:0] exec_result, // Final result after ALU/Mul Mux
    output logic [4:0] rd_out,
    output logic [31:0] rs2_value_out,
    output logic branch_flush,
    output logic [7:0] ctrl_s2,
    output logic [31:0] BranchAddr,
    output logic [31:0] ALUResult, // for jars/jalrs
    output logic [31:0] pc_out_s2,
    output logic M_over,
    output logic Jump
);
    logic compare_out;
    logic [31:0] alu_result;
    logic [31:0] mul_result;
    logic [31:0] alu_in1;
    logic [31:0] alu_in2;
    logic [3:0] ALUControl;
    logic [1:0] MemtoReg;
    logic [1:0] lsu_type;
    logic RegWrite, ALUSrc, Lui, Branch, Mul, M_ctrl, lsu_req, lsu_we, lsu_sign_ext;
    //Forwarding Signals
    logic [31:0] rs1_val_after, rs2_val_after;
    assign {
    RegWrite,        // 1
    MemtoReg,        // 2
    ALUSrc,          // 1
    Lui,             // 1
    ALUControl,      // 4
    Jump,            // 1
    Branch,          // 1
    Mul,             // 1
    M_ctrl,          // 1
    lsu_req,         // 1
    lsu_we,          // 1
    lsu_type,        // 2
    lsu_sign_ext     // 1
                     // 18 bits total
    } = ctrl_s1;

always_comb begin
    case(ForwardA)
        2'b00: rs1_val_after = rs1_value;
        2'b01: rs1_val_after = Fwd_rd_value1;
        2'b10: rs1_val_after = Fwd_rd_value2;
        default: rs1_val_after = rs1_value;
    endcase
    case(ForwardB)
        2'b00: rs2_val_after = rs2_value;
        2'b01: rs2_val_after = Fwd_rd_value1;
        2'b10: rs2_val_after = Fwd_rd_value2;
        default: rs2_val_after = rs2_value;
    endcase
end

alu_in1_mux mux1 (
    .rs1(rs1_val_after),
    .imm(imm),
    .Lui(Lui),
    .alu_in1(alu_in1)
);

alu_in2_mux mux2 (
    .rs2(rs2_val_after),
    .imm(imm),
    .pc(pc_in_2),
    .Lui(Lui),
    .ALUSrc(ALUSrc),
    .alu_in2(alu_in2)
);

alu alu (
    .a(alu_in1),
    .b(alu_in2),
    .Control(ALUControl),
    .branch(Branch),
    .result(alu_result),
    .compare_out(compare_out)
);

Pipelined_M multi (
    .A(rs1_val_after),
    .B(rs2_val_after),
    .clk(clk),
    .rst(rst),
    .P_32(mul_result),
    .M_ctrl(M_ctrl),
    .start(mul_start),
    .M_over(M_over)
);

alu_mul_mux mux3 (
    .alu_result(alu_result),
    .mul_result(mul_result),
    .Mul(Mul),
    .exec_result(exec_result)
);

    assign branch_flush = compare_out & Branch;
    assign BranchAddr = pc_in_2 + imm;
    assign ctrl_s2 = {
        MemtoReg,       // 2 (7:6)
        RegWrite,       // 1 (5)
        lsu_req,        // 1 (4)
        lsu_we,         // 1 (3)
        lsu_type,       // 2 (2:1)
        lsu_sign_ext    // 1 (0)
                        // 8 bits total
    };
    assign rd_out = rd;
    assign ALUResult = alu_result; // Address Calculation for Load/Store + ALU Result
    assign rs2_value_out = rs2_val_after; 
    assign pc_out_s2 = pc_in_2;

endmodule
// ============================================================
// Author: Goutham Badhrinath V
// 32-bit Signed Radix-4 Modified Booth 3S Pipelined Multiplier
// Wallace Reduction + Final 64-bit CLA
//
// Architecture:
//   Stage 1 : Radix-4 Booth PP Generation (17 PP rows)
//   Stage 2 : Wallace Compression Tree
//   Stage 3 : 64-bit Carry Lookahead Adder
// ============================================================

// ============================================================
// Top Multiplier
// ============================================================
`timescale 1ns / 1ps
module Pipelined_M(
    input clk,
    input rst,
    input logic start,
    output logic M_over,
    input  signed [31:0] A,
    input  signed [31:0] B,
    output signed [31:0] P_32,
    input logic M_ctrl
);
wire signed [63:0] pp [0:16];
reg signed [63:0] pp_next [0:16];
M1 multi1(.A(A),.B(B),.pp(pp));
integer i;
logic v1,v2,v2_prev;
always @(posedge clk) begin
    if (rst) begin
        v1 <= 0;
        v2 <= 0;
        v2_prev <= 0;
    end else begin
        v1 <= start;
        v2 <= v1;
        v2_prev <= v2;
    end
end
always @(posedge clk) begin
    if (rst) begin
        for (i = 0; i < 17; i = i + 1)
            pp_next[i] <= 0;
    end else if (start) begin
        for (i = 0; i < 17; i = i + 1)
            pp_next[i] <= pp[i];
    end else begin
        for (i = 0; i < 17; i = i + 1)
            pp_next[i] <= pp_next[i];
    end
end

wire signed [63:0] s6;
wire signed [64:0] c6;
reg signed [63:0] s6_next;
reg signed [64:0] c6_next;

M2 multi2(.pp(pp_next),.s6(s6),.c6(c6));

always@(posedge clk) begin
    if (rst) begin
        s6_next <= 0;
        c6_next <= 0;
    end else if (v1) begin
        s6_next <= s6;
        c6_next <= c6;
    end else begin
        s6_next <= s6_next;
        c6_next <= c6_next;
    end
    
end

// ============================================================
// Final CLA
// ============================================================
reg signed [63:0] P;
wire cz;
cla64 Final_Add(
    .a(s6_next),
    .b(c6_next[63:0]),
    .cin(1'b0),
    .sum(P),
    .cout(cz)
);
logic _unused;
assign _unused = cz; // Unused carry-out
assign P_32 = M_ctrl ? P[63:32] : P[31:0];
assign M_over = ~v2_prev & v2; // Assert M_over for one cycle when multiplication is done

endmodule


module M1(
    input  signed [31:0] A,
    input  signed [31:0] B,
    output reg signed [63:0] pp [0:16]
);

// ============================================================
// Booth Partial Products
// ============================================================

//wire signed [63:0] pp [0:16];

genvar i;

generate

    for(i=0;i<17;i=i+1) begin : BOOTH_PP_GEN

        wire [2:0] booth_bits;
        wire signed [2:0] code;

        if(i == 0) begin : GEN_I0
            assign booth_bits = {B[1], B[0], 1'b0};
        end
        else if(i == 16) begin : GEN_I16
            assign booth_bits = {B[31], B[31], B[31]};
        end
        else begin : GEN_MID
            assign booth_bits = {B[2*i+1], B[2*i], B[2*i-1]};
        end
        booth_encoder ENC(
            .y(booth_bits),
            .code(code)
        );

        reg signed [63:0] temp;

        always @(*) begin
            case(code)

                0: temp = 64'd0;

                1: temp = {{32{A[31]}},A};

               -1: temp = -({{32{A[31]}},A});

                2: temp = ({{32{A[31]}},A} <<< 1);

               -2: temp = -(({{32{A[31]}},A}) <<< 1);

                default: temp = 64'd0;

            endcase
        end

        assign pp[i] = $signed(temp) <<< (2*i);

    end

endgenerate
endmodule

module M2(
    input wire signed [63:0] pp [0:16],
    output signed [63:0] s6,
    output signed [64:0] c6
);

/* Stage 1 Partial Products:
    s1[0] c1[0]
    s1[1] c1[1]
    s1[2] c1[2]
    s1[3] c1[3]
    s1[4] c1[4]
    pp15  pp16  - remain unchanged
*/
// ============================================================
// Wallace Compression Tree
// ============================================================

// Stage 1
wire [63:0] s1 [0:4];
wire [64:0] c1 [0:4];
assign c1 [0][0] = 0;
assign c1 [1][0] = 0;
assign c1 [2][0] = 0;
assign c1 [3][0] = 0;
assign c1 [4][0] = 0;
genvar i;
generate

for(i=0;i<5;i=i+1) begin : WALLACE_STAGE1

    genvar j;

    for(j=0;j<64;j=j+1) begin : S1_GEN

        full_adder FA(
            .a   (pp[i*3][j]),
            .b   (pp[i*3+1][j]),
            .cin (pp[i*3+2][j]),
            .sum (s1[i][j]),
            .carry(c1[i][j+1])
        );

    end

end

endgenerate

// ============================================================
// Stage 2
// ============================================================

wire [63:0] s2 [0:3];
wire [64:0] c2 [0:3];
assign c2 [0][0] = 0;
assign c2 [1][0] = 0;
assign c2 [2][0] = 0;
assign c2 [3][0] = 0;
generate

    genvar k;

    for(k=0;k<64;k=k+1) begin : S2_GEN1

        full_adder FA2(
            .a   (s1[0][k]),
            .b   (c1[0][k]),
            .cin (s1[1][k]),
            .sum (s2[0][k]),
            .carry(c2[0][k+1])
        );

    end
    for(k=0;k<64;k=k+1) begin : S2_GEN2

        full_adder FA3(
            .a   (c1[1][k]),
            .b   (c1[2][k]),
            .cin (s1[2][k]),
            .sum (s2[1][k]),
            .carry(c2[1][k+1])
        );

    end
    for(k=0;k<64;k=k+1) begin : S2_GEN3

        full_adder FA4(
            .a   (s1[3][k]),
            .b   (c1[3][k]),
            .cin (s1[4][k]),
            .sum (s2[2][k]),
            .carry(c2[2][k+1])
        );

    end
    for(k=0;k<64;k=k+1) begin : S2_GEN4

        full_adder FA5(
            .a   (c1[4][k]),
            .b   (pp[15][k]),
            .cin (pp[16][k]),
            .sum (s2[3][k]),
            .carry(c2[3][k+1])
        );

    end


endgenerate

// ============================================================
// Stage 3
// ============================================================
wire [63:0] s3 [0:1];
wire [64:0] c3 [0:1];
assign c3 [0][0] = 0;
assign c3 [1][0] = 0;
generate

    genvar k1;

    for(k1=0;k1<64;k1=k1+1) begin : S3_GEN1

        full_adder FA6(
            .a   (s2[0][k1]),
            .b   (s2[1][k1]),
            .cin (c2[0][k1]),
            .sum (s3[0][k1]),
            .carry(c3[0][k1+1])
        );

    end
    for(k1=0;k1<64;k1=k1+1) begin : S3_GEN2

        full_adder FA7(
            .a   (s2[2][k1]),
            .b   (c2[1][k1]),
            .cin (c2[2][k1]),
            .sum (s3[1][k1]),
            .carry(c3[1][k1+1])
        );

    end

endgenerate

// ============================================================
// Stage 4
// ============================================================
wire [63:0] s4 [0:1];
wire [64:0] c4 [0:1];
assign c4 [0][0] = 0;
assign c4 [1][0] = 0;
generate

    genvar k2;

    for(k2=0;k2<64;k2=k2+1) begin : S4_GEN1

        full_adder FA8(
            .a   (s3[0][k2]),
            .b   (s3[1][k2]),
            .cin (c3[0][k2]),
            .sum (s4[0][k2]),
            .carry(c4[0][k2+1])
        );

    end
    for(k2=0;k2<64;k2=k2+1) begin : S4_GEN2

        full_adder FA9(
            .a   (c3[1][k2]),
            .b   (s2[3][k2]),
            .cin (c2[3][k2]),
            .sum (s4[1][k2]),
            .carry(c4[1][k2+1])
        );

    end

endgenerate

// ============================================================
// Stage 5
// ============================================================
wire [63:0] s5;
wire [64:0] c5;
assign c5[0] = 0;
generate

    genvar k4;

    for(k4=0;k4<64;k4=k4+1) begin : S5_GEN

        full_adder FA10(
            .a   (s4[0][k4]),
            .b   (s4[1][k4]),
            .cin (c4[0][k4]),
            .sum (s5[k4]),
            .carry(c5[k4+1])
        );

    end

endgenerate

// ============================================================
// Stage 6
// ============================================================
//wire [63:0] s6;
//wire [64:0] c6;
assign c6[0] = 0;
generate

    genvar k5;

    for(k5=0;k5<64;k5=k5+1) begin : S6_GEN

        full_adder FA11(
            .a   (s5[k5]),
            .b   (c5[k5]),
            .cin (c4[1][k5]),
            .sum (s6[k5]),
            .carry(c6[k5+1])
        );

    end

endgenerate

endmodule

module half_adder(
    input  a,
    input  b,
    output sum,
    output carry
);
assign sum   = a ^ b;
assign carry = a & b;
endmodule

module full_adder(
    input  a,
    input  b,
    input  cin,
    output sum,
    output carry
);
assign sum   = a ^ b ^ cin;
assign carry = (a & b) | (b & cin) | (a & cin);
endmodule


// ============================================================
// Radix-4 Booth Encoder
// ============================================================

module booth_encoder(
    input  [2:0] y,
    output reg signed [2:0] code
);

always @(*) begin
    case(y)
        3'b000: code =  0;
        3'b001: code = +1;
        3'b010: code = +1;
        3'b011: code = +2;
        3'b100: code = -2;
        3'b101: code = -1;
        3'b110: code = -1;
        3'b111: code =  0;
    endcase
end

endmodule

// ============================================================
// 64-bit Carry Lookahead Adder (CLA)
// Fully Functional Hierarchical CLA
// Supports fast carry computation using:
//   - 1-bit Generate/Propagate
//   - 4-bit CLA blocks
//   - 16-bit CLA blocks
//   - 64-bit top-level CLA
// ============================================================


// ============================================================
// 1-BIT GP CELL
// ============================================================

module gp_cell(
    input  wire a,
    input  wire b,
    output wire g,
    output wire p
);

assign g = a & b;   // Generate
assign p = a ^ b;   // Propagate

endmodule


// ============================================================
// 4-BIT CLA BLOCK
// ============================================================

module cla4(
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire       cin,

    output wire [3:0] sum,
    output wire       cout,

    output wire       G,
    output wire       P
);

wire [3:0] g, p;
wire c0,c1,c2,c3,c4;
wire [4:0] c = {c4, c3, c2, c1, c0};

// Generate/Propagate
genvar i;
generate
    for(i=0; i<4; i=i+1) begin : GP
        gp_cell gp_inst(
            .a(a[i]),
            .b(b[i]),
            .g(g[i]),
            .p(p[i])
        );
    end
endgenerate

assign c0 = cin;

// Carry Lookahead Logic
assign c1 = g[0] | (p[0] & c0);

assign c2 = g[1]
            | (p[1] & g[0])
            | (p[1] & p[0] & c0);

assign c3 = g[2]
            | (p[2] & g[1])
            | (p[2] & p[1] & g[0])
            | (p[2] & p[1] & p[0] & c0);

assign c4 = g[3]
            | (p[3] & g[2])
            | (p[3] & p[2] & g[1])
            | (p[3] & p[2] & p[1] & g[0])
            | (p[3] & p[2] & p[1] & p[0] & c0);

// Sum
assign sum[0] = p[0] ^ c0;
assign sum[1] = p[1] ^ c1;
assign sum[2] = p[2] ^ c2;
assign sum[3] = p[3] ^ c3;

assign cout = c4;

// Group Generate / Propagate
assign P = p[3] & p[2] & p[1] & p[0];

assign G = g[3]
         | (p[3] & g[2])
         | (p[3] & p[2] & g[1])
         | (p[3] & p[2] & p[1] & g[0]);

endmodule


// ============================================================
// 16-BIT CLA
// Built using four 4-bit CLA blocks
// ============================================================

module cla16(
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire        cin,

    output wire [15:0] sum,
    output wire        cout,

    output wire        G,
    output wire        P
);

wire [3:0] blockG, blockP;
wire c0,c1,c2,c3,c4;
wire [4:0] c = {c4, c3, c2, c1, c0};
wire cx;
assign c0 = cin;

// Carry between 4-bit blocks
assign c1 = blockG[0]
            | (blockP[0] & c0);

assign c2 = blockG[1]
            | (blockP[1] & blockG[0])
            | (blockP[1] & blockP[0] & c0);

assign c3 = blockG[2]
            | (blockP[2] & blockG[1])
            | (blockP[2] & blockP[1] & blockG[0])
            | (blockP[2] & blockP[1] & blockP[0] & c0);

assign c4 = blockG[3]
            | (blockP[3] & blockG[2])
            | (blockP[3] & blockP[2] & blockG[1])
            | (blockP[3] & blockP[2] & blockP[1] & blockG[0])
            | (blockP[3] & blockP[2] & blockP[1] & blockP[0] & c0);

// 4-bit CLA instances
genvar i;
generate
    for(i=0; i<4; i=i+1) begin : CLA4_BLOCKS

        cla4 cla4_inst(
            .a   (a[i*4 +: 4]),
            .b   (b[i*4 +: 4]),
            .cin (c[i]),

            .sum (sum[i*4 +: 4]),
            .cout(cx),

            .G   (blockG[i]),
            .P   (blockP[i])
        );

    end
endgenerate
logic _unused;
assign _unused = cx;
assign cout = c4;

// Group Generate/Propagate
assign P = blockP[3] & blockP[2] & blockP[1] & blockP[0];

assign G = blockG[3]
         | (blockP[3] & blockG[2])
         | (blockP[3] & blockP[2] & blockG[1])
         | (blockP[3] & blockP[2] & blockP[1] & blockG[0]);

endmodule


// ============================================================
// 64-BIT CLA TOP MODULE
// Built using four 16-bit CLA blocks
// ============================================================

module cla64(
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire        cin,

    output wire [63:0] sum,
    output wire        cout
);
wire cy;
wire [3:0] blockG, blockP;
wire c0,c1,c2,c3,c4;
wire [4:0] c = {c4, c3, c2, c1, c0};

assign c0 = cin;

// Carry lookahead between 16-bit blocks
assign c1 = blockG[0]
            | (blockP[0] & c0);

assign c2 = blockG[1]
            | (blockP[1] & blockG[0])
            | (blockP[1] & blockP[0] & c0);

assign c3 = blockG[2]
            | (blockP[2] & blockG[1])
            | (blockP[2] & blockP[1] & blockG[0])
            | (blockP[2] & blockP[1] & blockP[0] & c0);

assign c4 = blockG[3]
            | (blockP[3] & blockG[2])
            | (blockP[3] & blockP[2] & blockG[1])
            | (blockP[3] & blockP[2] & blockP[1] & blockG[0])
            | (blockP[3] & blockP[2] & blockP[1] & blockP[0] & c0);

// 16-bit CLA blocks
genvar i;
generate
    for(i=0; i<4; i=i+1) begin : CLA16_BLOCKS

        cla16 cla16_inst(
            .a   (a[i*16 +: 16]),
            .b   (b[i*16 +: 16]),
            .cin (c[i]),

            .sum (sum[i*16 +: 16]),
            .cout(cy),

            .G   (blockG[i]),
            .P   (blockP[i])
        );

    end
endgenerate

assign cout = c4;
logic _unused;
assign _unused = cy;
endmodule
`timescale 1ns / 1ps
module Memory_Ctrl #(
    parameter INSTR_ADDR = 32'h0000_8000
)(
    input logic clk,
    input logic rst,
    input logic [31:0] Mem_Ctrl_PC,
    output logic boot_mode
);
always_ff @(posedge clk) begin
    if (rst) begin
        boot_mode <= 1'b1; // Start in boot mode
    end else begin
        // Exit boot mode when PC reaches INSTR_ADDR
        if (Mem_Ctrl_PC >= (INSTR_ADDR - 32'd4)) begin
            boot_mode <= 1'b0;
        end
    end
end
endmodule
`timescale 1ns / 1ps
module CoreRV #(
    parameter BOOT_ADDR = 32'h0000_0000,
    parameter INSTR_ADDR = 32'h0000_0400,
    parameter DATA_ADDR = 32'h0001_0000,
    parameter EXTERNAL_ADDR = 32'h0002_0000
)(
    input logic clk,
    input logic rst,
    
    output logic [31:0] data_addr_o,
    output logic [31:0] data_wdata_o,
    output logic data_we_o,
    output logic data_req_o,
    output logic [3:0] data_be_o,
    input logic [31:0] data_rdata_i,
    input logic data_gnt_i,
    input logic data_rvalid_i
);
typedef struct packed {
    logic [4:0] rd_s12;
    logic [31:0] PC;
    logic [31:0] rs1_value;
    logic [31:0] rs2_value;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [31:0] imm;
    logic [17:0] ctrl;
    logic [31:0] rdata_mem;
} s1_buffer;


// Memory Width and Size Parameters
localparam int DATA_WORDS = (EXTERNAL_ADDR - DATA_ADDR) / 4;
localparam int DATA_ADDR_WIDTH = $clog2(DATA_WORDS); 
localparam int INSTR_WORDS = (DATA_ADDR - INSTR_ADDR) / 4;
localparam int INSTR_ADDR_WIDTH = $clog2(INSTR_WORDS);
localparam int BOOT_WORDS = (INSTR_ADDR - BOOT_ADDR) / 4;
localparam int BOOT_ADDR_WIDTH = $clog2(BOOT_WORDS);


//Stage 1 Signals
logic Reg_wb, branch_flush, redirect_flush, redirect_flush_d, Jump;
logic [4:0] rd_out;
logic [31:0] data_wb;
logic [31:0] BranchAddr;
logic [31:0] ALUResult;
logic [31:0] instr_PC_S12, rs1_value_S12, rs2_value_S12;
logic [4:0] rs1_S12, rs2_S12;
logic uses_rs1_S12, uses_rs2_S12;
logic [31:0] imm;
logic [17:0] ctrl;
logic m_stall;
logic load_hazard;
logic front_stall;
logic [4:0] rd_s12;
logic [1:0] PCSrc;
logic M_over;

// Buffer to hold Stage 1 outputs for use in Stage 2
s1_buffer s1_buf;

assign PCSrc = {Jump,branch_flush};
assign redirect_flush = branch_flush | Jump;
assign front_stall = m_stall | load_hazard;
logic loadE;
assign loadE = s1_buf.ctrl[17] && (s1_buf.ctrl[16:15] == 2'b01); // Check if it's a load instruction in EX stage

//Instruction memory Signals
logic en_mem;
logic [INSTR_ADDR_WIDTH-1:0] addr_mem;
logic [31:0] wdata_mem;
logic [31:0] rdata_mem;
logic we_mem;
logic [3:0] be_mem;
logic sign_ext_mem;

//Stage 2 Signals
logic [31:0] exec_result;
logic [4:0] rd_S23;
logic [31:0] rs2_value_S23;
logic [7:0] ctrl_s2;
logic [31:0] pc_out_s2;
logic [1:0] ForwardA, ForwardB;
logic mul_start;

// Memory Stage Signals
logic dram_en_i;
logic [DATA_ADDR_WIDTH-1:0] dram_addr_i;
logic [31:0] dram_wdata_i;
logic [31:0] dram_rdata_i;
logic dram_we_i;
logic [3:0] dram_be_i;
logic dram_sign_ext_i;
logic [1:0] mem_select;
logic lsu_we_i;
logic [1:0] lsu_type_i;
logic [31:0] lsu_wdata_i;
logic lsu_sign_ext_i;
logic lsu_req_i;
logic [31:0] adder_result_ex_i;
logic [31:0] lsu_rdata_o;
logic lsu_rdata_valid_o;
logic busy_o;

// WB signals
logic [31:0] alu_result_wb;
logic [31:0] pc_wb;
logic [1:0] memtoreg_wb;
logic [4:0] rd_wb;
logic       regwrite_wb;

// Mem to WB BUFFER
logic [31:0] alu_result_buf;
logic [31:0] mem_data_buf;
logic [31:0] pc_buf;
logic [1:0] memtoreg_buf;
logic [4:0] rd_buf;
logic       regwrite_buf;
logic [31:0] Mem_Ctrl_PC;
logic boot_mode;

Memory_Ctrl #(
    .INSTR_ADDR(INSTR_ADDR)
) mem_ctrl (
    .clk(clk),
    .rst(rst),
    .Mem_Ctrl_PC(Mem_Ctrl_PC),
    .boot_mode(boot_mode)
);
Stage1 #(
    .INSTR_ADDR_WIDTH(INSTR_ADDR_WIDTH),
    .BOOT_ADDR_WIDTH(BOOT_ADDR_WIDTH),
    .INSTR_WORDS(INSTR_WORDS),
    .BOOT_WORDS(BOOT_WORDS),
    .BOOT_ADDR(BOOT_ADDR),
    .INSTR_ADDR(INSTR_ADDR)
) s1(
    .clk(clk),
    .rst(rst),
    .pc_stall(front_stall),
    .RegWrite_wb(Reg_wb),
    .rd(rd_out),
    .rd_s12(rd_s12),
    .wb_data(data_wb),
    .PCSrc(PCSrc),
    .BranchAddr(BranchAddr),
    .ALUResult(ALUResult),
    .PC(Mem_Ctrl_PC),
    .boot_mode(boot_mode),
    .instr_PC(instr_PC_S12),
    .rs1_value(rs1_value_S12),
    .rs2_value(rs2_value_S12),
    .rs1(rs1_S12),
    .rs2(rs2_S12),
    .uses_rs1(uses_rs1_S12),
    .uses_rs2(uses_rs2_S12),
    .imm(imm),
    .ctrl(ctrl),
    .redirect_flush(redirect_flush),
    .redirect_flush_d(redirect_flush_d),
    // From MEM Stage 
    .en_mem(en_mem),
    .addr_mem(addr_mem),
    .wdata_mem(wdata_mem),
    .rdata_mem(rdata_mem),
    .we_mem(we_mem),
    .be_mem(be_mem),
    .sign_ext_mem(sign_ext_mem)
);


// The instruction RAM has a registered output. After a branch or jump,
// outstanding wrong-path read arrives one cycle after the redirect, so keep
// the Stage 1/2 buffer invalid for that additional cycle.
always_ff @(posedge clk) begin
    if (rst)
        redirect_flush_d <= 1'b0;
    else
        redirect_flush_d <= redirect_flush;
end

always_ff @(posedge clk) begin
    if (rst || redirect_flush || redirect_flush_d) begin
        s1_buf.PC <= 32'b0;
        s1_buf.rs1_value <= 32'b0;
        s1_buf.rs2_value <= 32'b0;
        s1_buf.rs1 <= 5'b0;
        s1_buf.rs2 <= 5'b0;
        s1_buf.imm <= 32'b0;
        s1_buf.ctrl <= 18'b0;
        s1_buf.rd_s12 <= 5'b0;
        s1_buf.rdata_mem <= 32'b0;
    end
    else if (m_stall) begin
        s1_buf <= s1_buf; // Hold the current values in the buffer
    end
    else if (load_hazard) begin
        // Freeze fetch/decode and inject a NOP into EX while the load advances.
        s1_buf.PC <= 32'b0;
        s1_buf.rs1_value <= 32'b0;
        s1_buf.rs2_value <= 32'b0;
        s1_buf.rs1 <= 5'b0;
        s1_buf.rs2 <= 5'b0;
        s1_buf.imm <= 32'b0;
        s1_buf.ctrl <= 18'b0;
        s1_buf.rd_s12 <= 5'b0;
        s1_buf.rdata_mem <= 32'b0;
    end
    else begin
        s1_buf.PC <= instr_PC_S12;
        s1_buf.rs1_value <= rs1_value_S12;
        s1_buf.rs2_value <= rs2_value_S12;
        s1_buf.rs1 <= rs1_S12;
        s1_buf.rs2 <= rs2_S12;
        s1_buf.imm <= imm;
        s1_buf.ctrl <= ctrl;
        s1_buf.rd_s12 <= rd_s12;
        s1_buf.rdata_mem <= rdata_mem;
    end
end

Stage2 s2 (
    .clk(clk),
    .rst(rst),
    .pc_in_2(s1_buf.PC),
    .imm(s1_buf.imm),
    .rs1_value(s1_buf.rs1_value),
    .rs2_value(s1_buf.rs2_value),
    .rd(s1_buf.rd_s12),
    .ctrl_s1(s1_buf.ctrl),
    .ForwardA(ForwardA),
    .ForwardB(ForwardB),
    .Fwd_rd_value1(data_wb),
    .Fwd_rd_value2(alu_result_wb),
    .mul_start(mul_start),
    .exec_result(exec_result),
    .rd_out(rd_S23),
    .rs2_value_out(rs2_value_S23),
    .branch_flush(branch_flush),
    .ctrl_s2(ctrl_s2),
    .BranchAddr(BranchAddr),
    .ALUResult(ALUResult),
    .pc_out_s2(pc_out_s2),
    .M_over(M_over),
    .Jump(Jump)
);

always_comb begin
    mem_select = 2'b00;

    en_mem = 0;
    addr_mem = 0;
    wdata_mem = 0;
    we_mem = 0;
    be_mem = 0;

    dram_en_i = 0;
    dram_addr_i = 0;
    dram_wdata_i = 0;
    dram_we_i = 0;
    dram_be_i = 0;

    lsu_we_i = 0;
    lsu_type_i = 0;
    lsu_wdata_i = 0;
    lsu_sign_ext_i = 0;
    lsu_req_i = 0;
    adder_result_ex_i = 0;

    if(exec_result >= INSTR_ADDR && exec_result < DATA_ADDR)  begin
        // Handle instruction memory access
        mem_select = 2'b01;
        en_mem = ctrl_s2[4] && boot_mode; // Only enable instruction memory access in boot mode
        addr_mem = (exec_result - INSTR_ADDR) >> 2;
        unique case (ctrl_s2[2:1])
            2'b00: wdata_mem = rs2_value_S23; //word
            2'b01: begin // half-word
                unique case (exec_result[1:0])
                2'b00: wdata_mem = {16'b0, rs2_value_S23[15:0]}; // lower half-word
                2'b01: wdata_mem = {8'b0, rs2_value_S23[23:8], 8'b0}; //
                2'b10: wdata_mem = {rs2_value_S23[31:16], 16'b0}; // upper half-word
                2'b11: wdata_mem = {rs2_value_S23[31:24], 16'b0, rs2_value_S23[7:0]}; //
                default: wdata_mem = {16'b0, rs2_value_S23[15:0]};
                endcase
            end
            2'b10: begin // byte
                unique case (exec_result[1:0])
                2'b00: wdata_mem = {24'b0, rs2_value_S23[7:0]}; // byte 0 (lowest)
                2'b01: wdata_mem = {16'b0, rs2_value_S23[15:8], 8'b0}; // byte 1
                2'b10: wdata_mem = {8'b0, rs2_value_S23[23:16], 16'b0}; // byte 2
                2'b11: wdata_mem = {rs2_value_S23[31:24], 24'b0}; // byte 3
                default: wdata_mem = {24'b0, rs2_value_S23[7:0]};
                endcase
            end
            default: wdata_mem = rs2_value_S23;
        endcase
        we_mem = ctrl_s2[3];
        sign_ext_mem = ctrl_s2[0];
        unique case (ctrl_s2[2:1])
            2'b00: be_mem = 4'b1111; //word
            2'b01: begin // half-word
                unique case (exec_result[1:0])
                2'b00: be_mem = 4'b0011; // lower half-word
                2'b01: be_mem = 4'b0110; // 
                2'b10: be_mem = 4'b1100; // upper half-word 
                2'b11: be_mem = 4'b1001; // 
                default: be_mem = 4'b0011;
                endcase
            end
            2'b10: begin // byte
                unique case (exec_result[1:0])
                2'b00: be_mem = 4'b0001; // byte 0 (lowest)
                2'b01: be_mem = 4'b0010; // byte 1
                2'b10: be_mem = 4'b0100; // byte 2
                2'b11: be_mem = 4'b1000; // byte 3
                default: be_mem = 4'b0001;
                endcase
            end
            default: be_mem = 4'b1111;
        endcase
    end
    else if(exec_result >= DATA_ADDR && exec_result < EXTERNAL_ADDR) begin
        mem_select = 2'b00;
        dram_en_i = ctrl_s2[4];
        dram_addr_i = (exec_result - DATA_ADDR) >> 2;
        unique case (ctrl_s2[2:1])
            2'b00: dram_wdata_i = rs2_value_S23; //word
            2'b01: begin // half-word
                unique case (exec_result[1:0])
                2'b00: dram_wdata_i = {16'b0, rs2_value_S23[15:0]}; // lower half-word
                2'b01: dram_wdata_i = {8'b0, rs2_value_S23[23:8], 8'b0}; //
                2'b10: dram_wdata_i = {rs2_value_S23[31:16], 16'b0}; // upper half-word
                2'b11: dram_wdata_i = {rs2_value_S23[31:24], 16'b0, rs2_value_S23[7:0]}; //
                default: dram_wdata_i = {16'b0, rs2_value_S23[15:0]};
                endcase
            end
            2'b10: begin // byte
                unique case (exec_result[1:0])
                2'b00: dram_wdata_i = {24'b0, rs2_value_S23[7:0]}; // byte 0 (lowest)
                2'b01: dram_wdata_i = {16'b0, rs2_value_S23[15:8], 8'b0}; // byte 1
                2'b10: dram_wdata_i = {8'b0, rs2_value_S23[23:16], 16'b0}; // byte 2
                2'b11: dram_wdata_i = {rs2_value_S23[31:24], 24'b0}; // byte 3
                default: dram_wdata_i = {24'b0, rs2_value_S23[7:0]};
                endcase
            end
            default: dram_wdata_i = rs2_value_S23;
        endcase
        dram_we_i = ctrl_s2[3];
        dram_sign_ext_i = ctrl_s2[0];
        unique case (ctrl_s2[2:1])
            2'b00: dram_be_i = 4'b1111; //word
            2'b01: begin // half-word
                unique case (exec_result[1:0])
                2'b00: dram_be_i = 4'b0011; // lower half-word
                2'b01: dram_be_i = 4'b0110; // 
                2'b10: dram_be_i = 4'b1100; // upper half-word 
                2'b11: dram_be_i = 4'b1001; // 
                default: dram_be_i = 4'b0011;
                endcase
            end
            2'b10: begin // byte
                unique case (exec_result[1:0])
                2'b00: dram_be_i = 4'b0001; // byte 0 (lowest)
                2'b01: dram_be_i = 4'b0010; // byte 1
                2'b10: dram_be_i = 4'b0100; // byte 2
                2'b11: dram_be_i = 4'b1000; // byte 3
                default: dram_be_i = 4'b0001;
                endcase
            end
            default: dram_be_i = 4'b1111;
        endcase
    end
    else if(exec_result >= EXTERNAL_ADDR) begin
        // Handle external I/O access (e.g., UART, GPIO)
        mem_select = 2'b10;
        lsu_we_i = ctrl_s2[3];
        lsu_type_i = ctrl_s2[2:1];
        lsu_wdata_i = rs2_value_S23;
        lsu_sign_ext_i = ctrl_s2[0];
        lsu_req_i = ctrl_s2[4];
        adder_result_ex_i = exec_result;
    end
end

stall_controller stall_ctrl (
    .clk(clk),
    .rst(rst),
    .rs1E(s1_buf.rs1),
    .rs2E(s1_buf.rs2),
    .rdW(rd_buf),
    .RegWriteW(Reg_wb),
    .RegWriteM(regwrite_wb),
    .ForwardAE(ForwardA),
    .ForwardBE(ForwardB),
    .rs1D(rs1_S12),
    .rs2D(rs2_S12),
    .rdE(s1_buf.rd_s12),
    .uses_rs1D(uses_rs1_S12),
    .uses_rs2D(uses_rs2_S12),
    .loadE(loadE),
    .load_hazard(load_hazard),
    .mul_req(s1_buf.ctrl[6]),
    .mul_start(mul_start),
    .M_over(M_over),
    .lsu_busy(busy_o),
    .pipe_stall(m_stall),
    .rdM(rd_wb)
);

LSU_RVX lsu(
  .clk(clk),
  .rst(rst),

  // data interface
  .data_req_o(data_req_o),
  .data_gnt_i(data_gnt_i),
  .data_rvalid_i(data_rvalid_i),

  .data_addr_o(data_addr_o),
  .data_we_o(data_we_o),
  .data_be_o(data_be_o),
  .data_wdata_o(data_wdata_o),
  .data_rdata_i(data_rdata_i),

  // ID/EX inputs
  .lsu_we_i(lsu_we_i),
  .lsu_type_i(lsu_type_i),
  .lsu_wdata_i(lsu_wdata_i),
  .lsu_sign_ext_i(lsu_sign_ext_i),
  .lsu_req_i(lsu_req_i),
  .adder_result_ex_i(adder_result_ex_i),

  // outputs to WB / pipeline control
  .lsu_rdata_o(lsu_rdata_o),
  .lsu_rdata_valid_o(lsu_rdata_valid_o),
  .busy_o(busy_o)
);

data_ram #(
    .ADDR_WIDTH(DATA_ADDR_WIDTH),
    .DATA_WIDTH(32),
    .NUM_WORDS(DATA_WORDS)
) dram(
    .clk(clk),
    .en_i(dram_en_i),
    .addr_i(dram_addr_i),
    .wdata_i(dram_wdata_i),
    .rdata_o(dram_rdata_i),
    .we_i(dram_we_i),
    .be_i(dram_be_i),
    .sign_ext_i(dram_sign_ext_i)
);
logic [1:0] mem_select_wb;
// EXE-MEM stage buffer
always_ff @(posedge clk) begin
    if (rst) begin
        alu_result_wb <= 32'd0;
        pc_wb         <= 32'd0;
        memtoreg_wb   <= 2'b00;
        rd_wb         <= 5'd0;
        regwrite_wb   <= 1'b0;
        mem_select_wb <= 2'b00;
    end
    else if (m_stall) begin
        alu_result_wb <= alu_result_wb; // Hold the current values in the buffer
        pc_wb         <= pc_wb;
        memtoreg_wb   <= memtoreg_wb;
        rd_wb         <= rd_wb;
        regwrite_wb   <= regwrite_wb;
        mem_select_wb <= mem_select_wb;
    end
    else begin
        alu_result_wb <= exec_result;
        pc_wb         <= pc_out_s2;
        memtoreg_wb   <= ctrl_s2[7:6];
        rd_wb         <= rd_S23;
        regwrite_wb   <= ctrl_s2[5];
        mem_select_wb <= mem_select;
    end
end
logic [31:0] mem_data_wb;

always_comb begin
    mem_data_wb = 32'd0;
    case(mem_select_wb)
        2'b00: mem_data_wb = dram_rdata_i;
        2'b01: mem_data_wb = rdata_mem;
        2'b10: mem_data_wb = lsu_rdata_valid_o ? lsu_rdata_o : 32'd0;
        default: mem_data_wb = 32'd0;
    endcase
end
//MEM-WB stage buffer
always_ff @(posedge clk) begin
    if (rst) begin
        alu_result_buf <= 32'd0;
        pc_buf         <= 32'd0;
        memtoreg_buf   <= 2'b00;
        mem_data_buf    <= 32'd0;
        rd_buf          <= 5'd0;
        regwrite_buf    <= 1'b0;
    end
    else begin
        alu_result_buf <= alu_result_wb;
        pc_buf         <= pc_wb;
        memtoreg_buf   <= memtoreg_wb;
        mem_data_buf    <= mem_data_wb;
        rd_buf          <= rd_wb;
        regwrite_buf    <= regwrite_wb;
    end
end
//WB Mux
memtoreg_mux mux_wb (
    .alu_result (alu_result_buf),
    .mem_data   (mem_data_buf),
    .pc         (pc_buf),
    .MemtoReg   (memtoreg_buf),
    .wb_data    (data_wb)
);
assign rd_out = rd_buf;
assign Reg_wb = regwrite_buf;

endmodule

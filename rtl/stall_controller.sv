module stall_controller (
    input  logic clk,
    input  logic rst,
    //Forwarding Unit Signals
    input logic [4:0] rs1E,rs2E,rdW,
    input logic RegWriteW,
    output logic ForwardAE,ForwardBE,
    // MUL
    input  logic mul_start,
    input  logic M_over,
    // LSU
    input  logic lsu_busy,
    // Final stall
    output logic pipe_stall
);
logic M_busy;
    always_comb begin
        if((rs1E == rdW)&&(RegWriteW)&&(rdW!=0))
            ForwardAE = 1'b1;
        else 
            ForwardAE = 1'b0;
        if((rs2E == rdW)&&(RegWriteW)&&(rdW!=0))
            ForwardBE = 1'b1;
        else
            ForwardBE = 1'b0;
    end

    always_ff @ (posedge clk) begin
        if(rst)
            M_busy <= 0;
        else if (mul_start)
            M_busy <= 1'b1;
        else if (M_over)
            M_busy <= 1'b0;
        else
            M_busy <= 0;
    end

assign pipe_stall = M_busy || lsu_busy;

endmodule

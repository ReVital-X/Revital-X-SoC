module stall_controller (
    input  logic clk,
    input  logic rst,
    //Forwarding Unit Signals
    input logic [4:0] rs1E,rs2E,rdW,rdM,
    input logic RegWriteW,
    output logic ForwardSelect,
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
        if((rs1E == rdW)&&(RegWriteW)&&(rdW!=0))begin
            ForwardAE = 1'b1;
            ForwardSelect = 1'b0;
        end
        else begin
            ForwardAE = 1'b0;
            ForwardSelect = 1'b1;
        end
        if((rs2E == rdW)&&(RegWriteW)&&(rdW!=0))begin
            ForwardBE = 1'b1;
            ForwardSelect = 1'b0;
        end 
        else begin
            ForwardBE = 1'b0; 
            ForwardSelect = 1'b1;
        end
        if((rs1E == rdM)&&(RegWriteW)&&(rdM!=0))begin
            ForwardAE = 1'b1;
            ForwardSelect = 1'b1;
        end 
        else begin
            ForwardAE = 1'b0;
            ForwardSelect = 1'b1;
        end
        if((rs2E == rdM)&&(RegWriteW)&&(rdM!=0))begin
            ForwardBE = 1'b1;
            ForwardSelect = 1'b1;
        end
        else begin
            ForwardBE = 1'b0;
            ForwardSelect = 1'b1;
        end
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

module forwarding_unit (
    input logic [4:0] rs1E,rs2E,rdW,
    input logic RegWriteW,
    output logic ForwardAE,ForwardBE
);
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
endmodule
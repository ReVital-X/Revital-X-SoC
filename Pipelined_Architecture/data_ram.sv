module data_ram (
    input logic clk,
    input logic [31:0] address,
    input logic [31:0] write_data,
    input logic MemRead,
    input logic MemWrite,
    output logic [31:0] read_data
);
    logic [31:0] mem [0:1023];
    always_ff @ (posedge clk) begin
        if (MemRead) begin
            read_data <= mem [address[31:2]] ;
        end 
        if (MemWrite) begin
            mem [address[31:2]] <= write_data;
        end
    end
endmodule
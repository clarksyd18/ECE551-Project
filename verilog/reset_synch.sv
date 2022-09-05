////////////////////////////////////////////////////////
//  Synchronizes the reset signal to every module
////////////////////////////////////////////////////////
module reset_synch(clk, RST_n, rst_n);
input clk;
input RST_n;
output logic rst_n;
logic RST_N_FF1, RST_N_FF2;

// double flop for metastability because RST_n is asynch signal
always_ff @(negedge clk or negedge RST_n)begin
    if(!RST_n) begin
        RST_N_FF1 <= 0;
        RST_N_FF2 <= 0;
    end
    else begin
        RST_N_FF1 <= 1;
        RST_N_FF2 <= RST_N_FF1;
    end
end

assign rst_n = RST_N_FF2;

endmodule

//////////////////////////////////////////////////////////////
// PB release block synchronizes a push button switch and then perform
// rising edge detection on it.
///////////////////////////////////////////////////////////////
module PB_release(clk, rst_n, PB, released);
input clk;
input rst_n;
input PB;
output released;

logic PB_ff1, PB_ff2, PB_ff3;   // flip flop holding registers

// first two flops initiated for meta-stability
// Third flop is used to implement a rising edge detector
always_ff @(posedge clk or negedge rst_n)begin
    if (!rst_n)
      begin
        PB_ff1 <= 1;		// preset flip flops when reset
        PB_ff2 <= 1;
        PB_ff3 <= 1;
      end
    else
      begin
        PB_ff1 <= PB;		
        PB_ff2 <= PB_ff1;
        PB_ff3 <= PB_ff2;
      end
end
assign released = ~PB_ff3 & PB_ff2;



endmodule
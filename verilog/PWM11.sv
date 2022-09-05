///////////////////////////////////////////////////////////////////
// A PWM takes an unsigned number as it input, and produces a signal
// whose duty cycle is proportional to that number. 
////////////////////////////////////////////////////////////////
module PWM11(clk, rst_n, duty, PWM_sig, PWM_sig_n);

input clk, rst_n;	// system clock and reset
input [10:0] duty;	// specifies the duty counter
output logic PWM_sig;
output PWM_sig_n;
 
logic [10:0] cnt;
logic PWM_in;

// 11 bit counter that specifies the duty counter
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		cnt <= 11'h000;
	else
		cnt <= (cnt + 1);

assign PWM_in = cnt < duty;

// flops the output signal
always_ff @(posedge clk, negedge rst_n)
		if(!rst_n)
			PWM_sig <= 1'b0;
		else 
			PWM_sig <= PWM_in;

assign PWM_sig_n = ~PWM_sig;

endmodule


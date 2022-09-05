
// Motor Drive send the correct duty cycles to the motor 
module MtrDrv(clk, rst_n, lft_spd, rght_spd, lftPWM1, lftPWM2, rghtPWM1, rghtPWM2);

input clk, rst_n;
input [10:0] lft_spd, rght_spd;
output logic lftPWM1, rghtPWM1;
output lftPWM2, rghtPWM2;

logic [10:0] PWM_left_in, PWM_right_in;

assign PWM_left_in = lft_spd + 11'h400; // calculates left duty signal
assign PWM_right_in = rght_spd + 11'h400;   // calculates right duty signal

PWM11 PWM_left(.clk(clk), .rst_n(rst_n), .duty(PWM_left_in), .PWM_sig(lftPWM1), .PWM_sig_n(lftPWM2));
PWM11 PWM_right(.clk(clk), .rst_n(rst_n), .duty(PWM_right_in), .PWM_sig(rghtPWM1), .PWM_sig_n(rghtPWM2));

endmodule


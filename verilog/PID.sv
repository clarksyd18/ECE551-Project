///////////////////////////////////////////////////////////////////
// convert this error signal to motor speed signals such
// that the error is driven to zero
////////////////////////////////////////////////////////////////
module PID(clk, rst_n, moving, err_vld, error, frwrd, lft_spd, rght_spd);

input clk, rst_n;	// system reset and clock
input moving;	// clear I_term if not moving
input err_vld;	// compute I & D again when vld
input signed [11:0] error;	// signed error into PID
input [9:0] frwrd;	// summed with PID to form left & right speed
output  [10:0] lft_spd, rght_spd;	// left and right speeds of the motor

logic signed [9:0] err_sat_inter;

// P term logic
logic signed [9:0] err_sat;
logic signed [13:0] P_term;
localparam signed P_COEFF = 5'h08;

// I term logic
logic [14:0] integrator, nxt_integrator, err_sat_sext, err_integrator_sum, sum_integrator_mux_result;
logic [8:0] I_term;
logic overflow;

// D term logic
logic [9:0] prev_err_intermediate, prev_err, D_diff;
logic [6:0] D_diff_sat;
logic [12:0] D_diff_sat_sext, D_diff_sat_eight, D_diff_sat_two;
logic [12:0] D_term;
localparam signed D_COEFF = 6'h0b;

// Logic specifically for this module
logic signed [13:0] I_term_sext, D_term_sext;
logic signed [13:0] PID;
logic signed [10:0] frwrd_zext, lft_sum, rght_sum, lft_spd_inter, rght_spd_inter, lft_spd_inter_ff, rght_spd_inter_ff, lft_spd_inter_ff1, rght_spd_inter_ff1;
logic [10:0] lft_spd_ff, lft_spd_ff1, rght_spd_ff, rght_spd_ff1;

// Pipelining of PID
logic [13:0]P_term_ff, I_term_ff, D_term_ff, frwrd_zext_ff, frwrd_zext_ff1;

// P term calculations
assign err_sat_inter = error[11] ?
							(~&error[10:9] ? 10'h200 : {1'b1, error[8:0]}) : // if error is negative and big, change to h200
							(|error[10:9] ? 10'h1ff : {1'b0, error[8:0]}); // if error is positive and big, change to h1ff

always_ff @(posedge clk) // pipelining flop to meet timing constraints
	err_sat <= err_sat_inter;

assign P_term = {err_sat[9], err_sat, {3{1'b0}}}; // signed multiply by h08

// I term calculations
assign err_sat_sext = {{5{err_sat[9]}}, err_sat};
assign err_integrator_sum = err_sat_sext + integrator;
assign overflow = err_sat_sext[14] ^~ integrator[14] ? (err_sat_sext[14] ^ err_integrator_sum[14] ? 1'b1 : 1'b0) : 1'b0; // if err_sat and integrator are both positive or negative, and their sum's sign doesn't match, then overflow occured
assign sum_integrator_mux_result = ~overflow & err_vld ? err_integrator_sum : integrator; // use previous value of integrator if there is overflow or an invalid error
assign nxt_integrator = moving ? sum_integrator_mux_result : 15'h0000; //don't drive motor if not moving, so I term should be 0
assign I_term = integrator[14:6];  // used to hold previous value of I term kind of
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		integrator <= 15'h0000;
	else
		integrator <= nxt_integrator;

// D term calculations
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		prev_err_intermediate <= 10'b0;
		prev_err <= 10'b0;
	end
	else if (err_vld) begin
		prev_err_intermediate <= err_sat;
		prev_err <= prev_err_intermediate;
	end
end

assign D_diff = err_sat - prev_err;

assign D_diff_sat = D_diff[9] ?
							(~&D_diff[8:6] ? 7'h40 : {1'b1, D_diff[5:0]}) : // if D_diff is negative and big, change to h40
							(|D_diff[8:6] ? 7'h3f : {1'b0, D_diff[5:0]}); // if D_diff is positive and big, change to h3fs


// multiply D_diff_sat by h0b to get D_term
assign D_diff_sat_sext = {{6{D_diff_sat[6]}}, D_diff_sat};
assign D_diff_sat_eight = {{3{D_diff_sat[6]}}, D_diff_sat, {3{1'b0}}};
assign D_diff_sat_two = {{5{D_diff_sat[6]}}, D_diff_sat, 1'b0};
assign D_term = D_diff_sat_sext + D_diff_sat_two + D_diff_sat_eight;


assign I_term_sext = {{5{I_term[8]}}, I_term};
assign D_term_sext = {D_term[12], D_term};
assign frwrd_zext = {1'b0, frwrd};

// pipelining P, I, and D terms to meet timing contraints
// frwrd_zext needs to be pipelined twice for timing to be correct
always_ff @(posedge clk) begin
	P_term_ff <= P_term;
	I_term_ff <= I_term_sext;
	D_term_ff <= D_term_sext;
	frwrd_zext_ff <= frwrd_zext;
	frwrd_zext_ff1 <= frwrd_zext_ff;
end


// Generate PID
assign PID = P_term_ff + I_term_ff + D_term_ff;

// Add/subtract PID with frwrd
assign lft_sum = PID[13:3] + frwrd_zext_ff1;
assign rght_sum = frwrd_zext_ff1 - PID[13:3];
//
assign lft_spd_inter_ff1 = moving ? lft_sum : 11'h000;
assign rght_spd_inter_ff1 = moving ? rght_sum : 11'h000;

// Pipelining left speed and right speed intermediate calculations to meet timing constraints
always_ff @(posedge clk) begin
	lft_spd_inter_ff <= lft_spd_inter_ff1;
	rght_spd_inter_ff <= rght_spd_inter_ff1;
end
assign lft_spd_inter = lft_spd_inter_ff;
assign rght_spd_inter = rght_spd_inter_ff;

// determine left and right speed
assign lft_spd_ff1 = (~PID[13] & lft_spd_inter[10]) ? 11'h3ff : lft_spd_inter;
assign rght_spd_ff1 = (PID[13] & rght_spd_inter[10]) ? 11'h3ff : rght_spd_inter;

// Pipelining left speed and right speed to meet timing constraints
always_ff @(posedge clk) begin
	lft_spd_ff <= lft_spd_ff1;
	rght_spd_ff <= rght_spd_ff1;
end

assign lft_spd = lft_spd_ff;
assign rght_spd = rght_spd_ff;
endmodule

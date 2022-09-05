// Allison, Garrett, Kareena, & Sydney

module cmd_proc(clk, rst_n, cmd, cmd_rdy, clr_cmd_rdy, send_resp, tour_go, heading,
    heading_rdy, strt_cal, cal_done, moving, lftIR, cntrIR, rghtIR, fanfare_go, frwrd, error);
////////////////////////////////////////////////////////////////////////////////////////////////////
// cmd_proc processes incoming commands from UART_Wrapper. The command could be calibrate         //
// gyro, a movement command, or a complete tour command. cmd_proc receives the desired heading    //
// coming from inert_int, it generates the error term to the PID. Cmd_proc also determines the	  //
// forward speed. It sends the error and forward to PID. 										 //
//////////////////////////////////////////////////////////////////////////////////////////////////

// Signals to/from UART Wrapper
input clk, rst_n;   // clock and active low reset
input [15:0] cmd;	// 16 bit command from UART_wrapper
input cmd_rdy;      // indicates that the command has been recieved
output logic clr_cmd_rdy; // clears the cmd_rdy signal
output logic send_resp;   // asserted when transmission complete

//signal to TourLogic/TourCmd
output logic tour_go;     // to TourLogic/TourCmd

//Signals to/from inert_intf
input signed [11:0] heading;    // heading of robot.  000 = Orig dir 3FF = 90 CCW 7FF = 180 CCW
input heading_rdy;  	 // goes high for 1 clock when new outputs ready (from inertial_integrator)
output logic strt_cal;   // initiate claibration of yaw readings
input cal_done;     // pulses high for 1 clock when calibration done
output logic moving;   // Only integrate yaw when going

//Signals from IR sensors
input lftIR, rghtIR; // left and right IRs are used for course corection
input  cntrIR; 		// center IR sensors see two pulses for every square it moves
//Signal to charge
output logic fanfare_go;  // signals start of music

//Signals to PID
output logic [9:0] frwrd;	// summed with PID to form left speed and right speed
output [11:0] error;		// Signed error into PID


////////////////////////////////////////////
// Declare any needed internal registers //
//////////////////////////////////////////
    logic [9:0] frwrd_speed; // determines new forward speed
    logic zero;		// asserted when forward speed is zero
    logic max_spd;	// asserted when forward speed is at max
    logic [7:0]increment, decrement;	// used to determine the amount to increase or decrease the forward speed
    logic update_speed;	// when enabled, change speed of forward

    logic [2:0] cmd_squares;	// register used to hold number of squares moved
	logic [3:0] cntrIR_count; 	// used to count cntrlIR squares
    logic rise_edge_cntrIR; // rising edge of cntrlIR when asserted
    logic cntrIR_ff;	// register used to determine the rising edge detect of cntrIR
	logic move_done;	// asserted when move command is issued

	// registers used to calculate the error term
	logic [11:0] desired_heading, lft_err_nudge, rght_err_nudge, err_nudge;
    logic error_small;

	parameter FAST_SIM = 1; // defaulted to one for testbench purposes

//////////////////////////////////////////////
// Declare outputs of SM are of type logic //
////////////////////////////////////////////
    logic clr_frwrd;	// clears forward speed when asserted
    logic dec_frwrd;	// decreases speed of forward when asserted
    logic inc_frwrd;	// Increases speed of forward when asserted
	logic move_cmd;		// Resets Line counter (square counter)
	logic fanfare;		// asserted when command is moving with fanfare
///////////////////////////////////////
// Create enumerated type for state //
/////////////////////////////////////

 typedef enum reg  [2:0] {IDLE, CAL, MOVING, RAMP_UP, RAMP_DOWN} state_t;
  state_t state,nxt_state;

/////////////////////////////////////////////////////////////////////////////////
// FORWARD SPEED REGISTER: goes to PID block and is added to the PID          //
// steering controls to  determine the overall forward speed of the motors.  //
//////////////////////////////////////////////////////////////////////////////

	always_ff @(posedge clk or negedge rst_n)begin
		if(!rst_n)
			frwrd <= 10'h000;
		else if(clr_frwrd)
			frwrd <= 10'h000;
		else if(update_speed)
		frwrd <= frwrd_speed;
	end

	// Determines new forward speed
	assign frwrd_speed = (inc_frwrd) ? (frwrd + increment) : (frwrd - decrement);
	assign max_spd = &frwrd[9:8];	// max speed is h300
	assign zero = ~|frwrd;
	assign increment = FAST_SIM ? 8'h20 : 8'h04;	// increment and decrement amount
	assign decrement = FAST_SIM ? 8'h40 : 8'h08;	// determined by FAST_SIM parameter

	assign update_speed = heading_rdy ? // change forward register only when a new heading is ready
				(inc_frwrd ? // don't increase speed when reached max speed
					(max_spd ? 0 : 1) :
				(dec_frwrd ?	// don't decrease speed when at zero
					(zero ? 0 : 1) :
				0)) :
				0;

/////////////////////////////////////////////////////////////////////////////////
// COUNTING SQUARES:  The central IR sensor will see pulses for every		  //
// square it moves. The robot stops when it sees the second pulse of cntrlIR. //
// The code below is used to determine the second pulse of cntrlIR. 		//
///////////////////////////////////////////////////////////////////////////////
	always_ff @(posedge clk or negedge rst_n)begin
		if(!rst_n)
			cmd_squares <= 3'h0;
		else if(move_cmd)	// when move command is issued, number of squares to move is in cmd[2:0]
			cmd_squares <= cmd[2:0];
	end

	always_ff @(posedge clk or negedge rst_n)begin
		if(!rst_n)
			cntrIR_count <= 4'h0;
		else if (move_cmd) 	// clears center counter when move_cmd is asserted
			cntrIR_count <= 4'h0;
		else if(rise_edge_cntrIR)
			cntrIR_count <= cntrIR_count + 1;
	end

	// compares two times the number of squares to the center line counter
	assign move_done = ({cmd_squares, 1'b0} == cntrIR_count);

	// rise edge detect cntrIR used to increment only once per line
	always_ff @(posedge clk or negedge rst_n)begin
		if(!rst_n)
			cntrIR_ff <= 0;
		else
			cntrIR_ff <= cntrIR;
	end
	assign rise_edge_cntrIR = ~cntrIR_ff && cntrIR; // detects rising edge of cntrIR


/////////////////////////
// PID Interface Logic //
/////////////////////////
	// determines right and left nudges based on FAST_SIM parameter
	assign lft_err_nudge = FAST_SIM ? 12'h1ff : 12'h05f;
	assign rght_err_nudge = FAST_SIM ? 12'he00 : 12'hfa1;

	// when a move command comes in, cmd[11:4] is the heading
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n)
			desired_heading <= 12'h000;
		else if (move_cmd)
			desired_heading <= {cmd[11:4], 4'hf};	// if non-zero, will promote it 4 bits
	end
	// if left or right guardrail signals, needs to nudge either left or right
	assign err_nudge = lftIR ? lft_err_nudge : (rghtIR ? rght_err_nudge : 12'h000);
	assign error = heading - desired_heading + err_nudge; // determines error term based off of nudges and error
	assign error_small = error[11] ? (error > 12'hfd0 ? 1'b1: 1'b0) : (error < 12'h030 ? 1'b1: 1'b0);

	assign fanfare = cmd[12]; // will be 1 if command is move with fanfare

 /////////////////////////s//////
// Instantiate State Machine //
//////////////////////////////
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    state <= IDLE;
  else
    state <= nxt_state;

always_comb begin
	clr_frwrd = 0;
    dec_frwrd = 0; // asserted when forward speed decreasing
    inc_frwrd = 0; // asserted when forward speed increasing
	clr_cmd_rdy = 0;
	strt_cal = 0; // start calibration
	send_resp = 0;  // send a response from UART_wrapper
	moving = 0; // robot is moving
	move_cmd = 0; // whether cmd is move (with or without fanfare)
	fanfare_go = 0; // actually asserts fanfare for charge.sv
	tour_go = 0; // sent to TourLogic
	nxt_state = state;
    case(state)
		IDLE : begin
			if(cmd_rdy && (cmd[15:12] == 4'b0000))begin // calibrate command
				clr_cmd_rdy = 1;
				clr_frwrd = 1;
				strt_cal = 1;
				nxt_state = CAL;
			end else if(cmd_rdy && cmd[15:13] == 3'b001)begin // move command
				clr_cmd_rdy = 1;
				clr_frwrd = 1;
				move_cmd = 1;
				nxt_state = MOVING;
			end else if(cmd_rdy && (cmd[15:12] == 4'b0100))begin // start tour command
				clr_cmd_rdy = 1;
				tour_go = 1;
				nxt_state = IDLE;
			end
		end
		CAL : begin
			clr_frwrd = 1;
			if(cal_done)begin
				send_resp = 1;
				nxt_state = IDLE;
			end
		end
		MOVING : begin
			moving = 1;
			if(error_small) // if robot is done turning, we should start moving forward
				nxt_state = RAMP_UP;
		end
		RAMP_UP : begin
			moving = 1;
			inc_frwrd = 1;
			if(move_done)begin
				nxt_state = RAMP_DOWN;
				if(fanfare) begin
					fanfare_go = 1;
				end
			end
		end
		RAMP_DOWN : begin
			moving = 1;
			dec_frwrd = 1;
			if(frwrd == 10'h000) begin
				send_resp = 1;
				nxt_state = IDLE;
			end
		end
	endcase
end

endmodule

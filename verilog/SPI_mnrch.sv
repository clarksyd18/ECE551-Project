

module SPI_mnrch(clk, rst_n, wrt, wrt_data, done, rd_data, SS_n, SCLK, MOSI, MISO);
  ///////////////////////////////////////////////////////////////
  //  SPI_mnrch is essentially a 16 bit shift
  //  register that that can parallel load data that we
  //  want to transmit, then shift it out (MSB first), 
  // at the same time it receives data from the serf in the LSB
  ///////////////////////////////////////////////////////////////

input clk, rst_n;		// clock and active low reset
input wrt;			// initiates a SPI transaction 
input MISO;			// Monarch In Serf Out - 
input [15:0] wrt_data;		// data(command) being sent to inertial sensor
output logic done;			// asserted when SPI transaction is complete
output logic [15:0] rd_data;		// data from SPI serf
output logic SS_n;			// Active low Serf Select
output logic MOSI;			// Monach Out Serf In - 
output logic SCLK;			// serial clock

//// Define state as enumerated type /////
typedef enum reg  [1:0] {IDLE, FRONT_PORCH, TRANSMITTING, BACK_PORCH} state_t;
state_t state,nxt_state;

// Register Intermediates
logic [3:0] bit_cntr;		// amount of shifts
logic [4:0] SCLK_div;		// clock cycle count - 32 counts per SCLK high, 32 per SCLK low
logic MISO_smpl;		// holds MISO sample

// SM controls
logic init;		// SM control used to initialize
logic shift;		// indicates shift in the register
logic ld_SCLK;		// preset SCLK
logic smpl;		// indicates MISO is ready
logic set_done;		// indicates that rd_data is ready, done should be asserted next clock cycle
logic rising_edge, falling_edge;

//////////////////////////////////////
// 16-bit counter that keeps track //
//  of the amount of shifts       //
///////////////////////////////////
always_ff @(posedge clk)begin
	if(init)
		bit_cntr <= 4'h0;
	else if (shift)
		bit_cntr <= bit_cntr + 1;
end

/////////////////////////////////
// continuous assignment flow //
///////////////////////////////
assign MOSI = rd_data[15];	// MOSI is MSB of shifted signal
assign SCLK = SCLK_div[4];	// SCLK is equal to MSB 
assign rising_edge = (SCLK_div == 5'h0F);
assign falling_edge = &SCLK_div;

/////////////////////////////////
// 5-bit counter that counts  //
// 
///////////////////////////////
always_ff @(posedge clk)begin
	if(ld_SCLK)
		SCLK_div <= 5'b10111;
	else
		SCLK_div <= SCLK_div + 1;
end


/////////////////
// MISO FLOP  //
///////////////
always_ff @(posedge clk)
	if(smpl)
		MISO_smpl <= MISO;

/////////////////////////////
// 16-bit shift register  //
///////////////////////////
always_ff @(posedge clk)begin
	if(init)
		rd_data <= wrt_data;
	else if(shift)
		rd_data <= {rd_data[14:0], MISO_smpl};
end


//////////////////////////////////////
// done is implemented with a flop  //
/////////////////////////////////////
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		done <= 1'b0; 
	else if(init)
		done <= 1'b0; 
	else if (set_done)
		done <= 1'b1;
end

////////////////////////////
// preset SS_N FLIP FLOP //
//////////////////////////
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		SS_n <= 1'b1; 
	else if(init)
		SS_n <= 1'b0; 
	else if(set_done)
		SS_n <= 1'b1; 
		
end

///////////////////////////////
// Instantiate State Machine //
//////////////////////////////


always_ff @(posedge clk)begin
	if(!rst_n)
		state <= IDLE;
	else 
		state <= nxt_state;
end

always_comb begin
	init = 0;
	set_done = 0;
	smpl = 0;
	shift = 0;
	ld_SCLK = 0;
	nxt_state = state;
	case (state)
	IDLE : begin
		ld_SCLK = 1;	// initialize SCLOCK
		if (wrt) begin 			
		init = 1;	// initialize bit counter & 16 bit shift register
		nxt_state = FRONT_PORCH;
		end
	end
	FRONT_PORCH : begin
		if(falling_edge) // falling SCLK = MOSI
			nxt_state = TRANSMITTING;
	end
	TRANSMITTING : begin
		smpl = rising_edge;
		shift = falling_edge;
		if (&bit_cntr) begin
			nxt_state = BACK_PORCH;
		end
	end
	BACK_PORCH : begin
		smpl = rising_edge;
		shift = falling_edge;
		if (falling_edge) begin	// falling SCLK = MOSI	
			smpl = 1;
			shift = 1;
			ld_SCLK = 1;	
			set_done = 1;
			nxt_state = IDLE;
		end
	end
	default:
		nxt_state = IDLE;
	endcase
end



endmodule	


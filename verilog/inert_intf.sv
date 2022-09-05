//////////////////////////////////////////////////////
// SPI interface interacts with inertial sensor.   //
// This module gives us the heading of the robot  //
// and tell us when calibration is ready given   //
/////////////////////////////////////////////////
module inert_intf(clk,rst_n,strt_cal,cal_done,heading,rdy,lftIR,
                  rghtIR,SS_n,SCLK,MOSI,MISO,INT,moving);

  parameter FAST_SIM = 1;	// used to speed up simulation
  
  input clk, rst_n;
  input MISO;					// SPI input from inertial sensor
  input INT;					// goes high when measurement ready
  input strt_cal;				// initiate claibration of yaw readings
  input moving;					// Only integrate yaw when going
  input lftIR,rghtIR;			// gaurdrail sensors
  
  output cal_done;				// pulses high for 1 clock when calibration done
  output signed [11:0] heading;	// heading of robot.  000 = Orig dir 3FF = 90 CCW 7FF = 180 CCW
  output rdy;					// goes high for 1 clock when new outputs ready (from inertial_integrator)
  output SS_n,SCLK,MOSI;		// SPI outputs
 

  ////////////////////////////////////////////
  // Declare any needed internal registers //
  //////////////////////////////////////////
   logic INT_ff1, INT_ff2;  // buffers asynch INT signal
   logic [15:0] inert_data;  // data from SPI serf
   logic [7:0] yawL;
   logic [7:0] yawH;
	logic [15:0]yaw_rt;
	logic [15:0]cnt, cnt_mux;
	logic cnt_max;
	logic [7:0]LED;
  
  //////////////////////////////////////////////
  // Declare outputs of SM are of type logic //
  ////////////////////////////////////////////
  logic wrt;        // initiates a SPI transaction
  logic [15:0] cmd; // data being sent from SPI mnrch
  logic C_Y_H;      // asserted when yaw high is ready to be read
  logic C_Y_L;      // asserted when yaw low is ready to be read
  logic vld;
  
  
  ///////////////////////////////////////
  // Create enumerated type for state //
  /////////////////////////////////////
  typedef enum logic[2:0] {INIT1, INIT2, INIT3, INT_IDLE, READ_Y_L, READ_Y_H, READ_RDY}state_t;
  state_t state, nxt_state;
  
  ////////////////////////////////////////////////////////////
  // Instantiate SPI monarch for Inertial Sensor interface //
  //////////////////////////////////////////////////////////
  SPI_mnrch iSPI(.clk(clk),.rst_n(rst_n),.SS_n(SS_n),.SCLK(SCLK),
                 .MISO(MISO),.MOSI(MOSI),.wrt(wrt),.done(done),
				 .rd_data(inert_data),.wrt_data(cmd));
				  
  ////////////////////////////////////////////////////////////////////
  // Instantiate Angle Engine that takes in angular rate readings  //
  // and acceleration info and produces a heading reading         //
  /////////////////////////////////////////////////////////////////
  inertial_integrator #(FAST_SIM) iINT(.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal),.vld(vld),
                           .rdy(rdy),.cal_done(cal_done), .yaw_rt(yaw_rt),.moving(moving),.lftIR(lftIR),
                           .rghtIR(rghtIR),.heading(heading));
	
  ////////////////////////////////////////////////
  // INT is asynch, so need to double flop     //
  // prior to use for meta-stability purposes //
  /////////////////////////////////////////////
	always_ff @(posedge clk) begin
		if (C_Y_L) begin
			INT_ff1 <= 1'b0;			// reset to idle state
			INT_ff2 <= 1'b0;
		end else begin
			INT_ff1 <= INT;
			INT_ff2 <= INT_ff1;
		end
	end

  ////////////////////////////
  // 8 bit hold register  //
  //////////////////////////
	always_ff @(posedge clk)begin
		if(C_Y_L)
			yawL <= inert_data[7:0];
		else if(C_Y_H)
			yawH <= inert_data[7:0];
	end
  
  //Combine signals
	assign yaw_rt = {yawH, yawL};
	
  ///////////////////////////////
  // 16 bit timer              //
  ///////////////////////////////
	assign cnt_mux = !rst_n ? 16'h0000 : cnt+1;
	assign cnt_max = 16'hffff == cnt ? 1'b1 : 1'b0;
	always_ff @(posedge clk) begin
		
		cnt <= cnt_mux;
	end
  
  ///////////////////////////////
  // Instantiate State Machine //
  //////////////////////////////

always_ff @(posedge clk)begin
	if(!rst_n)
		state <= INIT1;
	else 
		state <= nxt_state;
end

always_comb begin
	wrt = 1'b0;
	vld = 1'b0;
	C_Y_L = 1'b0;
	C_Y_H = 1'b0;
	cmd = 16'hxxxx;
	nxt_state = state;
		case (state)
			INIT1: begin
				cmd = 16'h0D02; // writes to register to configure the INT output pin
				if(cnt_max)begin
					wrt = 1'b1;
					nxt_state = INIT2;
				end
			end
			INIT2 : begin
				cmd = 16'h1160;	 
				if(done)begin
					wrt = 1'b1;
					nxt_state = INIT3;
				end
			end
			INIT3 : begin
				cmd = 16'h1440;
				if(done)begin
					wrt = 1'b1;
					nxt_state = INT_IDLE;
				end
			end
			INT_IDLE: begin
				cmd = 16'hA6xx;	
				if(INT_ff2) begin
					wrt = 1'b1;
					nxt_state = READ_Y_L;
				end
			end
			READ_Y_L : begin
				cmd = 16'hA7xx; 
				if(done) begin
					wrt = 1'b1;
					C_Y_L = 1'b1;
					nxt_state = READ_Y_H;
				end
			end
			READ_Y_H : begin
				if(done) begin
					C_Y_H = 1'b1;
					nxt_state = READ_RDY;
				end
			end
			default : begin
				vld = 1'b1;
				nxt_state = INT_IDLE;
			end
	endcase
end

  
 
endmodule
	  

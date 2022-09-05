module TourCmd(clk, rst_n, start_tour, mv_indx, move, cmd_UART, cmd_rdy_UART, cmd, clr_cmd_rdy, send_resp, resp, cmd_rdy);

input clk, rst_n; 
input start_tour, cmd_rdy_UART, clr_cmd_rdy, send_resp; 
input [7:0] move;      // Move command from TourLogic
input [15:0] cmd_UART; //cmd given from UART_wrapper
output [4:0] mv_indx;  //Used to access move of solution from TourLogic’s memory
output [15:0] cmd;     //Command to cmd_proc 
output cmd_rdy;	       //cmd_rdy to cmd_proc
output [7:0] resp;     // Response to send to host, either 0xA5 or 0x5A

logic [15:0] tour_cmd;
logic [4:0] mv_indx_reg;
logic mv_indx_full;

// signals for state machine
logic x_move, cmd_rdy_tour, cmd_sel, mv_indx_clr, mv_indx_incr;

// create command from tour logic output. Bits 12-4 are direction command
assign tour_cmd = move[0] ? (x_move ? 16'h33f1 : 16'h2002) :
				  move[1] ? (x_move ? 16'h3bf1 : 16'h2002) :
				  move[2] ? (x_move ? 16'h33f2 : 16'h2001) :
				  move[3] ? (x_move ? 16'h33f2 : 16'h27f1) :
				  move[4] ? (x_move ? 16'h33f1 : 16'h27f2) :
				  move[5] ? (x_move ? 16'h3bf1 : 16'h27f2) :
				  move[6] ? (x_move ? 16'h3bf2 : 16'h2001) :
				  move[7] ? (x_move ? 16'h3bf2 : 16'h27f1) :
				  16'h2000; // don't move if no bits are 1, case stmt should never actually reach here

//Determine if output cmd and cmd_rdy comes from UART_wrapper or TourLogic
assign cmd = cmd_sel ? cmd_UART : tour_cmd;
assign cmd_rdy = cmd_sel ? cmd_rdy_UART : cmd_rdy_tour;

always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		mv_indx_reg <= 5'h00;
	else if (mv_indx_clr)
		mv_indx_reg <= 5'h00;
	else if (mv_indx_incr)
		mv_indx_reg <= mv_indx_reg + 1'b1;

assign mv_indx_full = mv_indx_reg == 5'd23;
assign mv_indx = mv_indx_reg;

// resp will only ever change value when send_resp is asserted
assign resp = (cmd_sel | mv_indx_full) ? 8'ha5 : 8'h5a;


// state definitions for SM 
typedef enum reg [2:0] {IDLE,Y_one, Y_two, X_one, X_two} state_t;
  state_t state,nxt_state;

//State Machine
always_ff @(posedge clk or negedge rst_n)begin
    if (!rst_n)
	  state <= IDLE;
	else 
	  state <= nxt_state;
end


always_comb begin
  cmd_sel = 0; //Select which Byte should be transmitted
  mv_indx_clr = 0;
  mv_indx_incr = 0;
  x_move =0;
  cmd_rdy_tour = 0;
  nxt_state = state;
case (state)
	  Y_one : begin
		cmd_rdy_tour = 1;
		if (clr_cmd_rdy) begin 
		  nxt_state = Y_two; 
		end 
	  end
	  Y_two : begin
		if (send_resp) begin 
		  nxt_state = X_one; 
		end 
	  end
	  X_one : begin
		cmd_rdy_tour = 1;
		x_move =1; 
		if (clr_cmd_rdy) begin 
		  nxt_state = X_two; 
		end 
	  end
	  X_two : begin
	    x_move =1; 
		if (send_resp & !mv_indx_full) begin 
		  mv_indx_incr = 1;
		  nxt_state = Y_one; 
		end 
		else if (send_resp & mv_indx_full) begin 
		  nxt_state = IDLE; 
		end 
	  end	  

	  default : begin // IDLE
	    cmd_sel = 1'b1;
		if (start_tour) begin  //When new data is being sent, start
		  mv_indx_clr = 1'b1;
		  nxt_state = Y_one;
		end  
	  end
	endcase
  end
endmodule
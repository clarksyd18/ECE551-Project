// Kareena Clendeing, ECE 551
module RemoteComm(clk, rst_n, RX, TX, cmd, send_cmd, cmd_sent, resp_rdy, resp);
////////////////////////////////////////////////////////
// RemoteComm takes a 16-bit command and sends it as two
// 8-bit bytes over to UART. 
////////////////////////////////////////////////////////

input clk, rst_n;		// clock and active low reset
input RX;			// serial data input
input logic send_cmd;		// indicates to tranmit 24-bit command (cmd)
input [15:0] cmd;		// 16-bit command

output TX;			// serial data output
output logic cmd_sent;		// indicates transmission of command complete
output resp_rdy;		// indicates 8-bit response has been received
output [7:0] resp;		// 8-bit response from DUT

wire [7:0] tx_data;		// 8-bit data to send to UART
wire tx_done;			// indicates 8-bit was sent over UART
wire rx_rdy;			// indicates 8-bit response is ready from UART

///////////////////////////////////////////////
// Registers needed & state machine control //
/////////////////////////////////////////////

logic [7:0] lower_byte; // used to buffer low byte of cmd
logic sel;		// SM control determines if lower or upper byte needs to be trasnmitted
logic set_cmd_sent;	// SM control that indicates cmd_sent should be asserted
logic trmt;		// SM control that tells TX section to transmit tx_data

////////////////////////////////
// Define state as enum type //
//////////////////////////////
typedef enum reg [1:0] {IDLE, UPPER_BYTE, LOWER_BYTE} state_t;
state_t state,nxt_state;

////////////////////////////
// Infer state flop next //
//////////////////////////
always_ff @(posedge clk)begin
	if(!rst_n)
		state <= IDLE;
	else 
		state <= nxt_state;
end

////////////////////////////////////
// Continuous assignement follow //
//////////////////////////////////
assign tx_data = sel ? cmd[15:8] : lower_byte;

////////////////////////////////////
// Infer lower byte of cmd signal //
////////////////////////////////////
always_ff @ (posedge clk) begin
	if(send_cmd)
		lower_byte <= cmd[7:0];  
end

///////////////////
// cmd_sent flop //
//////////////////
always_ff @(posedge clk, negedge rst_n)begin
	if(!rst_n)
		cmd_sent <= 0;
	else if(set_cmd_sent)
		cmd_sent <= 1;
	else if(send_cmd)
		cmd_sent <= 0;
end

//////////////////////////
// State machine logic //
////////////////////////
always_comb begin
  	//////////////////////////////////////
 	// Default assign all output of SM //
 	////////////////////////////////////
	set_cmd_sent = 0;
	trmt = 0;
	nxt_state = state;

	case (state)
	IDLE : begin
		if (send_cmd) begin
			trmt = 1; 
			sel = 1; // transmit upper byte
			nxt_state = UPPER_BYTE;
		end
	end
	UPPER_BYTE : begin	
		if (tx_done) begin	//upper byte has completed transmission
			trmt = 1;	
			sel = 0;	// transmit lower byte
			nxt_state = LOWER_BYTE;
		end
	end
	LOWER_BYTE : begin
		if (tx_done) begin	//lower byte has completed transmission
			trmt = 0;	
			set_cmd_sent = 1; //assert cmd_sent
			nxt_state = IDLE;
		end
	end

endcase
end



///////////////////////////////////
// Instantiate basic 8-bit UART //
/////////////////////////////////
UART iUART(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .tx_data(tx_data), .trmt(trmt),
           .tx_done(tx_done), .rx_data(resp), .rx_rdy(resp_rdy), .clr_rx_rdy(resp_rdy));
		   
					


endmodule	

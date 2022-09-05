module UART_wrapper(clk,rst_n, clr_cmd_rdy, cmd_rdy, cmd, trmt, resp, tx_done, TX, RX);

input clk,rst_n;	// clock and active low reset
input clr_cmd_rdy;	// clears cmd_rdy
input trmt;		// trmt input to 8-bit UART	
input [7:0] resp;       // Byte for tx_data for 8-bit UART 
output [15:0] cmd;	// 2 byte to transmit from 8-bit UART
output logic cmd_rdy;	// Asserted when wrapper is done transmitting
output tx_done;         // asstered when 8-bit UART is done transmitting
input RX;		
output TX;		

//SM Logic
logic clr_rdy,set_rdy;  // clears and sets rdy to UART
logic rx_rdy;		// output from UART 	
logic byte_select;	// determins if mux in UART wrapper should accept next byte
			// transmitted of hold high bytes
//Other
logic [7:0] rx_data;	//Byte from the UART
logic [7:0] cmd_mux;	// Byte selected by byte_select


///MUX 
always_ff @ (posedge clk) begin
  if(byte_select)
	cmd_mux <= rx_data; //store new byte from UART when avaliable
  else 
	cmd_mux <= cmd[15:8]; //Store the high byte of cmd
end
assign cmd[15:0] = { cmd_mux, rx_data}; //new cmd is the new byte as the LSByte and the stored MSByte

///State Machine
typedef enum reg [1:0] {IDLE, RX_RDY} state_t;
state_t state,nxt_state;


always_ff @(posedge clk or negedge rst_n)begin // Basically making cmd_rdy a set/reset flop
	if(!rst_n)
	  cmd_rdy <= 0;
	else if(clr_cmd_rdy)
	  cmd_rdy <= 0;
	else if(byte_select) //cmd shouldn't be ready when there's a new byte
	  cmd_rdy <= 0;
	else if (set_rdy)
	cmd_rdy <= 1;
end

// State Machine Flip Flop
always_ff @(posedge clk or negedge rst_n)begin
	if(!rst_n)
	  state <= IDLE;
	else 
	  state <= nxt_state;
  end

//////////////////////////
// State Machine Logic //
////////////////////////
always_comb begin
	byte_select = 0;
	clr_rdy = 0;
	set_rdy = 0;
	nxt_state = state;
	case (state)
	IDLE : begin
		if (rx_rdy) begin //begin when first byte is ready to be recieved from UART
		clr_rdy = 1;
		byte_select = 1;
		nxt_state = RX_RDY;
		end
	end
	default: begin    //RX_RDY state
		if (rx_rdy) begin //begin when second byte is ready to be recieved from UART
         		clr_rdy = 1;
			set_rdy = 1;
			byte_select =0;
			nxt_state = IDLE;
		end
	end

endcase
end

/////////////////////////////
// Instantiate 8-bit UART //
///////////////////////////
UART iDUT(.clk(clk), .rst_n(rst_n), .TX(TX), .trmt(trmt),
        .tx_data(resp), .tx_done(tx_done), .RX(RX), .rx_rdy(rx_rdy),
            .clr_rx_rdy(clr_rdy), .rx_data(rx_data));

endmodule

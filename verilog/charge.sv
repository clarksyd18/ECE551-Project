module charge(clk, rst_n, go, piezo, piezo_n);
input clk;
input rst_n;
input go;
output piezo;
output piezo_n;


//FAST_SIM
parameter FAST_SIM = 1;	// FAST_SIM is defaulted to true
logic [5:0]increment;
logic [15:0]timer;
logic [24:0] duration;
logic [15:0] fclk_cnt;

logic piezo_ff; 
//SM Logic
logic [15:0] set_timer;
logic zero_dur, fclk_zero;

//generate if statement to create an amount bu which you increment the timer
 generate if(FAST_SIM) begin
     assign increment = 6'h10;
 end else begin
     assign increment = 6'h01;
  end 
 endgenerate

// timer frequency 
always_ff @(posedge clk or negedge rst_n)begin
     if (!rst_n)begin
        timer <= 0;
     end
     else
        timer <= set_timer;
 end

// counter note duration 
always_ff @(posedge clk or negedge rst_n)begin
     if (!rst_n)
        duration <= 0;
     else if(zero_dur)
        duration <= 0;
     else
        duration<= duration + increment;
 end

// generate clk duty cycle
always_ff @(posedge clk or negedge rst_n)begin
     if (!rst_n)
        fclk_cnt <= 0;
     else if(fclk_zero)
        fclk_cnt <= 0;
     else if (timer == fclk_cnt)
	fclk_cnt <= 0;
     else
        fclk_cnt<= fclk_cnt + 1;
 end

always_ff @(posedge clk or negedge rst_n)begin
    if (!rst_n)
      begin
        piezo_ff <= 0;
      end
    else if (timer/2 == fclk_cnt) begin
	piezo_ff <= 0;
    end
    else if (timer == fclk_cnt) begin
	piezo_ff <= 1;
    end
	
end
assign piezo = piezo_ff;
assign piezo_n = !piezo_ff;

// state definitions for SM 
typedef enum reg [2:0] {IDLE,G6, C7, E7_one, G7_one, G7_one_short, E7_two, G7_two} state_t;
  state_t state,nxt_state;

//State Machine
always_ff @(posedge clk or negedge rst_n)begin
    if (!rst_n)
	  state <= IDLE;
	else 
	  state <= nxt_state;
end


always_comb begin
  //Select which Byte should be transmitted
  zero_dur =0;
  set_timer = 13'd0;
  fclk_zero =0;
  nxt_state = state;
case (state)
	  G6 : begin
		set_timer= 16'd31888;
		if (duration == 2**23) begin 
		  nxt_state = C7;
		  zero_dur = 1;
		  fclk_zero = 1; 
		end 
	  end
	  C7 : begin
	    set_timer= 16'd23889;
		if (duration == 2**23) begin 
		  nxt_state = E7_one;
		  zero_dur = 1;
		  fclk_zero = 1; 
		end
	  end
 	  E7_one : begin
	    set_timer= 16'd18961;
		if (duration == 2**23) begin 
		  nxt_state = G7_one; 
		  zero_dur = 1;
		  fclk_zero = 1; 
		end
	  end
	  G7_one : begin
		set_timer= 16'd15944;
		if (duration == 2**23) begin 
		  nxt_state = G7_one_short; 
		  zero_dur = 1;
		  fclk_zero = 1; 
		end
	  end
	  G7_one_short : begin
		set_timer= 16'd15944;
		if (duration == 2**22) begin 
		  nxt_state = E7_two; 
		  zero_dur = 1;
		  fclk_zero = 1;
		end
	  end
	  E7_two : begin
		set_timer= 16'd18961;
		if (duration == 2**22) begin 
		  nxt_state = G7_two; 
		  zero_dur = 1;
		  fclk_zero = 1;
		end
	  end
	  G7_two : begin
		set_timer= 16'd15944;
		if (duration == 2**24) begin 
		  nxt_state = IDLE; 
		  zero_dur = 1;
		  fclk_zero = 1;
		end
	  end
	  default : begin // IDLE
	    fclk_zero = 1;
		if (go) begin  //When new data is being sent, start
		  zero_dur = 1;
		  nxt_state = G6;
		end  
	  end
	endcase
  end
endmodule
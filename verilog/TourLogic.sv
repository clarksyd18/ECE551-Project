module TourLogic(clk,rst_n,x_start,y_start,go,done,indx,move);

	input clk,rst_n;				// 50MHz clock and active low asynch reset
	input [2:0] x_start, y_start;	// starting position on 5x5 board
	input go;						// initiate calculation of solution
	input [4:0] indx;				// used to specify index of move to read out
	output logic done;			// pulses high for 1 clock when solution complete
	output logic [7:0] move;			// the move addressed by indx (1 of 24 moves)

	////////////////////////////////////////
	// Declare needed internal registers //
	//////////////////////////////////////
	//SM logic
	logic visited_set, visited_remove, clear, initi, try_inc, try_zero, calc_moves;
	
    integer i,j;  // used for loops in functions
	logic [3:0] k, XOFF, YOFF;
  
	


	//Testing related stuff for garett
	logic signed [3:0]nxt_yy, nxt_xx, yoff, xoff;
	logic possible_move;
	logic store_move, undo_move;
	//logic [2:0]try_moves [23:0];
	
	
    //// Define state as enumerated type /////
    typedef enum reg  [2:0] {IDLE, INIT, POSSIBLE, MAKE_MOVE, BACKUP} state_t;
    state_t state,nxt_state;

	//2-D array of 5-bit vectors that keep track of where on the board the knight
	//    has visited.  Will be reduced to 1-bit boolean after debug phase 
	logic visited [4:0][4:0]; 
	logic [7:0] last_moves [23:0];  // keep track of last move taken from each move index
	// 1-D array (of size 24) to keep track of possible moves from each move index 
	logic [7:0] poss_moves[23:0];

	logic [7:0] try; // hold what try you are on
	logic [5:0] move_num;     // when you have moved 24 times you are done.  Decrement when backing up 
	logic signed [3:0] xx, yy; // 3-bit vectors that represent the current x/y coordinates of the knight



	///////////////////////////////////////////////////
	// Function returns a packed byte of
	// all the possible moves (at least in bound) moves given
	// coordinates of Knight.
	/////////////////////////////////////////////////////
	function [7:0] calc_poss(input signed [3:0] xpos,ypos);
	// seeing if all 8 moves are valid
	for (k = 1; k < 9; k++) begin		
		if(((xpos + x_off(move_set(k-1)))>=4'b0000) && ((xpos + x_off(move_set(k-1)))<4'b0101) && 
		((ypos + y_off(move_set(k-1)))>=4'b0000) && ((ypos + y_off(move_set(k-1)))<4'b0101))begin
			// if has not been visited
			if(visited[xpos + x_off(move_set(k-1))][ypos + y_off(move_set(k-1))]==0)begin
				// add as a possible move 
				//$display("Made it here. K is %d", k-1);
				calc_poss[(k-1)] = 1'b1;
				//$display("calc_poss[(k-1)] = ", calc_poss[(k-1)]);
			end
		end else begin
		//Zero out so not 'x' if not possible
		calc_poss[(k-1)] = 1'b0;
		end
	end
	//$display("[%d, %d, %d", calc_poss[0],calc_poss[1], calc_poss[2] );
	endfunction
	
	
	

    ///////////////////////////////////////////////////////////
	// Function x-offset returns the  3-bit signed number given 
	// an input argument that is a 1-hot encoded move byte.  
	/////////////////////////////////////////////////////////
	function signed [3:0] x_off(input [7:0] move);
		case (move)
			8'h01 : x_off = 4'b1111;
			8'h02 : x_off = 4'b0001;
			8'h04 : x_off = 4'b1110;
			8'h08 : x_off = 4'b1110;
			8'h10 : x_off = 4'b1111;
			8'h20 : x_off = 4'b0001;
			8'h40 : x_off = 4'b0010;
			8'h80 : x_off = 4'b0010;
			default: x_off = 4'b0000;
		endcase
	endfunction

	///////////////////////////////////////////////////////////
	// Function y-offset returns the  3-bit signed number given 
	// an input argument that is a 1-hot encoded move byte.  
	/////////////////////////////////////////////////////////
	function signed [3:0] y_off(input [7:0] move); //{-1, 1, -2, -2, -1, 1, 2, 2}; 
		case (move)
			8'h01 : y_off = 4'b0010;
			8'h02 : y_off = 4'b0010;
			8'h04 : y_off = 4'b0001;
			8'h08 : y_off = 4'b1111;
			8'h10 : y_off = 4'b1110;
			8'h20 : y_off = 4'b1110;
			8'h40 : y_off = 4'b0001;
			8'h80 : y_off = 4'b1111;
			default: y_off = 4'b0000;
		endcase
	endfunction
	
	
	//////////////////////////////////////////
	// Function to get current one hot move //
	//////////////////////////////////////////
	function signed [7:0] move_set(input [2:0] move);
		case (move)
			3'h0 : move_set = 8'h01;
			3'h1 : move_set = 8'h02;
			3'h2 : move_set = 8'h04;
			3'h3 : move_set = 8'h08;
			3'h4 : move_set = 8'h10;
			3'h5 : move_set = 8'h20;
			3'h6 : move_set = 8'h40;
			3'h7 : move_set = 8'h80;
			default: move_set = 8'h01;
		endcase
	endfunction
  
	/////////////////
	// Move output //
	/////////////////
	assign move = last_moves[indx];
	
	
	
	//Store last move
	always_ff @(posedge clk) begin
		if(initi) begin 
			//last_moves[move_num] <= 8'h00;
			move_num <= 6'h00;
		end else if(calc_moves) begin
			poss_moves[move_num] <= calc_poss(xx, yy); 
			
			//$strobe("Possible moves: %b", poss_moves[move_num]);
			// if(move_num == 23)
			// $stop();
		end	else if(store_move) begin
			last_moves[move_num] <= try;
			poss_moves[move_num] <= poss_moves[move_num] & ~try;
			//try_moves[move_num] <= try;
			move_num <= move_num + 1'b1;
		end else if(undo_move) begin
			move_num <= move_num - 1'b1;
		end
	end

	//Try inc and zero when move made/ undone
	always_ff @(posedge clk) begin
		if(initi) begin
			try <= 8'h01;
		end else if(try_zero) begin 
			try <= 8'h01;
		end else if(try_inc) begin
			try <= {try[6:0], try[7]};
		end
	end
	
	//Change position of knight
	always_ff @(posedge clk) begin
		if(initi) begin 
			xx <= {1'b0,x_start};
			yy <= {1'b0,y_start};
		end else if(store_move) begin
			xx <= xx + x_off(try); 
			yy <= yy + y_off(try);
		end else if(undo_move) begin
			xx <= xx - x_off(last_moves[move_num - 1'b1]);
			yy <= yy - y_off(last_moves[move_num - 1'b1]);
		end
	end
	
	//Store/undo visited tile
	always_ff @(posedge clk) begin
		if(clear) begin 
			for(i = 0; i < 5; i++)begin
				for(j = 0; j < 5; j++)begin
					visited[i][j] <= 1'b0;
				end
			end
		end else if(initi) begin 
			visited[x_start][y_start] <= 1'b1;
		end else if(visited_set) begin
			visited[xx][yy] <= 1'b1;
		end else if (visited_remove) begin
			visited[xx][yy] <= 1'b0;
		end
	end
	
	//Evaluates if a move can be made or if the tiles already been used
	logic posmv, spot_clear, backupLogic, try_logic;
	assign xoff = x_off(try);
	assign yoff = y_off(try);
	assign nxt_xx = xx+xoff;
	assign nxt_yy = yy+yoff;
	assign posmv = ^ (poss_moves[move_num] & try);
	assign spot_clear = (4'b0100 >= nxt_xx) && (nxt_xx >= 4'b0000) && (4'b0100 >= nxt_yy) && (nxt_yy >= 4'b0000)   ? !(visited[nxt_xx][nxt_yy] || 1'b0) : 1'b0;
	assign possible_move = posmv && spot_clear;
	
	
	////////////////
	// SM LOGIC //
	//////////////
	always_ff @(posedge clk or negedge rst_n)begin
		if(!rst_n)
			state <= IDLE;
		else 
			state <= nxt_state;
	end

	always_comb begin
		store_move = 1'b0;
		undo_move = 1'b0;
		done = 1'b0;
		visited_set = 1'b0;
		visited_remove = 1'b0;
		clear = 1'b0;
		initi = 1'b0;
		try_zero = 1'b0;
		try_inc = 1'b0;
		calc_moves = 1'b0;
		nxt_state = state;
		case (state)
		IDLE : begin
			if (go) begin
				clear = 1'b1;
				nxt_state = INIT;
			end
		end
		INIT : begin
			initi = 1'b1;
			nxt_state = POSSIBLE;
		end
		POSSIBLE : begin
			// determine all possible moves from this square
			calc_moves = 1'b1;
			try_zero = 1'b1;
			nxt_state = MAKE_MOVE;
		end
		MAKE_MOVE : begin
			//Make the move if it's possible
			if(possible_move) begin
				visited_set = 1'b1;
				store_move = 1'b1;
				// done all moves have been made
				if(move_num == 6'h17)begin
					done = 1'b1;
					//Now cmd tour can retrieve correct moves
					nxt_state = IDLE;
				end else begin
					nxt_state = POSSIBLE;
				end 
			end else if(try != 8'h80)begin		// move is not possible, are there other possible moves 
				try_inc = 1'b1;
			end	else begin			// no moves possible ... we need to backup
				visited_remove = 1'b1;
				nxt_state = BACKUP;
			end
		end
		BACKUP : begin
			visited_remove = 1'b1;
			// next move to try is last one advanced
			backupLogic = (|poss_moves[move_num-1]);
			try_logic = !(last_moves[move_num - 1'b1] == 8'h80);
			if((|poss_moves[move_num-1]) && !(last_moves[move_num - 1'b1] == 8'h80)) begin// after backing up, we have some moves to try
				undo_move = 1'b1;
				try_zero = 1'b1;
				nxt_state = MAKE_MOVE;
			end else begin	//there is an infered "else" here where we stay in BACKUP and backup yet again.
				undo_move = 1'b1;
			end
		end
		default:
			nxt_state = IDLE;
		endcase
	end
  
endmodule

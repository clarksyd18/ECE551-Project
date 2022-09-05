module KnightsTour_test4();
  //////////////////////////////////////////////////////////
  // Test 4 waits for init & calibrate. Then performs a  //
  // tour_go command starting in a board position 2,4   //
  ///////////////////////////////////////////////////////

  import tb_tasks::*;
  /////////////////////////////
  // Stimulus of type reg //
  /////////////////////////
  reg clk, RST_n;
  reg [15:0] cmd;
  reg send_cmd;

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////
  wire SS_n,SCLK,MOSI,MISO,INT;
  wire lftPWM1,lftPWM2,rghtPWM1,rghtPWM2;
  wire TX_RX, RX_TX;
  logic cmd_sent;
  logic resp_rdy;
  logic [7:0] resp;
  wire IR_en;
  wire lftIR_n,rghtIR_n,cntrIR_n;
  integer omega_sum_init;

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  KnightsTour iDUT(.clk(clk), .RST_n(RST_n), .SS_n(SS_n), .SCLK(SCLK),
                   .MOSI(MOSI), .MISO(MISO), .INT(INT), .lftPWM1(lftPWM1),
				   .lftPWM2(lftPWM2), .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2),
				   .RX(TX_RX), .TX(RX_TX), .piezo(piezo), .piezo_n(piezo_n),
				   .IR_en(IR_en), .lftIR_n(lftIR_n), .rghtIR_n(rghtIR_n),
				   .cntrIR_n(cntrIR_n));

  /////////////////////////////////////////////////////
  // Instantiate RemoteComm to send commands to DUT //
  ///////////////////////////////////////////////////
  //<< This is my remoteComm.  It is possible yours has a slight variation
  //   in port names>>
  RemoteComm iRMT(.clk(clk), .rst_n(RST_n), .RX(RX_TX), .TX(TX_RX), .cmd(cmd),
             .send_cmd(send_cmd), .cmd_sent(cmd_sent), .resp_rdy(resp_rdy), .resp(resp));

  //////////////////////////////////////////////////////
  // Instantiate model of Knight Physics (and board) //
  ////////////////////////////////////////////////////
  KnightPhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),
                      .MOSI(MOSI),.INT(INT),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
					  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),.IR_en(IR_en),
					  .lftIR_n(lftIR_n),.rghtIR_n(rghtIR_n),.cntrIR_n(cntrIR_n));


// test bench signals
logic [5:0] i;
logic [5:0] boardDisplay[4:0][4:0];
integer x,y;
initial begin
  ////////////////////////////////
  // Initialize and Calibrate //
  /////////////////////////////
    clk = 0;
    RST_n =1;
    @(negedge clk);
    RST_n = 0;
    repeat(2) @(negedge clk);
    RST_n = 1;
    //Checks if nemo is setup
    timeOut(clk, iPHYS.iNEMO.NEMO_setup, 100000, "Wait for Nemo_setup timed out");
    $display("Init Complete");
    cmd = 16'h0xxx;
    @(posedge clk);
    send_cmd = 1;
    @(posedge clk);
    send_cmd = 0;
    // checks if you get a positive acknowledgement
    timeOut(clk, resp_rdy, 100000000, "Wait for pos ack timed out");
     $display("Calibrate Complete");
    

  //////////////////////////
  // Start Tour in board position 2,4 //
  /////////////////////////
    cmd = 16'h4x24; // third and fourth position refer to starting coordinates
    @(posedge clk);
    send_cmd = 1;
    @(posedge clk);
    send_cmd = 0;
    // Check is tour go asserts
    timeOut(clk, iDUT.tour_go, 1000000, "ERROR: timed out waiting for tour_go");
    // Check if start tour asserts
    timeOut(clk, iDUT.start_tour, 10000000, "ERROR: timed out waiting for start_tour");
    // Iterates through each move
    for (i = 0; i < 24; i = i + 1) begin
      repeat(2) @(posedge clk);
      $display("Round %d, move index is %d", i, iDUT.mv_indx); 
      $display("Move is %d", iDUT.move);
      $display("cmd is %h", iDUT.cmd);
      timeOutNeg(clk, iDUT.moving, 100000000, "ERROR: moving to 0 timed out"); // waits for y position move
      $display("Move is %d", iDUT.move);
      $display("cmd is %h", iDUT.cmd);
      timeOutNeg(clk, iDUT.moving, 100000000, "ERROR: moving to 0 timed out"); // waits for x position move
      $display("Board position is %h, %h", iPHYS.xx[14:12], iPHYS.yy[14:12]);
      $display("resp is %h", resp);
      boardDisplay[iPHYS.xx[14:12]][iPHYS.yy[14:12]] = i;// store board move
    end
    for (x = 0; x <10000; x = x + 1) begin
      repeat(1000) @(posedge clk);
      if (iDUT.moving !== 0) begin
        $display("ERROR: moving should stay at 0");
        $stop();
      end
    end
    // display board sequence:
		for (y=4; y>=0; y--) begin
			$display("%2d %2d %2d %2d %2d\n", boardDisplay[0][y], boardDisplay[1][y], boardDisplay[2][y], 
						boardDisplay[3][y], boardDisplay[4][y]);
		end
		$display("--------------------\n");
	
  $display("YAHOO!! tests passed! have fun reading thru the output tho.");
  $stop();
end

always #5 clk = ~clk;
endmodule

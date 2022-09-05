module KnightsTour_test3a();
  //////////////////////////////////////////////////////////
  // Test 3a waits for init & calibrate. Then move      //
  // north 2 squares without fanfare                    //
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
  logic tb_err;
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

  ///////////////////////////////////
  // Move 2  north without fanfare //
  //////////////////////////////+////
    $display("Begin move 2 north with fanfare");
    cmd = 16'h3002;
    @(posedge clk);
    send_cmd = 1;
    omega_sum_init = iPHYS.omega_sum;
    @(posedge clk);
    send_cmd = 0;
    // check to see if omega sum is ramping up
    rampUpTimeOut(clk, iPHYS.cntrIR_n,iPHYS.omega_sum,100000000);
	timeOut(clk, iDUT.fanfare_go, 10000000, "ERROR: timed out waiting for fanfare_go");
    // Check to see if moving goes to zero
    timeOutNeg(clk, iDUT.moving, 10000000, "ERROR: timed out waiting for moving to go to zero");
    
    if (!((iDUT.iCMD.heading > -100) && (iDUT.iCMD.heading < 100))) begin
      $display("heading is incorrect");
      tb_err = 1; 
    end
	repeat(10000000) @(posedge clk);
    // checks to see if ending board position is correct
    if (iPHYS.xx != 16'h2xxx) begin
      $display("ERROR: ending x incorrrect: should be 2xxx, is %h", iPHYS.xx);
      $stop();
    end
    if (iPHYS.yy != 16'h4xxx) begin
      $display("ERROR: ending y incorrect: should be 4xxx, is %h", iPHYS.yy);
      $stop();
    end
  $display("YAHOO!! tests passed!");
  $stop();
end

  always
    #5 clk = ~clk;

endmodule

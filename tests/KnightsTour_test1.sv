module KnightsTour_test1();
  /////////////////////////////////////////////////////////////////
  // Test 1 Checks if calibration & Initalization work correctly //
  ////////////////////////////////////////////////////////////////
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
  clk = 0;
  RST_n =1;
  @(negedge clk);
  RST_n = 0;
  repeat(2) @(negedge clk);
  RST_n = 1;
  // Check to make sure that PWM’s and midrail values are running just after reset
      if (lftPWM1 !== 0) begin
      $display("ERROR in rst process, left PWM is not 0");
      $stop();
    end
    if (rghtPWM1 !== 0) begin
      $display("ERROR in rst process, right PWM is not 0");
      $stop();
    end
  //Checks if nemo is setup
  timeOut(clk, iPHYS.iNEMO.NEMO_setup, 100000, "Wait for Nemo_setup timed out");
  cmd = 16'h0xxx;
  @(posedge clk);
  send_cmd = 1;
  @(posedge clk);
  send_cmd = 0;
  // checks if cal_done asserts
  timeOut(clk, iDUT.cal_done, 1000000, "Wait for cal_done timed out");
  // checks if you get a positive acknowledgement
  timeOut(clk, resp_rdy, 1000000, "Wait for positive acknowledgement timed out");
  if (iDUT.iCNTRL.frwrd !== 10'h000) begin
    $display("ERROR: frwrd in PID  should be 0 after calibrating");
    $stop();
  end
  if (resp !== 8'ha5) 
    $display("ERROR: resp should be a5, was %h", resp);
  $display("YAHOO!! tests passed!");
  $stop();
end


  always
    #5 clk = ~clk;

endmodule

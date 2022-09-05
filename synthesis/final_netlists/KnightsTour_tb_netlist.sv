`timescale 1ns/1ps
module KnightsTour_tb_netlist();


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
    integer i;

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
task initialize();
begin
    @(negedge clk);
    RST_n = 0;
    repeat(2) @(negedge clk);
    RST_n = 1;
    if (lftPWM1 !== 0) begin
      $display("ERROR in rst process, left PWM is not 0");
      $stop();
    end
    if (rghtPWM1 !== 0) begin
      $display("ERROR in rst process, right PWM is not 0");
      $stop();
    end

    fork begin: timeout0
      repeat(100000) @(posedge clk);
        $display("Wait for SPI NEMO INT timed out");
        $stop();
      end
      begin
        @(posedge iPHYS.iNEMO.NEMO_setup); // I think this is the signal he means but im not 100%
        disable timeout0;
      end
    join
  end
endtask


task SendCmd(input [15:0] cmd_input);
begin
    cmd = cmd_input;
    @(posedge clk);
    send_cmd = 1;	// cmd signal is ready
    @(posedge clk);
    send_cmd = 0;	//deassert cmd signal
    fork begin : timeout1
		  repeat(1000000) @(posedge clk);
		  $display("Send Command timed out");
		  $stop;
	  end begin
		  @(posedge resp_rdy);
		  disable timeout1;
	  end
    join
end
endtask

task CalibrateCheck();
begin
  $display("Begin calibrate check");
  cmd = 16'h0xxx;
  @(posedge clk);
  send_cmd = 1;
  @(posedge clk);
  send_cmd = 0;
  fork begin : timeout3
    repeat(1000000) @(posedge clk);
    $display("Send Command timed out");
    $stop;
  end begin
    @(posedge resp_rdy);
    disable timeout3;
  end
  join
  if (resp !== 8'ha5) begin
	$display("ERROR: calibration response incorrect");
	$stop();
  end
  $display("Calibrate check complete");
end
endtask



initial begin
  RST_n = 1;
  clk = 0;
  initialize();
  CalibrateCheck();
  $display("Begin move 1 west without fanfare");
  cmd = 16'h23f1;
  @(posedge clk);
  send_cmd = 1;
  omega_sum_init = iPHYS.omega_sum;
  @(posedge clk);
  send_cmd = 0;
  fork
  begin: timeout4
	repeat(100000000) @(posedge clk);
	$display("ERROR: cntrIR_n timed out");
	$stop();
  end
  begin
	@(negedge iPHYS.cntrIR_n);
	$display("First center edge");
	if (iPHYS.omega_sum <= omega_sum_init) begin
		$display("ERROR: omega sum is not ramping up");
		$stop();
	end
	@(negedge iPHYS.cntrIR_n);
	$display("Second center edge");
	disable timeout4;
  end
  join

  if (iPHYS.xx != 16'h1xxx) begin
	$display("ERROR: ending x incorrrect: should be 2xxx, is %h", iPHYS.xx);
	$stop();
  end
  if (iPHYS.yy != 16'h2xxx) begin
	$display("ERROR: ending y incorrect: should be 3xxx, is %h", iPHYS.yy);
	$stop();
  end

  $display("YAHOO! tests passed!");
  $stop();  

end


  always
    #5 clk = ~clk;

endmodule

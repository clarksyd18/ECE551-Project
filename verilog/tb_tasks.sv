package tb_tasks;

task automatic timeOut(
    ref logic clk, posEdgeSignal,
    input int waitNumClkCycles,
    input string errMess
);
  begin
    fork begin: timeout
      repeat(waitNumClkCycles) @(posedge clk);
        $display(errMess);
        $stop();
      end
      begin
        @(posedge posEdgeSignal); 
        disable timeout;
      end
    join

  end
endtask

task automatic timeOutNeg(
    ref logic clk, posEdgeSignal,
    input int waitNumClkCycles,
    input string errMess
);
  begin
    fork begin: timeout
      repeat(waitNumClkCycles) @(posedge clk);
        $display(errMess);
        $stop();
      end
      begin
        @(negedge posEdgeSignal); 
        disable timeout;
      end
    join

  end
endtask


task automatic rampUpTimeOut(
    ref logic clk, 
    ref logic clkSignal,
    ref logic signed [16:0] rampUpSignal,
    input int waitNumClkCycles
);
integer tempsig;
  begin
    tempsig = rampUpSignal;
    fork begin: timeout1
      repeat(waitNumClkCycles) @(posedge clk);
        $display("ERROR: %s timed out", rampUpSignal);
        $stop();
      end
      begin
        repeat(2) @(negedge clkSignal);
        if (rampUpSignal <= tempsig) begin
          $display("ERROR: %s is not ramping up", rampUpSignal);
          $stop();
	      end
        repeat(2) @(negedge clkSignal);
        tempsig = rampUpSignal;
        disable timeout1;
      end
    join

  end
endtask

endpackage


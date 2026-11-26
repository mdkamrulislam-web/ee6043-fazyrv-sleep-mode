// -----------------------------------------------------------------------------
// tb_top.sv - system test for top_pynqz2
//
// Runs the LED-counter program (built with a short delay: fw/build.sh sim) on
// the whole system and checks, without looking inside the design:
//   1. after reset the LEDs count 0, 1, 2, ... 15, 0, 1 ... with no step missed;
//   2. with SW0 = 1 the steps come about four times faster;
//   3. pressing BTN0 restarts the count from 0.
// Prints PASS or FAIL and the number of clock cycles per LED step.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

`ifndef TB_CHUNKSIZE
`define TB_CHUNKSIZE 8
`endif

module tb_top;
  parameter int CHUNKSIZE = `TB_CHUNKSIZE;

  logic       clk = 1'b0;
  logic       btn0 = 1'b1;     // start with reset pressed
  logic       sw0  = 1'b0;
  logic [3:0] led;

  always #4 clk = ~clk;        // 8 ns = 125 MHz, as on the board

  top_pynqz2 #(.CHUNKSIZE(CHUNKSIZE), .MEMFILE("firmware_sim.mem")) dut (
    .sysclk(clk), .btn0(btn0), .sw0(sw0), .led(led)
  );

  int errors = 0;
  longint cyc = 0;
  always @(posedge clk) cyc <= cyc + 1;

  // Wait for the next LED change; return the cycles it took (timeout = error).
  task automatic next_step(output longint dt);
    logic [3:0] old;
    longint t0;
    old = led;
    t0  = cyc;
    fork : wait_change
      begin @(led); end
      begin repeat (200000) @(posedge clk); end
    join_any
    disable wait_change;
    dt = cyc - t0;
    if (led === old) begin
      $display("FAIL: LEDs stuck at %0d", led);
      errors++;
    end
  endtask

  // Check n steps; each must be the previous value + 1 (mod 16).
  task automatic check_steps(input int n, output longint avg);
    longint dt, sum;
    logic [3:0] expect_v;
    sum = 0;
    for (int i = 0; i < n; i++) begin
      expect_v = led + 4'd1;
      next_step(dt);
      if (i > 0) sum += dt;         // the first step may be a partial one
      if (led !== expect_v) begin
        $display("FAIL: LEDs %0d, expected %0d", led, expect_v);
        errors++;
      end
    end
    avg = sum / (n - 1);
  endtask

  longint slow, fast, dt;

`ifdef TB_SLEEP
  // Sleep design: count the edges of the processor's (gated) clock, to show it really stops
  longint cpu_edges = 0;
  always @(posedge dut.clk_cpu) cpu_edges <= cpu_edges + 1;
  longint c0, e0;
`endif

  initial begin
    repeat (20) @(posedge clk);
    btn0 = 1'b0;                     // release reset

    // 1. First value after reset is 0.
    wait (led === 4'd0);
    $display("LEDs start at 0 after reset (cycle %0d)", cyc);

    // 2. Slow count with SW0 = 0, 20 steps (wraps past 15).
`ifdef TB_SLEEP
    c0 = cyc; e0 = cpu_edges;
`endif
    check_steps(20, slow);
    $display("SW0=0: 20 steps OK, %0d cycles per step", slow);
`ifdef TB_SLEEP
    $display("CPU clock: %0d of %0d clock cycles (%.1f%%) during 20 steps; asleep the rest",
             cpu_edges - e0, cyc - c0, 100.0 * (cpu_edges - e0) / (cyc - c0));
`endif

    // 3. Fast count with SW0 = 1.
    sw0 = 1'b1;
    next_step(dt);                   // let the program see the switch
    next_step(dt);
    check_steps(10, fast);
    $display("SW0=1: 10 steps OK, %0d cycles per step", fast);
    if (!(fast * 3 < slow && fast * 5 > slow)) begin
      $display("FAIL: fast step should be about 1/4 of the slow step");
      errors++;
    end

    // 4. Reset in the middle of counting: the count restarts from 0.
    @(posedge clk) btn0 = 1'b1;
    repeat (5) @(posedge clk);
    btn0 = 1'b0;
    sw0  = 1'b0;
    // The program restarts and writes 0, then 1, 2, ...
    fork : wait_one
      begin wait (led === 4'd1); end
      begin repeat (200000) @(posedge clk); end
    join_any
    disable wait_one;
    if (led !== 4'd1) begin
      $display("FAIL: after reset the count did not restart (LEDs = %0d)", led);
      errors++;
    end else begin
      check_steps(3, dt);
      $display("Reset in the middle: count restarts from 0");
    end

    if (errors == 0) $display("PASS (CHUNKSIZE=%0d)", CHUNKSIZE);
    else             $display("FAIL: %0d errors (CHUNKSIZE=%0d)", errors, CHUNKSIZE);
    $finish;
  end
endmodule

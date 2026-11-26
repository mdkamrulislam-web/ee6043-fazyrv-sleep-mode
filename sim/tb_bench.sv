// -----------------------------------------------------------------------------
// tb_bench.sv - runs the workload program (fw/bench.c, built with
// "fw/build.sh bench_sim") on the whole system and checks it from the pins:
//   - after reset the LEDs show the pass counter 1, 2, 3, ... (each pass = one
//     full job whose result matched the expected value);
//   - a wrong result stops the program with 1010 on the LEDs, which shows up
//     here as a timeout.
// Prints PASS/FAIL and the clock cycles per pass (used for energy per pass).
// Also used for the activity (SAIF) runs of the power analysis.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

`ifndef TB_CHUNKSIZE
`define TB_CHUNKSIZE 4
`endif
`ifndef TB_PASSES
`define TB_PASSES 6
`endif

module tb_bench;
  parameter int CHUNKSIZE = `TB_CHUNKSIZE;

  logic       clk  = 1'b0;
  logic       btn0 = 1'b1;
  logic       sw0  = 1'b0;
  logic [3:0] led;

  always #4 clk = ~clk;   // 125 MHz

  top_pynqz2 #(.CHUNKSIZE(CHUNKSIZE), .MEMFILE("firmware_sim.mem")) dut (
    .sysclk(clk), .btn0(btn0), .sw0(sw0), .led(led)
  );

  longint cyc = 0;
  always @(posedge clk) cyc <= cyc + 1;

  int errors = 0;
  longint t_first, t_last;

  // Register-file RAM activity (counted by rf_ram_counter, bound into fazyrv_ram_sp below)
  logic counting = 1'b0;
  longint n_rd = 0, n_wr = 0, n_cyc = 0;
  always @(posedge clk) if (counting) n_cyc <= n_cyc + 1;

  initial begin
    logic [3:0] expect_v;
    repeat (20) @(posedge clk);
    btn0 = 1'b0;
    for (int i = 1; i <= `TB_PASSES; i++) begin
      fork : w
        begin @(led); end
        begin repeat (2_000_000) @(posedge clk); end
      join_any
      disable w;
      expect_v = i[3:0];
      if (led !== expect_v) begin
        $display("FAIL: pass %0d, LEDs = %b (expected %b)", i, led, expect_v);
        errors++;
        break;
      end
      if (i == 1) begin t_first = cyc; counting = 1'b1; end
      t_last = cyc;
      if (i == `TB_PASSES) counting = 1'b0;
      $display("pass %0d done at cycle %0d", i, cyc);
    end
    if (errors == 0) begin
      $display("CYCLES_PER_PASS %0d", (t_last - t_first) / (`TB_PASSES - 1));
      $display("RF_RAM_PER_PASS reads %0d writes %0d cycles %0d (reads in %0.1f%% of cycles)",
               n_rd / (`TB_PASSES - 1), n_wr / (`TB_PASSES - 1), n_cyc / (`TB_PASSES - 1),
               100.0 * n_rd / n_cyc);
      $display("PASS (CHUNKSIZE=%0d)", CHUNKSIZE);
    end else
      $display("FAIL (CHUNKSIZE=%0d)", CHUNKSIZE);
    $finish;
  end
endmodule

// Counts reads and writes of the register-file RAM (it reads in every cycle without a write).
module rf_ram_counter (input logic clk, input logic we, input logic re, input logic [4:0] raddr);
  always @(posedge clk) if (tb_bench.counting) begin
    if (re) tb_bench.n_rd <= tb_bench.n_rd + 1;
    if (we) tb_bench.n_wr <= tb_bench.n_wr + 1;
  end
  // Optional trace of 160 cycles (sim/run_bench_*/rf_trace.csv) for the report plot
  integer fd = 0;
  longint t0 = -1;
  always @(posedge clk) if (tb_bench.counting) begin
    if (t0 < 0) begin t0 = tb_bench.cyc + 20000; fd = $fopen("rf_trace.csv", "w"); $fwrite(fd, "cycle,read,write,raddr\n"); end
    if (tb_bench.cyc >= t0 && tb_bench.cyc < t0 + 160) $fwrite(fd, "%0d,%0d,%0d,%0d\n", tb_bench.cyc - t0, re, we, raddr);
    if (tb_bench.cyc == t0 + 160) $fclose(fd);
  end
endmodule

bind fazyrv_ram_sp rf_ram_counter u_rf_cnt (.clk(clk_i), .we(we_i), .re(~we_i), .raddr(raddr_i[4:0]));

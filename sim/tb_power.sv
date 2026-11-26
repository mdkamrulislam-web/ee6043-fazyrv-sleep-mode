// -----------------------------------------------------------------------------
// tb_power.sv - stimulus for the activity-based power analysis.
// Runs the routed netlist (post-implementation functional simulation) with the
// program that is inside the bitstream's block RAM (fw/firmware.mem = workload),
// so the switching activity (SAIF file) is the real activity of the workload.
// No checks here: the function is checked by tb_bench.sv and the 40 tests.
// The run time is set by the power script (one full workload pass + reset).
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module tb_power;
  logic       clk  = 1'b0;
  logic       btn0 = 1'b1;
  logic       sw0  = 1'b0;
  wire  [3:0] led;

  always #4 clk = ~clk;   // 125 MHz, as on the board

  top_pynqz2 dut (.sysclk(clk), .btn0(btn0), .sw0(sw0), .led(led));

  initial begin
    #200 btn0 = 1'b0;     // release reset after 200 ns
  end
endmodule

// top_pynqz2_diag.sv - DIAGNOSTIC wrapper (board debugging only, not part of the measured designs).
// Adds two indicators on the RGB LEDs that do not depend on the processor:
//   LD4 green : blinks about 1 Hz straight from the 125 MHz clock (stops = clock stopped)
//   LD5 red   : on while the processor is held in reset
module top_pynqz2_diag #(parameter int CHUNKSIZE = 4) (
  input  logic       sysclk,
  input  logic       btn0,
  input  logic       sw0,
  output logic [3:0] led,
  output logic       led4_g,
  output logic       led5_r
);
  top_pynqz2 #(.CHUNKSIZE(CHUNKSIZE)) u_top (.sysclk(sysclk), .btn0(btn0), .sw0(sw0), .led(led));

  logic [26:0] hb = '0;
  always_ff @(posedge sysclk) hb <= hb + 27'd1;
  assign led4_g = hb[26];                 // 125e6 / 2^27 = 0.93 Hz
  assign led5_r = ~u_top.rst_n;
endmodule

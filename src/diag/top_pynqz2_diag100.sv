// top_pynqz2_diag100.sv - DIAGNOSTIC wrapper like top_pynqz2_diag.sv, but the processor system runs at
// 100 MHz made by an MMCM from the 125 MHz board clock (VCO 1000 MHz = 125 x 8, /10 = 100 MHz).
// Same module name as top_pynqz2_diag.sv (build.tcl picks the file with DIAG=2).
module top_pynqz2_diag #(parameter int CHUNKSIZE = 4) (
  input  logic       sysclk,
  input  logic       btn0,
  input  logic       sw0,
  output logic [3:0] led,
  output logic       led4_g,
  output logic       led5_r
);
  logic clk_fb, clk_fb_buf, clk100_u, clk100, locked;
  MMCME2_BASE #(
    .CLKIN1_PERIOD   (8.0),
    .CLKFBOUT_MULT_F (8.0),
    .CLKOUT0_DIVIDE_F(10.0),
    .DIVCLK_DIVIDE   (1)
  ) u_mmcm (
    .CLKIN1(sysclk), .CLKFBIN(clk_fb_buf), .CLKFBOUT(clk_fb), .CLKOUT0(clk100_u),
    .LOCKED(locked), .PWRDWN(1'b0), .RST(1'b0),
    .CLKFBOUTB(), .CLKOUT0B(), .CLKOUT1(), .CLKOUT1B(), .CLKOUT2(), .CLKOUT2B(),
    .CLKOUT3(), .CLKOUT3B(), .CLKOUT4(), .CLKOUT5(), .CLKOUT6()
  );
  BUFG u_bufg_fb  (.I(clk_fb),   .O(clk_fb_buf));
  BUFG u_bufg_100 (.I(clk100_u), .O(clk100));

  // processor held in reset until the MMCM is locked
  top_pynqz2 #(.CHUNKSIZE(CHUNKSIZE)) u_top (.sysclk(clk100), .btn0(btn0 | ~locked), .sw0(sw0), .led(led));

  logic [26:0] hb = '0;
  always_ff @(posedge sysclk) hb <= hb + 27'd1;
  assign led4_g = hb[26];
  assign led5_r = ~u_top.rst_n;
endmodule

// top_pynqz2_diag25.sv - like top_pynqz2_diag3.sv, but the processor system runs at 25 MHz from an MMCM
// (VCO 1000 MHz = 125 x 8, /40 = 25 MHz): a very large timing margin, to test if the board hang is timing-related.
//   LD4 green : 0.93 Hz heartbeat straight from the clock (stops = clock stopped)
//   LD5 red   : ANY reset of the processor (even a 1-cycle glitch on BTN0) lights it for about 0.5 s
//   LD5 blue  : on while the processor writes to the GPIO at least every 50 ms (alive); off = processor stopped
// Same module name as top_pynqz2_diag.sv (build.tcl picks the file with DIAG=4).
module top_pynqz2_diag #(parameter int CHUNKSIZE = 4) (
  input  logic       sysclk,
  input  logic       btn0,
  input  logic       sw0,
  output logic [3:0] led,
  output logic       led4_g,
  output logic       led5_r,
  output logic       led5_b
);
  logic clk_fb, clk_fb_buf, clk25_u, clk25, locked;
  MMCME2_BASE #(.CLKIN1_PERIOD(8.0), .CLKFBOUT_MULT_F(8.0), .CLKOUT0_DIVIDE_F(40.0), .DIVCLK_DIVIDE(1)) u_mmcm (
    .CLKIN1(sysclk), .CLKFBIN(clk_fb_buf), .CLKFBOUT(clk_fb), .CLKOUT0(clk25_u), .LOCKED(locked), .PWRDWN(1'b0),
    .RST(1'b0), .CLKFBOUTB(), .CLKOUT0B(), .CLKOUT1(), .CLKOUT1B(), .CLKOUT2(), .CLKOUT2B(), .CLKOUT3(),
    .CLKOUT3B(), .CLKOUT4(), .CLKOUT5(), .CLKOUT6());
  BUFG u_bufg_fb (.I(clk_fb), .O(clk_fb_buf));
  BUFG u_bufg_25 (.I(clk25_u), .O(clk25));
  top_pynqz2 #(.CHUNKSIZE(CHUNKSIZE)) u_top (.sysclk(clk25), .btn0(btn0 | ~locked), .sw0(sw0), .led(led));

  logic [26:0] hb = '0;
  always_ff @(posedge sysclk) hb <= hb + 27'd1;
  assign led4_g = hb[26];

  // reset stretcher: any cycle with rst_n = 0 restarts a 0.5 s timer
  logic [25:0] rst_t = '0;
  always_ff @(posedge sysclk)
    if (!u_top.rst_n) rst_t <= 26'd62_500_000;
    else if (rst_t != 0) rst_t <= rst_t - 26'd1;
  assign led5_r = (rst_t != 0);

  // alive: GPIO write within the last 50 ms (one workload pass = 3 ms)
  logic gpio_wr;
  assign gpio_wr = u_top.u_soc.wb_gpio_stb & u_top.u_soc.wb_gpio_we;
  logic [22:0] alive_t = '0;
  always_ff @(posedge sysclk)
    if (gpio_wr) alive_t <= 23'd6_250_000;
    else if (alive_t != 0) alive_t <= alive_t - 23'd1;
  assign led5_b = (alive_t != 0);
endmodule

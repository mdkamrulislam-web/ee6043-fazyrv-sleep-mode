// top_pynqz2_diag3.sv - DIAGNOSTIC wrapper (board debugging only). Processor at 125 MHz as in the measured designs.
//   LD4 green : 0.93 Hz heartbeat straight from the clock (stops = clock stopped)
//   LD5 red   : ANY reset of the processor (even a 1-cycle glitch on BTN0) lights it for about 0.5 s
//   LD5 blue  : on while the processor writes to the GPIO at least every 50 ms (alive); off = processor stopped
// Same module name as top_pynqz2_diag.sv (build.tcl picks the file with DIAG=3).
module top_pynqz2_diag #(parameter int CHUNKSIZE = 4) (
  input  logic       sysclk,
  input  logic       btn0,
  input  logic       sw0,
  output logic [3:0] led,
  output logic       led4_g,
  output logic       led5_r,
  output logic       led5_b
);
  top_pynqz2 #(.CHUNKSIZE(CHUNKSIZE)) u_top (.sysclk(sysclk), .btn0(btn0), .sw0(sw0), .led(led));

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

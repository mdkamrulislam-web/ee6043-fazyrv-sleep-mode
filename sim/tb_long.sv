// -----------------------------------------------------------------------------
// tb_long.sv - long run of the exact board program (fw/firmware.mem: workload with
// LED_SHIFT=7, LEDs change every 128 passes) to reproduce the board behaviour.
// Prints every LED change with its time. If the LEDs do not change for 1.5 LED
// steps, prints FROZEN and the last instruction addresses fetched by the core
// (a tight loop at the error stop "for(;;)" or somewhere else = a hang).
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps
`ifndef TB_STEPS
`define TB_STEPS 12
`endif

module tb_long;
  logic       clk  = 1'b0;
  logic       btn0 = 1'b1;
  wire  [3:0] led;
  always #4 clk = ~clk;

  top_pynqz2 #(.CHUNKSIZE(4), .MEMFILE("firmware.mem")) dut (.sysclk(clk), .btn0(btn0), .sw0(1'b0), .led(led));

  longint cyc = 0;
  always @(posedge clk) cyc <= cyc + 1;

  // last 8 distinct instruction fetch addresses
  logic [31:0] hist [0:7] = '{default: '0};
  always @(posedge clk)
    if (dut.u_soc.wb_cpu_imem_stb && dut.u_soc.wb_cpu_imem_adr != hist[0]) begin
      for (int k = 7; k > 0; k--) hist[k] <= hist[k - 1];
      hist[0] <= dut.u_soc.wb_cpu_imem_adr;
    end

  // GPIO writes: value and cycle
  always @(posedge clk)
    if (dut.u_soc.wb_gpio_stb && dut.u_soc.wb_gpio_we && dut.u_soc.wb_gpio_ack && led !== dut.u_soc.wb_gpio_wdat[3:0])
      $display("GPIO write %0h at cycle %0d", dut.u_soc.wb_gpio_wdat, cyc);

  initial begin
    repeat (20) @(posedge clk);
    btn0 = 1'b0;
    wait (led === 4'd0);                 // first write: pass 1 done, LEDs = pass >> 7 = 0
    $display("LEDs = 0 at cycle %0d (first pass done)", cyc);
    for (int i = 1; i <= `TB_STEPS; i++) begin
      fork : w
        begin @(led); end
        begin repeat (72_000_000) @(posedge clk); end   // 1.5 LED steps (48.2M cycles per step)
      join_any
      disable w;
      if (led === i[3:0]) $display("LEDs = %0d at cycle %0d (%.3f s)", led, cyc, cyc * 8e-9);
      else begin
        $display("FROZEN at LEDs = %b, cycle %0d", led, cyc);
        for (int k = 0; k < 8; k++) $display("  fetch[%0d] = %h", k, hist[k]);
        $finish;
      end
    end
    $display("LONG RUN OK: %0d LED steps", `TB_STEPS);
    $finish;
  end
endmodule

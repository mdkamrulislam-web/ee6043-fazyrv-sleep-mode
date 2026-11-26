// -----------------------------------------------------------------------------
// sleep_ctrl.sv - sleep controller with clock gating (my design)
//
// Bus register at 0x2000_0000 (write only for sleeping, read = status):
//   write N (N > 0) : the processor system sleeps for N clock cycles.
//   read            : 0 (the processor can only read it while awake).
//
// How it works (runs on the FREE clock, the processor system on the GATED clock):
//   1. The processor stores N to 0x2000_0000. The store is acknowledged in the
//      same cycle (combinational ack), so the processor finishes the store on
//      that clock edge.
//   2. On the same edge the controller sets "sleeping" and loads its counter
//      with N-1. clk_en_o goes low, so the BUFGCE in the top level suppresses
//      the next clock edge of the processor, its RAMs and its GPIO: their whole
//      state is frozen and their clock tree stops switching.
//   3. The counter counts down on the free clock. When it reaches 0, clk_en_o
//      goes high again and the processor continues exactly where it stopped.
//   4. The frozen store is still visible on the bus when the processor wakes up,
//      so a new sleep is only accepted after the bus strobe has been low once
//      ("armed"); otherwise the same store would start a second sleep.
// Cost: a 32-bit counter, two flags and a little logic.
// -----------------------------------------------------------------------------
module sleep_ctrl (
  input  logic        clk_i,      // free-running clock
  input  logic        rst_in,     // low-active reset (same as the processor's)
  input  logic        stb_i,      // bus request (already decoded for 0x2xxx_xxxx)
  input  logic        we_i,
  input  logic [31:0] dat_i,
  output logic        ack_o,
  output logic [31:0] dat_o,
  output logic        clk_en_o,   // 1 = processor clock on
  output logic        sleeping_o  // for indicators / test benches
);
  logic [31:0] cnt_r;
  logic        sleeping_r;
  logic        armed_r;

  assign ack_o      = stb_i;
  assign dat_o      = {31'b0, sleeping_r};
  assign clk_en_o   = ~sleeping_r;
  assign sleeping_o = sleeping_r;

  always_ff @(posedge clk_i) begin
    if (!rst_in) begin
      sleeping_r <= 1'b0;
      armed_r    <= 1'b1;
      cnt_r      <= '0;
    end else if (sleeping_r) begin
      if (cnt_r == 32'd0) sleeping_r <= 1'b0;   // wake up
      else                cnt_r      <= cnt_r - 32'd1;
    end else begin
      if (!stb_i) armed_r <= 1'b1;              // bus idle once since the last sleep
      if (stb_i && we_i && armed_r && dat_i != 32'd0) begin
        sleeping_r <= 1'b1;
        armed_r    <= 1'b0;
        cnt_r      <= dat_i - 32'd1;
      end
    end
  end
endmodule

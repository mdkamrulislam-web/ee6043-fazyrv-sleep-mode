// -----------------------------------------------------------------------------
// top_pynqz2.sv (SLEEP version) - same ports and module name as src/top_pynqz2.sv,
// so every test bench and script works unchanged. Selected with SLEEP=1.
//
// Differences from src/top_pynqz2.sv:
//   - the processor system (fsoc_sleep: core, RAMs, GPIO) runs on a GATED clock
//     from a BUFGCE (glitch-free clock buffer with enable);
//   - the sleep controller (sleep_ctrl) runs on the free clock and drives the
//     BUFGCE enable: the processor can stop its own clock for N cycles.
// The reset stretcher and the switch synchroniser are unchanged (free clock).
// -----------------------------------------------------------------------------
module top_pynqz2 #(
  parameter int CHUNKSIZE = 8,
  parameter     RFTYPE    = "BRAM_BP",
  parameter     MEMFILE   = "firmware.mem"
) (
  input  logic       sysclk,
  input  logic       btn0,
  input  logic       sw0,
  output logic [3:0] led
);

  // Free clock (global buffer) and gated clock for the processor system
  logic clk_free, clk_cpu, clk_en;
  BUFG   u_bufg   (.I(sysclk), .O(clk_free));
  BUFGCE u_bufgce (.I(sysclk), .CE(clk_en), .O(clk_cpu));

  // Reset stretcher (as in src/top_pynqz2.sv)
  logic [4:0] rst_cnt = '0;
  always_ff @(posedge clk_free or posedge btn0) begin
    if (btn0)              rst_cnt <= '0;
    else if (!rst_cnt[4])  rst_cnt <= rst_cnt + 5'd1;
  end
  logic rst_n;
  assign rst_n = rst_cnt[4];

  // Two-flip-flop synchroniser for the switch
  (* ASYNC_REG = "TRUE" *) logic [1:0] sw_sync = '0;
  always_ff @(posedge clk_free) sw_sync <= {sw_sync[0], sw0};

  // Processor system on the gated clock
  logic        slp_stb, slp_we, slp_ack, sleeping;
  logic [31:0] slp_wdat, slp_rdat;

  fsoc_sleep #(
    .CHUNKSIZE ( CHUNKSIZE ),
    .CONF      ( "MIN"     ),
    .RFTYPE    ( RFTYPE    ),
    .RVC       ( "NONE"    ),
    .MEMFILE   ( MEMFILE   ),
    .MEMSIZE   ( 4096      ),
    .MEMDLY1   ( 0         ),
    .GPOCNT    ( 4         )
  ) u_soc (
    .clk_i     ( clk_cpu    ),
    .rst_in    ( rst_n      ),
    .gpi_i     ( sw_sync[1] ),
    .gpo_o     ( led        ),
    .slp_stb_o ( slp_stb    ),
    .slp_we_o  ( slp_we     ),
    .slp_dat_o ( slp_wdat   ),
    .slp_ack_i ( slp_ack    ),
    .slp_dat_i ( slp_rdat   )
  );

  // Sleep controller on the free clock
  sleep_ctrl u_sleep (
    .clk_i      ( clk_free  ),
    .rst_in     ( rst_n     ),
    .stb_i      ( slp_stb   ),
    .we_i       ( slp_we    ),
    .dat_i      ( slp_wdat  ),
    .ack_o      ( slp_ack   ),
    .dat_o      ( slp_rdat  ),
    .clk_en_o   ( clk_en    ),
    .sleeping_o ( sleeping  )
  );

endmodule

// -----------------------------------------------------------------------------
// top_pynqz2.sv - FazyRV system on the PYNQ-Z2 (xc7z020clg400-1)
//
// The FazyRV reference SoC "fsoc" (core + 4 KB block-RAM memory + GPIO) with
// the board's pins:
//   sysclk : 125 MHz clock from the board (pin H16)
//   btn0   : reset button (pressed = reset)
//   sw0    : speed switch, read by the program through the GPIO input
//   led    : four LEDs, written by the program through the GPIO output
//
// Added here (not in fsoc):
//   - a reset stretcher: reset is applied as soon as BTN0 is pressed and is
//     released 16 clock cycles after BTN0 is let go, in step with the clock;
//   - a two-flip-flop synchroniser on SW0, because the switch is not in step
//     with the clock.
// -----------------------------------------------------------------------------

module top_pynqz2 #(
  parameter int CHUNKSIZE = 8,              // data-path width of the core: 1, 2, 4 or 8 bits
  parameter     RFTYPE    = "BRAM_BP",      // register file in block RAM, with bypass
  parameter     MEMFILE   = "firmware.mem"  // program loaded into the RAM at configuration
) (
  input  logic       sysclk,
  input  logic       btn0,
  input  logic       sw0,
  output logic [3:0] led
);

  // Reset: assert at once, release in step with the clock after 16 cycles.
  logic [4:0] rst_cnt = '0;   // FPGA starts with 0, so the core starts in reset
  always_ff @(posedge sysclk or posedge btn0) begin
    if (btn0)
      rst_cnt <= '0;
    else if (!rst_cnt[4])
      rst_cnt <= rst_cnt + 5'd1;
  end
  logic rst_n;
  assign rst_n = rst_cnt[4];  // low-active reset for the SoC

  // Two-flip-flop synchroniser for the switch.
  (* ASYNC_REG = "TRUE" *) logic [1:0] sw_sync = '0;
  always_ff @(posedge sysclk) sw_sync <= {sw_sync[0], sw0};

  fsoc #(
    .CHUNKSIZE ( CHUNKSIZE ),
    .CONF      ( "MIN"     ),
    .RFTYPE    ( RFTYPE    ),
    .RVC       ( "NONE"    ),
    .MEMFILE   ( MEMFILE   ),
    .MEMSIZE   ( 4096      ),   // bytes: 1024 words of 32 bits
    .MEMDLY1   ( 0         ),
    .GPOCNT    ( 4         )
  ) u_soc (
    .clk_i  ( sysclk     ),
    .rst_in ( rst_n      ),
    .gpi_i  ( sw_sync[1] ),
    .gpo_o  ( led        )
  );

endmodule

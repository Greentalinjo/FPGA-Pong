module game_clock_generator (
    output fast_clock_out,
    output slow_clock_out
);

  logic clk_48MHz;

  // Generate a 48MHz clock using the internal high frequency oscillator.
  SB_HFOSC #(
      .CLKHF_DIV("0b00")
  ) hfosc_inst (
      .CLKHFPU(1'b1),
      .CLKHFEN(1'b1),
      .CLKHF  (clk_48MHz)
  );

  // Convert the clock to 25.125MHz using an internal PLL.
  SB_PLL40_CORE #(
      .FEEDBACK_PATH("SIMPLE"),
      .DIVR(4'b0011),  // DIVR =  3
      .DIVF(7'b1000010),  // DIVF = 66
      .DIVQ(3'b101),  // DIVQ =  5
      .FILTER_RANGE(3'b001)  // FILTER_RANGE = 1
  ) pll_inst (
      .LOCK(),
      .RESETB(1'b1),
      .BYPASS(1'b0),
      .REFERENCECLK(clk_48MHz),
      .PLLOUTCORE(fast_clock_out)
  );

  SB_LFOSC lfosc_inst (
      .CLKLFEN(1'b1),
      .CLKLFPU(1'b1),
      .CLKLF  (slow_clock_out)
  );

endmodule

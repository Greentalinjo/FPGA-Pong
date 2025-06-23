module button_debouncer #(
    parameter DEBOUNCE_WIDTH_IN_CLOCKS
) (
    input clk,
    input rst,
    input button,
    output logic debounced_button
);

  localparam int DEBOUNCE_COUNTER_SIZE = $clog2(DEBOUNCE_WIDTH_IN_CLOCKS + 1);

  typedef enum logic [0:0] {
    IDLE   = 1'b0,
    ACTIVE = 1'b1
  } state_t;

  state_t is_active;

  logic [DEBOUNCE_COUNTER_SIZE-1:0] debounce_counter;
  logic stated_button;

  always_ff @(posedge clk or negedge rst)
    if (~rst) begin
      debounce_counter <= '0;
      is_active <= IDLE;
    end else begin
      if (debounce_counter == DEBOUNCE_WIDTH_IN_CLOCKS) begin
        is_active <= ~is_active;
        debounce_counter <= '0;
      end else begin
        if (stated_button) debounce_counter <= debounce_counter + 1;
        else debounce_counter <= '0;
      end
    end

  assign stated_button = button ^ is_active;
  assign debounced_button = is_active;

endmodule

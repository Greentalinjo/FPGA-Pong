module paddle #(
    parameter int POSITION_CHANGE_FREQ_IN_CLOCKS,
    parameter int DEBOUNCE_WIDTH_IN_CLOCKS
) (
    input clk,
    input rst,
    input button_up,
    input button_down,
    output logic signed [1:0] position_change
);

  localparam int POSITION_CHANGE_COUNTER_SIZE = $clog2(POSITION_CHANGE_FREQ_IN_CLOCKS + 1);

  logic debounced_up;
  logic debounced_down;
  logic signed [1:0] debounced_delta;
  int debounced_delta_sum;
  int next_debounced_delta_sum;
  logic [POSITION_CHANGE_COUNTER_SIZE-1:0] position_change_counter;
  logic [POSITION_CHANGE_COUNTER_SIZE-1:0] next_position_change_counter;

  button_debouncer #(
      .DEBOUNCE_WIDTH_IN_CLOCKS(DEBOUNCE_WIDTH_IN_CLOCKS)
  ) up_debouncer (
      .clk(clk),
      .rst(rst),
      .button(button_up),
      .debounced_button(debounced_up)
  );

  button_debouncer #(
      .DEBOUNCE_WIDTH_IN_CLOCKS(DEBOUNCE_WIDTH_IN_CLOCKS)
  ) down_debouncer (
      .clk(clk),
      .rst(rst),
      .button(button_down),
      .debounced_button(debounced_down)
  );

  always_ff @(posedge clk or negedge rst)
    if (~rst) begin
      position_change_counter <= '0;
      debounced_delta_sum <= '0;
    end else begin
      debounced_delta_sum <= next_debounced_delta_sum;
      position_change_counter <= next_position_change_counter;
    end


  always_comb begin
    // Default values.
    position_change = 0;
    next_debounced_delta_sum = debounced_delta_sum + debounced_delta;
    next_position_change_counter = position_change_counter + 1;

    if (next_position_change_counter == POSITION_CHANGE_FREQ_IN_CLOCKS) begin
      // Reset the counter
      next_position_change_counter = 0;
      // Determine whether movement took place - output accordingly. High Y is the bottom of the screen to outputs are inverted.
      unique case (next_debounced_delta_sum)
      -POSITION_CHANGE_FREQ_IN_CLOCKS: begin
        position_change = 1;
      end

      POSITION_CHANGE_FREQ_IN_CLOCKS: begin
        position_change = -1;
      end
      
      default: begin
        position_change = 0;
      end
    endcase
    // We reset the sum so that we can begin summation again. 
    next_debounced_delta_sum = 0;
    end
  end

  assign debounced_delta = debounced_up - debounced_down;



endmodule

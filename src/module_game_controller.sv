module game_controller #(
    parameter int POSITION_CHANGE_FREQ_IN_CLOCKS,
    parameter int DEBOUNCE_WIDTH_IN_CLOCKS      ,
    parameter int INITIAL_PADDLE_1_X            ,
    parameter int INITIAL_PADDLE_2_X            ,
    parameter int INITIAL_PADDLE_Y              ,
    parameter int INITIAL_BALL_X                ,
    parameter int INITIAL_BALL_Y                ,
    parameter int TOTAL_WIDTH                   ,
    parameter int TOTAL_HEIGHT                  ,
    parameter int PADDLE_HEIGHT                 ,
    parameter int PADDLE_WIDTH                  ,
    parameter int BALL_SIDE_SIZE                ,
    parameter int BALL_OFFSET_RANGE             ,
    parameter int BORDER_PIXEL_WIDTH
) (
    input logic clk,
    input logic rst,

    input logic button_up_1,
    input logic button_down_1,

    input logic button_up_2,
    input logic button_down_2,

    output logic [HEIGHT_COUNTER_SIZE:0] paddle_1_pos,
    output logic [HEIGHT_COUNTER_SIZE:0] paddle_2_pos,
    output logic [ WIDTH_COUNTER_SIZE:0] ball_pos_x,
    output logic [HEIGHT_COUNTER_SIZE:0] ball_pos_y
);

  localparam int HEIGHT_COUNTER_SIZE = $clog2(TOTAL_HEIGHT + 1);
  localparam int WIDTH_COUNTER_SIZE = $clog2(TOTAL_WIDTH + 1);
  localparam int BALL_OFFSET_RANGE_COUNTER_SIZE = $clog2(BALL_OFFSET_RANGE + 1);
  localparam int BALL_POSITION_CHANGE_COUNTER_SIZE = $clog2(POSITION_CHANGE_FREQ_IN_CLOCKS + 1);

  // This is our internal logic's paddle heights.
  logic [HEIGHT_COUNTER_SIZE:0] internal_height_paddle_1;
  logic [HEIGHT_COUNTER_SIZE:0] internal_height_paddle_2;

  logic [HEIGHT_COUNTER_SIZE:0] next_height_paddle_1;
  logic [HEIGHT_COUNTER_SIZE:0] next_height_paddle_2;

  // The position_change signed variable and its sign-extended version for both paddles.
  logic signed [1:0] position_change_1;
  logic signed [1:0] position_change_2;
  logic [HEIGHT_COUNTER_SIZE:0] extended_position_change_1;
  logic [HEIGHT_COUNTER_SIZE:0] extended_position_change_2;

  logic [HEIGHT_COUNTER_SIZE:0] internal_ball_y;
  logic [WIDTH_COUNTER_SIZE:0] internal_ball_x;

  logic [HEIGHT_COUNTER_SIZE:0] next_ball_y;
  logic [WIDTH_COUNTER_SIZE:0] next_ball_x;

  logic signed [1:0] internal_ball_x_direction;
  logic signed [1:0] internal_ball_y_direction;
  logic signed [1:0] next_internal_ball_y_direction;
  logic signed [1:0] next_internal_ball_x_direction;

  logic [BALL_OFFSET_RANGE_COUNTER_SIZE - 1:0] ball_offset_range_counter;

  logic [BALL_POSITION_CHANGE_COUNTER_SIZE-1:0] ball_position_change_counter;
  logic [BALL_POSITION_CHANGE_COUNTER_SIZE-1:0] next_ball_position_change_counter;

  logic [HEIGHT_COUNTER_SIZE:0] lower_bound_check_paddle_1;
  logic [HEIGHT_COUNTER_SIZE:0] upper_bound_check_paddle_1;
  logic [HEIGHT_COUNTER_SIZE:0] lower_bound_check_paddle_2;
  logic [HEIGHT_COUNTER_SIZE:0] upper_bound_check_paddle_2;

  logic ball_deflected;

  logic signed [HEIGHT_COUNTER_SIZE:0] extended_ball_y_direction;
  logic signed [WIDTH_COUNTER_SIZE:0] extended_ball_x_direction;

  paddle #(
      .POSITION_CHANGE_FREQ_IN_CLOCKS(POSITION_CHANGE_FREQ_IN_CLOCKS),
      .DEBOUNCE_WIDTH_IN_CLOCKS(DEBOUNCE_WIDTH_IN_CLOCKS)
  ) paddle_1 (
      .clk(clk),
      .rst(rst),
      .button_up(button_up_1),
      .button_down(button_down_1),
      .position_change(position_change_1)
  );

  paddle #(
      .POSITION_CHANGE_FREQ_IN_CLOCKS(POSITION_CHANGE_FREQ_IN_CLOCKS),
      .DEBOUNCE_WIDTH_IN_CLOCKS(DEBOUNCE_WIDTH_IN_CLOCKS)
  ) paddle_2 (
      .clk(clk),
      .rst(rst),
      .button_up(button_up_2),
      .button_down(button_down_2),
      .position_change(position_change_2)
  );

  // Paddles position manager.
  always_ff @(posedge clk or negedge rst)
    if (~rst) begin
      internal_height_paddle_1 <= INITIAL_PADDLE_Y;
      internal_height_paddle_2 <= INITIAL_PADDLE_Y;
    end else begin
      internal_height_paddle_1 <= next_height_paddle_1;
      internal_height_paddle_2 <= next_height_paddle_2;
    end

  always_comb begin
    // Default: Keep current values.
    next_height_paddle_1 = internal_height_paddle_1;
    next_height_paddle_2 = internal_height_paddle_2;
    // If we did not reach the edges, change position according to paddle movement logic.
    if ((internal_height_paddle_1 + extended_position_change_1 != TOTAL_HEIGHT - PADDLE_HEIGHT - BORDER_PIXEL_WIDTH) && (internal_height_paddle_1 + extended_position_change_1 != $bits(internal_height_paddle_1)'(BORDER_PIXEL_WIDTH)))
      next_height_paddle_1 = internal_height_paddle_1 + extended_position_change_1;
    if ((internal_height_paddle_2 + extended_position_change_2 != TOTAL_HEIGHT - PADDLE_HEIGHT - BORDER_PIXEL_WIDTH) && (internal_height_paddle_2 + extended_position_change_2 != $bits(internal_height_paddle_1)'(BORDER_PIXEL_WIDTH)))
      next_height_paddle_2 = internal_height_paddle_2 + extended_position_change_2;
  end

  // Sign-extend the position-change.
  assign extended_position_change_1 = {
    {(HEIGHT_COUNTER_SIZE - 1) {position_change_1[1]}}, position_change_1
  };
  assign extended_position_change_2 = {
    {(HEIGHT_COUNTER_SIZE - 1) {position_change_2[1]}}, position_change_2
  };


  // Ball position manager.
  always_ff @(posedge clk or negedge rst)
    if (~rst) begin
      internal_ball_x <= INITIAL_BALL_X;
      internal_ball_y <= INITIAL_BALL_Y;
      internal_ball_x_direction <= -1;
      internal_ball_y_direction <= -1;
      ball_position_change_counter <= '0;
    end else begin
      internal_ball_y_direction <= next_internal_ball_y_direction;
      internal_ball_y <= next_ball_y;
      internal_ball_x_direction <= next_internal_ball_x_direction;
      internal_ball_x <= next_ball_x;
      ball_position_change_counter <= next_ball_position_change_counter;
    end

  always_comb begin
    // Default values.
    lower_bound_check_paddle_1 = 0;
    upper_bound_check_paddle_1 = 0;
    lower_bound_check_paddle_2 = 0;
    upper_bound_check_paddle_2 = 0;
    ball_deflected = 0;
    // Always advance the position change counter.
    next_ball_position_change_counter = ball_position_change_counter + 1;
    // Default: Keep current values.
    next_ball_y = internal_ball_y;
    next_ball_x = internal_ball_x;
    next_internal_ball_y_direction = internal_ball_y_direction;
    next_internal_ball_x_direction = internal_ball_x_direction;
    // If counter reached (previous counter is 1 off of the goal value): We change the position, and zero the counter.
    if (next_ball_position_change_counter == POSITION_CHANGE_FREQ_IN_CLOCKS) begin
      // Reset ball movement counter.
      next_ball_position_change_counter = 0;

      // Handle top and bottom screen limits.
      next_ball_y = next_ball_y + extended_ball_y_direction;
      // If the ball touched the upper or lower screen bound, we flip its direction.
      if ((next_ball_y == TOTAL_HEIGHT - BALL_SIDE_SIZE - BORDER_PIXEL_WIDTH) | (next_ball_y == BORDER_PIXEL_WIDTH))
        next_internal_ball_y_direction = -internal_ball_y_direction;

      // Handle X direction and paddle interactions.
      next_ball_x = next_ball_x + extended_ball_x_direction;

      lower_bound_check_paddle_1 = (next_height_paddle_1 < BALL_SIDE_SIZE) ? 0 : next_height_paddle_1 - BALL_SIDE_SIZE;
      upper_bound_check_paddle_1 = (next_height_paddle_1 > TOTAL_HEIGHT - PADDLE_HEIGHT) ? TOTAL_HEIGHT : next_height_paddle_1 + PADDLE_HEIGHT;
      lower_bound_check_paddle_2 = (next_height_paddle_2 < BALL_SIDE_SIZE) ? 0 : next_height_paddle_2 - BALL_SIDE_SIZE;
      upper_bound_check_paddle_2 = (next_height_paddle_2 > TOTAL_HEIGHT - PADDLE_HEIGHT) ? TOTAL_HEIGHT : next_height_paddle_2 + PADDLE_HEIGHT;

      // Did the ball hit the left paddle?
      if ((next_ball_x == $bits(next_ball_x)'(INITIAL_PADDLE_1_X + PADDLE_WIDTH)) && (next_ball_y <= upper_bound_check_paddle_1) && (next_ball_y >= lower_bound_check_paddle_1)) begin
        next_internal_ball_x_direction = -internal_ball_x_direction;
        ball_deflected = 1'b1;
      end
      // Did the ball hit the right paddle?
      if ((next_ball_x == $bits(next_ball_x)'(INITIAL_PADDLE_2_X - BALL_SIDE_SIZE)) && (next_ball_y <= upper_bound_check_paddle_2) && (next_ball_y >= lower_bound_check_paddle_2)) begin
        next_internal_ball_x_direction = -internal_ball_x_direction;
        ball_deflected = 1'b1;
      end
      
      // Did the ball score a goal (We enter into the if here only if the ball reached one of the sides, but did not hit any paddles).
      if (((next_ball_x == $bits(next_ball_x)'(INITIAL_PADDLE_1_X + PADDLE_WIDTH)) || (next_ball_x == $bits(next_ball_x)'(INITIAL_PADDLE_2_X - BALL_SIDE_SIZE))) && ~ball_deflected) begin
        next_ball_x = INITIAL_BALL_X;
        // Set the starting Y position and directions to "random" values.
        next_ball_y = INITIAL_BALL_Y - (BALL_OFFSET_RANGE / 2) + ball_offset_range_counter;
        next_internal_ball_x_direction = ball_offset_range_counter[0];
        next_internal_ball_y_direction = ball_offset_range_counter[1];
      end
    end
  end

  // Ball Y position on goal offset counter.
  always_ff @(posedge clk or negedge rst)
    if (~rst) begin
      ball_offset_range_counter <= '0;
    end else begin
      ball_offset_range_counter <= (ball_offset_range_counter == BALL_OFFSET_RANGE) ? 0 : ball_offset_range_counter + 1;
    end

  assign extended_ball_y_direction = {
    {(HEIGHT_COUNTER_SIZE - 1) {internal_ball_y_direction[1]}}, internal_ball_y_direction
  };

  assign extended_ball_x_direction = {
    {(WIDTH_COUNTER_SIZE - 1) {internal_ball_x_direction[1]}}, internal_ball_x_direction
  };


  // Handle output.
  assign paddle_1_pos = internal_height_paddle_1;
  assign paddle_2_pos = internal_height_paddle_2;
  assign ball_pos_y = internal_ball_y;
  assign ball_pos_x = internal_ball_x;



endmodule

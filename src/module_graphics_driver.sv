module graphics_driver #(
    parameter int HEIGHT_COUNTER_SIZE,
    parameter int WIDTH_COUNTER_SIZE,
    parameter int INITIAL_PADDLE_1_X,
    parameter int INITIAL_PADDLE_2_X,
    parameter int INITIAL_PADDLE_Y,
    parameter int INITIAL_BALL_X,
    parameter int INITIAL_BALL_Y,
    parameter int PADDLE_WIDTH,
    parameter int PADDLE_HEIGHT,
    parameter int BALL_SIDE_SIZE,
    parameter int BORDER_PIXEL_WIDTH
) (
    input clk,  // This is a proper ~25.172 MHz clock.
    input rst,
    input logic [HEIGHT_COUNTER_SIZE:0] paddle_1_pos,
    input logic [HEIGHT_COUNTER_SIZE:0] paddle_2_pos,
    input logic [WIDTH_COUNTER_SIZE:0] ball_pos_x,
    input logic [HEIGHT_COUNTER_SIZE:0] ball_pos_y,
    // Sampled outputs - These are the outputs that we actually send to the VGA monitor.
    output logic hsync_s,
    output logic vsync_s,
    output logic red_s,
    output logic green_s,
    output logic blue_s
);

  localparam int X_ACTIVE_IN_CLOCKS  = 640;
  localparam int X_FRONT_IN_CLOCKS   = 16;
  localparam int X_PULSE_IN_CLOCKS   = 96;
  localparam int X_BACK_IN_CLOCKS    = 48;
  localparam int TOTAL_X             = X_ACTIVE_IN_CLOCKS + X_FRONT_IN_CLOCKS + X_PULSE_IN_CLOCKS + X_BACK_IN_CLOCKS;

  localparam int Y_ACTIVE_IN_LINES   = 480;
  localparam int Y_FRONT_IN_LINES    = 10;
  localparam int Y_PULSE_IN_LINES    = 2;
  localparam int Y_BACK_IN_LINES     = 33;
  localparam int TOTAL_Y             = Y_ACTIVE_IN_LINES + Y_FRONT_IN_LINES + Y_PULSE_IN_LINES + Y_BACK_IN_LINES;

  localparam int VGA_X_COUNTER_SIZE = $clog2(TOTAL_X);
  localparam int VGA_Y_COUNTER_SIZE = $clog2(TOTAL_Y);

  logic [VGA_X_COUNTER_SIZE-1:0] x_change_counter;
  logic [VGA_Y_COUNTER_SIZE-1:0] y_change_counter;
  logic [VGA_X_COUNTER_SIZE-1:0] next_x_change_counter;
  logic [VGA_Y_COUNTER_SIZE-1:0] next_y_change_counter;

  logic [HEIGHT_COUNTER_SIZE:0] sampled_paddle_1_pos;
  logic [HEIGHT_COUNTER_SIZE:0] sampled_paddle_2_pos;
  logic [WIDTH_COUNTER_SIZE:0] sampled_ball_pos_x;
  logic [HEIGHT_COUNTER_SIZE:0] sampled_ball_pos_y;

  logic [HEIGHT_COUNTER_SIZE:0] next_paddle_1_pos;
  logic [HEIGHT_COUNTER_SIZE:0] next_paddle_2_pos;
  logic [WIDTH_COUNTER_SIZE:0] next_ball_pos_x;
  logic [HEIGHT_COUNTER_SIZE:0] next_ball_pos_y;

  logic x_line_finished;

  // Unsampled outputs - Used internally.
  logic hsync;
  logic vsync;
  logic red;
  logic green;
  logic blue;

  // Graphics driver sampler.
  always_ff @(posedge clk or negedge rst)
    if (~rst) begin
      x_change_counter <= '0;
      y_change_counter <= '0;
      sampled_paddle_1_pos <= INITIAL_PADDLE_Y;
      sampled_paddle_2_pos <= INITIAL_PADDLE_Y;
      sampled_ball_pos_x <= INITIAL_BALL_X;
      sampled_ball_pos_y <= INITIAL_BALL_Y;
    end else begin
      // Sample the object positions.
      sampled_paddle_1_pos <= next_paddle_1_pos;
      sampled_paddle_2_pos <= next_paddle_2_pos;
      sampled_ball_pos_x <= next_ball_pos_x;
      sampled_ball_pos_y <= next_ball_pos_y;
      // Sample x and y counters.
      x_change_counter <= next_x_change_counter;
      y_change_counter <= next_y_change_counter;
    end

  // Horizontal and vertical sync logic.
  always_comb begin
    // Default assignments.
    next_paddle_1_pos = sampled_paddle_1_pos;
    next_paddle_2_pos = sampled_paddle_2_pos;
    next_ball_pos_x = sampled_ball_pos_x;
    next_ball_pos_y = sampled_ball_pos_y;

    next_x_change_counter = x_change_counter + 1;
    x_line_finished = 1'b0;

    // Reset x counter and trigger y counter increment.
    if (next_x_change_counter == TOTAL_X) begin
      next_x_change_counter = '0;
      x_line_finished = 1'b1;
    end

    next_y_change_counter = y_change_counter + x_line_finished;

    hsync = ((x_change_counter >= (X_ACTIVE_IN_CLOCKS + X_FRONT_IN_CLOCKS)) &&
           (x_change_counter <  (X_ACTIVE_IN_CLOCKS + X_FRONT_IN_CLOCKS + X_PULSE_IN_CLOCKS))) ? 1'b0 : 1'b1;

    vsync = ((y_change_counter >= (Y_ACTIVE_IN_LINES + Y_FRONT_IN_LINES)) &&
           (y_change_counter <  (Y_ACTIVE_IN_LINES + Y_FRONT_IN_LINES + Y_PULSE_IN_LINES))) ? 1'b0 : 1'b1;

    // Reset vertical counter and resample game positions.
    if (next_y_change_counter == TOTAL_Y) begin
      next_y_change_counter = '0;

      next_paddle_1_pos = paddle_1_pos;
      next_paddle_2_pos = paddle_2_pos;
      next_ball_pos_x = ball_pos_x;
      next_ball_pos_y = ball_pos_y;
    end
  end

  // Pixel color logic.
  always_comb begin
    {red, green, blue} = 3'b000;
    // If x and y inside any of the shapes (or the display border) - display (R G B = 1) else display (R G B = 0).
    if ((x_change_counter < X_ACTIVE_IN_CLOCKS) && (y_change_counter < Y_ACTIVE_IN_LINES)) begin
      // Left paddle.
      if ((x_change_counter >= INITIAL_PADDLE_1_X) && (x_change_counter < INITIAL_PADDLE_1_X + PADDLE_WIDTH) && (y_change_counter >= sampled_paddle_1_pos) && (y_change_counter < sampled_paddle_1_pos + PADDLE_HEIGHT)) begin
        {red, green, blue} = 3'b111;
      end
      // Right paddle.
      if ((x_change_counter >= INITIAL_PADDLE_2_X) && (x_change_counter < INITIAL_PADDLE_2_X + PADDLE_WIDTH) && (y_change_counter >= sampled_paddle_2_pos) && (y_change_counter < sampled_paddle_2_pos + PADDLE_HEIGHT)) begin
        {red, green, blue} = 3'b111;
      end
      // Ball.
      if ((x_change_counter >= sampled_ball_pos_x) && (x_change_counter < sampled_ball_pos_x + BALL_SIDE_SIZE) && (y_change_counter >= sampled_ball_pos_y) && (y_change_counter < sampled_ball_pos_y + BALL_SIDE_SIZE)) begin
        {red, green, blue} = 3'b111;
      end
      // Border.
      if ((x_change_counter < BORDER_PIXEL_WIDTH) || (x_change_counter >= X_ACTIVE_IN_CLOCKS - BORDER_PIXEL_WIDTH) || (y_change_counter < BORDER_PIXEL_WIDTH) || (y_change_counter >= Y_ACTIVE_IN_LINES - BORDER_PIXEL_WIDTH)) begin
        {red, green, blue} = 3'b111;
      end
    end
  end

  // Graphics output sampler.
  always_ff @(posedge clk or negedge rst)
    if (~rst) begin
      hsync_s <= 0;
      vsync_s <= 0;
      red_s   <= 0;
      green_s <= 0;
      blue_s  <= 0;
    end else begin
      hsync_s <= hsync;
      vsync_s <= vsync;
      red_s   <= red;
      green_s <= green;
      blue_s  <= blue;
    end

endmodule

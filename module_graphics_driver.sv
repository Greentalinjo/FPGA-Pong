module graphics_driver #(
    parameter int HEIGHT_COUNTER_SIZE           ,
    parameter int WIDTH_COUNTER_SIZE            ,
    parameter int INITIAL_PADDLE_1_X            ,
    parameter int INITIAL_PADDLE_2_X            ,
    parameter int INITIAL_PADDLE_Y              ,
    parameter int INITIAL_BALL_X                ,
    parameter int INITIAL_BALL_Y                ,
    parameter int PADDLE_WIDTH                  ,
    parameter int PADDLE_HEIGHT                 ,
    parameter int BALL_SIDE_SIZE
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

  typedef enum logic [1:0] {
    COORDINATE_ACTIVE = 2'b00,
    COORDINATE_FRONT  = 2'b01,
    COORDINATE_PULSE  = 2'b10,
    COORDINATE_BACK   = 2'b11
  } screen_state_t;

  localparam int X_ACTIVE_IN_CLOCKS = 640;
  localparam int X_FRONT_IN_CLOCKS = 16;
  localparam int X_PULSE_IN_CLOCKS = 96;
  localparam int X_BACK_IN_CLOCKS = 48;
  localparam int TOTAL_X             = X_ACTIVE_IN_CLOCKS + X_FRONT_IN_CLOCKS + X_PULSE_IN_CLOCKS + X_BACK_IN_CLOCKS;

  localparam int Y_ACTIVE_IN_LINES = 480;
  localparam int Y_FRONT_IN_LINES = 10;
  localparam int Y_PULSE_IN_LINES = 2;
  localparam int Y_BACK_IN_LINES = 33;
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

  screen_state_t x_state;
  screen_state_t y_state;
  screen_state_t next_x_state;
  screen_state_t next_y_state;

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
      x_state <= COORDINATE_ACTIVE;
      y_state <= COORDINATE_ACTIVE;
      x_change_counter <= '0;
      y_change_counter <= '0;
      // We zero these. after reset both counters are zero and states are active so we dont refresh the correct positions for a single frame.
      sampled_paddle_1_pos <= INITIAL_PADDLE_Y;
      sampled_paddle_2_pos <= INITIAL_PADDLE_Y;
      sampled_ball_pos_x   <= INITIAL_BALL_X;
      sampled_ball_pos_y   <= INITIAL_BALL_Y;
    end else begin
      // Sample the object positions.
      sampled_paddle_1_pos <= next_paddle_1_pos;
      sampled_paddle_2_pos <= next_paddle_2_pos;
      sampled_ball_pos_x <= next_ball_pos_x;
      sampled_ball_pos_y <= next_ball_pos_y;
      // Sample x and y counters.
      x_change_counter <= next_x_change_counter;
      y_change_counter <= next_y_change_counter;
      // Sample the x and y states.
      x_state <= next_x_state;
      y_state <= next_y_state;
    end

  // Horizontal and vertical sync logic.
  always_comb begin
    // Default values.
    next_paddle_1_pos = sampled_paddle_1_pos;
    next_paddle_2_pos = sampled_paddle_2_pos;
    next_ball_pos_x = sampled_ball_pos_x;
    next_ball_pos_y = sampled_ball_pos_y;
    next_x_change_counter = x_change_counter + 1;
    next_y_change_counter = y_change_counter;
    next_x_state = x_state;
    next_y_state = y_state;
    hsync = 1'b1;
    vsync = 1'b1;
    x_line_finished = 1'b0;

    unique case (x_state)
      COORDINATE_ACTIVE: begin
        hsync = 1'b1;
        if (next_x_change_counter == X_ACTIVE_IN_CLOCKS) 
          next_x_state = COORDINATE_FRONT;
      end
      COORDINATE_FRONT: begin
        hsync = 1'b1;
        if (next_x_change_counter == X_ACTIVE_IN_CLOCKS + X_FRONT_IN_CLOCKS)
          next_x_state = COORDINATE_PULSE;
      end
      COORDINATE_PULSE: begin
        hsync = 1'b0;
        if (next_x_change_counter == X_ACTIVE_IN_CLOCKS + X_FRONT_IN_CLOCKS + X_PULSE_IN_CLOCKS)
          next_x_state = COORDINATE_BACK;
      end
      COORDINATE_BACK: begin
        hsync = 1'b1;
        if (next_x_change_counter == X_ACTIVE_IN_CLOCKS + X_FRONT_IN_CLOCKS + X_PULSE_IN_CLOCKS + X_BACK_IN_CLOCKS) begin
          next_x_state = COORDINATE_ACTIVE;
          next_x_change_counter = '0;
          x_line_finished = 1'b1;
        end
      end
      default: begin
        // This is impossible.
      end
    endcase

    next_y_change_counter = y_change_counter + x_line_finished;

    unique case (y_state)
      COORDINATE_ACTIVE: begin
        vsync = 1'b1;
        if (next_y_change_counter == Y_ACTIVE_IN_LINES) next_y_state = COORDINATE_FRONT;
      end
      COORDINATE_FRONT: begin
        vsync = 1'b1;
        if (next_y_change_counter == Y_ACTIVE_IN_LINES + Y_FRONT_IN_LINES)
          next_y_state = COORDINATE_PULSE;
      end
      COORDINATE_PULSE: begin
        vsync = 1'b0;
        if (next_y_change_counter == Y_ACTIVE_IN_LINES + Y_FRONT_IN_LINES + Y_PULSE_IN_LINES)
          next_y_state = COORDINATE_BACK;
      end
      COORDINATE_BACK: begin
        vsync = 1'b1;
        if (next_y_change_counter == Y_ACTIVE_IN_LINES + Y_FRONT_IN_LINES + Y_PULSE_IN_LINES + Y_BACK_IN_LINES) begin
          next_y_state = COORDINATE_ACTIVE;
          next_y_change_counter = '0;
          // In this case, we need to re-sample the game shape positions.
          next_paddle_1_pos = paddle_1_pos;
          next_paddle_2_pos = paddle_2_pos;
          next_ball_pos_x = ball_pos_x;
          next_ball_pos_y = ball_pos_y;
        end
      end
      default: begin
        // This is impossible.
      end
    endcase

  end

  // Pixel color logic.
  always_comb begin
    {red, green, blue} = 3'b000;
    // If x and y inside any of the shapes - display (R G B = 1) else display (R G B = 0).
    if ((x_state == COORDINATE_ACTIVE) && (y_state == COORDINATE_ACTIVE)) begin
      if ((x_change_counter >= INITIAL_PADDLE_1_X) && (x_change_counter < INITIAL_PADDLE_1_X + PADDLE_WIDTH) && (y_change_counter >= sampled_paddle_1_pos) && (y_change_counter < sampled_paddle_1_pos + PADDLE_HEIGHT)) begin
        {red, green, blue} = 3'b111;
      end
      if ((x_change_counter >= INITIAL_PADDLE_2_X) && (x_change_counter < INITIAL_PADDLE_2_X + PADDLE_WIDTH) && (y_change_counter >= sampled_paddle_2_pos) && (y_change_counter < sampled_paddle_2_pos + PADDLE_HEIGHT)) begin
        {red, green, blue} = 3'b111;
      end
      if ((x_change_counter >= sampled_ball_pos_x) && (x_change_counter < sampled_ball_pos_x + BALL_SIDE_SIZE) && (y_change_counter >= sampled_ball_pos_y) && (y_change_counter < sampled_ball_pos_y + BALL_SIDE_SIZE)) begin
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

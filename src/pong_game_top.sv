`include "game_constants_pkg.svh"

module pong_game_top #(
    parameter int GAME_CONTROLLER_CLOCK_RATE                = GAME_CONTROLLER_CLOCK_RATE,
    parameter int BUTTON_BOUNCE_DURATION_IN_SECONDS         = BUTTON_BOUNCE_DURATION_IN_SECONDS,
    parameter int TOP_TO_BOTTOM_PADDLE_SPEED_IN_SECONDS     = TOP_TO_BOTTOM_PADDLE_SPEED_IN_SECONDS,
    parameter int POSITION_CHANGE_FREQ_IN_CLOCKS            = POSITION_CHANGE_FREQ_IN_CLOCKS,
    parameter int DEBOUNCE_WIDTH_IN_CLOCKS                  = DEBOUNCE_WIDTH_IN_CLOCKS,
    parameter int TOTAL_WIDTH                               = TOTAL_WIDTH,
    parameter int TOTAL_HEIGHT                              = TOTAL_HEIGHT,
    parameter int PADDLE_DISTANCE_FROM_EDGE                 = PADDLE_DISTANCE_FROM_EDGE,
    parameter int PADDLE_HEIGHT                             = PADDLE_HEIGHT,
    parameter int PADDLE_WIDTH                              = PADDLE_WIDTH,
    parameter int BALL_SIDE_SIZE                            = BALL_SIDE_SIZE
) (
    input logic rst,

    input logic button_up_1,
    input logic button_down_1,
    input logic button_up_2,
    input logic button_down_2,

    output logic hsync,
    output logic vsync,
    output logic red,
    output logic green,
    output logic blue,

    // Debugging signals - Currently used to indicate whether the reset is on or off.
    output logic LED_R,
    output logic LED_G,
    output logic LED_B

);

  localparam int HEIGHT_COUNTER_SIZE = $clog2(TOTAL_HEIGHT + 1);
  localparam int WIDTH_COUNTER_SIZE = $clog2(TOTAL_WIDTH + 1);

  localparam int INITIAL_PADDLE_1_X = PADDLE_DISTANCE_FROM_EDGE;
  localparam int INITIAL_PADDLE_2_X = TOTAL_WIDTH - PADDLE_DISTANCE_FROM_EDGE - PADDLE_WIDTH;
  localparam int INITIAL_PADDLE_Y = (TOTAL_HEIGHT / 2) - (PADDLE_HEIGHT / 2);
  localparam int INITIAL_BALL_X = (TOTAL_WIDTH / 2) - (BALL_SIDE_SIZE / 2);
  localparam int INITIAL_BALL_Y = (TOTAL_HEIGHT / 2) - (BALL_SIDE_SIZE / 2);

  logic clk_25_125_MHz;
  logic clk_10_KHz;

  logic [HEIGHT_COUNTER_SIZE:0] paddle_1_pos;
  logic [HEIGHT_COUNTER_SIZE:0] paddle_2_pos;
  logic [ WIDTH_COUNTER_SIZE:0] ball_pos_x;
  logic [HEIGHT_COUNTER_SIZE:0] ball_pos_y;

  logic [HEIGHT_COUNTER_SIZE:0] sync_paddle_1_pos;
  logic [HEIGHT_COUNTER_SIZE:0] sync_paddle_2_pos;
  logic [ WIDTH_COUNTER_SIZE:0] sync_ball_pos_x;
  logic [HEIGHT_COUNTER_SIZE:0] sync_ball_pos_y;

  logic [$bits(paddle_1_pos) + 
         $bits(paddle_2_pos) + 
         $bits(ball_pos_x) + 
         $bits(ball_pos_y) - 1 : 0] input_packed_for_handshake;
  logic [$bits(sync_paddle_1_pos) + 
         $bits(sync_paddle_2_pos) + 
         $bits(sync_ball_pos_x) + 
         $bits(sync_ball_pos_y) - 1 : 0] output_packed_for_handshake;

  game_clock_generator clock_inst (
    .fast_clock_out(clk_25_125_MHz),
    .slow_clock_out(clk_10_KHz)
  );

  game_controller #(
      .POSITION_CHANGE_FREQ_IN_CLOCKS(POSITION_CHANGE_FREQ_IN_CLOCKS),
      .DEBOUNCE_WIDTH_IN_CLOCKS(DEBOUNCE_WIDTH_IN_CLOCKS),
      .INITIAL_PADDLE_1_X(INITIAL_PADDLE_1_X),
      .INITIAL_PADDLE_2_X(INITIAL_PADDLE_2_X),
      .INITIAL_PADDLE_Y(INITIAL_PADDLE_Y),
      .INITIAL_BALL_X(INITIAL_BALL_X),
      .INITIAL_BALL_Y(INITIAL_BALL_Y),
      .TOTAL_WIDTH(TOTAL_WIDTH),
      .TOTAL_HEIGHT(TOTAL_HEIGHT),
      .PADDLE_HEIGHT(PADDLE_HEIGHT),
      .PADDLE_WIDTH(PADDLE_WIDTH),
      .BALL_SIDE_SIZE(BALL_SIDE_SIZE)
  ) game_controller_inst (
      .clk(clk_10_KHz),
      .rst(rst),
      .button_up_1(button_up_1),
      .button_down_1(button_down_1),
      .button_up_2(button_up_2),
      .button_down_2(button_down_2),
      .paddle_1_pos(paddle_1_pos),
      .paddle_2_pos(paddle_2_pos),
      .ball_pos_x(ball_pos_x),
      .ball_pos_y(ball_pos_y)
  );

  domain_constant_handshake #(
      .DATA_WIDTH($bits(input_packed_for_handshake)),
  ) domain_constant_handshake_inst (
      .i_clk_a(clk_10_KHz),
      .i_clk_b(clk_25_125_MHz),
      .rst(rst),
      .i_data(input_packed_for_handshake),
      .o_data(output_packed_for_handshake)
  );

  graphics_driver #(
    .HEIGHT_COUNTER_SIZE(HEIGHT_COUNTER_SIZE),
    .WIDTH_COUNTER_SIZE(WIDTH_COUNTER_SIZE),
    .INITIAL_PADDLE_1_X(INITIAL_PADDLE_1_X),
    .INITIAL_PADDLE_2_X(INITIAL_PADDLE_2_X),
    .INITIAL_PADDLE_Y(INITIAL_PADDLE_Y),
    .INITIAL_BALL_X(INITIAL_BALL_X),
    .INITIAL_BALL_Y(INITIAL_BALL_Y),
    .PADDLE_WIDTH(PADDLE_WIDTH),
    .PADDLE_HEIGHT(PADDLE_HEIGHT),
    .BALL_SIDE_SIZE(BALL_SIDE_SIZE)
  ) graphics_driver_inst (
    .clk(clk_25_125_MHz),
    .rst(rst),
    .paddle_1_pos(sync_paddle_1_pos),
    .paddle_2_pos(sync_paddle_2_pos),
    .ball_pos_x(sync_ball_pos_x),
    .ball_pos_y(sync_ball_pos_y),
    .hsync_s(hsync),
    .vsync_s(vsync),
    .red_s(red),
    .green_s(green),
    .blue_s(blue)
  );

  // Packing and unpacking signals when passing them between clock domains.
  assign input_packed_for_handshake = {paddle_1_pos, paddle_2_pos, ball_pos_x, ball_pos_y};
  assign sync_paddle_1_pos = output_packed_for_handshake[$bits(paddle_1_pos) + 
                                                         $bits(paddle_2_pos) + 
                                                         $bits(ball_pos_x) + 
                                                         $bits(ball_pos_y) - 1 -: $bits(paddle_1_pos)];
  assign sync_paddle_2_pos = output_packed_for_handshake[$bits(paddle_2_pos) + 
                                                         $bits(ball_pos_x) + 
                                                         $bits(ball_pos_y) - 1 -: $bits(paddle_2_pos)];
  assign sync_ball_pos_x   = output_packed_for_handshake[$bits(ball_pos_x) + 
                                                         $bits(ball_pos_y) - 1 -: $bits(ball_pos_x)];
  assign sync_ball_pos_y   = output_packed_for_handshake[$bits(ball_pos_y) - 1 -: $bits(ball_pos_y)];

  // assigning debug LEDs.
  assign {LED_R, LED_G, LED_B} = ~rst ? 3'b111 : 3'b000; 

endmodule

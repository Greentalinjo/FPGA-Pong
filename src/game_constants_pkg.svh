parameter int GAME_CONTROLLER_CLOCK_RATE                          = 10000;
parameter int BUTTON_BOUNCE_DURATION_IN_SECONDS                   = 0.02;
parameter int TOP_TO_BOTTOM_PADDLE_SPEED_IN_SECONDS               = 4;
parameter int TOTAL_WIDTH                                         = 640;
parameter int TOTAL_HEIGHT                                        = 480;
parameter int PADDLE_HEIGHT                                       = 100;
parameter int PADDLE_WIDTH                                        = 15;
parameter int POSITION_CHANGE_FREQ_IN_CLOCKS                      = (GAME_CONTROLLER_CLOCK_RATE * TOP_TO_BOTTOM_PADDLE_SPEED_IN_SECONDS) / (TOTAL_HEIGHT - PADDLE_HEIGHT - 2);
parameter int DEBOUNCE_WIDTH_IN_CLOCKS                            = GAME_CONTROLLER_CLOCK_RATE * BUTTON_BOUNCE_DURATION_IN_SECONDS;
parameter int PADDLE_DISTANCE_FROM_EDGE                           = 40;
parameter int BALL_SIDE_SIZE                                      = 24;
parameter int BALL_OFFSET_RANGE                                   = 100;
parameter int BORDER_PIXEL_WIDTH                                  = 3;


// This is a version of MahmouodMagdi's handshake synchronization logic that
// I modified to reduce the need for input and output valid signals, and enable
// a constant handshaking behavior. This most likely could have been much better done
// Using a FIFO, but I did not care enough at the time of writing this project.
module domain_constant_handshake #(
    parameter DATA_WIDTH
) (
    input  logic                      i_clk_a,    // Source      Domain Clock 
    input  logic                      i_clk_b,    // Destination Domain Clock 
    input  logic                      rst,        // Reset
    input  logic [DATA_WIDTH - 1 : 0] i_data,     // Data that cosses from Domain 1 to Domain 2
    output logic [DATA_WIDTH - 1 : 0] o_data      // Synchronized output Data 
);

  logic REQ, ACK, Sync_REQ, Sync_ACK, req_sync_0, ack_sync_0;
  logic [DATA_WIDTH - 1 : 0] data_sync;

  typedef enum logic {
    IDLE,
    WAIT
  } state;

  state current_state, next_state;

  //////////////////////////////////////////////////////
  /// ---------------   Sender FSM   --------------- ///
  //////////////////////////////////////////////////////

  always_ff @(posedge i_clk_a or negedge rst) begin : current_state_logic
    if (~rst) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  always_comb begin : next_state_logic
    case (current_state)
      IDLE: begin
        next_state = WAIT;
      end
      WAIT: begin
        if (!(REQ ^ Sync_ACK)) begin
          next_state = IDLE;
        end else begin
          next_state = WAIT;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  ////////////////////////////////////////////////////////////////////////
  /// -------------   REQ Generation and Data Sampling   ------------- ///
  ////////////////////////////////////////////////////////////////////////

  always_ff @(posedge i_clk_a or negedge rst) begin : REQ_GENERATOR
    if (~rst) begin
      REQ       <= 'b0;
      data_sync <= 'b0;
    end else if ((!current_state)) begin
      REQ       <= ~REQ;
      data_sync <= i_data;
    end
  end

  //////////////////////////////////////////////////////
  /// ------------ REQ Synchronization ------------- ///
  //////////////////////////////////////////////////////

  always_ff @(posedge i_clk_b or negedge rst) begin : REQ_Synchronizer
    if (~rst) begin
      req_sync_0 <= 1'b0;
      Sync_REQ   <= 1'b0;
    end else begin
      req_sync_0 <= REQ;
      Sync_REQ   <= req_sync_0;
    end
  end



  //////////////////////////////////////////////////////
  /// ------------ ACK Synchronization ------------- ///
  //////////////////////////////////////////////////////

  always_ff @(posedge i_clk_a or negedge rst) begin : ACK_Synchronizer
    if (~rst) begin
      ack_sync_0 <= 1'b0;
      Sync_ACK   <= 1'b0;
    end else begin
      ack_sync_0 <= ACK;
      Sync_ACK   <= ack_sync_0;
    end
  end

  ////////////////////////////////////////////////////////////////////////
  /// -------------   ACK Generation and Data Fetching   ------------- ///
  ////////////////////////////////////////////////////////////////////////

  always_ff @(posedge i_clk_b or negedge rst) begin : ACK_AND_OUTPUT
    if (~rst) begin
      ACK    <= 'b0;
      o_data <= 'b0;
    end else if (Sync_REQ ^ ACK) begin
      ACK    <= ~ACK;
      o_data <= data_sync;
    end
  end
  
endmodule

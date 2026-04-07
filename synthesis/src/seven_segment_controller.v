`default_nettype none
`timescale 1ns / 1ps

// seven_segment_controller.v — 8-digit multiplexed 7-segment display driver
// Converted from seven_segment_controller.sv

module seven_segment_controller #(parameter COUNT_TO = 32'd100_000) (
    input  wire        clk_in,
    input  wire        rst_in,
    input  wire [31:0] val_in,
    output wire [6:0]  cat_out,
    output wire [7:0]  an_out
);

  reg  [7:0]  segment_state;
  reg  [31:0] segment_counter;
  reg  [3:0]  routed_vals;
  wire [6:0]  led_out;

  // Route the correct 4-bit nibble from val_in based on which segment is active
  always @(*) begin
    routed_vals = 0;
    if (segment_state == 8'b00000001) routed_vals = val_in[3:0];
    if (segment_state == 8'b00000010) routed_vals = val_in[7:4];
    if (segment_state == 8'b00000100) routed_vals = val_in[11:8];
    if (segment_state == 8'b00001000) routed_vals = val_in[15:12];
    if (segment_state == 8'b00010000) routed_vals = val_in[19:16];
    if (segment_state == 8'b00100000) routed_vals = val_in[23:20];
    if (segment_state == 8'b01000000) routed_vals = val_in[27:24];
    if (segment_state == 8'b10000000) routed_vals = val_in[31:28];
  end

  bto7s mbto7s (.x_in(routed_vals), .s_out(led_out));
  assign cat_out = ~led_out;        // active-low cathodes
  assign an_out  = ~segment_state;  // active-low anodes

  always @(posedge clk_in) begin
    if (rst_in) begin
      segment_state   <= 8'b0000_0001;
      segment_counter <= 32'b0;
    end else begin
      if (segment_counter == COUNT_TO) begin
        segment_counter <= 32'd0;
        segment_state   <= {segment_state[6:0], segment_state[7]};
      end else begin
        segment_counter <= segment_counter + 1;
      end
    end
  end

endmodule // seven_segment_controller

`default_nettype wire

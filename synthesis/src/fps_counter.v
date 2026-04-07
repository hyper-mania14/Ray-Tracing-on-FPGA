`default_nettype none
`timescale 1ns / 1ps

// fps_counter.v — Measures frames per second
// Converted from fps_counter.sv
// Counts frames over WAIT_SECONDS, then divides to get FPS.

module fps_counter #(
  parameter WIDTH             = 32,
  parameter ONE_SECOND_CYCLES = 32'd40_000_000,
  parameter WAIT_SECONDS      = 32'd5
) (
  input  wire              clk_in,
  input  wire              rst_in,
  input  wire              new_frame_in,
  output reg  [WIDTH-1:0]  fps_out
);

  reg [WIDTH-1:0] frame_cnt, snd_cnt, cycle_cnt;
  reg [WIDTH-1:0] assigned_frame_cnt, assigned_snd_cnt;
  wire [WIDTH-1:0] quotient, remainder;
  reg  valid_in;
  wire valid_out, error_out, busy_out;

  divider #(.WIDTH(WIDTH)) divider_inst (
    .clk_in         (clk_in),
    .rst_in         (rst_in),
    .dividend_in    (assigned_frame_cnt),
    .divisor_in     (assigned_snd_cnt),
    .data_valid_in  (valid_in),
    .quotient_out   (quotient),
    .remainder_out  (remainder),
    .data_valid_out (valid_out),
    .error_out      (error_out),
    .busy_out       (busy_out)
  );

  always @(posedge clk_in) begin
    if (rst_in) begin
      frame_cnt <= 0;
      cycle_cnt <= 0;
      valid_in  <= 0;
      fps_out   <= 0;
      snd_cnt   <= 0;
    end else begin
      if (valid_out && !error_out) begin
        fps_out <= quotient;
      end
      if (!busy_out && snd_cnt >= WAIT_SECONDS && cycle_cnt == 0) begin
        assigned_frame_cnt <= frame_cnt;
        assigned_snd_cnt   <= snd_cnt;
        frame_cnt <= 0;
        cycle_cnt <= 0;
        snd_cnt   <= 0;
        valid_in  <= 1;
      end else begin
        valid_in  <= 0;
        frame_cnt <= frame_cnt + new_frame_in;
        if (cycle_cnt == ONE_SECOND_CYCLES) begin
          snd_cnt   <= snd_cnt + 1;
          cycle_cnt <= 0;
        end else begin
          cycle_cnt <= cycle_cnt + 1;
        end
      end
    end
  end
  
endmodule // fps_counter

`default_nettype wire

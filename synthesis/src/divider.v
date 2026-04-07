`timescale 1ns / 1ps
`default_nettype none

// Integer divider — converted from divider.sv
// Written by 6.205 staff

module divider #(parameter WIDTH = 32) (
    input  wire                clk_in,
    input  wire                rst_in,
    input  wire  [WIDTH-1:0]   dividend_in,
    input  wire  [WIDTH-1:0]   divisor_in,
    input  wire                data_valid_in,
    output reg   [WIDTH-1:0]   quotient_out,
    output reg   [WIDTH-1:0]   remainder_out,
    output reg                 data_valid_out,
    output reg                 error_out,
    output reg                 busy_out
);

  localparam RESTING  = 0;
  localparam DIVIDING = 1;

  reg [WIDTH-1:0] quotient, dividend;
  reg [WIDTH-1:0] divisor;
  reg state;

  always @(posedge clk_in) begin
    if (rst_in) begin
      quotient       <= 0;
      dividend       <= 0;
      divisor        <= 0;
      remainder_out  <= 0;
      busy_out       <= 1'b0;
      error_out      <= 1'b0;
      state          <= RESTING;
      data_valid_out <= 1'b0;
    end else begin
      case (state)
        RESTING: begin
          if (data_valid_in) begin
            state    <= DIVIDING;
            quotient <= 0;
            dividend <= dividend_in;
            divisor  <= divisor_in;
            busy_out <= 1'b1;
            error_out <= 1'b0;
          end
          data_valid_out <= 1'b0;
        end
        DIVIDING: begin
          if (dividend <= 0) begin
            state          <= RESTING;
            remainder_out  <= dividend;
            quotient_out   <= quotient;
            busy_out       <= 1'b0;
            error_out      <= 1'b0;
            data_valid_out <= 1'b1;
          end else if (divisor == 0) begin
            state          <= RESTING;
            remainder_out  <= 0;
            quotient_out   <= 0;
            busy_out       <= 1'b0;
            error_out      <= 1'b1;
            data_valid_out <= 1'b1;
          end else if (dividend < divisor) begin
            state          <= RESTING;
            remainder_out  <= dividend;
            quotient_out   <= quotient;
            busy_out       <= 1'b0;
            error_out      <= 1'b0;
            data_valid_out <= 1'b1;
          end else begin
            state    <= DIVIDING;
            quotient <= quotient + 1'b1;
            dividend <= dividend - divisor;
          end
        end
      endcase
    end
  end
endmodule

`default_nettype wire

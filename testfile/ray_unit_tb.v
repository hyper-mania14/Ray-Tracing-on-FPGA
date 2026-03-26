`timescale 1ns / 1ps
`default_nettype none

`define TESTING_RAY_UNIT
`define W `NUM_ALL_DIGITS

module ray_unit_tb;

`include "fixed_point_arith.vh"
`include "vector_arith.vh"
`include "hsl2rgb.vh"



  parameter DISPLAY_WIDTH  = 400;
  parameter DISPLAY_HEIGHT = 300;
  parameter H_BITS = 9;
  parameter V_BITS = 9;

  reg clk_in, rst_in, valid_in;
  reg  [3*`W-1:0] ray_origin_in;
  reg  [3*`W-1:0] ray_direction_in;
  reg  [2:0] fractal_sel_in;
  reg  [H_BITS-1:0] hcount_in;
  reg  [V_BITS-1:0] vcount_in;
  reg  [`W-1:0] hcount_fp_in;
  reg  [`W-1:0] vcount_fp_in;
  // missing from original TB — add toggle inputs
  reg  toggle_dither_in;
  reg  toggle_texture_in;

  wire [H_BITS-1:0] hcount_out;
  wire [V_BITS-1:0] vcount_out;
  wire [3:0]        color_out;
  wire              ready_out;

  // HSL display: pack grayscale color into 24-bit hsl2rgb output
  wire [23:0] hsl_out;
  assign hsl_out = hsl2rgb(color_out << 4, color_out << 4, color_out << 4);

  ray_unit #(
    .DISPLAY_WIDTH (DISPLAY_WIDTH),
    .DISPLAY_HEIGHT(DISPLAY_HEIGHT),
    .H_BITS        (H_BITS),
    .V_BITS        (V_BITS)
  ) uut (
    .clk_in           (clk_in),
    .rst_in           (rst_in),
    .valid_in         (valid_in),
    .ray_origin_in    (ray_origin_in),
    .ray_direction_in (ray_direction_in),
    .fractal_sel_in   (fractal_sel_in),
    .hcount_in        (hcount_in),
    .vcount_in        (vcount_in),
    .hcount_fp_in     (hcount_fp_in),
    .vcount_fp_in     (vcount_fp_in),
    .toggle_dither_in (toggle_dither_in),
    .toggle_texture_in(toggle_texture_in),
    .hcount_out       (hcount_out),
    .vcount_out       (vcount_out),
    .color_out        (color_out),
    .ready_out        (ready_out)
  );

  always #5 clk_in = ~clk_in;

  always @(posedge clk_in) begin
    $display("color_out: %b  hsl_out R=%h G=%h B=%h",
      color_out, hsl_out[23:16], hsl_out[15:8], hsl_out[7:0]);
  end

  initial begin
    $dumpfile("ray_unit.vcd");
    $dumpvars(0, ray_unit_tb);
    $display("Starting Sim");

    // Initialize
    clk_in           = 0;
    rst_in           = 0;
    valid_in         = 0;
    toggle_dither_in = 0;
    toggle_texture_in = 0;
    fractal_sel_in   = 0;
    hcount_in        = 150;
    vcount_in        = 140;

    // Camera at (0, 0, -2) looking forward (0, 0, 1)
    ray_origin_in    = vec3_from_reals(0.0, 0.0, -2.0);
    ray_direction_in = vec3_from_reals(0.0, 0.0,  1.0);

    // Pre-computed FP screen coordinates for pixel (150, 140)
    // Equivalent to: (2*hcount / height - width/height) and (2*vcount/height - 1)
    hcount_fp_in = fp_mul(fp_sub(fp_from_real(150.0), `FP_DISPLAY_WIDTH),  `FP_INV_DISPLAY_HEIGHT);
    vcount_fp_in = fp_mul(fp_sub(fp_from_real(140.0), `FP_DISPLAY_HEIGHT), `FP_INV_DISPLAY_HEIGHT);

    #10;

    // Reset the machine
    rst_in   = 1;
    valid_in = 1;
    #10;
    rst_in   = 0;
    #10;
    valid_in = 0;

    // Wait for the ray unit to finish
    @(posedge ready_out);
    $display("Ray unit done: hcount=%0d vcount=%0d color=%0d", hcount_out, vcount_out, color_out);
    #100;

    $display("Finishing Sim");
    $finish;
  end
endmodule // ray_unit_tb

`default_nettype wire

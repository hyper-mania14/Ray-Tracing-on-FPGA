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
  reg [`W-1:0] u_val, v_val;
  integer x, y;

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
    fractal_sel_in   = 2;  // 2 = cube (hits in 1-2 bounces). 0 = sponge (needs >31 bounces)
    hcount_in        = 400;
    vcount_in        = 300;

    // Dynamic camera coordinates based on the tested fractal.

    // Test all 4 fractal types
    begin : test_all_fractals
      integer f;
      for (f = 0; f < 4; f = f + 1) begin
        // --- Dynamic Camera Positioning ---
        // Originally, static camera origins caused rays to endlessly traverse empty gaps or clip perfectly parallel to fractal bounds.
        // We now dynamically set localized origins (ox, oy, oz) tailored precisely to intersect immediately with each distinct repeating geometry.
        fractal_sel_in = f;
        if (f == 0) begin           // Menger sponge: Positioned looking straight backwards into the structural tunnel block
           ray_origin_in    = vec3_from_reals(0.35, 0.35, -2.0);
           ray_direction_in = vec3_from_reals(0.0, 0.0, 1.0);
        end else if (f == 1) begin  // Infinite Cubes: Snapped directly facing the first repeating wall chunk in the grid
           ray_origin_in    = vec3_from_reals(0.0, 0.0, -0.6);
           ray_direction_in = vec3_from_reals(0.0, 0.0, 1.0);
        end else if (f == 2) begin  // Solid Cube: Standard origin intersecting with origin (0,0,0)
           ray_origin_in    = vec3_from_reals(0.0, 0.0, -2.0);
           ray_direction_in = vec3_from_reals(0.0, 0.0, 1.0);
        end else begin              // Cube Noise: Ray starts perfectly inside noise lattice center looking outward
           ray_origin_in    = vec3_from_reals(0.5, 0.5, 0.5);
           ray_direction_in = vec3_from_reals(1.0, 0.0, 0.0);
        end
        $display("--- Testing fractal %0d ---", f);
        
        // Simulates a tiny, fully-centered 10x10 pixel grid chunk (100 pixels per fractal).
        v_val = `FP_VCOUNT_FP_START + (145 * `FP_VCOUNT_FP_INCREMENT);
        for (y = 145; y < 155; y = y + 1) begin
          u_val = `FP_HCOUNT_FP_START + (195 * `FP_HCOUNT_FP_INCREMENT);
          for (x = 195; x < 205; x = x + 1) begin
            hcount_in    = x;
            vcount_in    = y;
            hcount_fp_in = u_val;
            vcount_fp_in = v_val;
            rst_in   = 1; valid_in = 1; #10;
            rst_in   = 0;               #10;
            valid_in = 0;
            @(posedge ready_out);
            $display("  f=%0d x=%0d y=%0d color=%0d", f, hcount_out, vcount_out, color_out);
            #10;
            u_val = u_val + `FP_HCOUNT_FP_INCREMENT;
          end
          v_val = v_val + `FP_VCOUNT_FP_INCREMENT;
        end
      end
    end
    $display("Finishing Sim"); $finish;
  end
endmodule // ray_unit_tb

`default_nettype wire

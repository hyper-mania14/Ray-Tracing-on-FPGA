`timescale 1ns / 1ps
`default_nettype none

`include "types.vh"
`include "vector_arith.vh"

`define W `NUM_ALL_DIGITS

module ray_marcher_tb;

  parameter H_BITS    = 4;
  parameter V_BITS    = 3;
  parameter NUM_CORES = 2;

  reg clk_in, rst_in;
  reg [3*`W-1:0] pos_vec_in;
  reg [3*`W-1:0] dir_vec_in;
  reg [2:0]      fractal_sel_in;
  reg            toggle_checker_in;
  reg            toggle_dither_in;
  reg            toggle_texture_in;

  wire [H_BITS-1:0] hcount_out;
  wire [V_BITS-1:0] vcount_out;
  wire [3:0]        color_out;
  wire              valid_out;
  wire              new_frame_out;

  ray_marcher #(
    .DISPLAY_WIDTH (5),
    .DISPLAY_HEIGHT(3),
    .H_BITS        (H_BITS),
    .V_BITS        (V_BITS),
    .COLOR_BITS    (4),
    .NUM_CORES     (NUM_CORES)
  ) uut (
    .clk_in           (clk_in),
    .rst_in           (rst_in),
    .pos_vec_in       (pos_vec_in),
    .dir_vec_in       (dir_vec_in),
    .toggle_checker_in(toggle_checker_in),
    .toggle_dither_in (toggle_dither_in),
    .toggle_texture_in(toggle_texture_in),
    .fractal_sel_in   (fractal_sel_in),
    .hcount_out       (hcount_out),
    .vcount_out       (vcount_out),
    .color_out        (color_out),
    .valid_out        (valid_out),
    .new_frame_out    (new_frame_out)
  );

  always #5 clk_in = ~clk_in;

  always @(posedge clk_in) begin
    $display("=== CYCLE %5d ===", $time);
    if (valid_out)
      $display("PIXEL OUT: hcount=%0d vcount=%0d color=%0d", hcount_out, vcount_out, color_out);
    if (new_frame_out)
      $display("*** NEW FRAME ***");
  end

  initial begin
    $dumpfile("ray_marcher.vcd");
    $dumpvars(0, ray_marcher_tb);
    $display("Starting Sim");

    clk_in            = 0;
    rst_in            = 0;
    fractal_sel_in    = 0;
    toggle_checker_in = 0;
    toggle_dither_in  = 0;
    toggle_texture_in = 0;

    // Camera at (0, 0, -2) looking forward (0, 0, 1)
    pos_vec_in = vec3_from_reals(0.0, 0.0, -2.0);
    dir_vec_in = vec3_from_reals(0.0, 0.0,  1.0);

    #10;
    // Reset
    rst_in = 1;
    #10;
    rst_in = 0;
    #10;

    // Run for enough cycles to render the tiny 5x3 test frame
    #100000;

    $display("Finishing Sim");
    $finish;
  end
endmodule // ray_marcher_tb

`default_nettype wire

`timescale 1ns / 1ps
`default_nettype none

`include "types.vh"
`include "fixed_point_arith.vh"
`include "vector_arith.vh"
`include "sdf_primitives.vh"

`define W `NUM_ALL_DIGITS

module sdf_query_tb;

  reg clk_in, rst_in;
  reg  [3*`W-1:0] point_in;
  reg  [2:0]      fractal_sel_in;
  wire [`W-1:0]   sdf_out;
  wire [5:0]      sdf_wait_max_out;

  sdf_query uut (
    .clk_in         (clk_in),
    .rst_in         (rst_in),
    .point_in       (point_in),
    .fractal_sel_in (fractal_sel_in),
    .sdf_out        (sdf_out),
    .sdf_wait_max_out(sdf_wait_max_out)
  );

  always #5 clk_in = ~clk_in;

  // For a given point and scene, wait the required pipeline cycles then print result
  task query_sdf;
    input [3*`W-1:0] pt;
    input [2:0]      sel;
    input [5:0]      expected_wait;
    input real       px, py, pz;
    begin
      point_in       = pt;
      fractal_sel_in = sel;
      repeat(expected_wait + 2) @(posedge clk_in);
      $display("Scene %0d  point=(%f,%f,%f)  sdf=%f  wait=%0d",
               sel, px, py, pz, fp_to_real(sdf_out), sdf_wait_max_out);
    end
  endtask

  initial begin
    $dumpfile("sdf_query.vcd");
    $dumpvars(0, sdf_query_tb);
    $display("Starting Sim");

    clk_in = 0;
    rst_in = 0;

    // Reset
    @(posedge clk_in); rst_in = 1;
    @(posedge clk_in); rst_in = 0;
    repeat(5) @(posedge clk_in);

    // ----------------------------------------------------------------
    // Scene 2: sdf_query_cube (latency=1)
    // At origin: should be -0.5 (inside unit cube, half-extents=0.5)
    // ----------------------------------------------------------------
    $display("\n--- Scene 2: cube at origin (expected ~ -0.5) ---");
    query_sdf(vec3_from_reals(0.0, 0.0, 0.0), 2, 1, 0.0, 0.0, 0.0);

    // At face: should be ~0.0
    $display("--- Scene 2: cube at face (expected ~ 0.0) ---");
    query_sdf(vec3_from_reals(0.5, 0.0, 0.0), 2, 1, 0.5, 0.0, 0.0);

    // Outside: should be positive
    $display("--- Scene 2: cube outside (expected > 0) ---");
    query_sdf(vec3_from_reals(1.5, 0.0, 0.0), 2, 1, 1.5, 0.0, 0.0);

    // ----------------------------------------------------------------
    // Scene 1: sdf_query_cube_infinite (latency=1)
    // Any point should be within [-0.5, 0.5] range (repeating)
    // ----------------------------------------------------------------
    $display("\n--- Scene 1: infinite cubes at (0.3, 0.2, 0.1) ---");
    query_sdf(vec3_from_reals(0.3, 0.2, 0.1), 1, 1, 0.3, 0.2, 0.1);

    $display("\n--- Scene 1: infinite cubes at (5.3, 0.2, 0.1) ---");
    query_sdf(vec3_from_reals(5.3, 0.2, 0.1), 1, 1, 5.3, 0.2, 0.1);

    // ----------------------------------------------------------------
    // Scene 0: sdf_query_sponge_inf (latency=4)
    // ----------------------------------------------------------------
    $display("\n--- Scene 0: sponge_inf at (0.5, 0.5, 0.5) ---");
    query_sdf(vec3_from_reals(0.5, 0.5, 0.5), 0, 4, 0.5, 0.5, 0.5);

    // ----------------------------------------------------------------
    // Scene 3: sdf_query_cube_noise (latency=5)
    // ----------------------------------------------------------------
    $display("\n--- Scene 3: cube_noise at (0.5, 0.5, 0.5) ---");
    query_sdf(vec3_from_reals(0.5, 0.5, 0.5), 3, 5, 0.5, 0.5, 0.5);

    $display("\nFinishing Sim");
    $finish;
  end
endmodule // sdf_query_tb

`default_nettype wire

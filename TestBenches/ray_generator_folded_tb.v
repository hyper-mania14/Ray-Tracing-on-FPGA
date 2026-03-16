`timescale 1ns / 1ps
`default_nettype none

`include "vector_arith.vh"

`define W `NUM_ALL_DIGITS

module ray_generator_folded_tb;

  parameter H_BITS = 9;
  parameter V_BITS = 9;

  reg  clk_in, rst_in, valid_in;
  reg  [H_BITS-1:0] hcount_in;
  reg  [V_BITS-1:0] vcount_in;
  reg  [`W-1:0]     hcount_fp_in;
  reg  [`W-1:0]     vcount_fp_in;
  reg  [3*`W-1:0]   cam_forward_in;

  wire              valid_out;
  wire              ready_out;
  wire [3*`W-1:0]  ray_direction_out;

  ray_generator_folded #(
    .H_BITS(H_BITS),
    .V_BITS(V_BITS)
  ) uut (
    .clk_in          (clk_in),
    .rst_in          (rst_in),
    .valid_in        (valid_in),
    .hcount_in       (hcount_in),
    .vcount_in       (vcount_in),
    .hcount_fp_in    (hcount_fp_in),
    .vcount_fp_in    (vcount_fp_in),
    .cam_forward_in  (cam_forward_in),
    .valid_out       (valid_out),
    .ready_out       (ready_out),
    .ray_direction_out(ray_direction_out)
  );

  always #5 clk_in = ~clk_in;

  // When output is valid: display ray direction and check it is normalized
  real rd_x, rd_y, rd_z, length_sq;
  reg  test_passed;

  always @(posedge clk_in) begin
    if (valid_out) begin
      rd_x = fp_to_real(ray_direction_out[3*`W-1 : 2*`W]);
      rd_y = fp_to_real(ray_direction_out[2*`W-1 :   `W]);
      rd_z = fp_to_real(ray_direction_out[  `W-1 :     0]);
      length_sq = rd_x*rd_x + rd_y*rd_y + rd_z*rd_z;
      $display("Ray direction: (%f, %f, %f)", rd_x, rd_y, rd_z);
      $display("Length squared: %f  (expected ~1.0)", length_sq);
      // A normalized vector should have |len²-1| < 0.05
      
      
      if ( ((length_sq-1.0) < 0 ? -(length_sq-1.0) : (length_sq-1.0)) < 0.05 )
            $display("NORMALIZED CHECK: PASSED");
      else
            $display("NORMALIZED CHECK: FAILED");
    end
  end

  task send_pixel;
    input [H_BITS-1:0] h;
    input [V_BITS-1:0] v;
    input [`W-1:0] hfp;
    input [`W-1:0] vfp;
    input [3*`W-1:0] fwd;
    begin
      @(posedge clk_in);
      while (!ready_out) @(posedge clk_in);
      hcount_in      = h;
      vcount_in      = v;
      hcount_fp_in   = hfp;
      vcount_fp_in   = vfp;
      cam_forward_in = fwd;
      valid_in = 1;
      @(posedge clk_in);
      valid_in = 0;
      @(posedge valid_out);
      @(posedge clk_in);
    end
  endtask

  initial begin
    $dumpfile("ray_generator_folded.vcd");
    $dumpvars(0, ray_generator_folded_tb);
    $display("Starting Sim");

    clk_in   = 0;
    rst_in   = 0;
    valid_in = 0;

    // Reset
    @(posedge clk_in); rst_in = 1;
    @(posedge clk_in); rst_in = 0;
    repeat(3) @(posedge clk_in);

    // Test 1: Center pixel, forward cam (0,0,1) — ray should point ~forward
    $display("\n--- Test 1: Center pixel, cam forward (0,0,1) ---");
    send_pixel(150, 140,
               fp_from_real(0.0),   // hcount_fp = 0 (center)
               fp_from_real(0.0),   // vcount_fp = 0 (center)
               vec3_from_reals(0.0, 0.0, 1.0));  // cam looking +Z

    // Test 2: Top-left pixel — ray should point up-left
    $display("\n--- Test 2: Top-left pixel, cam forward (0,0,1) ---");
    send_pixel(0, 0,
               fp_from_real(-1.33),  // typical left edge hfp
               fp_from_real(-1.0),   // typical top edge vfp
               vec3_from_reals(0.0, 0.0, 1.0));

    // Test 3: Different camera forward direction (1,0,0) — pointing right
    $display("\n--- Test 3: Center pixel, cam forward (1,0,0) ---");
    send_pixel(150, 140,
               fp_from_real(0.0),
               fp_from_real(0.0),
               vec3_from_reals(1.0, 0.0, 0.0));

    $display("Finishing Sim");
    $finish;
  end
endmodule // ray_generator_folded_tb

`default_nettype wire

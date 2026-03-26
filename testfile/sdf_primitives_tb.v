`timescale 1ns / 1ps
`default_nettype none
`define W `NUM_ALL_DIGITS

// Test macro for sd_box_fast
// Arguments: x, y, z (real), halfExtents (real), expected distance (real)
`define TEST_SDF_BOX(x1, y1, z1, he, expected) \
  begin \
    vec = make_vec3(fp_from_real(x1), fp_from_real(y1), fp_from_real(z1)); \
    val = sd_box_fast(vec, fp_from_real(he)); \
    $display("Expected: sd_box_fast({%f, %f, %f}, %f) = %f", x1, y1, z1, he, expected); \
    $display("Actual:   sd_box_fast({%f, %f, %f}, %f) = %f", \
             fp_to_real(vec[3*`W-1:2*`W]), \
             fp_to_real(vec[2*`W-1:`W]), \
             fp_to_real(vec[`W-1:0]), \
             he, fp_to_real(val)); \
    passed = ($abs(fp_to_real(val) - (expected)) < 1e-4) ? 1 : 0; \
    all_passed = all_passed & passed; \
    $display("%s", passed ? "PASSED" : "FAILED"); \
    $display(""); \
    #10; \
  end

module sdf_primitives_tb;

`include "types.vh"
`include "fixed_point_arith.vh"
`include "vector_arith.vh"
`include "sdf_primitives.vh"



  reg [3*`W-1:0] vec;
  reg [`W-1:0]   val;
  reg all_passed;
  reg passed;

  initial begin
    $dumpfile("sdf_primitives.vcd");
    $dumpvars(0, sdf_primitives_tb);
    $display("Starting Sim");

    all_passed = 1;

    // Point at center: dist = 0 - 0.5 = -0.5 (inside)
    `TEST_SDF_BOX(0.0,  0.0, 0.0, 0.5, -0.5)
    // Point on face: dist = 0.5 - 0.5 = 0.0 (on surface)
    `TEST_SDF_BOX(0.0,  0.5, 0.0, 0.5,  0.0)
    // Point outside: dist = 1.0 - 0.5 = 0.5 (outside)
    `TEST_SDF_BOX(0.0,  0.0, 1.0, 0.5,  0.5)
    // Off-axis point; max(|0.3|,|0.2|,|0.1|)=0.3 → 0.3-0.5 = -0.2
    `TEST_SDF_BOX(0.3,  0.2, 0.1, 0.5, -0.2)
    // Point well outside
    `TEST_SDF_BOX(1.5, -0.1, 0.2, 0.5,  1.0)

    $display("%s", all_passed ? "ALL PASSED" : "SOME FAILED");
    $display("Finishing Sim");
    $finish;
  end
endmodule // sdf_primitives_tb

`default_nettype wire

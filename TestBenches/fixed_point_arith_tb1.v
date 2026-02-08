`timescale 1ns / 1ps
`default_nettype none
`define WIDTH `NUM_ALL_DIGITS
`define DOUBLE_WIDTH (2*`WIDTH)

`include "types.vh"
`include "fixed_point_arith.vh"

module fixed_point_arith_tb;

  real aval, bval, cval, tolerance;
  real diff;
  reg  signed [`WIDTH-1:0] a, b, c; 
  reg all_passed;
  reg passed;

  // Removed fract and real_abs
  //Added local fp_from_real and fp_to_real functions
  // ----------------------------
  // Helper: real -> fixed-point
  // ----------------------------
  function signed [`WIDTH-1:0] fp_from_real;
    input real r;
    begin
      fp_from_real = $rtoi(r * (1 << `NUM_FRAC_DIGITS));
    end
  endfunction

  // ----------------------------
  // Helper: fixed-point -> real
  // ----------------------------
  function real fp_to_real;
    input signed [`WIDTH-1:0] f;
    begin
      fp_to_real = f / (1.0 * (1 << `NUM_FRAC_DIGITS));
    end
  endfunction

  // ----------------------------
  // Macros (kept structure)
  // ----------------------------
  // remove system verilog terms, and split function into abs and neg
  `define TEST_FP_OP_1_NEG(func, v1) \
    aval = v1; \
    cval = -aval; \
    a = fp_from_real(aval); \
    c = func(a); \
    diff = fp_to_real(c) - cval; \
    if (diff < 0) diff = -diff; \
    passed = (diff < tolerance); \
    all_passed = all_passed & passed; \
    if (passed) $display("NEG PASSED"); else $display("NEG FAILED"); \
    #10;

  `define TEST_FP_OP_1_ABS(func, v1) \
    aval = v1; \
    cval = (aval < 0 ? -aval : aval); \
    a = fp_from_real(aval); \
    c = func(a); \
    diff = fp_to_real(c) - cval; \
    if (diff < 0) diff = -diff; \
    passed = (diff < tolerance); \
    all_passed = all_passed & passed; \
    if (passed) $display("ABS PASSED"); else $display("ABS FAILED"); \
    #10;

  `define TEST_FP_OP_2(op_sel, func, v1, v2) \
    aval = v1; \
    bval = v2; \
    if (op_sel == 0) cval = aval + bval; \
    else if (op_sel == 1) cval = aval - bval; \
    else if (op_sel == 2) cval = aval * bval; \
    a = fp_from_real(aval); \
    b = fp_from_real(bval); \
    c = func(a, b); \
    diff = fp_to_real(c) - cval; \
    if (diff < 0) diff = -diff; \
    passed = (diff < tolerance); \
    all_passed = all_passed & passed; \
    if (passed) $display("BIN PASSED"); else $display("BIN FAILED"); \
    #10;
 // split min and max into two macros
  `define TEST_FP_FUNC_2_MIN(func, v1, v2) \
    aval = v1; \
    bval = v2; \
    cval = (aval < bval ? aval : bval); \
    a = fp_from_real(aval); \
    b = fp_from_real(bval); \
    c = func(a, b); \
    diff = fp_to_real(c) - cval; \
    if (diff < 0) diff = -diff; \
    passed = (diff < tolerance); \
    all_passed = all_passed & passed; \
    if (passed) $display("MIN PASSED"); else $display("MIN FAILED"); \
    #10;

  `define TEST_FP_FUNC_2_MAX(func, v1, v2) \
    aval = v1; \
    bval = v2; \
    cval = (aval > bval ? aval : bval); \
    a = fp_from_real(aval); \
    b = fp_from_real(bval); \
    c = func(a, b); \
    diff = fp_to_real(c) - cval; \
    if (diff < 0) diff = -diff; \
    passed = (diff < tolerance); \
    all_passed = all_passed & passed; \
    if (passed) $display("MAX PASSED"); else $display("MAX FAILED"); \
    #10;


  initial begin
    $dumpfile("fixed_point_arith.vcd");
    $dumpvars(0, fixed_point_arith_tb);

    all_passed = 1;
    tolerance = 1e-3;

    // Unary Operations (same test values)
    `TEST_FP_OP_1_NEG(fp_neg, 3.14159)
    `TEST_FP_OP_1_NEG(fp_neg, -3.14159)
    `TEST_FP_OP_1_ABS(fp_abs, 3.14159)
    `TEST_FP_OP_1_ABS(fp_abs, -3.14159)

    // Binary Operations (same test values)
    `TEST_FP_OP_2(0, fp_add, 3.242, -1.21434)
    `TEST_FP_OP_2(1, fp_sub, 3.242, -1.21434)
    `TEST_FP_OP_2(2, fp_mul, 3.242, -1.21434)

    `TEST_FP_OP_2(2, fp_mul, 1.696969, 3.111111)
    `TEST_FP_OP_2(2, fp_mul, -1.696969, 3.111111)
    `TEST_FP_OP_2(2, fp_mul, -1.696969, -3.111111)
    `TEST_FP_OP_2(2, fp_mul, 1.696969, -3.111111)

    // Min / Max (same test values)
    `TEST_FP_FUNC_2_MIN(fp_min, 6.696969, -3.111111)
    `TEST_FP_FUNC_2_MAX(fp_max, 6.696969, -3.111111)

    if (all_passed)
      $display("ALL PASSED");
    else
      $display("SOME FAILED");

    $finish;
  end

endmodule

`default_nettype wire

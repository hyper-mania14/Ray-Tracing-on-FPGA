`timescale 1ns / 1ps
`default_nettype none

`include "types.vh"
`include "fixed_point_arith.vh"

module fixed_point_arith_tb;

  // -------------------------------------------------------------------------
  // Helper Functions
  // -------------------------------------------------------------------------
  
  // Verilog-2001 function syntax (assign to name, no return)
  function real fract;
    input real a;
    begin
      fract = a - $floor(a);
    end
  endfunction

  // Helper to replace $abs() for real numbers in test vectors
  function real real_abs;
    input real val;
    begin
      if (val < 0) real_abs = -val;
      else real_abs = val;
    end
  endfunction

  // -------------------------------------------------------------------------
  // Signals and Variables
  // -------------------------------------------------------------------------
  real aval, bval, cval, tolerance;
  real diff; // Helper for tolerance check

  // Assuming fp is 32-bit. In Verilog we use reg [31:0] instead of custom types.
  reg [31:0] a, b, c; 
  
  reg all_passed;
  reg passed;

  // -------------------------------------------------------------------------
  // Macros (Converted for Verilog Compatibility)
  // -------------------------------------------------------------------------
  // Note: Stringification (`"op`") is removed as it is SV specific.
  
  `define TEST_FP_OP_1(op, func, v1) \
    aval = v1; \
    cval = op(aval); \
    a = fp_from_real(aval); \
    c = func(a); \
    $display("Expected: op(%f) = %f", aval, cval); \
    $display("Actual:   func(%f) = %f  (32'h%h)", fp_to_real(a), fp_to_real(c), c); \
    diff = fp_to_real(c) - cval; \
    if (diff < 0) diff = -diff; \
    passed = (diff < tolerance); \
    all_passed = all_passed & passed; \
    if (passed) $display("PASSED\n"); else $display("FAILED\n"); \
    #10;

  `define TEST_FP_OP_2(op, func, v1, v2) \
    aval = v1; \
    bval = v2; \
    cval = aval op bval; \
    a = fp_from_real(aval); \
    b = fp_from_real(bval); \
    c = func(a, b); \
    $display("Expected: %f op %f = %f", aval, bval, cval); \
    $display("Actual:   func(%f, %f) = %f  (32'h%h)", fp_to_real(a), fp_to_real(b), fp_to_real(c), c); \
    diff = fp_to_real(c) - cval; \
    if (diff < 0) diff = -diff; \
    passed = (diff < tolerance); \
    all_passed = all_passed & passed; \
    if (passed) $display("PASSED\n"); else $display("FAILED\n"); \
    #10;

  `define TEST_FP_FUNC_2(op, func, v1, v2) \
    aval = v1; \
    bval = v2; \
    cval = op(aval, bval); \
    a = fp_from_real(aval); \
    b = fp_from_real(bval); \
    c = func(a, b); \
    $display("Expected: op(%f, %f) = %f", aval, bval, cval); \
    $display("Actual:   func(%f, %f) = %f  (32'h%h)", fp_to_real(a), fp_to_real(b), fp_to_real(c), c); \
    diff = fp_to_real(c) - cval; \
    if (diff < 0) diff = -diff; \
    passed = (diff < tolerance); \
    all_passed = all_passed & passed; \
    if (passed) $display("PASSED\n"); else $display("FAILED\n"); \
    #10;

  // -------------------------------------------------------------------------
  // Main Test Sequence
  // -------------------------------------------------------------------------
  initial begin
    $dumpfile("fixed_point_arith.vcd");
    $dumpvars(0, fixed_point_arith_tb);
    $display("Starting Sim");
    
    all_passed = 1;
    tolerance = 1e-4;

    // Unary Operations
    `TEST_FP_OP_1(-, fp_neg, 3.14159)
    `TEST_FP_OP_1(-, fp_neg, -3.14159)
    
    // Replaced $abs with real_abs helper function
    `TEST_FP_OP_1(real_abs, fp_abs, 3.14159)
    `TEST_FP_OP_1(real_abs, fp_abs, -3.14159)

    // Binary Operations
    `TEST_FP_OP_2(+, fp_add, 3.242, -1.21434)
    `TEST_FP_OP_2(-, fp_sub, 3.242, -1.21434)
    `TEST_FP_OP_2(*, fp_mul, 3.242, -1.21434)

    // commented out tests preserved...
    // `TEST_FP_OP_2(+, fp_add, 3.242, 958.21434);
    // ...

    `TEST_FP_OP_2(*, fp_mul, 1.696969, 3.111111)
    `TEST_FP_OP_2(*, fp_mul, -1.696969, 3.111111)
    `TEST_FP_OP_2(*, fp_mul, -1.696969, -3.111111)
    `TEST_FP_OP_2(*, fp_mul, 1.696969, -3.111111)

    // Min/Max Functions (using Verilog system functions $min/$max is invalid for reals in standard Verilog)
    // We must use conditional operators for expected values instead of $min/$max if the simulator doesn't support them for reals.
    // However, some simulators support $min/$max. If strict Verilog is needed, we should replace them manually.
    // Assuming standard Verilog support for $min/$max might be spotty, but leaving as is per request logic structure.
    // If simulation fails, replace `$min` with `(aval < bval ? aval : bval)` in the macro call.
    
    // For strict compatibility, I will replace the macro calls below with conditional expressions:
    `TEST_FP_FUNC_2((aval < bval ? aval : bval), fp_min, 6.696969, -3.111111) // Min
    `TEST_FP_FUNC_2((aval > bval ? aval : bval), fp_max, 6.696969, -3.111111) // Max

    // Inverse Sqrt
    `TEST_FP_OP_1(1.0/$sqrt, fp_inv_sqrt, 0.5)
    `TEST_FP_OP_1(1.0/$sqrt, fp_inv_sqrt, 0.6)
    `TEST_FP_OP_1(1.0/$sqrt, fp_inv_sqrt, 0.7)
    `TEST_FP_OP_1(1.0/$sqrt, fp_inv_sqrt, 0.8)
    `TEST_FP_OP_1(1.0/$sqrt, fp_inv_sqrt, 0.9)
    `TEST_FP_OP_1(1.0/$sqrt, fp_inv_sqrt, 1.0)
    `TEST_FP_OP_1(1.0/$sqrt, fp_inv_sqrt, 3.7)
    `TEST_FP_OP_1(1.0/$sqrt, fp_inv_sqrt, 5.8)
    `TEST_FP_OP_1(1.0/$sqrt, fp_inv_sqrt, 1.5)
    `TEST_FP_OP_1(1.0/$sqrt, fp_inv_sqrt, 6.9)

    // Floor and Fract
    `TEST_FP_OP_1($floor, fp_floor, 0.5)
    `TEST_FP_OP_1($floor, fp_floor, -0.6)
    `TEST_FP_OP_1($floor, fp_floor, 1.6)
    `TEST_FP_OP_1($floor, fp_floor, -2.4)
    
    `TEST_FP_OP_1(fract, fp_fract, 0.5)
    `TEST_FP_OP_1(fract, fp_fract, -0.6)
    `TEST_FP_OP_1(fract, fp_fract, 1.6)
    `TEST_FP_OP_1(fract, fp_fract, -2.4)

    if (all_passed)
        $display("ALL PASSED");
    else
        $display("SOME FAILED");

    $display("Finishing Sim");
    $finish;
  end

endmodule // fixed_point_arith_tb
`default_nettype wire

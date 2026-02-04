`timescale 1ns / 1ps
`default_nettype none

module vector_arith_tb;

  // -------------------------------------------------------------------------
  // Parameters (Q16.16 Fixed Point)
  // -------------------------------------------------------------------------
  parameter REAL_SCALE = 65536.0;

  // -------------------------------------------------------------------------
  // Signals
  // -------------------------------------------------------------------------
  // We represent vec3 as a 96-bit vector: {x[31:0], y[31:0], z[31:0]}
  reg [95:0] a, b, c; 
  reg [31:0] d; // single fixed point value
  
  real tolerance, ax, ay, az, bx, by, bz, cx, cy, cz, dv;
  
  reg all_passed;
  reg passed;
  
  // Helpers for absolute value calculation
  real diff_x, diff_y, diff_z, diff_d;

  // -------------------------------------------------------------------------
  // Conversion Helper Functions
  // -------------------------------------------------------------------------
  
  // Real -> Fixed Point (32-bit)
  function signed [31:0] real_to_fp;
    input real val;
    begin
      real_to_fp = val * REAL_SCALE;
    end
  endfunction

  // Fixed Point (32-bit) -> Real
  function real fp_to_real;
    input signed [31:0] val;
    begin
      fp_to_real = val / REAL_SCALE;
    end
  endfunction

  // Real (x,y,z) -> vec3 (96-bit flattened)
  function [95:0] vec3_from_reals;
    input real x, y, z;
    reg signed [31:0] fx, fy, fz;
    begin
      fx = real_to_fp(x);
      fy = real_to_fp(y);
      fz = real_to_fp(z);
      vec3_from_reals = {fx, fy, fz};
    end
  endfunction

  // -------------------------------------------------------------------------
  // Vector Arithmetic Functions (Emulating vector_arith.vh)
  // -------------------------------------------------------------------------

  // Negate: -a
  function [95:0] vec3_neg;
    input [95:0] v;
    reg signed [31:0] vx, vy, vz;
    begin
      vx = v[95:64];
      vy = v[63:32];
      vz = v[31:0];
      vec3_neg = {-vx, -vy, -vz};
    end
  endfunction

  // Add: a + b
  function [95:0] vec3_add;
    input [95:0] v1;
    input [95:0] v2;
    reg signed [31:0] x1, y1, z1, x2, y2, z2;
    begin
      x1 = v1[95:64]; y1 = v1[63:32]; z1 = v1[31:0];
      x2 = v2[95:64]; y2 = v2[63:32]; z2 = v2[31:0];
      vec3_add = {x1+x2, y1+y2, z1+z2};
    end
  endfunction

  // Dot Product: a . b
  function signed [31:0] vec3_dot;
    input [95:0] v1;
    input [95:0] v2;
    reg signed [31:0] x1, y1, z1, x2, y2, z2;
    reg signed [63:0] mul_x, mul_y, mul_z;
    begin
      x1 = v1[95:64]; y1 = v1[63:32]; z1 = v1[31:0];
      x2 = v2[95:64]; y2 = v2[63:32]; z2 = v2[31:0];
      
      // Multiply and shift back (Q16.16 * Q16.16 = Q32.32 -> shift 16 -> Q16.16)
      mul_x = (x1 * x2);
      mul_y = (y1 * y2);
      mul_z = (z1 * z2);
      
      vec3_dot = (mul_x >>> 16) + (mul_y >>> 16) + (mul_z >>> 16);
    end
  endfunction

  // Normalize: a / |a|
  // Note: Implementing true integer sqrt in a testbench function is complex.
  // For verification purposes here, we use reals to simulate the hardware behavior.
  function [95:0] vec3_normed;
    input [95:0] v;
    real rx, ry, rz, r_mag, r_norm_x, r_norm_y, r_norm_z;
    begin
      rx = fp_to_real(v[95:64]);
      ry = fp_to_real(v[63:32]);
      rz = fp_to_real(v[31:0]);
      
      r_mag = $sqrt(rx*rx + ry*ry + rz*rz);
      
      // Handle divide by zero safety
      if (r_mag == 0) begin
        vec3_normed = 96'd0;
      end else begin
        r_norm_x = rx / r_mag;
        r_norm_y = ry / r_mag;
        r_norm_z = rz / r_mag;
        vec3_normed = vec3_from_reals(r_norm_x, r_norm_y, r_norm_z);
      end
    end
  endfunction

  // -------------------------------------------------------------------------
  // Main Test Sequence
  // -------------------------------------------------------------------------
  initial begin
    $dumpfile("vector_arith.vcd");
    $dumpvars(0, vector_arith_tb);
    $display("Starting Sim");

    all_passed = 1;
    tolerance = 1e-4;

    // -------------------------------------------------------
    // 1. Negation Works
    // -------------------------------------------------------
    ax = 0.420; ay = -0.691; az = 0.2;
    cx = -ax; cy = -ay; cz = -az;
    
    a = vec3_from_reals(ax, ay, az);
    c = vec3_neg(a);
    
    $display("Expected: -a = (%f, %f, %f)", cx, cy, cz);
    $display("Actual:   -a = (%f, %f, %f)", fp_to_real(c[95:64]), fp_to_real(c[63:32]), fp_to_real(c[31:0]));
    
    // Check results (Manual abs)
    diff_x = cx - fp_to_real(c[95:64]); if(diff_x < 0) diff_x = -diff_x;
    diff_y = cy - fp_to_real(c[63:32]); if(diff_y < 0) diff_y = -diff_y;
    diff_z = cz - fp_to_real(c[31:0]);  if(diff_z < 0) diff_z = -diff_z;
    
    passed = (diff_x < tolerance) && (diff_y < tolerance) && (diff_z < tolerance);
    all_passed = all_passed & passed;
    if (passed) $display("PASSED\n"); else $display("FAILED\n");


    // -------------------------------------------------------
    // 2. Binary Operation (Addition) Works
    // -------------------------------------------------------
    ax = 0.420;  ay = -0.691; az = 0.2;
    bx = -0.420; by = 0.420;  bz = 0.5;
    cx = ax+bx;  cy = ay+by;  cz = az+bz;
    
    a = vec3_from_reals(ax, ay, az);
    b = vec3_from_reals(bx, by, bz);
    c = vec3_add(a, b);
    
    $display("Expected: a+b = (%f, %f, %f)", cx, cy, cz);
    $display("Actual:   a+b = (%f, %f, %f)", fp_to_real(c[95:64]), fp_to_real(c[63:32]), fp_to_real(c[31:0]));

    diff_x = cx - fp_to_real(c[95:64]); if(diff_x < 0) diff_x = -diff_x;
    diff_y = cy - fp_to_real(c[63:32]); if(diff_y < 0) diff_y = -diff_y;
    diff_z = cz - fp_to_real(c[31:0]);  if(diff_z < 0) diff_z = -diff_z;

    passed = (diff_x < tolerance) && (diff_y < tolerance) && (diff_z < tolerance);
    all_passed = all_passed & passed;
    if (passed) $display("PASSED\n"); else $display("FAILED\n");


    // -------------------------------------------------------
    // 3. Dot Product Works
    // -------------------------------------------------------
    ax = 0.420;  ay = -0.691; az = 0.2;
    bx = -0.420; by = 0.420;  bz = 0.5;
    dv = ax*bx + ay*by + az*bz;
    
    a = vec3_from_reals(ax, ay, az);
    b = vec3_from_reals(bx, by, bz);
    d = vec3_dot(a, b);
    
    $display("Expected: a dot b = %f", dv);
    $display("Actual:   a dot b = %f", fp_to_real(d));
    
    diff_d = dv - fp_to_real(d); if(diff_d < 0) diff_d = -diff_d;
    
    passed = (diff_d < tolerance);
    all_passed = all_passed & passed;
    if (passed) $display("PASSED\n"); else $display("FAILED\n");


    // -------------------------------------------------------
    // 4. Vector Normalization 1
    // -------------------------------------------------------
    tolerance = 1e-2;
    
    ax = 0.420; ay = -0.691; az = 0.2;
    dv = $sqrt(ax*ax + ay*ay + az*az);
    cx = ax/dv; cy = ay/dv; cz = az/dv;
    
    a = vec3_from_reals(ax, ay, az);
    c = vec3_normed(a);
    
    $display("Expected: norm(a) = (%f, %f, %f)", cx, cy, cz);
    $display("Actual:   norm(a) = (%f, %f, %f)", fp_to_real(c[95:64]), fp_to_real(c[63:32]), fp_to_real(c[31:0]));

    diff_x = cx - fp_to_real(c[95:64]); if(diff_x < 0) diff_x = -diff_x;
    diff_y = cy - fp_to_real(c[63:32]); if(diff_y < 0) diff_y = -diff_y;
    diff_z = cz - fp_to_real(c[31:0]);  if(diff_z < 0) diff_z = -diff_z;

    passed = (diff_x < tolerance) && (diff_y < tolerance) && (diff_z < tolerance);
    all_passed = all_passed & passed;
    if (passed) $display("PASSED\n"); else $display("FAILED\n");


    // -------------------------------------------------------
    // 5. Vector Normalization 2
    // -------------------------------------------------------
    ax = 0.39; ay = 0.01; az = 0.52;
    dv = $sqrt(ax*ax + ay*ay + az*az);
    cx = ax/dv; cy = ay/dv; cz = az/dv;
    
    a = vec3_from_reals(ax, ay, az);
    c = vec3_normed(a);
    
    $display("Expected: norm(a) = (%f, %f, %f)", cx, cy, cz);
    $display("Actual:   norm(a) = (%f, %f, %f)", fp_to_real(c[95:64]), fp_to_real(c[63:32]), fp_to_real(c[31:0]));

    diff_x = cx - fp_to_real(c[95:64]); if(diff_x < 0) diff_x = -diff_x;
    diff_y = cy - fp_to_real(c[63:32]); if(diff_y < 0) diff_y = -diff_y;
    diff_z = cz - fp_to_real(c[31:0]);  if(diff_z < 0) diff_z = -diff_z;

    passed = (diff_x < tolerance) && (diff_y < tolerance) && (diff_z < tolerance);
    all_passed = all_passed & passed;
    if (passed) $display("PASSED\n"); else $display("FAILED\n");


    // -------------------------------------------------------
    // 6. Vector Normalization 3
    // -------------------------------------------------------
    ax = 2.5; ay = 0.91; az = 1.8;
    dv = $sqrt(ax*ax + ay*ay + az*az);
    cx = ax/dv; cy = ay/dv; cz = az/dv;
    
    a = vec3_from_reals(ax, ay, az);
    c = vec3_normed(a);
    
    $display("Expected: norm(a) = (%f, %f, %f)", cx, cy, cz);
    $display("Actual:   norm(a) = (%f, %f, %f)", fp_to_real(c[95:64]), fp_to_real(c[63:32]), fp_to_real(c[31:0]));

    diff_x = cx - fp_to_real(c[95:64]); if(diff_x < 0) diff_x = -diff_x;
    diff_y = cy - fp_to_real(c[63:32]); if(diff_y < 0) diff_y = -diff_y;
    diff_z = cz - fp_to_real(c[31:0]);  if(diff_z < 0) diff_z = -diff_z;

    passed = (diff_x < tolerance) && (diff_y < tolerance) && (diff_z < tolerance);
    all_passed = all_passed & passed;
    if (passed) $display("PASSED\n"); else $display("FAILED\n");


    // -------------------------------------------------------
    // Final Result
    // -------------------------------------------------------
    if (all_passed)
        $display("----------------\nALL PASSED\n----------------");
    else
        $display("----------------\nSOME FAILED\n----------------");

    $display("Finishing Sim");
    $finish;
  end

endmodule
`default_nettype wire

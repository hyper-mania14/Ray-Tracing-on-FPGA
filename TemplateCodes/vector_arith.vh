`timescale 1ns / 1ps
`default_nettype none

`ifndef VECTOR_ARITH_VH
`define VECTOR_ARITH_VH

`include "fixed_point_arith.vh"
`include "types.vh"

// =============================================================================
// ASSIGNMENT: 3D Vector Math Library - Verilog Port
// =============================================================================
//
// OBJECTIVE:
// Port the 3D vector math library from SystemVerilog to standard Verilog.
// You will implement functions for vector arithmetic, transformations, and
// element-wise operations using fixed-point math.
//
// BACKGROUND:
// In SystemVerilog, vec3 was a struct with fields {x, y, z}. In Verilog, we
// cannot use structs, so we represent vec3 as a flat bit vector where three
// fixed-point numbers are concatenated together.
//
// DATA STRUCTURE:
// - vec3 is represented as: [3*W-1:0] where W = NUM_ALL_DIGITS (width of one fixed-point number)
// - Layout: { X_component, Y_component, Z_component }
//   - Bits [3*W-1 : 2*W] = X component
//   - Bits [2*W-1 :   W] = Y component  
//   - Bits [  W-1 :   0] = Z component
//
// CRITICAL RULES:
// 1. DO NOT change function signatures - widths are calculated from types.vh
// 2. To READ components: Slice the input vector
//    Example: x = a[3*W-1 : 2*W];
// 3. To WRITE results: Concatenate components
//    Example: result = {res_x, res_y, res_z};
// 4. Use fp_* functions from fixed_point_arith.vh for all math operations
// 5. Declare temporary variables as reg inside function begin/end blocks
//
// AVAILABLE FIXED-POINT FUNCTIONS (from fixed_point_arith.vh):
// - fp_add, fp_sub, fp_mul, fp_neg
// - fp_min, fp_max, fp_abs, fp_sign, fp_apply_sign
// - fp_floor, fp_fract, fp_mod
// - fp_mul_half, fp_mul_2, fp_mul_3
// - fp_inv_sqrt (for normalization)
// - fp_lt (less than comparison, returns 1 or 0)
// - Constants: `FP_ZERO, `FP_ONE
//
// =============================================================================

// Helper macro for readability
`define W `NUM_ALL_DIGITS

// -----------------------------------------------------------------------------
// CONSTRUCTOR (EXAMPLE PROVIDED - DO NOT MODIFY)
// -----------------------------------------------------------------------------
function automatic [3*`W-1:0] make_vec3;
    input [`W-1:0] x;
    input [`W-1:0] y;
    input [`W-1:0] z;
    begin
        // Concatenate X, Y, Z to form the vector
        make_vec3 = {x, y, z};
    end
endfunction

// -----------------------------------------------------------------------------
// BASIC ARITHMETIC OPERATIONS
// -----------------------------------------------------------------------------

// Negate all components of vector a
// Result: {-a.x, -a.y, -a.z}
function automatic [3*`W-1:0] vec3_neg;
    input [3*`W-1:0] a;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] rx, ry, rz;
    begin
        // TODO: Extract components from a
        // TODO: Negate each component using fp_neg
        // TODO: Concatenate results
        vec3_neg = 0; // REPLACE THIS
    end
endfunction

// Component-wise addition: a + b
function automatic [3*`W-1:0] vec3_add;
    input [3*`W-1:0] a;
    input [3*`W-1:0] b;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] bx, by, bz;
    reg [`W-1:0] rx, ry, rz;
    begin
        // TODO: Extract components from a and b
        // TODO: Add corresponding components using fp_add
        // TODO: Concatenate results
        vec3_add = 0; // REPLACE THIS
    end
endfunction

// Component-wise subtraction: a - b
function automatic [3*`W-1:0] vec3_sub;
    input [3*`W-1:0] a;
    input [3*`W-1:0] b;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] bx, by, bz;
    reg [`W-1:0] rx, ry, rz;
    begin
        // TODO: Extract components
        // TODO: Subtract using fp_sub
        // TODO: Concatenate results
        vec3_sub = 0; // REPLACE THIS
    end
endfunction

// Component-wise minimum: min(a, b)
function automatic [3*`W-1:0] vec3_min;
    input [3*`W-1:0] a;
    input [3*`W-1:0] b;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] bx, by, bz;
    reg [`W-1:0] rx, ry, rz;
    begin
        // TODO: Extract components
        // TODO: Find minimum of each pair using fp_min
        // TODO: Concatenate results
        vec3_min = 0; // REPLACE THIS
    end
endfunction

// Component-wise maximum: max(a, b)
function automatic [3*`W-1:0] vec3_max;
    input [3*`W-1:0] a;
    input [3*`W-1:0] b;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] bx, by, bz;
    reg [`W-1:0] rx, ry, rz;
    begin
        // TODO: Extract components
        // TODO: Find maximum using fp_max
        // TODO: Concatenate results
        vec3_max = 0; // REPLACE THIS
    end
endfunction

// -----------------------------------------------------------------------------
// VECTOR OPERATIONS
// -----------------------------------------------------------------------------

// Dot product: a·b = a.x*b.x + a.y*b.y + a.z*b.z
// NOTE: Returns a SCALAR (single fixed-point value), not a vector!
function automatic [`W-1:0] vec3_dot;
    input [3*`W-1:0] a;
    input [3*`W-1:0] b;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] bx, by, bz;
    reg [`W-1:0] x2, y2, z2;
    reg [`W-1:0] sum;
    begin
        // TODO: Extract components from a and b
        // TODO: Calculate x2 = ax * bx using fp_mul
        // TODO: Calculate y2 = ay * by using fp_mul
        // TODO: Calculate z2 = az * bz using fp_mul
        // TODO: Calculate sum = x2 + (y2 + z2) using fp_add
        vec3_dot = 0; // REPLACE THIS
    end
endfunction

// Cross product: a × b
// Result.x = a.y*b.z - a.z*b.y
// Result.y = a.z*b.x - a.x*b.z
// Result.z = a.x*b.y - a.y*b.x
function automatic [3*`W-1:0] vec3_cross;
    input [3*`W-1:0] a;
    input [3*`W-1:0] b;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] bx, by, bz;
    reg [`W-1:0] rx, ry, rz;
    begin
        // TODO: Extract components
        // TODO: Calculate rx = ay*bz - az*by using fp_mul and fp_sub
        // TODO: Calculate ry = az*bx - ax*bz
        // TODO: Calculate rz = ax*by - ay*bx
        // TODO: Concatenate results
        vec3_cross = 0; // REPLACE THIS
    end
endfunction

// -----------------------------------------------------------------------------
// SCALING OPERATIONS
// -----------------------------------------------------------------------------

// Multiply vector by scalar: a * s
function automatic [3*`W-1:0] vec3_scaled;
    input [3*`W-1:0] a;
    input [`W-1:0] s;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] rx, ry, rz;
    begin
        // TODO: Extract components
        // TODO: Multiply each by s using fp_mul
        // TODO: Concatenate results
        vec3_scaled = 0; // REPLACE THIS
    end
endfunction

// Multiply vector by 0.5 (optimized)
function automatic [3*`W-1:0] vec3_scaled_half;
    input [3*`W-1:0] a;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] rx, ry, rz;
    begin
        // TODO: Extract components
        // TODO: Multiply each by 0.5 using fp_mul_half
        // TODO: Concatenate results
        vec3_scaled_half = 0; // REPLACE THIS
    end
endfunction

// Multiply vector by 2 (optimized)
function automatic [3*`W-1:0] vec3_scaled_2;
    input [3*`W-1:0] a;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] rx, ry, rz;
    begin
        // TODO: Extract components
        // TODO: Multiply each by 2 using fp_mul_2
        // TODO: Concatenate results
        vec3_scaled_2 = 0; // REPLACE THIS
    end
endfunction

// Multiply vector by 3 (optimized)
function automatic [3*`W-1:0] vec3_scaled_3;
    input [3*`W-1:0] a;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] rx, ry, rz;
    begin
        // TODO: Extract components
        // TODO: Multiply each by 3 using fp_mul_3
        // TODO: Concatenate results
        vec3_scaled_3 = 0; // REPLACE THIS
    end
endfunction

// Component-wise modulo by scalar s
function automatic [3*`W-1:0] vec3_modded;
    input [3*`W-1:0] a;
    input [`W-1:0] s;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] rx, ry, rz;
    begin
        // TODO: Extract components
        // TODO: Apply fp_mod to each component
        // TODO: Concatenate results
        vec3_modded = 0; // REPLACE THIS
    end
endfunction

// Normalize vector to unit length
// Steps: 1) Calculate length² using dot product
//        2) Calculate 1/sqrt(length²) 
//        3) Scale vector by this factor
function automatic [3*`W-1:0] vec3_normed;
    input [3*`W-1:0] a;
    reg [`W-1:0] sum;
    reg [`W-1:0] factor;
    begin
        // TODO: Calculate sum = vec3_dot(a, a)
        // TODO: Calculate factor = fp_inv_sqrt(sum)
        // TODO: Return vec3_scaled(a, factor)
        vec3_normed = 0; // REPLACE THIS
    end
endfunction

// -----------------------------------------------------------------------------
// ELEMENT-WISE MATH OPERATIONS
// -----------------------------------------------------------------------------

// Component-wise fractional part (value - floor(value))
function automatic [3*`W-1:0] vec3_fract;
    input [3*`W-1:0] a;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] rx, ry, rz;
    begin
        // TODO: Extract components
        // TODO: Apply fp_fract to each
        // TODO: Concatenate results
        vec3_fract = 0; // REPLACE THIS
    end
endfunction

// Component-wise absolute value
function automatic [3*`W-1:0] vec3_abs;
    input [3*`W-1:0] a;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] rx, ry, rz;
    begin
        // TODO: Extract components
        // TODO: Apply fp_abs to each
        // TODO: Concatenate results
        vec3_abs = 0; // REPLACE THIS
    end
endfunction

// Component-wise floor
function automatic [3*`W-1:0] vec3_floor;
    input [3*`W-1:0] a;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] rx, ry, rz;
    begin
        // TODO: Extract components
        // TODO: Apply fp_floor to each
        // TODO: Concatenate results
        vec3_floor = 0; // REPLACE THIS
    end
endfunction

// Component-wise step function
// Returns 0.0 if a.i < b.i, else 1.0 for each component
function automatic [3*`W-1:0] vec3_step;
    input [3*`W-1:0] b;
    input [3*`W-1:0] a;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] bx, by, bz;
    reg [`W-1:0] rx, ry, rz;
    begin
        // TODO: Extract components from a and b
        // TODO: For each component: if fp_lt(a, b) then 0 else 1
        // Hint: rx = fp_lt(ax, bx) ? `FP_ZERO : `FP_ONE;
        // TODO: Concatenate results
        vec3_step = 0; // REPLACE THIS
    end
endfunction

// Component-wise sign (-1, 0, or +1)
function automatic [3*`W-1:0] vec3_sign;
    input [3*`W-1:0] a;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] rx, ry, rz;
    begin
        // TODO: Extract components
        // TODO: Apply fp_sign to each
        // TODO: Concatenate results
        vec3_sign = 0; // REPLACE THIS
    end
endfunction

// Apply sign of b to magnitude of a (component-wise)
function automatic [3*`W-1:0] vec3_apply_sign;
    input [3*`W-1:0] a;
    input [3*`W-1:0] b;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] bx, by, bz;
    reg [`W-1:0] rx, ry, rz;
    begin
        // TODO: Extract components
        // TODO: Apply fp_apply_sign to each pair
        // TODO: Concatenate results
        vec3_apply_sign = 0; // REPLACE THIS
    end
endfunction

// -----------------------------------------------------------------------------
// BITWISE SHIFT OPERATIONS
// -----------------------------------------------------------------------------

// Arithmetic right shift by b bits (component-wise)
function automatic [3*`W-1:0] vec3_sr;
    input [3*`W-1:0] a;
    input integer b;
    reg signed [`W-1:0] ax, ay, az;
    reg signed [`W-1:0] rx, ry, rz;
    begin
        // TODO: Extract components (use signed slicing)
        // TODO: Shift each right: rx = ax >>> b;
        // TODO: Concatenate results
        vec3_sr = 0; // REPLACE THIS
    end
endfunction

// Left shift by b bits (component-wise)
function automatic [3*`W-1:0] vec3_sl;
    input [3*`W-1:0] a;
    input integer b;
    reg signed [`W-1:0] ax, ay, az;
    reg signed [`W-1:0] rx, ry, rz;
    begin
        // TODO: Extract components (use signed slicing)
        // TODO: Shift each left: rx = ax << b;
        // TODO: Concatenate results
        vec3_sl = 0; // REPLACE THIS
    end
endfunction

// -----------------------------------------------------------------------------
// SIMULATION/TESTBENCH UTILITIES (NOT SYNTHESIZABLE)
// -----------------------------------------------------------------------------

// Convert three real numbers to a vec3
function automatic [3*`W-1:0] vec3_from_reals;
    input real a;
    input real b;
    input real c;
    begin
        // TODO: Convert each real to fixed-point using fp_from_real
        // TODO: Use make_vec3 to create the vector
        vec3_from_reals = 0; // REPLACE THIS
    end
endfunction

// Note: vec3_to_str has been removed because Verilog-2001 functions cannot
// return strings. For debugging, use $display with fp_to_real:
// 
// Example in testbench:
//   vec3 = some_vector;
//   $display("Vector: (%f, %f, %f)", 
//            fp_to_real(vec3[3*W-1:2*W]),
//            fp_to_real(vec3[2*W-1:W]),
//            fp_to_real(vec3[W-1:0]));

`endif

`default_nettype wire

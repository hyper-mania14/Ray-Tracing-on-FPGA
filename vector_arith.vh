`timescale 1ns / 1ps
`default_nettype none

`ifndef VECTOR_ARITH_VH
`define VECTOR_ARITH_VH


`include "types.vh"
`include "fixed_point_arith.vh"
`define W `NUM_ALL_DIGITS

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
        ax = a[3*`W-1 : 2*`W];
        ay = a[2*`W-1 : `W];
        az = a[`W-1 : 0];
        rx = fp_neg(ax);
        ry = fp_neg(ay);
        rz = fp_neg(az);
        vec3_neg = {rx, ry, rz};
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
        ax = a[3*`W-1 : 2*`W];
        ay = a[2*`W-1 : `W];
        az = a[`W-1 : 0];
        bx = b[3*`W-1 : 2*`W];
        by = b[2*`W-1 : `W];
        bz = b[`W-1 : 0];

        rx = fp_add(ax,bx);
        ry = fp_add(ay,by);
        rz = fp_add(az,bz);
        vec3_add = {rx, ry, rz};
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
        ax = a[3*`W-1 : 2*`W];
        ay = a[2*`W-1 : `W];
        az = a[`W-1 : 0];
        bx = b[3*`W-1 : 2*`W];
        by = b[2*`W-1 : `W];
        bz = b[`W-1 : 0];

        rx = fp_sub(ax,bx);
        ry = fp_sub(ay,by);
        rz = fp_sub(az,bz);
        vec3_sub = {rx, ry, rz}; 
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
        ax = a[3*`W-1 : 2*`W];
        ay = a[2*`W-1 : `W];
        az = a[`W-1 : 0];
        bx = b[3*`W-1 : 2*`W];
        by = b[2*`W-1 : `W];
        bz = b[`W-1 : 0];

        rx = fp_min(ax,bx);
        ry = fp_min(ay,by);
        rz = fp_min(az,bz);
        vec3_min = {rx, ry, rz};
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
        ax = a[3*`W-1 : 2*`W];
        ay = a[2*`W-1 : `W];
        az = a[`W-1 : 0];
        bx = b[3*`W-1 : 2*`W];
        by = b[2*`W-1 : `W];
        bz = b[`W-1 : 0];

        rx = fp_max(ax,bx);
        ry = fp_max(ay,by);
        rz = fp_max(az,bz);
        vec3_max = {rx, ry, rz};
    end
endfunction

// -----------------------------------------------------------------------------
// VECTOR OPERATIONS
// -----------------------------------------------------------------------------

// Dot product: a·b = a.x*b.x + a.y*b.y + a.z*b.z
function automatic [`W-1:0] vec3_dot;
    input [3*`W-1:0] a;
    input [3*`W-1:0] b;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] bx, by, bz;
    reg [`W-1:0] x2, y2, z2;
    reg [`W-1:0] sum;
    begin
        ax = a[3*`W-1 : 2*`W];
        ay = a[2*`W-1 : `W];
        az = a[`W-1 : 0];
        bx = b[3*`W-1 : 2*`W];
        by = b[2*`W-1 : `W];
        bz = b[`W-1 : 0];
        x2 = fp_mul(ax,bx);
        y2 = fp_mul(ay,by);
        z2 = fp_mul(az,bz);
        sum = fp_add(x2, fp_add(y2, z2));
        vec3_dot = sum;
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
        ax = a[3*`W-1 : 2*`W];
        ay = a[2*`W-1 : `W];
        az = a[`W-1 : 0];
        bx = b[3*`W-1 : 2*`W];
        by = b[2*`W-1 : `W];
        bz = b[`W-1 : 0];

        rx = fp_sub(fp_mul(ay,bz),fp_mul(az,by));
        ry = fp_sub(fp_mul(az,bx),fp_mul(ax,bz));
        rz = fp_sub(fp_mul(ax,by),fp_mul(ay,bx));
        vec3_cross = {rx, ry, rz};
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
        ax = a[3*`W-1 : 2*`W];
        ay = a[2*`W-1 : `W];
        az = a[`W-1 : 0];
        rx = fp_mul(ax,s);
        ry = fp_mul(ay,s);
        rz = fp_mul(az,s);
        vec3_scaled= {rx, ry, rz}; 
    end
endfunction

// Multiply vector by 0.5 (optimized)
function automatic [3*`W-1:0] vec3_scaled_half;
    input [3*`W-1:0] a;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] rx, ry, rz;
    begin
        ax = a[3*`W-1 : 2*`W];
        ay = a[2*`W-1 : `W];
        az = a[`W-1 : 0];
        rx = fp_mul_half(ax);
        ry = fp_mul_half(ay);
        rz = fp_mul_half(az);
        vec3_scaled_half= {rx, ry, rz}; 
    end
endfunction

// Multiply vector by 2 (optimized)
function automatic [3*`W-1:0] vec3_scaled_2;
    input [3*`W-1:0] a;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] rx, ry, rz;
    begin
        ax = a[3*`W-1 : 2*`W];
        ay = a[2*`W-1 : `W];
        az = a[`W-1 : 0];
        rx = fp_mul_2(ax);
        ry = fp_mul_2(ay);
        rz = fp_mul_2(az);
        vec3_scaled_2= {rx, ry, rz};
    end
endfunction

// Multiply vector by 3 (optimized)
function automatic [3*`W-1:0] vec3_scaled_3;
    input [3*`W-1:0] a;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] rx, ry, rz;
    begin
        ax = a[3*`W-1 : 2*`W];
        ay = a[2*`W-1 : `W];
        az = a[`W-1 : 0];
        rx = fp_mul_3(ax);
        ry = fp_mul_3(ay);
        rz = fp_mul_3(az);
        vec3_scaled_3= {rx, ry, rz};
    end
endfunction

// Component-wise modulo by scalar s
function automatic [3*`W-1:0] vec3_modded;
    input [3*`W-1:0] a;
    input [`W-1:0] s;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] rx, ry, rz;
    begin
        ax = a[3*`W-1 : 2*`W];
        ay = a[2*`W-1 : `W];
        az = a[`W-1 : 0];
        rx = fp_mod(ax,s);
        ry = fp_mod(ay,s);
        rz = fp_mod(az,s);
        vec3_modded= {rx, ry, rz};
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
        sum = vec3_dot(a,a);
        factor = fp_inv_sqrt(sum);
         vec3_normed = vec3_scaled(a,factor);
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
        ax = a[3*`W-1 : 2*`W];
        ay = a[2*`W-1 : `W];
        az = a[`W-1 : 0];
        rx = fp_fract(ax);
        ry = fp_fract(ay);
        rz = fp_fract(az);
        vec3_fract= {rx, ry, rz};
    end
endfunction

// Component-wise absolute value
function automatic [3*`W-1:0] vec3_abs;
    input [3*`W-1:0] a;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] rx, ry, rz;
    begin
        ax = a[3*`W-1 : 2*`W];
        ay = a[2*`W-1 : `W];
        az = a[`W-1 : 0];
        rx = fp_abs(ax);
        ry = fp_abs(ay);
        rz = fp_abs(az);
        vec3_abs= {rx, ry, rz};

    end
endfunction

// Component-wise floor
function automatic [3*`W-1:0] vec3_floor;
    input [3*`W-1:0] a;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] rx, ry, rz;
    begin
        ax = a[3*`W-1 : 2*`W];
        ay = a[2*`W-1 : `W];
        az = a[`W-1 : 0];
        rx = fp_floor(ax);
        ry = fp_floor(ay);
        rz = fp_floor(az);
        vec3_floor= {rx, ry, rz};
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
        ax = a[3*`W-1 : 2*`W];
        ay = a[2*`W-1 : `W];
        az = a[`W-1 : 0];
        bx = b[3*`W-1 : 2*`W];
        by = b[2*`W-1 : `W];
        bz = b[`W-1 : 0];
        rx = fp_lt(ax,bx)?`FP_ZERO : `FP_ONE;
        ry = fp_lt(ay,by)?`FP_ZERO : `FP_ONE;
        rz = fp_lt(az,bz)?`FP_ZERO : `FP_ONE;
        vec3_step= {rx, ry, rz};
    end
endfunction

// Component-wise sign (-1, 0, or +1)
function automatic [3*`W-1:0] vec3_sign;
    input [3*`W-1:0] a;
    reg [`W-1:0] ax, ay, az;
    reg [`W-1:0] rx, ry, rz;
    begin
        ax = a[3*`W-1 : 2*`W];
        ay = a[2*`W-1 : `W];
        az = a[`W-1 : 0];
        rx = fp_sign(ax);
        ry = fp_sign(ay);
        rz = fp_sign(az);
        vec3_sign= {rx, ry, rz};
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
        ax = a[3*`W-1 : 2*`W];
        ay = a[2*`W-1 : `W];
        az = a[`W-1 : 0];
        bx = b[3*`W-1 : 2*`W];
        by = b[2*`W-1 : `W];
        bz = b[`W-1 : 0];
        rx = fp_apply_sign(ax,bx);
        ry = fp_apply_sign(ay,by);
        rz = fp_apply_sign(az,bz);
        vec3_apply_sign= {rx, ry, rz};
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
        ax = $signed(a[3*`W-1 : 2*`W]);
        ay = $signed(a[2*`W-1 : `W]);
        az = $signed(a[`W-1 : 0]);
        rx = ax >>> b;
        ry = ay >>> b;
        rz = az >>> b;
        vec3_sr= {rx, ry, rz};
    end
endfunction

// Left shift by b bits (component-wise)
function automatic [3*`W-1:0] vec3_sl;
    input [3*`W-1:0] a;
    input integer b;
    reg signed [`W-1:0] ax, ay, az;
    reg signed [`W-1:0] rx, ry, rz;
    begin
        ax = $signed(a[3*`W-1 : 2*`W]);
        ay = $signed(a[2*`W-1 : `W]);
        az = $signed(a[`W-1 : 0]);
        rx = ax << b;
        ry = ay << b;
        rz = az << b;
        vec3_sl= {rx, ry, rz};
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
        reg[`W-1:0]a_fp, b_fp, c_fp;
        a_fp = fp_from_real(a);
        b_fp = fp_from_real(b);
        c_fp = fp_from_real(c);
        vec3_from_reals = make_vec3(a_fp,b_fp,c_fp); // REPLACE THIS
    end
endfunction

// Note: vec3_to_str has been removed because Verilog-2001 functions cannot
// return strings. For debugging, use $display with fp_to_real:
// 
// Example in testbench:
//   vec3 = some_vector;
//   $display("Vector: (%f, %f, %f)", 
//     fp_to_real(vec3[3*W-1:2*W]),
//     fp_to_real(vec3[2*W-1:W]),
//     fp_to_real(vec3[W-1:0]));

`endif

`default_nettype wire


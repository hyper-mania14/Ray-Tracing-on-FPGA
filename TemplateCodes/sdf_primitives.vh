`timescale 1ns / 1ps
`default_nettype none

`ifndef SDF_PRIMITIVES_VH
`define SDF_PRIMITIVES_VH

`include "types.vh"
`include "fixed_point_arith.vh"

`define W `NUM_ALL_DIGITS

// =============================================================================
// ASSIGNMENT: SDF Primitive Shapes Library
// File: sdf_primitives.vh
// =============================================================================
//
// BACKGROUND:
// A Signed Distance Function (SDF) returns the signed distance from a query
// point to the nearest surface of a shape:
//   - Positive: point is OUTSIDE the shape
//   - Negative: point is INSIDE the shape
//   - Zero:     point is exactly ON the surface
//
// All values are fixed-point fp numbers (defined in types.vh).
// A vec3 is a flat [3*W-1:0] bus where W = `NUM_ALL_DIGITS:
//   point[3*W-1 : 2*W] = X component
//   point[2*W-1 :   W] = Y component
//   point[W-1   :   0] = Z component
//
// AVAILABLE FUNCTIONS (from fixed_point_arith.vh):
//   fp_abs(a)      → |a|
//   fp_max(a, b)   → max(a, b)
//   fp_sub(a, b)   → a - b
//
// VERILOG RULES:
//   - Use reg [W-1:0] for local fp variables  
//   - Declare all variables BEFORE the begin block
//   - Assign result to function name (no `return`)
//   - No `automatic` keyword
// =============================================================================


// =============================================================================
// FUNCTION: sd_box_fast
// =============================================================================
//
// TASK: Implement the signed distance to an axis-aligned cube centered at the
//       origin, with "half-extents" defining the cube's half-size in each axis.
//
// INPUTS:
//   point       [3*W-1:0]  — the query point (vec3)
//   halfExtents [W-1:0]    — half-side-length of the cube (fp scalar)
//
// OUTPUT:
//   [W-1:0]  — signed distance from point to cube surface (fp)
//
// ALGORITHM:
//   This uses the L-infinity norm (max of absolute values) as the distance
//   metric, which gives a cube shape.
//
//   Step 1: Extract components from the flat vec3 bus:
//             px = point[3*W-1 : 2*W]   (X)
//             py = point[2*W-1 :   W]   (Y)
//             pz = point[W-1   :   0]   (Z)
//
//   Step 2: Take absolute value of each component:
//             x_abs   = fp_abs(px)
//             y_abs   = fp_abs(py)
//             z_abs   = fp_abs(pz)
//
//   Step 3: Find the maximum across all three axes (L-infinity norm):
//             xy_max  = fp_max(x_abs, y_abs)
//             xyz_max = fp_max(xy_max, z_abs)
//
//   Step 4: Subtract half-extents to get signed distance:
//             result  = fp_sub(xyz_max, halfExtents)
//
//   INTUITION: If the point is at (0.3, 0.1, 0.2) and halfExtents = 0.5,
//   then xyz_max = 0.3, and distance = 0.3 - 0.5 = -0.2 (inside the box).
//   If point is at (0.6, 0.1, 0.2), xyz_max = 0.6, distance = 0.1 (outside).
//
function [`W-1:0] sd_box_fast;
    input [3*`W-1:0] point;
    input [`W-1:0]   halfExtents;
    reg [`W-1:0] px, py, pz;
    reg [`W-1:0] x_abs, y_abs, z_abs, xy_max, xyz_max;
    begin
        // TODO: Step 1 - Extract the X, Y, Z components from the flat bus
        //   px = point[3*`W-1 : 2*`W];
        //   py = ...
        //   pz = ...

        // TODO: Step 2 - Absolute value of each component
        //   x_abs = fp_abs(px);
        //   ...

        // TODO: Step 3 - L-infinity norm (max of all three)
        //   xy_max  = fp_max(x_abs, y_abs);
        //   xyz_max = fp_max(xy_max, z_abs);

        // TODO: Step 4 - Subtract half-extents
        //   sd_box_fast = fp_sub(xyz_max, halfExtents);

        sd_box_fast = 0; // REPLACE THIS
    end
endfunction

`endif

`default_nettype wire

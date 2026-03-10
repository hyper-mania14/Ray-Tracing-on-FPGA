`timescale 1ns / 1ps
`default_nettype none

`ifndef SDF_PRIMITIVES_VH
`define SDF_PRIMITIVES_VH

`include "types.vh"
`include "fixed_point_arith.vh"
`define W `NUM_ALL_DIGITS

function [`W-1:0] sd_box_fast;
    input [3*`W-1:0] point;
    input [`W-1:0]   halfExtents;
    reg [`W-1:0] px, py, pz;
    reg [`W-1:0] x_abs, y_abs, z_abs, xy_max, xyz_max;
    begin
             px = point[3*`W-1:2*`W];
             py = point[2*`W-1:`W];
             pz = point[`W-1:0];


             x_abs=fp_abs(px);
             y_abs=fp_abs(py);
             z_abs=fp_abs(pz);
             
             xy_max  = fp_max(x_abs, y_abs);
             xyz_max = fp_max(xy_max, z_abs);
        sd_box_fast = fp_sub(xyz_max, halfExtents); 
    end
endfunction

`endif

`default_nettype wire
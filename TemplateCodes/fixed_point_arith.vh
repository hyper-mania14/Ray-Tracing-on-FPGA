`timescale 1ns / 1ps
`ifndef FIXED_POINT_ARITH_VH
`define FIXED_POINT_ARITH_VH

`include "types.vh"

// --- Basic Operations ---

function signed [`WIDTH-1:0] fp_add;
    input signed [`WIDTH-1:0] a;
    input signed [`WIDTH-1:0] b;
    begin
        fp_add = a + b;
    end
endfunction

function signed [`WIDTH-1:0] fp_mul;
    input signed [`WIDTH-1:0] a;
    input signed [`WIDTH-1:0] b;
    reg signed [`DOUBLE_WIDTH-1:0] temp_result;
    begin
        temp_result = a * b;
        fp_mul = temp_result >>> `NUM_FRAC_DIGITS;
    end
endfunction

// TEAM TASK: Implement Sub, Min, Max, Comparisons below...

`endif

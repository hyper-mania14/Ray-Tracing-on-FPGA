`timescale 1ns / 1ps
`ifndef FIXED_POINT_ARITH_VH
`define FIXED_POINT_ARITH_VH
`define WIDTH `NUM_ALL_DIGITS
`define DOUBLE_WIDTH (2*`WIDTH)
`include "types.vh"

// ----BASIC OPERATIONS----

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

function signed [`WIDTH-1:0] fp_sub;
    input signed [`WIDTH-1:0] a;
    input signed [`WIDTH-1:0] b;
    begin
        fp_sub = a - b;
    end
endfunction

function signed [`WIDTH-1:0] fp_neg;
    input signed [`WIDTH-1:0] a;
    begin
        fp_neg = ~a +1;
    end
endfunction
 
//----COMPARISONS----

function reg fp_lt;
    input signed [`WIDTH-1:0] a;
    input signed [`WIDTH-1:0] b;
    begin
        fp_lt = (a<b)? 1:0;
    end
endfunction

function reg fp_gt;
    input signed [`WIDTH-1:0] a;
    input signed [`WIDTH-1:0] b;
    begin
        fp_gt = (a>b)? 1:0;
    end
endfunction

function signed [`WIDTH-1:0] fp_min;
    input signed [`WIDTH-1:0] a;
    input signed [`WIDTH-1:0] b;
    begin
        fp_min = (a<b)? a:b;
    end
endfunction

function signed [`WIDTH-1:0] fp_max;
    input signed [`WIDTH-1:0] a;
    input signed [`WIDTH-1:0] b;
    begin
        fp_max = (a>b)? a:b;
    end
endfunction

//----SIGN UTILITIES----
function signed [`WIDTH-1:0] fp_abs;
    input signed [`WIDTH-1:0] a;
    begin
        fp_abs = (a<0)? -a:a;
    end
endfunction

function signed [`WIDTH-1:0] fp_sign;
    input signed [`WIDTH-1:0] a;
    begin
        fp_sign = (a<0)? -1: 1;
    end
endfunction

function signed [`WIDTH-1:0] fp_apply_sign;
    input signed [`WIDTH-1:0] a;
    input signed [`WIDTH-1:0] b;
    begin
        fp_apply_sign = (b<0)? -a:a;
    end
endfunction

//----OPTIMIZATION FUNCTIONS----

function signed [`WIDTH-1:0] fp_mul_half;
    input signed [`WIDTH-1:0] a;
    begin
        fp_mul_half = a >>> 1;
    end
endfunction

function signed [`WIDTH-1:0] fp_mul_2;
    input signed [`WIDTH-1:0] a;
    begin
        fp_mul_2 = a << 1;
    end
endfunction

function signed [`WIDTH-1:0] fp_mul_3;
    input signed [`WIDTH-1:0] a;
    begin
        fp_mul_3 = (a<<1) + a;
    end
endfunction

function signed [`WIDTH-1:0] fp_mul_4;
    input signed [`WIDTH-1:0] a;
    begin
        fp_mul_4 = a << 2;
    end
endfunction

function signed [`WIDTH-1:0] fp_mul_5;
    input signed [`WIDTH-1:0] a;
    begin
        fp_mul_5 = (a<<2) + a;
    end
endfunction

function signed [`WIDTH-1:0] fp_mul_6;
    input signed [`WIDTH-1:0] a;
    begin
        fp_mul_6 = (a<<2) + (a<<1);
    end
endfunction

function signed [`WIDTH-1:0] fp_mul_7;
    input signed [`WIDTH-1:0] a;
    begin
        fp_mul_7 = (a<<3) - a;
    end
endfunction

function signed [`WIDTH-1:0] fp_mul_8;
    input signed [`WIDTH-1:0] a;
    begin
        fp_mul_8 = a << 3;
    end
endfunction

`endif

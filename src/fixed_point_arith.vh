`timescale 1ns / 1ps
`ifndef FIXED_POINT_ARITH_VH
`define FIXED_POINT_ARITH_VH
`define WIDTH `NUM_ALL_DIGITS
`define DOUBLE_WIDTH (2*`WIDTH)
`include "types.vh"


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

function signed [`WIDTH-1:0] fp_floor;
    input signed [`WIDTH-1:0] a;
    reg signed [`WIDTH-1:0] truncated;
    begin
        truncated = (a >>> `NUM_FRAC_DIGITS) << `NUM_FRAC_DIGITS;
        if (a < 0 && (a != truncated))
            fp_floor = truncated - (1 << `NUM_FRAC_DIGITS);
        else
            fp_floor = truncated;
    end
endfunction


function signed [`WIDTH-1:0] fp_fract;
    input signed [`WIDTH-1:0] a;
    begin
        fp_fract = fp_sub(a,fp_floor(a));
    end
endfunction


function signed [`WIDTH-1:0] fp_mod;
    input signed [`WIDTH-1:0] a;
    input signed [`WIDTH-1:0] s;
    reg signed [`WIDTH-1:0] div_result;
    begin
        div_result = fp_floor(fp_mul(a, fp_inv(s)));
        fp_mod = fp_sub(a,fp_mul(s, div_result));
    end
endfunction


function signed [`WIDTH-1:0] fp_inv;
    input signed [`WIDTH-1:0] a;
    reg signed [`WIDTH-1:0] x;
    reg signed [`WIDTH-1:0] two;
    integer i;
    begin
        two = 2 << `NUM_FRAC_DIGITS;
        // Initial guess: 1.0
        x = 1 << `NUM_FRAC_DIGITS;
        for (i = 0; i < 8; i = i + 1)
            x = fp_mul(x, fp_sub(two, fp_mul(a, x)));
        fp_inv = x;
    end
endfunction

function signed [`WIDTH-1:0] fp_inv_sqrt;
    input signed [`WIDTH-1:0] a;
    reg signed [`WIDTH-1:0] x;
    reg signed [`WIDTH-1:0] half_a;
    reg signed [`WIDTH-1:0] three_halves;
    integer i;
    begin
        three_halves = (1 << `NUM_FRAC_DIGITS) + (1 << (`NUM_FRAC_DIGITS - 1)); // 1.5
        half_a = fp_mul_half(a);
        // Initial guess: 1.0
        x = 1 << `NUM_FRAC_DIGITS;
        for (i = 0; i < 8; i = i + 1)
            x = fp_mul(x, fp_sub(three_halves, fp_mul(half_a, fp_mul(x, x))));
        fp_inv_sqrt = x;
    end
endfunction

// fp_from_real: simulation only, converts a real to fixed point
function signed [`WIDTH-1:0] fp_from_real;
    input real a;
    begin
        fp_from_real = $rtoi(a * (1 << `NUM_FRAC_DIGITS));
    end
endfunction
// Simulation only - convert fixed point to real
`ifndef SYNTHESIS
function real fp_to_real;
    input signed [`WIDTH-1:0] a;
    begin
        fp_to_real = $itor(a) / $itor(1 << `NUM_FRAC_DIGITS);
    end
endfunction
`endif

function signed [5:0] fp_count_leading_zeros;
    input signed [`WIDTH-1:0] value;
    integer i;
    reg found;
    begin
        fp_count_leading_zeros = 0;
        found = 0;
        for (i = `WIDTH-1; i >= 0; i = i - 1) begin
            if (!found && value[i] == 0) begin
                fp_count_leading_zeros = fp_count_leading_zeros + 1;
            end else begin
                found = 1;
            end
        end
    end
endfunction

`endif

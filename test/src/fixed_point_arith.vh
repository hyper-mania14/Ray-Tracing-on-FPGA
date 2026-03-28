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

//----MATH & SIMULATION----
function [`WIDTH-1:0] fp_from_real;
    input real val;
    begin
        fp_from_real = val * (2.0 ** `NUM_FRAC_DIGITS);
    end
endfunction

function real fp_to_real;
    input [`WIDTH-1:0] a;
    begin
        fp_to_real = $signed(a) / (2.0 ** `NUM_FRAC_DIGITS);
    end
endfunction

function signed [`WIDTH-1:0] fp_floor;
    input signed [`WIDTH-1:0] a;
    reg signed [`WIDTH-1:0] out;
    begin
        out = a & ~((1 << `NUM_FRAC_DIGITS) - 1);
        fp_floor = out;
    end
endfunction

function signed [`WIDTH-1:0] fp_fract;
    input signed [`WIDTH-1:0] a;
    begin
        fp_fract = a - fp_floor(a);
    end
endfunction

function signed [`WIDTH-1:0] fp_mod;
    input signed [`WIDTH-1:0] a;
    input signed [`WIDTH-1:0] b;
    reg signed [`DOUBLE_WIDTH-1:0] div;
    reg signed [`WIDTH-1:0] quotient;
    begin
        if (b == 0) fp_mod = 0;
        else begin
            div = (a <<< `NUM_FRAC_DIGITS) / b;
            quotient = fp_floor(div);
            fp_mod = a - fp_mul(quotient, b);
        end
    end
endfunction

// ---- SYNTHESIZABLE Combinational Inverse Square Root ----
// Unrolled Newton-Raphson (same algorithm as fp_inv_sqrt_folded.v)
// Steps: normalize → initial guess → 2 NR iterations → denormalize
//
// WARNING: This creates a long combinational path (multiple chained
// multipliers). Acceptable for places like vec3_normed where adding
// handshaking would be too complex, but use fp_inv_sqrt_folded for
// timing-critical sequential paths.
function signed [`WIDTH-1:0] fp_inv_sqrt;
    input signed [`WIDTH-1:0] a;

    reg signed [5:0]          diff;
    reg signed [`WIDTH-1:0]   norm;       // normalized input
    reg signed [`WIDTH-1:0]   x;          // current estimate
    reg signed [`WIDTH-1:0]   x_sq;       // x * x
    reg signed [`WIDTH-1:0]   half_norm;  // norm >> 1 (i.e. norm/2)
    reg signed [`WIDTH-1:0]   y;          // half_norm * x_sq
    reg signed [`WIDTH-1:0]   correction; // 1.5 - y
    reg signed [5:0]          final_shift;
    reg signed [`WIDTH-1:0]   x_shifted;
    reg signed [`DOUBLE_WIDTH-1:0] temp_mul;

    begin
        if (a <= 0) begin
            fp_inv_sqrt = 0;
        end else begin
            // --- Step 1: Normalization ---
            // Count leading zeros and compute shift to bring into [0.5, 1.0)
            diff = fp_count_leading_zeros(a) - `NUM_WHOLE_DIGITS;
            if (diff >= 0)
                norm = a << diff;
            else
                norm = a >> (-diff);

            // --- Step 2: Initial Guess ---
            // x0 = sqrt(2) - slope * (norm - 0.5)
            temp_mul = `FP_INTERP_SLOPE * fp_sub(norm, `FP_HALF);
            x = fp_sub(`FP_SQRT_TWO, temp_mul >>> `NUM_FRAC_DIGITS);

            half_norm = norm >>> 1;

            // --- Step 3: Newton-Raphson Iteration 1 ---
            // x_sq = x * x
            temp_mul = x * x;
            x_sq = temp_mul >>> `NUM_FRAC_DIGITS;
            // y = half_norm * x_sq
            temp_mul = half_norm * x_sq;
            y = temp_mul >>> `NUM_FRAC_DIGITS;
            // x = x * (1.5 - y)
            correction = fp_sub(`FP_THREE_HALFS, y);
            temp_mul = x * correction;
            x = temp_mul >>> `NUM_FRAC_DIGITS;

            // --- Step 4: Newton-Raphson Iteration 2 ---
            // x_sq = x * x
            temp_mul = x * x;
            x_sq = temp_mul >>> `NUM_FRAC_DIGITS;
            // y = half_norm * x_sq
            temp_mul = half_norm * x_sq;
            y = temp_mul >>> `NUM_FRAC_DIGITS;
            // x = x * (1.5 - y)
            correction = fp_sub(`FP_THREE_HALFS, y);
            temp_mul = x * correction;
            x = temp_mul >>> `NUM_FRAC_DIGITS;

            // --- Step 5: Denormalization ---
            final_shift = (diff + 1) >>> 1;
            if (final_shift >= 0)
                x_shifted = x << final_shift;
            else
                x_shifted = x >>> (-final_shift);

            // If original shift was odd, multiply by 1/sqrt(2)
            if (diff[0]) begin
                temp_mul = x_shifted * `FP_INV_SQRT_TWO;
                fp_inv_sqrt = temp_mul >>> `NUM_FRAC_DIGITS;
            end else begin
                fp_inv_sqrt = x_shifted;
            end
        end
    end
endfunction

// ---- Simulation-only inverse sqrt (for testbenches) ----
// Uses $sqrt — NOT synthesizable, but gives exact results for verification
function signed [`WIDTH-1:0] fp_inv_sqrt_sim;
    input signed [`WIDTH-1:0] a;
    real r_a, r_inv;
    begin
        r_a = fp_to_real(a);
        if (r_a <= 0.0)
            r_inv = 0.0;
        else
            r_inv = 1.0 / $sqrt(r_a);
        fp_inv_sqrt_sim = fp_from_real(r_inv);
    end
endfunction

function [5:0] fp_count_leading_zeros;
    input [`WIDTH-1:0] a;
    integer i;
    reg found;
    begin
        fp_count_leading_zeros = `WIDTH;
        found = 0;
        for (i = `WIDTH - 1; i >= 0; i = i - 1) begin
            if (a[i] == 1'b1 && !found) begin
                fp_count_leading_zeros = `WIDTH - 1 - i;
                found = 1;
            end
        end
    end
endfunction

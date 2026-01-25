// Inverse square root algorithm
//
// Objective: Design a hardware module in Verilog that calculates 
// the Inverse Square Root (1/√x) of a fixed-point number.
//
// Newton Raphson's algorithm
//
// Step A: Calculate    x^2
// Step B: Calculate    0.5*original×(x^2) = y
// Step C: Calculate    x × (1.5 − y)
//
// xn+1 = xn × (1.5 − (input>>1) × (xn×xn))
//
// Calculation Flow
// normalization:
// Shift the input left/right until it lies in range 0.5 to 1.0.
// Count shifts (shift count)
// initial Guess (x0):
// x0 = 2 − 0.828 × (normalized_input − 0.5)
// iteration:
// Run Steps A, B, C exactly 2 times
// denormalization:
// Shift result right by (shift_count >> 1)
// If shift_count is odd, multiply final result by 0.7071 (1/√2)

`timescale 1ns / 1ps
`default_nettype none

`include "types.vh"


module fp_inv_sqrt_folded(
    input wire clk_in,
    input wire rst_in,
    input wire signed [`WIDTH-1:0] a_in,
    input wire valid_in,
    
    output wire signed [`WIDTH-1:0] res_out,
    output reg valid_out,
    output reg ready_out
);
   `include "fixed_point_arith.vh"
    parameter MAX_NEWTON_ITER = 2;

    // --- Internal State Registers ---
    reg [3:0] stage;
    reg [2:0] newton_iter;
    reg [2:0] newton_iter_step;

    // --- Shared Multiplier ---
    reg signed [`WIDTH-1:0] mult1_a;
    reg signed [`WIDTH-1:0] mult1_b;
    wire signed [`WIDTH-1:0] mult1_res;
    assign mult1_res = fp_mul(mult1_a, mult1_b);

    // --- Algorithm Variables ---
    wire signed [`WIDTH-1:0] slope;
    assign slope = `FP_INTERP_SLOPE; 

    reg signed [`WIDTH-1:0] original;
    reg signed [5:0] diff;

    wire signed [5:0] _diff;
    assign _diff = fp_count_leading_zeros(original) - `NUM_WHOLE_DIGITS;

    reg signed [`WIDTH-1:0] x;
    reg signed [`WIDTH-1:0] x_mult;

    // --- Final output shifting logic ---
    wire signed [5:0] final_shift;
    wire signed [`WIDTH-1:0] x_shifted;

    assign final_shift = diff >>> 1;
    assign x_shifted = (final_shift >= 0) ? (x << final_shift) : (x >>> -final_shift);
    assign res_out = x;

    // ============================================================
    // PART 1: Combinational Multiplier Mux
    // ============================================================
    always @* begin
        mult1_a = 0;
        mult1_b = 0;

        if (stage == 2) begin
            // Initial Guess: slope * (original - 0.5)
            mult1_a = slope;
            mult1_b = fp_sub(original, `FP_HALF);
        end 
        else if (stage == 3) begin
            // TASK 1: Newton Loop Multiplier Control
            // Step 0: x * x
            // Step 1: (original >> 1) * x_mult
            // Step 2: x * (1.5 - x_mult)

            if (newton_iter_step == 0) begin
                mult1_a = x;
                mult1_b = x;
            end 
            else if (newton_iter_step == 1) begin
                mult1_a = original >>> 1;
                mult1_b = x_mult;
            end 
            else begin
                mult1_a = x;
                mult1_b = fp_sub(`FP_THREE_HALFS, x_mult);
            end
        end 
        else if (stage == 4) begin
            // TASK 2: Final Odd-Shift Correction Multiply
            // x_shifted * (1/√2)
            mult1_a = x_shifted <<< 1;
            mult1_b = `FP_INV_SQRT_TWO;
        end
    end

    // ============================================================
    // PART 2: Sequential State Machine
    // ============================================================
    always @(posedge clk_in) begin
        if (rst_in) begin
            stage <= 0;
            valid_out <= 0;
            ready_out <= 1;
        end 

        else if (stage == 0) begin
            // IDLE
            valid_out <= 0;
            if (valid_in) begin
                ready_out <= 0;
                original <= a_in;
                stage <= 1;
            end
        end 

        else if (stage == 1) begin
            // NORMALIZATION
            diff <= _diff;
            if (_diff >= 0)
                original <= original << _diff;
            else
                original <= original >> (-_diff);
            stage <= 2;
        end 

        else if (stage == 2) begin
            // INITIAL GUESS
            x <= fp_sub(`FP_SQRT_TWO, mult1_res);
            stage <= 3;
            newton_iter <= 0;
            newton_iter_step <= 0;
        end 

        else if (stage == 3) begin
            // TASK 3: Newton Iteration State Logic

            if (newton_iter_step == 0) begin
                x_mult <= mult1_res;
                newton_iter_step <= 1;
            end 
            else if (newton_iter_step == 1) begin
                x_mult <= mult1_res;
                newton_iter_step <= 2;
            end 
            else begin
                x <= mult1_res;
                newton_iter_step <= 0;
                newton_iter <= newton_iter + 1;
                if (newton_iter == MAX_NEWTON_ITER - 1)
                    stage <= 4;
            end
        end 

        else if (stage == 4) begin
            // TASK 4: Final Output Logic

            if (diff[0])
                x <= mult1_res;     
            else
                x <= x_shifted;     

            valid_out <= 1;
            ready_out <= 1;
            stage <= 0;
        end
    end

endmodule

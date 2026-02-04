`timescale 1ns / 1ps
`default_nettype none

// Include shared definitions and math library
`include "types.vh"
`include "fixed_point_arith.vh"

module fp_inv_sqrt_folded(
    input wire clk_in,
    input wire rst_in,
    input wire signed [`WIDTH-1:0] a_in,
    input wire valid_in,
    
    output wire signed [`WIDTH-1:0] res_out,
    output reg valid_out,
    output reg ready_out
);

    parameter MAX_NEWTON_ITER = 2;

    // --- Internal State Registers ---
    reg [3:0] stage;
    reg [2:0] newton_iter;      // Tracks loop count (0 to MAX)
    reg [2:0] newton_iter_step; // Tracks micro-steps (0, 1, 2)

    // --- The Shared Multiplier (The "Folded" Resource) ---
    reg signed [`WIDTH-1:0] mult1_a;
    reg signed [`WIDTH-1:0] mult1_b;
    wire signed [`WIDTH-1:0] mult1_res;

    // We instantiate the multiplier function ONCE here.
    // Your job is to control 'mult1_a' and 'mult1_b' in the always @* block.
    assign mult1_res = fp_mul(mult1_a, mult1_b);

    // --- Algorithm Variables ---
    wire signed [`WIDTH-1:0] slope;
    assign slope = `FP_INTERP_SLOPE; 

    reg signed [`WIDTH-1:0] original; // Stores the normalized input
    reg [4:0] diff;                   // Stores shift count
    
    // Helper to count zeros (calls library function)
    wire [4:0] _diff;
    assign _diff = `NUM_WHOLE_DIGITS - fp_count_leading_zeros(original);

    // Registers for calculation
    reg signed [`WIDTH-1:0] x;      // Current Guess
    reg signed [`WIDTH-1:0] x_mult; // Temp variable

    // Final output shifting logic
    wire signed [`WIDTH-1:0] x_shifted;
    assign x_shifted = x >>> (diff >> 1); // Arithmetic shift right
    assign res_out = x;

    // ============================================================
    // PART 1: Combinational Multiplexer (Control the Multiplier)
    // ============================================================
    always @* begin
        // Default values
        mult1_a = 0;
        mult1_b = 0;

        if (stage == 2) begin
            // Example: Initial Guess Calculation
            // Logic: slope * (original - 0.5)
            mult1_a = slope;
            mult1_b = fp_sub(original, `FP_HALF);
        end 
        else if (stage == 3) begin
            // TASK 1: Implement the Mux logic for the Newton Loop
            // Check 'newton_iter_step' (0, 1, or 2)
            // Step 0: Feed x and x into multiplier
            // Step 1: Feed (original >>> 1) and x_mult into multiplier
            // Step 2: Feed x and (1.5 - x_mult) into multiplier
            
            // ... write your code here ...
            
        end 
        else if (stage == 4) begin
            // TASK 2: Implement the Mux logic for Final Correction
            // Feed 'x_shifted' and 'FP_INV_SQRT_TWO' into multiplier
            
            // ... write your code here ...
        end
    end

    // ============================================================
    // PART 2: Sequential State Machine (Update Registers)
    // ============================================================
    always @(posedge clk_in) begin
        if (rst_in) begin
            stage <= 0;
            valid_out <= 0;
            ready_out <= 1;
        end 
        else if (stage == 0) begin
            // IDLE State
            valid_out <= 0;
            if (valid_in) begin
                ready_out <= 0;
                original <= a_in;
                stage <= 1;
            end
        end 
        else if (stage == 1) begin
            // NORMALIZE State
            diff <= _diff;
            original <= original << _diff; // Shift left to normalize
            stage <= 2;
        end 
        else if (stage == 2) begin
            // INITIAL GUESS State
            // We use the multiplier result from the previous cycle logic
            // Formula: x = Sqrt(2) - mult1_res
            x <= fp_sub(`FP_SQRT_TWO, mult1_res);
            
            // Setup for the loop
            stage <= 3;
            newton_iter <= 0;
            newton_iter_step <= 0;
        end 
        else if (stage == 3) begin
            // TASK 3: Implement the Newton Loop State Logic
            // 1. If step == 0: Save 'mult1_res' into 'x_mult', increment step
            // 2. If step == 1: Save 'mult1_res' into 'x_mult', increment step
            // 3. If step == 2: Save 'mult1_res' into 'x'. 
            //    Reset step to 0. Increment 'newton_iter'.
            //    If 'newton_iter' reached MAX_NEWTON_ITER, go to Stage 4.
            
            // ... write your code here ...
            
        end 
        else if (stage == 4) begin
            // TASK 4: Implement Final Output Logic
            // Check if 'diff' is odd (diff[0] == 1).
            // If odd: x <= mult1_res
            // If even: x <= x_shifted
            // Set valid_out <= 1, ready_out <= 1, go back to Stage 0.
            
            // ... write your code here ...
        end
    end

endmodule


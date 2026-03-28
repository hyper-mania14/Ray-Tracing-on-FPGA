`timescale 1ns / 1ps
`default_nettype none
`include "types.vh"
// =============================================================================
// ASSIGNMENT: Pipelined Ray Direction Generator
// File: ray_generator_folded.v
// =============================================================================

module ray_generator_folded #(
    parameter DISPLAY_WIDTH  = `DISPLAY_WIDTH,
    parameter DISPLAY_HEIGHT = `DISPLAY_HEIGHT,
    parameter H_BITS         = `H_BITS,
    parameter V_BITS         = `V_BITS
) (
    input  wire clk_in,
    input  wire rst_in,
    input  wire valid_in,
    input  wire [H_BITS-1:0]  hcount_in,
    input  wire [V_BITS-1:0]  vcount_in,
    input  wire [`W-1:0]      hcount_fp_in,
    input  wire [`W-1:0]      vcount_fp_in,
    input  wire [3*`W-1:0]    cam_forward_in,
    output reg                 valid_out,
    output reg                 ready_out,
    output reg  [3*`W-1:0]    ray_direction_out
);




    `include "fixed_point_arith.vh"
    `include "vector_arith.vh"

    reg [3:0] stage;

    // Latched inputs (stage 0)
    reg [H_BITS-1:0] hcount;
    reg [V_BITS-1:0] vcount;
    reg [`W-1:0]     px, py;
    reg [3*`W-1:0]   cam_forward;

    // Computed vectors (all flat [3*W-1:0] bus, X in high bits)
    reg [3*`W-1:0] cam_right;
    reg [3*`W-1:0] cam_up;
    reg [3*`W-1:0] scaled_right;
    reg [3*`W-1:0] scaled_up;
    reg [3*`W-1:0] rd1;

    // Combinational rd1 computation (before normalization)
    wire [3*`W-1:0] _rd0, _rd1;
    assign _rd0 = vec3_add(scaled_right, scaled_up);
    assign _rd1 = vec3_add(_rd0, cam_forward);

    // fp_inv_sqrt_folded submodule
    reg  fisf_valid_in;
    wire fisf_valid_out, fisf_ready_out;
    wire [`W-1:0] fisf_res_out;
    wire [`W-1:0] rd1_dot;
    assign rd1_dot = vec3_dot(rd1, rd1);

    fp_inv_sqrt_folded fisf (
        .clk_in    (clk_in),
        .rst_in    (rst_in),
        .a_in      (rd1_dot),
        .valid_in  (fisf_valid_in),
        .res_out   (fisf_res_out),
        .valid_out (fisf_valid_out),
        .ready_out (fisf_ready_out)
    );

    // Three shared multipliers — inputs muxed by stage
    reg  [`W-1:0] mult1_a, mult1_b;
    reg  [`W-1:0] mult2_a, mult2_b;
    reg  [`W-1:0] mult3_a, mult3_b;
    wire [`W-1:0] mult1_res, mult2_res, mult3_res;
    assign mult1_res = fp_mul(mult1_a, mult1_b);
    assign mult2_res = fp_mul(mult2_a, mult2_b);
    assign mult3_res = fp_mul(mult3_a, mult3_b);

    // Helper slices for cam_forward, cam_right, cam_up, rd1
    wire [`W-1:0] cf_x, cf_y, cf_z;
    assign cf_x = cam_forward[3*`W-1 : 2*`W];
    assign cf_y = cam_forward[2*`W-1 :   `W];
    assign cf_z = cam_forward[  `W-1 :     0];

    wire [`W-1:0] cr_x, cr_y, cr_z;
    assign cr_x = cam_right[3*`W-1 : 2*`W];
    assign cr_y = cam_right[2*`W-1 :   `W];
    assign cr_z = cam_right[  `W-1 :     0];

    wire [`W-1:0] cu_x, cu_y, cu_z;
    assign cu_x = cam_up[3*`W-1 : 2*`W];
    assign cu_y = cam_up[2*`W-1 :   `W];
    assign cu_z = cam_up[  `W-1 :     0];

    wire [`W-1:0] rd1_x, rd1_y, rd1_z;
    assign rd1_x = rd1[3*`W-1 : 2*`W];
    assign rd1_y = rd1[2*`W-1 :   `W];
    assign rd1_z = rd1[  `W-1 :     0];

    // =========================================================================
    // Multiplier mux — select inputs based on current stage
    // =========================================================================
    always @(*) begin
        mult1_a = 0; mult1_b = 0;
        mult2_a = 0; mult2_b = 0;
        mult3_a = 0; mult3_b = 0;

        if (stage == 1) begin
            // cam_up.x = -(y*x)
            mult1_a = cf_y; mult1_b = fp_neg(cf_x);
            // cam_up.y = z² + x²
            mult2_a = cf_z; mult2_b = cf_z;
            mult3_a = cf_x; mult3_b = cf_x;

        end else if (stage == 2) begin
            // cam_up.z = -(y*z)
            mult1_a = cf_y; mult1_b = cf_z;

        end else if (stage == 4) begin
            // scaled_right = cam_right * px
            mult1_a = cr_x; mult1_b = px;
            mult2_a = cr_y; mult2_b = px;
            mult3_a = cr_z; mult3_b = px;

        end else if (stage == 7) begin
            // scaled_up = cam_up * py
            mult1_a = cu_x; mult1_b = py;
            mult2_a = cu_y; mult2_b = py;
            mult3_a = cu_z; mult3_b = py;

        end else if (stage == 6) begin
            // Normalization scaling
            mult1_a = rd1_x; mult1_b = fisf_res_out;
            mult2_a = rd1_y; mult2_b = fisf_res_out;
            mult3_a = rd1_z; mult3_b = fisf_res_out;
        end
    end

    // =========================================================================
    // State machine — sequential pipeline stages
    // =========================================================================
    always @(posedge clk_in) begin
        if (rst_in) begin
            stage         <= 0;
            valid_out     <= 0;
            ready_out     <= 1;
            fisf_valid_in <= 0;

        end else if (stage == 0) begin
            valid_out <= 0;
            if (valid_in) begin
                ready_out   <= 0;
                hcount      <= hcount_in;
                vcount      <= vcount_in;
                cam_forward <= cam_forward_in;
                px          <= hcount_fp_in;
                py          <= vcount_fp_in;
                stage       <= 1;
            end

        end else if (stage == 1) begin
            // cam_right.x = cf_z, cam_right.y = 0, cam_right.z = fp_neg(cf_x)
            cam_right <= {cf_z, {`W{1'b0}}, fp_neg(cf_x)};

            // cam_up.x and cam_up.y
            cam_up[3*`W-1:2*`W] <= mult1_res;
            cam_up[2*`W-1:  `W] <= fp_add(mult2_res, mult3_res);
            
            stage <= 2;

        end else if (stage == 2) begin
            // cam_up.z
            cam_up[`W-1:0] <= fp_neg(mult1_res);
            stage <= 4;

        end else if (stage == 4) begin
            scaled_right <= {mult1_res, mult2_res, mult3_res};
            stage <= 7;

        end else if (stage == 7) begin
            scaled_up = {mult1_res, mult2_res, mult3_res};
            stage <= 5;

        end else if (stage == 5 && fisf_ready_out) begin
            rd1           <= _rd1;
            fisf_valid_in <= 1;
            stage         <= 6;

        end else if (stage == 6) begin
            fisf_valid_in <= 0;
            if (fisf_valid_out) begin
                // Y IS NEGATED here
                ray_direction_out <= {mult1_res, fp_neg(mult2_res), mult3_res};
                valid_out <= 1;
                ready_out <= 1;
                stage     <= 0;
            end
        end
    end

endmodule // ray_generator_folded

`default_nettype wire

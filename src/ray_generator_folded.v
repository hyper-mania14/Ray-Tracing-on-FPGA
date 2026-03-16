`timescale 1ns / 1ps
`default_nettype none



`define W `NUM_ALL_DIGITS //bit width setting

// =============================================================================
// ASSIGNMENT: Pipelined Ray Direction Generator
// File: ray_generator_folded.v
// =============================================================================
//
// OBJECTIVE:
// Given (px, py) — the fixed-point screen coordinates of a pixel — and the
// camera's forward direction vector, compute the normalized 3D ray direction
// that passes through that pixel.
//
// KEY EQUATIONS:
//   cam_right = cross((0, 1, 0), cam_forward)
//           .x =  cam_forward.z
//           .y =  0
//           .z = -cam_forward.x
//
//   cam_up = cross(cam_forward, cam_right)
//         .x = -(cam_forward.y * cam_forward.x)
//         .y =   cam_forward.z² + cam_forward.x²
//         .z = -(cam_forward.y * cam_forward.z)
//
//   rd1 = vec3_add(vec3_add(px*cam_right, py*cam_up), cam_forward)
//   ray_direction = normalize(rd1) = rd1 * inv_sqrt(dot(rd1, rd1))
//   NOTE: negate ray_direction.y (screen Y vs world Y flip)
//
// ARCHITECTURE:
//   This module uses 3 shared multipliers (mult1, mult2, mult3) reused across
//   6 pipeline stages (0→1→2→4→7→5→6→0). The same hardware does different
//   math each stage, saving area vs having separate multipliers everywhere.
//
// STAGE SEQUENCE:
//   Stage 0: Idle / accept input
//   Stage 1: Compute cam_right, cam_up.x, cam_up.y (multiplier: y·(-x), z·z, x·x)
//   Stage 2: Compute cam_up.z                      (multiplier: y·z)
//   Stage 4: Compute scaled_right = cam_right * px  (3 multiplies)
//   Stage 7: Compute scaled_up = cam_up * py         (3 multiplies)
//   Stage 5: Submit to fp_inv_sqrt_folded (wait if busy)
//   Stage 6: Wait for inv_sqrt result, scale rd1, output
//
// See ray_generator_folded_guide.md for full algorithm detail.
// =============================================================================
`include "vector_arith.vh"
`include "types.vh" 
module ray_generator_folded #(
    parameter DISPLAY_WIDTH  = `DISPLAY_WIDTH ,
    parameter DISPLAY_HEIGHT = `DISPLAY_HEIGHT,
    parameter H_BITS         = `H_BITS,
    parameter V_BITS         = `V_BITS
) (
    input  wire clk_in,
    input  wire rst_in,
    input  wire valid_in,                            //valid=1 -> new pixel ready on input
    input  wire [H_BITS-1:0]  hcount_in,             //pixel X coordinate (int)
    input  wire [V_BITS-1:0]  vcount_in,             //pixel Y coordinate (int)
    input  wire [`W-1:0]      hcount_fp_in,          //pixel X coordinate (fp)
    input  wire [`W-1:0]      vcount_fp_in,          //pixel Y coordinate (fp)
    input  wire [3*`W-1:0]    cam_forward_in,        //direction camera is facing (fp vec3)
    output reg                 valid_out,            //ray_direction_out is ready
    output reg                 ready_out,            // module can accept new pixel
    output reg  [3*`W-1:0]    ray_direction_out      //normalized ray vector final (fp vec3)
);

    reg [3:0] stage;

    // Latched inputs (stage 0) : stores pixel details in registers
    reg [H_BITS-1:0] hcount;
    reg [V_BITS-1:0] vcount;
    reg [`W-1:0]     px, py;
    reg [3*`W-1:0]   cam_forward;

    // Computed vectors (all flat [3*W-1:0] bus, X in high bits)
    reg [3*`W-1:0] cam_right;
    reg [3*`W-1:0] cam_up;
    reg [3*`W-1:0] scaled_right;        //px * cam_right
    reg [3*`W-1:0] scaled_up;           //py * cam_up
    reg [3*`W-1:0] rd1;                 //px*cam_right + py*cam_up + cam_forward (not normalised)

    // Combinational rd1 computation (before normalization)
    wire [3*`W-1:0] _rd0, _rd1;
    assign _rd0 = vec3_add(scaled_right, scaled_up);
    assign _rd1 = vec3_add(_rd0, cam_forward);

    // fp_inv_sqrt_folded submodule (to normalize)
    reg  fisf_valid_in;  //fisf = fp_inv_sqrt_folded
    wire fisf_valid_out, fisf_ready_out;
    wire [`W-1:0] fisf_res_out;
    wire [`W-1:0] rd1_dot;
    assign rd1_dot = vec3_dot(rd1, rd1);        // gives x^2 + y^2 + z^2

    fp_inv_sqrt_folded fisf (
        .clk_in    (clk_in),
        .rst_in    (rst_in),
        .a_in      (rd1_dot),
        .valid_in  (fisf_valid_in),
        .res_out   (fisf_res_out),
        .valid_out (fisf_valid_out),
        .ready_out (fisf_ready_out)
    );

    // Three shared fp multipliers — inputs muxed by stage
    reg  [`W-1:0] mult1_a, mult1_b;
    reg  [`W-1:0] mult2_a, mult2_b;
    reg  [`W-1:0] mult3_a, mult3_b;
    wire [`W-1:0] mult1_res, mult2_res, mult3_res;
    assign mult1_res = fp_mul(mult1_a, mult1_b);
    assign mult2_res = fp_mul(mult2_a, mult2_b);
    assign mult3_res = fp_mul(mult3_a, mult3_b);

    // Slices for cam_forward, cam_right, cam_up, rd1

    //cam_forward components
    wire [`W-1:0] cf_x, cf_y, cf_z;                 
    assign cf_x = cam_forward[3*`W-1 : 2*`W];
    assign cf_y = cam_forward[2*`W-1 : `W];
    assign cf_z = cam_forward[`W-1 : 0];

    // cam_right components
    wire [`W-1:0] cr_x, cr_y, cr_z;     //packed into 1 vector [x|y|z]
    assign cr_x = cam_right[3*`W-1 : 2*`W]; 
    assign cr_y = cam_right[2*`W-1 :`W];
    assign cr_z = cam_right[`W-1 : 0];

    // cam_up components
    wire [`W-1:0] cu_x, cu_y, cu_z;
    assign cu_x = cam_up[3*`W-1 : 2*`W];
    assign cu_y = cam_up[2*`W-1 : `W];
    assign cu_z = cam_up[`W-1 : 0];

    // rd1 components
    wire [`W-1:0] rd1_x, rd1_y, rd1_z;
    assign rd1_x = rd1[3*`W-1 : 2*`W];
    assign rd1_y = rd1[2*`W-1 :`W];
    assign rd1_z = rd1[`W-1 :0];

    // =========================================================================
    // Multiplier mux — select inputs based on current stage
    // =========================================================================
    always @(*) begin
        mult1_a = 0; mult1_b = 0;
        mult2_a = 0; mult2_b = 0;
        mult3_a = 0; mult3_b = 0;

        if (stage == 1) begin
            mult1_a = cf_y; mult1_b = fp_neg(cf_x);     // cam_up.y = cam_forward.z² + cam_forward.x²
            mult2_a = cf_z; mult2_b = cf_z;             // cam_up.z = fp_neg(cam_forward.y * cam_forward.z)
            mult3_a = cf_x; mult3_b = cf_x;             // cam_up.x = fp_neg(cam_forward.y * cam_forward.x)

        end else if (stage == 2) begin
            // cam_up.z = fp_neg(cam_forward.y * cam_forward.z)
            mult1_a = cf_y; mult1_b = cf_z;

        end else if (stage == 4) begin
            //scaled_right = cam_right * px (X, Y, Z)
            mult1_a = cr_x; mult1_b = px;
            mult2_a = cr_y; mult2_b = px;
            mult3_a = cr_z; mult3_b = px;

        end else if (stage == 7) begin
            //scaled_up = cam_up * py (X, Y, Z)
            mult1_a = cu_x; mult1_b = py;
            mult2_a = cu_y; mult2_b = py;
            mult3_a = cu_z; mult3_b = py;

        end else if (stage == 6) begin
            //final scale: rd1 * fisf_res_out (X, Y, Z)
            //ray = rd1 * inv_sqrt(rd1 . rd1)
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

        end else if (stage == 0) begin  //IDLE
            valid_out <= 0;
            if (valid_in) begin
                //load values into registers
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
            cam_up[3*`W-1 : 2*`W] <= mult1_res;                     // cam_up.x = -(y*x) (negated in mult1_b)
            cam_up[2*`W-1 : `W] <= fp_add(mult2_res, mult3_res);    // cam_up.y = = z² + x²
            stage <= 2;

        end else if (stage == 2) begin
            cam_up[`W-1 : 0] <= fp_neg(mult1_res);      // cam_up.z = -(fy*fz)
            stage <= 4;

        end else if (stage == 4) begin
            //scaled_right = cam_right * px
            scaled_right <= {mult1_res, mult2_res, mult3_res};
            stage <= 7;

        end else if (stage == 7) begin
            //scaled_up = cam_up * py
            scaled_up = {mult1_res, mult2_res, mult3_res}; //update must be in same cycle bfr stage 5
            stage <= 5;

        end else if (stage == 5 && fisf_ready_out) begin
            //rd1 = scaled_right + scaled_up + cam_forward
            rd1           <= _rd1;
            fisf_valid_in <= 1;
            stage         <= 6;

        end else if (stage == 6) begin
            fisf_valid_in <= 0;          //waits for inv_sqrt output
            if (fisf_valid_out) begin
                // ray_direction_out.x  ← mult1_res
                // ray_direction_out.y  = mult2_res (negated in mult2_b)
                // ray_direction_out.z  ← mult3_res
                ray_direction_out <= {mult1_res, fp_neg(mult2_res), mult3_res}; 
                valid_out <= 1;
                ready_out <= 1;
                stage     <= 0;
            end
        end
    end

endmodule // ray_generator_folded

`default_nettype wire

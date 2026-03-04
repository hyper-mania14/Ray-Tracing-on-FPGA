`timescale 1ns / 1ps

`default_nettype none

`include "vector_arith.vh"
`include "fixed_point_arith.vh"
`include "types.vh"

module ray_generator #(
    parameter DISPLAY_WIDTH = 640,
    parameter DISPLAY_HEIGHT = 480,
    parameter H_BITS = 10,
    parameter V_BITS = 10,
    parameter FP_BITS = 16,
    parameter FP_FRAC = 8
) (
    input wire clk_in,
    input wire rst_in,
    input wire valid_in,
    input wire [H_BITS-1:0] hcount_in,
    input wire [V_BITS-1:0] vcount_in,
    input wire [FP_BITS-1:0] hcount_fp_in,
    input wire [FP_BITS-1:0] vcount_fp_in,
    input wire [3*FP_BITS-1:0] cam_forward_in,
    output wire valid_out,
    output wire ready_out,
    output wire [3*FP_BITS-1:0] ray_direction_out
);

/* ---------------- Control ---------------- */

// 7 Stage pipeline : input -> pixel map -> camera basis -> scale -> add -> normalize -> output
// each state has its own valid and ready bit (to track)

reg v0, v1, v2, v3, v4, v5, v6; //valid bits for each stage
wire r0, r1, r2, r3, r4, r5, r6; //ready bits for each stage

`define READY(n_ready, curr_valid)((n_ready) || !(curr_valid))  // next stage ready or current not valid
assign r6 = ready_out;
assign r5 = `READY(r6, v5);
assign r4 = `READY(r5, v4);
assign r3 = `READY(r4, v3);
assign r2 = `READY(r3, v2);
assign r1 = `READY(r2, v1);
assign r0 = `READY(r1, v0);

assign valid_out = v6;

//here numbers indicate the stage they belong to

  // Stage 0 regs
  reg [FP_BITS-1:0] h0_fp, v0_fp;
  reg [3*FP_BITS-1:0] cam_fwd0;
  // Stage 1 regs
  reg [FP_BITS-1:0] px1, py1;
  reg [3*FP_BITS-1:0] cam_fwd1;
  // Stage 2 regs
  reg [3*FP_BITS-1:0] cam_right2, cam_up2, cam_fwd2;
  reg [FP_BITS-1:0] px2, py2;
  // Stage 3 regs
  reg [3*FP_BITS-1:0] sr3, su3, cam_fwd3;
  // Stage 4 regs
  reg [3*FP_BITS-1:0] ray4;
  // Stage 5 regs
  reg [3*FP_BITS-1:0] ray5;


// Stage 0 : Input
always@(posedge clk_in) begin
    if (rst_in) begin
        v0 <= 1'b0;
    end 
    else if (r1) begin //only if stage 1 ready is issued
        v0 <= valid_in;
        h0_fp <= hcount_fp_in;
        v0_fp <= vcount_fp_in;
        cam_fwd0 <= cam_forward_in;
    end
    //otherwise hold current values
end

// Stage 1: Pixel Mapping
wire [FP_BITS-1:0] twoh = fp_mul_2(h0_fp);
wire [FP_BITS-1:0] twov = fp_mul_2(v0_fp);
wire n_px1 = fp_mul(fp_sub(twoh, `FP_DISPLAY_WIDTH), `FP_INV_DISPLAY_WIDTH) // ((2h - W) / W
wire n_py1 = fp_mul(fp_sub(twov, `FP_DISPLAY_HEIGHT), `FP_INV_DISPLAY_HEIGHT) // ((2v - H) / H

always@(posedge clk_in) begin
    if (rst_in) begin
        v1 <= 1'b0;
    end
    else if (r2) begin
        v1 <= v0;
        px1 <= n_px1;
        py1 <= n_py1;
        cam_fwd1 <= cam_fwd0;
    end
end

// Stage 2: Camera Basis
wire [3*FP_BITS-1:0] ref_up_vector = {`FP_ZERO, `FP_ONE, `FP_ZERO}; // (0,1,0)
wire [3*FP_BITS-1:0] n_cam_right = vec3_normed( vec3_cross( ref_up_vector, cam_fwd1 ) ); // right = normalize( up x forward )
wire [3*FP_BITS-1:0] n_cam_up = vec3_cross( cam_fwd1, n_cam_right ); // up = forward x right

always@(posedge clk_in) begin
    if (rst_in) begin
        v2 <= 1'b0;
    end
    else if (r3) begin
        v2 <= v1;
        cam_fwd2 <= cam_fwd1;
        cam_right2 <= n_cam_right;
        cam_up2 <= n_cam_up;
        px2 <= px1;
        py2 <=py1;
    end
end

// Stage 3: Scaling
wire [3*FP_BITS-1:0] n_sr3 = vec3_scaled(cam_right2, px2); // scaled right vector
wire [3*FP_BITS-1:0] n_su3 = vec3_scaled(cam_up2, py2); // scaled up vector

always@(posedge clk_in) begin
   if (rst_in) begin
    v3 <= 1'b0;
   end
   else if (r4) begin
    v3 <= v2;
    cam_fwd3 <= cam_fwd2;
    su3 <= n_su3;
    sr3 <= n_sr3;
   end
end

// Stage 4: Adding
wire [3*FP_BITS-1:0] n_ray4 = vec3_add (cam_fwd3, vec3_add (sr3, su3)); // ray = forward + scaled_right + scaled_up

always@(posedge clk_in) begin
    if (rst_in) begin
        v4 <= 1'b0;
    end
    else if (r5) begin
        v4 <= v3;
        ray4 <= n_ray4;
    end
end

// Stage 5: Normalisation
wire [3*FP_BITS-1:0] n_ray5 = vec3_normed(ray4); // normalized ray

always@(posedge clk_in) begin
    if (rst_in) begin
        v5 <= 1'b0;
    end
    else if (r6) begin
        v5 <= v4;
        ray5 <= n_ray5;
    end
end

// Stage 6: Output
wire [3*FP_BITS-1:0] ray_direction; // final ray direction reg

always@(posedge clk_in) begin
    if (rst_in) begin
        v6 <= 1'b0;
    end
    else if (ready_out) begin
        v6 <= v5;
        ray_direction <= ray5;
    end
end

assign ray_direction_out = ray_direction;

endmodule

`default_nettype wire
`timescale 1ns / 1ps
`default_nettype none
`include "types.vh"

module march_ray (
    input  wire [3*`W-1:0] ray_origin_in,
    input  wire [3*`W-1:0] ray_direction_in,
    input  wire [`W-1:0]   t_in,
    output wire [3*`W-1:0] ray_origin_out
);
    `include "fixed_point_arith.vh"
    `include "vector_arith.vh"

    wire [3*`W-1:0] scaled_dir;
    assign scaled_dir = vec3_scaled(ray_direction_in, t_in);
    assign ray_origin_out = vec3_add(ray_origin_in, scaled_dir);
endmodule


module brick_texture (
    input  wire [3*`W-1:0] point_in,
    input  wire [6:0]      ray_depth_in, // MAX_RAY_DEPTH=64, 7 bits
    output wire [6:0]      color_out
);
    `include "fixed_point_arith.vh"
    `include "vector_arith.vh"
    wire [3*`W-1:0] scaled_point;
    assign scaled_point = vec3_sl(point_in, 4);
    
    wire [`W-1:0] sp_x, sp_y, sp_z;
    assign sp_x = scaled_point[3*`W-1 : 2*`W];
    assign sp_y = scaled_point[2*`W-1 :   `W];
    assign sp_z = scaled_point[  `W-1 :     0];
    
    wire [`W-1:0] o, u, v, ex, ey;
    assign o = fp_fract(fp_mul_half(fp_floor(fp_sub(sp_y, `FP_HALF))));
    assign u = fp_add(fp_fract(fp_add(fp_mul_half(sp_x), fp_mul_half(sp_z))), o);
    assign v = fp_fract(sp_y);
    
    assign ex = fp_sub(fp_abs(fp_sub(u, `FP_HALF)), `FP_TENTH);
    assign ey = fp_sub(fp_abs(fp_sub(v, `FP_HALF)), `FP_TENTH);
    
    assign color_out = fp_gt(fp_min(ex, ey), `FP_ZERO) ? ray_depth_in - 7'd2 : ray_depth_in;
endmodule

module ray_unit #(
    parameter DISPLAY_WIDTH  = `DISPLAY_WIDTH,
    parameter DISPLAY_HEIGHT = `DISPLAY_HEIGHT,
    parameter H_BITS         = `H_BITS,
    parameter V_BITS         = `V_BITS,
    parameter MAX_RAY_DEPTH  = `MAX_RAY_DEPTH
) (
    input  wire clk_in, rst_in,
    input  wire [3*`W-1:0] ray_origin_in,
    input  wire [3*`W-1:0] ray_direction_in,
    input  wire [2:0]      fractal_sel_in,
    input  wire [H_BITS-1:0] hcount_in,
    input  wire [V_BITS-1:0] vcount_in,
    input  wire [`W-1:0]   hcount_fp_in,
    input  wire [`W-1:0]   vcount_fp_in,
    input  wire            toggle_dither_in,
    input  wire            toggle_texture_in,
    input  wire            valid_in,
    output reg  [H_BITS-1:0] hcount_out,
    output reg  [V_BITS-1:0] vcount_out,
    output reg  [3:0]        color_out,
    output wire              ready_out
);
    `include "fixed_point_arith.vh"
    `include "vector_arith.vh"

    localparam RU_Ready  = 4'd0;
    localparam RU_Setup  = 4'd1;
    localparam RU_Busy_1 = 4'd2;
    localparam RU_Busy_2 = 4'd3;
    reg [3:0] state;

    reg [H_BITS-1:0] hcount;
    reg [V_BITS-1:0] vcount;
    reg [2:0]        current_fractal;
    reg [`W-1:0]     hcount_fp, vcount_fp;
    reg [3*`W-1:0]   ray_origin, ray_direction;
    reg [6:0]        ray_depth;

    // ray_generator_folded signals
    reg              gen_valid_in;
    wire             gen_valid_out, gen_ready_out;
    reg  [3*`W-1:0]  cam_forward_in;
    wire [3*`W-1:0]  ray_direction_out;

    // sdf_query signals
    wire [`W-1:0]    sdf_dist;
    wire [5:0]       sdf_wait_max;
    reg  [5:0]       sdf_wait;

    // texture and color signals
    wire [6:0] texture_out;
    wire [6:0] current_color;
    assign current_color = toggle_texture_in ? texture_out : ray_depth;

    // march_ray output
    wire [3*`W-1:0]  next_pos_vec;

    assign ready_out = (state == RU_Ready);

    ray_generator_folded #(
        .DISPLAY_WIDTH(DISPLAY_WIDTH),
        .DISPLAY_HEIGHT(DISPLAY_HEIGHT),
        .H_BITS(H_BITS),
        .V_BITS(V_BITS)
    ) ray_gen (
        .clk_in(clk_in), .rst_in(rst_in),
        .valid_in(gen_valid_in),
        .hcount_in(hcount), .vcount_in(vcount),
        .hcount_fp_in(hcount_fp), .vcount_fp_in(vcount_fp),
        .cam_forward_in(cam_forward_in),
        .ray_direction_out(ray_direction_out),
        .valid_out(gen_valid_out), .ready_out(gen_ready_out)
    );

    sdf_query scene (
        .clk_in(clk_in), .rst_in(rst_in),
        .point_in(ray_origin),
        .fractal_sel_in(current_fractal),
        .sdf_out(sdf_dist),
        .sdf_wait_max_out(sdf_wait_max)
    );

    brick_texture texture (
        .point_in(ray_origin),
        .ray_depth_in(ray_depth),
        .color_out(texture_out)
    );

    march_ray marcher (
        .ray_origin_in(ray_origin),
        .ray_direction_in(ray_direction),
        .t_in(sdf_dist),
        .ray_origin_out(next_pos_vec)
    );

    wire hit;
    wire miss;
    wire dither_correction;

    assign hit  = fp_lt(sdf_dist, (`FP_HUNDREDTH >> 1));
    assign miss = fp_gt(sdf_dist, `FP_FIVE) || (ray_depth == MAX_RAY_DEPTH);
    // Clamp current_color to 5 bits for the color formula (same as reference MAX_RAY_DEPTH=31 behavior).
    // Depths 0-30 → bright to dark, depths 31-64 → black (fully iterated, near-miss = background).
    wire [4:0] clamped_color = (current_color > 7'd30) ? 5'd30 : current_color[4:0];
    assign dither_correction = ((clamped_color >> 1) != 4'd15) && toggle_dither_in && current_color[0] && (hcount[0] ^ vcount[0]);

    always @(posedge clk_in) begin
        if (rst_in) begin
            state <= RU_Ready;
            gen_valid_in <= 0;
            color_out <= 0;
            hcount_out <= 0;
            vcount_out <= 0;
        end else begin
            case (state)
                RU_Ready: begin
                    if (valid_in) begin
                        hcount <= hcount_in;
                        vcount <= vcount_in;
                        hcount_fp <= hcount_fp_in;
                        vcount_fp <= vcount_fp_in;
                        ray_origin <= ray_origin_in;
                        current_fractal <= fractal_sel_in;
                        ray_depth <= 0;
                        cam_forward_in <= ray_direction_in;
                        gen_valid_in <= 1;
                        state <= RU_Setup;
                    end
                end
                
                RU_Setup: begin
                    gen_valid_in <= 0;
                    if (gen_valid_out) begin
                        ray_direction <= ray_direction_out;
                        sdf_wait <= 0;
                        state <= RU_Busy_1;
                    end
                end
                
                RU_Busy_1: begin
                    sdf_wait <= sdf_wait + 1;
                    if (sdf_wait + 1 == sdf_wait_max) begin
                        state <= RU_Busy_2;
                    end
                end
                
                RU_Busy_2: begin
                    ray_origin <= next_pos_vec;
                    if (hit || miss) begin
                        color_out <= hit ? (4'hF - (clamped_color >> 1) - dither_correction) : 4'd0;
                        hcount_out <= hcount;
                        vcount_out <= vcount;
                        state <= RU_Ready;
                    end else begin
                        ray_depth <= ray_depth + 1;
                        sdf_wait <= 0;
                        state <= RU_Busy_1;
                    end
                end
            endcase
        end
    end

endmodule

`default_nettype wire

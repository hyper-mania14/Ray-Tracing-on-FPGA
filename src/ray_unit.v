
`include "types.vh"
`include "vector_arith.vh"
`include "fixed_point_arith.vh"

module march_ray (
    input  wire [3*`W-1:0] ray_origin_in,     // current position (vec3)
    input  wire [3*`W-1:0] ray_direction_in,  // ray direction (vec3)
    input  wire [`W-1:0]   t_in,              // step distance (fp)
    output wire [3*`W-1:0] ray_origin_out     // new position (vec3)
);

wire scaled_dir [3*`W-1:0];
assign scaled_dir    = vec3_scaled(ray_direction_in, t_in)
assign ray_origin_out = vec3_add(ray_origin_in, scaled_dir)

endmodule

module brick_texture (
    input  wire [3*`W-1:0] point_in,    // surface point (vec3)
    input  wire [`MAX_RAY_DEPTH_SIZE-1:0] ray_depth_in,
    output wire [`MAX_RAY_DEPTH_SIZE-1:0] color_out
);

wire scaled_point [3*`W-1:0];
assign scaled_point = vec3_sl(point_in, 4); //16x scale for more detailed pattern
// slicing into components
wire [`W-1:0] scaled_point.x, scaled_point.y, scaled_point.z;
assign scaled_point.x = scaled_point[3*`W-1 : 2*`W];
assign scaled_point.y = scaled_point[2*`W-1 : `W];
assign scaled_point.z = scaled_point[`W-1 : 0];

//defining mortar offset (for alternating brick row offset)
wire [`W-1:0] m_offset;
assign m_offset = fp_fract(fp_mul_half(fp_floor(fp_sub(scaled_point.y, FP_HALF))));

//uv coordinates for brick pattern
wire [`W-1:0] u, v;
assign u = fp_add(fp_fract(fp_add(fp_mul_half(scaled_point.x), fp_mul_half(scaled_point.z))), m_offset);
assign v = fp_fract(scaled_point.y);

//signed distance to brick edge (negative inside mortar)
wire [`W-1:0] ex, ey;
assign ex = fp_sub(fp_abs(fp_sub(u, FP_HALF)), FP_TENTH);
assign ey = fp_sub(fp_abs(fp_sub(v, FP_HALF)), FP_TENTH);

//if both ex and ey are positive, we're in the brick and need to reduce depth by 2
assign color_out = (fp_min (ex, ey) > 0) ? (ray_depth_in - 2) : ray_depth_in;

endmodule

module ray_unit #(
    parameter DISPLAY_WIDTH  = `DISPLAY_WIDTH,
    parameter DISPLAY_HEIGHT = `DISPLAY_HEIGHT,
    parameter H_BITS         = `H_BITS,
    parameter V_BITS         = `V_BITS,
    parameter MAX_RAY_DEPTH  = `MAX_RAY_DEPTH
) (
    input  wire clk_in, rst_in,
    input  wire [3*`W-1:0] ray_origin_in,      // camera position
    input  wire [3*`W-1:0] ray_direction_in,   // camera forward direction
    input  wire [2:0] fractal_sel_in,
    input  wire [H_BITS-1:0] hcount_in,
    input  wire [V_BITS-1:0] vcount_in,
    input  wire [`W-1:0] hcount_fp_in,
    input  wire [`W-1:0] vcount_fp_in,
    input  wire toggle_dither_in,
    input  wire toggle_texture_in,
    input  wire valid_in,
    output reg  [H_BITS-1:0] hcount_out,
    output reg  [V_BITS-1:0] vcount_out,
    output reg  [3:0] color_out,
    output wire  ready_out
);

//Ray Unit machine states
localparam RU_Ready  = 4'd0;   // Waiting for valid_in
localparam RU_Setup  = 4'd1;   // Ray generator running
localparam RU_Busy_1 = 4'd2;   // Waiting for SDF pipeline latency
localparam RU_Busy_2 = 4'd3;   // SDF done, make decision
reg [3:0] state;

//Internal registers
reg [H_BITS-1:0] hcount;
reg [V_BITS-1:0] vcount;
reg [2:0]        current_fractal;
reg [`W-1:0]     hcount_fp, vcount_fp;
reg [3*`W-1:0]   ray_origin, ray_direction;
reg [`MAX_RAY_DEPTH_SIZE-1:0] ray_depth;
reg dither_correction, hit, miss;

// ray_generator_folded
reg              gen_valid_in;
wire             gen_valid_out, gen_ready_out;
reg  [3*`W-1:0]  cam_forward_in;
wire [3*`W-1:0]  ray_direction_out;

// sdf_query
wire [`W-1:0]    sdf_dist;
wire [5:0]       sdf_wait_max;
reg  [5:0]       sdf_wait;

// texture and color
wire [`MAX_RAY_DEPTH_SIZE-1:0] texture_out;
wire [`MAX_RAY_DEPTH_SIZE-1:0] current_color;
assign current_color = toggle_texture_in ? texture_out : ray_depth;

// march_ray output
wire [3*`W-1:0]  next_pos_vec;

assign ready_out = (state == RU_Ready);

// State logic
always@(posedge clk ) begin
    case(state)
        RU_Ready: begin
            if(valid_in) begin
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
           if ((sdf_wait + 1'd1 )== sdf_wait_max) begin
                state <= RU_Busy_2;
           end
           else begin
                state <= RU_Busy_1;
           end
        end
        RU_Busy_2: begin
            ray_origin <= next_pos_vec;
            hit <= (sdf_dist < (FP_HUNDREDTH >>1)) ? 1 : 0;
            miss <= ((sdf_dist > FP_FIVE)|| (ray_depth >= MAX_RAY_DEPTH)) ? 1 : 0;
            if (hit || miss) begin
                dither_correction <= ((current_color >> 1) != 4'hF && toggle_dither_in && current_color[0] && (hcount[0] ^ vcount[0])) ? 1 : 0);
                color_out <= hit ? (4'hF - (current_color >> 1) - dither_correction) : 4'd0;
                hcount_out <= hcount;  
                vcount_out <= vcount;
                state <= RU_Ready;
            end    
            else begin
                    ray_depth <= ray_depth + 1;
                    sdf_wait <= 0;
                    state <= RU_Busy_1;
            end
        end
    endcase

end

//module instantiations
ray_generator_folded #(
    parameter DISPLAY_WIDTH  = `DISPLAY_WIDTH ,
    parameter DISPLAY_HEIGHT = `DISPLAY_HEIGHT,
    parameter H_BITS         = `H_BITS,
    parameter V_BITS         = `V_BITS
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

endmodule
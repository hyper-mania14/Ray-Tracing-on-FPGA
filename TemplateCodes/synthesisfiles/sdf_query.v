`timescale 1ns / 1ps
`default_nettype none
`include "types.vh"

module sdf_query_cube (
    input  wire clk_in,
    input  wire rst_in,
    input  wire [3*`W-1:0] point_in,
    output reg  [`W-1:0] sdf_out
);
    `include "fixed_point_arith.vh"
    `include "vector_arith.vh"
    `include "sdf_primitives.vh"
    always @(posedge clk_in) begin
        sdf_out <= sd_box_fast(point_in, `FP_HALF);
    end
endmodule

module sdf_query_cube_infinite (
    input  wire clk_in,
    input  wire rst_in,
    input  wire [3*`W-1:0] point_in,
    output reg  [`W-1:0] sdf_out
);
    `include "fixed_point_arith.vh"
    `include "vector_arith.vh"
    `include "sdf_primitives.vh"
    wire [3*`W-1:0] hhh;
    assign hhh = make_vec3(`FP_HALF, `FP_HALF, `FP_HALF);
    
    always @(posedge clk_in) begin
        sdf_out <= sd_box_fast(vec3_sub(vec3_fract(vec3_add(point_in, hhh)), hhh), `FP_QUARTER);
    end
endmodule

module sdf_query_sponge #(
    parameter ITERATIONS = 3
)(
    input  wire clk_in,
    input  wire rst_in,
    input  wire [3*`W-1:0] point_in,
    output wire [`W-1:0] sdf_out
);
`include "fixed_point_arith.vh"
`include "vector_arith.vh"
`include "sdf_primitives.vh"
    wire [`W-1:0] scales     [0:4];
    wire [`W-1:0] inv_scales [0:4];
    assign scales[0] = `FP_ONE;       assign inv_scales[0] = `FP_ONE;
    assign scales[1] = `FP_THREE;     assign inv_scales[1] = `FP_THIRD;
    assign scales[2] = `FP_NINE;      assign inv_scales[2] = `FP_NINTH;
    assign scales[3] = `FP_TWENTY_SEVEN;  assign inv_scales[3] = `FP_TWENTY_SEVENTH;
    assign scales[4] = `FP_EIGHTY_ONE;    assign inv_scales[4] = `FP_EIGHTY_ONETH;

    reg [`W-1:0] distances [0:3];
    wire [3*`W-1:0] hhh;
    assign hhh = make_vec3(`FP_ONE, `FP_ONE, `FP_ONE);
    wire [`W-1:0] bounds;
    assign bounds = sd_box_fast(point_in, `FP_ONE);

    // Initial state is just comb output of bounds if iteration was 0, but logic uses `distances`.
    // The guide provides this loop:
    generate
        genvar i;
        for (i = 1; i < ITERATIONS + 1; i = i + 1) begin : sponge_loop
            wire [3*`W-1:0] a, r;
            assign a = vec3_sub(
                vec3_sl(vec3_fract(vec3_sr(vec3_scaled(point_in, scales[i-1]), 1)), 1),
                hhh);
            assign r = vec3_abs(vec3_sub(hhh, vec3_scaled_3(vec3_abs(a))));
            always @(posedge clk_in) begin
                distances[i] <= fp_max(
                    i == 1 ? bounds : distances[i-1],
                    fp_mul(
                        fp_sub(fp_min(fp_max(r[3*`W-1:2*`W], r[2*`W-1:`W]),
                                      fp_min(fp_max(r[2*`W-1:`W], r[`W-1:0]),
                                             fp_max(r[3*`W-1:2*`W], r[`W-1:0]))),
                               `FP_ONE),
                        inv_scales[i]));
            end
        end
    endgenerate
    assign sdf_out = distances[ITERATIONS];
endmodule

module sdf_query_sponge_inf (
    input  wire clk_in,
    input  wire rst_in,
    input  wire [3*`W-1:0] point_in,
    output reg  [`W-1:0] sdf_out
);
`include "fixed_point_arith.vh"
`include "vector_arith.vh"
`include "sdf_primitives.vh"
    function [`W-1:0] mmp;
        input [3*`W-1:0] v;
        begin
            mmp = fp_min(fp_max(v[3*`W-1:2*`W], v[2*`W-1:`W]),  
                  fp_min(fp_max(v[2*`W-1:`W], v[`W-1:0]), 
                         fp_max(v[3*`W-1:2*`W], v[`W-1:0])));
        end
    endfunction

    wire [3*`W-1:0] p1, p2, p3, p4;
    wire [`W-1:0] d1_, d2_, d3_, sdf_out_;
    
    reg [`W-1:0] d1, d2, d3;

    // Layer 1
    assign p1 = vec3_abs(vec3_sub(
             vec3_sl(vec3_fract(vec3_sr(point_in, 1)), 1),
             make_vec3(`FP_ONE, `FP_ONE, `FP_ONE)));
    assign d1_ = fp_add(mmp(p1), `FP_MAGIC_NUMBER_A);

    // Layer 2
    assign p2 = vec3_abs(vec3_sub(vec3_fract(point_in), make_vec3(`FP_HALF, `FP_HALF, `FP_HALF)));
    assign d2_ = fp_max(d1, fp_add(mmp(p2), `FP_MAGIC_NUMBER_B));

    // Layer 3
    assign p3 = vec3_abs(vec3_sub(
             vec3_sr(vec3_fract(vec3_sl(point_in, 1)), 1),
             make_vec3(`FP_QUARTER, `FP_QUARTER, `FP_QUARTER)));
    assign d3_ = fp_max(d2, fp_add(mmp(p3), `FP_MAGIC_NUMBER_C));

    // Layer 4
    assign p4 = vec3_abs(vec3_sub(
             vec3_sr(vec3_fract(vec3_sl(point_in, 3)), 3),
             make_vec3(`FP_ONE_SIXTEENTHS, `FP_ONE_SIXTEENTHS, `FP_ONE_SIXTEENTHS)));
    assign sdf_out_ = fp_max(d3, fp_add(mmp(p4), `FP_MAGIC_NUMBER_D));

    always @(posedge clk_in) begin
        if (rst_in) begin
            d1 <= 0;
            d2 <= 0;
            d3 <= 0;
            sdf_out <= 0;
        end else begin
            d1 <= d1_;
            d2 <= d2_;
            d3 <= d3_;
            sdf_out <= sdf_out_;
        end
    end
endmodule

module sdf_query_cube_noise (
    input  wire clk_in,
    input  wire rst_in,
    input  wire [3*`W-1:0] point_in,
    output reg  [`W-1:0] sdf_out
);
    `include "fixed_point_arith.vh"
    `include "vector_arith.vh"
    `include "sdf_primitives.vh"
    reg [3*`W-1:0] poke_s2, poke_s3, poke_s4, poke_s5;
    reg [3*`W-1:0] cube_s2, cube_s3;

    // Stage 1
    wire [3*`W-1:0] hhh = make_vec3(`FP_HALF, `FP_HALF, `FP_HALF);
    wire [3*`W-1:0] cube = vec3_add(vec3_floor(point_in), hhh);
    wire [3*`W-1:0] poke = vec3_sub(point_in, cube);
    wire [3*`W-1:0] _octa1 = vec3_abs(poke);
    reg  [3*`W-1:0] octa1;

    // Stage 2
    wire [3*`W-1:0] octa2 = vec3_step(make_vec3(octa1[2*`W-1:`W], octa1[`W-1:0], octa1[3*`W-1:2*`W]), octa1);
    wire [3*`W-1:0] octa3 = vec3_step(make_vec3(octa1[`W-1:0], octa1[3*`W-1:2*`W], octa1[2*`W-1:`W]), octa1);
    wire [3*`W-1:0] _octa4 = octa2 & octa3;
    reg  [3*`W-1:0] octa4;

    // Stage 3
    wire [3*`W-1:0] _id = vec3_add(cube_s3, vec3_apply_sign(vec3_scaled_half(octa4), poke_s3));
    reg  [3*`W-1:0] id;

    // Stage 4
    wire [`W-1:0] _hash = fp_fract(vec3_dot(id, make_vec3(`FP_THREE_HALFS, `FP_THIRD, `FP_QUARTER)));
    reg  [`W-1:0] hash;

    // Stage 5
    wire [`W-1:0] p_x = poke_s5[3*`W-1:2*`W];
    wire [`W-1:0] p_y = poke_s5[2*`W-1:`W];
    wire [`W-1:0] p_z = poke_s5[`W-1:0];

    wire [`W-1:0] hash_y = fp_gt(hash, `FP_HALF) ? p_x : p_y;
    wire [`W-1:0] x = fp_abs(fp_gt(hash, `FP_THIRD) ? hash_y : p_x);

    wire [`W-1:0] hash_y2 = fp_gt(hash, `FP_HALF) ? p_z : p_z; // note: guide had p_z : p_z which is odd but directly transcribed
    wire [`W-1:0] y = fp_abs(fp_gt(hash, `FP_THIRD) ? hash_y2 : p_y);

    wire [`W-1:0] _sdf_out = fp_sub(fp_max(x, y), `FP_ONE_SIXTEENTHS);

    always @(posedge clk_in) begin
        if (rst_in) begin
            poke_s2 <= 0; poke_s3 <= 0; poke_s4 <= 0; poke_s5 <= 0;
            cube_s2 <= 0; cube_s3 <= 0;
            octa1 <= 0; octa4 <= 0; id <= 0; hash <= 0; sdf_out <= 0;
        end else begin
            // Stage 1 -> 2
            octa1 <= _octa1;
            poke_s2 <= poke;
            cube_s2 <= cube;

            // Stage 2 -> 3
            octa4 <= _octa4;
            poke_s3 <= poke_s2;
            cube_s3 <= cube_s2;

            // Stage 3 -> 4
            id <= _id;
            poke_s4 <= poke_s3;

            // Stage 4 -> 5
            hash <= _hash;
            poke_s5 <= poke_s4;

            // Stage 5 -> out
            sdf_out <= _sdf_out;
        end
    end
endmodule

module sdf_query (
    input  wire clk_in,
    input  wire rst_in,
    input  wire [3*`W-1:0] point_in,
    input  wire [2:0]      fractal_sel_in,
    output wire [`W-1:0]   sdf_out,
    output reg  [5:0]      sdf_wait_max_out
);
    `include "fixed_point_arith.vh"
    `include "vector_arith.vh"
    `include "sdf_primitives.vh"
    wire [`W-1:0] sdf_queries [0:3];

    sdf_query_sponge_inf f0 (
        .clk_in(clk_in), .rst_in(rst_in), .point_in(point_in), .sdf_out(sdf_queries[0])
    );
    sdf_query_cube_infinite f1 (
        .clk_in(clk_in), .rst_in(rst_in), .point_in(point_in), .sdf_out(sdf_queries[1])
    );
    sdf_query_cube f2 (
        .clk_in(clk_in), .rst_in(rst_in), .point_in(point_in), .sdf_out(sdf_queries[2])
    );
    sdf_query_cube_noise f3 (
        .clk_in(clk_in), .rst_in(rst_in), .point_in(point_in), .sdf_out(sdf_queries[3])
    );

    assign sdf_out = sdf_queries[fractal_sel_in[1:0]]; // Use lower 2 bits to stay in 0..3 bounds

    always @(*) begin
        case (fractal_sel_in)
            0: sdf_wait_max_out = 4;
            1: sdf_wait_max_out = 1;
            2: sdf_wait_max_out = 1;
            3: sdf_wait_max_out = 5;
            default: sdf_wait_max_out = 1;
        endcase
    end
endmodule

`default_nettype wire

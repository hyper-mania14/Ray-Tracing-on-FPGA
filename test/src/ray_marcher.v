`timescale 1ns / 1ps
`default_nettype none
`include "types.vh"

`ifndef TESTING_RAY_MARCHER
`define RAY_UNIT_TYPE ray_unit
`define USE_CHECKERBOARD_RENDERING
`else
`define RAY_UNIT_TYPE ray_unit_dummy
`endif

module ray_marcher #(
    parameter DISPLAY_WIDTH  = `DISPLAY_WIDTH,
    parameter DISPLAY_HEIGHT = `DISPLAY_HEIGHT,
    parameter H_BITS         = `H_BITS,
    parameter V_BITS         = `V_BITS,
    parameter COLOR_BITS     = `COLOR_BITS,
    parameter NUM_CORES      = `NUM_CORES
) (
    input  wire clk_in, rst_in,
    input  wire [3*`W-1:0] pos_vec_in,
    input  wire [3*`W-1:0] dir_vec_in,
    input  wire toggle_checker_in,
    input  wire toggle_dither_in,
    input  wire toggle_texture_in,
    input  wire [2:0] fractal_sel_in,
    output reg  [H_BITS-1:0] hcount_out,
    output reg  [V_BITS-1:0] vcount_out,
    output reg  [3:0]        color_out,
    output reg               valid_out,
    output reg               new_frame_out
);


    `include "fixed_point_arith.vh"
    `include "vector_arith.vh"

`ifdef USE_CHECKERBOARD_RENDERING
    reg        checker_bit;
    reg  [1:0] checker_frame;
`endif


    wire [H_BITS-1:0]     core_hcount_out [0:NUM_CORES-1];
    wire [V_BITS-1:0]     core_vcount_out [0:NUM_CORES-1];
    wire [COLOR_BITS-1:0] core_color_out  [0:NUM_CORES-1];
    wire [NUM_CORES-1:0]  core_ready_out;

    wire all_cores_ready;
    assign all_cores_ready = &core_ready_out;

    reg assigning;
    reg [4:0] assign_to;

    reg [3*`W-1:0] current_pos_vec, current_dir_vec;
    reg [2:0] current_fractal;

    reg [H_BITS-1:0] hcount, assign_hcount;
    reg [V_BITS-1:0] vcount, assign_vcount;
    reg [`W-1:0] hcount_fp, vcount_fp, assign_hcount_fp, assign_vcount_fp;

    reg [4:0] core_idx;

    generate
        genvar i;
        for (i = 0; i < NUM_CORES; i = i + 1) begin : ray_marcher_core_decl
            `RAY_UNIT_TYPE #(
                .DISPLAY_WIDTH(DISPLAY_WIDTH),
                .DISPLAY_HEIGHT(DISPLAY_HEIGHT),
                .H_BITS(H_BITS), .V_BITS(V_BITS)
            ) ray_unit_inst (
                .clk_in          (clk_in),
                .rst_in          (rst_in),
                .ray_origin_in   (current_pos_vec),
                .ray_direction_in(current_dir_vec),
                .fractal_sel_in  (current_fractal),
                .hcount_in       (assign_hcount),
                .hcount_fp_in    (assign_hcount_fp),
                .vcount_in       (assign_vcount),
                .vcount_fp_in    (assign_vcount_fp),
                .toggle_dither_in(toggle_dither_in),
                .toggle_texture_in(toggle_texture_in),
                .valid_in        (assign_to == i && assigning),
                .hcount_out      (core_hcount_out[i]),
                .vcount_out      (core_vcount_out[i]),
                .color_out       (core_color_out[i]),
                .ready_out       (core_ready_out[i])
            );
        end
    endgenerate

    always @(posedge clk_in) begin
        if (rst_in) begin
            hcount           <= 0;
            hcount_fp        <= `FP_HCOUNT_FP_START;
            vcount           <= DISPLAY_HEIGHT;
            new_frame_out    <= 0;
            assigning        <= 0;
            core_idx         <= 0;
`ifdef USE_CHECKERBOARD_RENDERING
            checker_bit      <= 0;
            checker_frame    <= 0;
`endif
        end else begin
            if (vcount == DISPLAY_HEIGHT) begin
                assigning <= 0;
                if (all_cores_ready) begin
                    current_pos_vec <= pos_vec_in;
                    current_dir_vec <= dir_vec_in;
                    current_fractal <= fractal_sel_in;
                    hcount          <= 0;
                    hcount_fp       <= `FP_HCOUNT_FP_START;
                    vcount          <= 0;
                    vcount_fp       <= `FP_VCOUNT_FP_START;
                    new_frame_out   <= 1;
`ifdef USE_CHECKERBOARD_RENDERING
                    checker_bit     <= checker_frame[0] ^ checker_frame[1];
                    checker_frame   <= checker_frame + 1;
`endif
                end
            end else if (hcount == DISPLAY_WIDTH) begin
                vcount          <= vcount + 1;
                vcount_fp       <= fp_add(vcount_fp, `FP_VCOUNT_FP_INCREMENT);
                hcount          <= 0;
                hcount_fp       <= `FP_HCOUNT_FP_START;
                assigning       <= 0;
`ifdef USE_CHECKERBOARD_RENDERING
                checker_bit     <= ~checker_bit;
`endif
            end else begin
                new_frame_out <= 0;
                if (core_ready_out[core_idx]) begin
                    assign_to        <= core_idx;
                    assign_hcount    <= hcount;
                    assign_hcount_fp <= hcount_fp;
                    assign_vcount    <= vcount;
                    assign_vcount_fp <= vcount_fp;
                    hcount           <= hcount + 1;
                    hcount_fp        <= fp_add(hcount_fp, `FP_HCOUNT_FP_INCREMENT);
`ifdef USE_CHECKERBOARD_RENDERING
                    checker_bit      <= ~checker_bit;
                    assigning        <= checker_bit | ~toggle_checker_in;
`else
                    assigning        <= 1;
`endif
                end else begin
                    assigning        <= 0;
                end
            end

            core_idx <= (core_idx + 1 == NUM_CORES) ? 0 : core_idx + 1;
        end
    end

    always @(posedge clk_in) begin
        if (rst_in) begin
            valid_out  <= 0;
            hcount_out <= 0;
            vcount_out <= 0;
            color_out  <= 0;
        end else begin
            // Only emit a pixel when the core selected by core_idx is ready.
            if (core_ready_out[core_idx]) begin
                hcount_out <= core_hcount_out[core_idx];
                vcount_out <= core_vcount_out[core_idx];
                color_out  <= core_color_out[core_idx];
                valid_out  <= 1;
            end else begin
                valid_out  <= 0;
            end
        end
    end

endmodule

`default_nettype wire

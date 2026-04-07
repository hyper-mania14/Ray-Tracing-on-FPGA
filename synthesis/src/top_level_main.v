// =============================================================================
// top_level_main.v — Main System Wiring (Simplified, No Ethernet, No User Control)
//
// Connects:
//   Clock Wizard   →  40 MHz system/VGA clock
//   Fixed camera   →  raytracer_top (ray_marcher → bram_manager → vga_display)
//   fps_counter    →  bin2bcd → seven_segment_controller
//   Switches       →  fractal selection & render toggles
//   LEDs           →  FPS readout
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

`include "types.vh"

module top_level_main (
    input  wire        clk_100mhz,
    input  wire        cpu_resetn,
    input  wire [15:0] sw,
    output reg  [15:0] led,
    output wire [3:0]  vga_r, vga_g, vga_b,
    output wire        vga_hs, vga_vs,
    output wire        ca, cb, cc, cd, ce, cf, cg,
    output wire [7:0]  an
);

    // =========================================================================
    // RESET
    // =========================================================================
    wire sys_rst;
    assign sys_rst = ~cpu_resetn;  // cpu_resetn is active-low on Nexys4 DDR

    // =========================================================================
    // CLOCK GENERATION — 100 MHz → 40 MHz (VGA) + 50 MHz (unused)
    // =========================================================================
    wire sys_clk;  // 40 MHz — used for ray marcher, VGA, and all display logic
    wire clk_50mhz_unused;

    clk_100_to_40_and_50_mhz_clk_wiz clk_conv (
        .clk_100mhz_in (clk_100mhz),
        .clk_40mhz_out (sys_clk),
        .clk_50mhz_out (clk_50mhz_unused),
        .reset          (sys_rst),
        .locked         ()
    );

    // =========================================================================
    // FIXED CAMERA (replaces user_control — skip for now)
    // =========================================================================
    // Default position: (x=0, y=1, z=-1.5)
    // Default direction: (x=0, y=0, z=1)
    //
    // vec3 packing: {X, Y, Z}  (X=MSBs, Z=LSBs)
    // FP format: 6 whole bits + 16 fractional bits = 22 bits per component
    //
    // FP_ZERO         = 22'h000000
    // FP_ONE          = 22'h010000  (1.0)
    // -FP_THREE_HALFS = -1.5 → two's complement of 22'h018000 = 22'h3E8000

    wire [3*`W-1:0] pos_vec;
    wire [3*`W-1:0] dir_vec;

    // Position: (0.0, 1.0, -1.5)
    assign pos_vec = {
        `FP_ZERO,                                    // X = 0.0
        `FP_ONE,                                     // Y = 1.0
        (~(`FP_ONE + (`FP_ONE >>> 1)) + 1'b1)        // Z = -1.5 (negate 1.5)
    };

    // Direction: (0.0, 0.0, 1.0)
    assign dir_vec = {
        `FP_ZERO,   // X = 0.0
        `FP_ZERO,   // Y = 0.0
        `FP_ONE     // Z = 1.0
    };

    // =========================================================================
    // SWITCH MAPPING
    // =========================================================================
    wire [2:0] fractal_sel;
    wire       toggle_hue, toggle_color;
    wire       toggle_checker, toggle_dither, toggle_texture;

    assign fractal_sel     = sw[15:13];
    assign toggle_hue      = sw[4];
    assign toggle_color    = sw[5];
    assign toggle_checker  = sw[12];
    assign toggle_dither   = sw[11];
    assign toggle_texture  = sw[10];

    // =========================================================================
    // RAYTRACER — ray_marcher → bram_manager → vga_display
    // =========================================================================
    wire ray_marcher_new_frame;

    raytracer_top u_raytracer (
        .clk_in            (sys_clk),        // 40 MHz for ray marcher
        .vga_clk_in        (sys_clk),        // 40 MHz for VGA display
        .rst_in            (sys_rst),
        .pos_vec_in        (pos_vec),
        .dir_vec_in        (dir_vec),
        .fractal_sel_in    (fractal_sel),
        .toggle_checker_in (toggle_checker),
        .toggle_dither_in  (toggle_dither),
        .toggle_texture_in (toggle_texture),
        .toggle_hue_in     (toggle_hue),
        .toggle_color_in   (toggle_color),
        .vga_r             (vga_r),
        .vga_g             (vga_g),
        .vga_b             (vga_b),
        .vga_hs            (vga_hs),
        .vga_vs            (vga_vs)
    );

    // =========================================================================
    // FPS COUNTER + 7-SEGMENT DISPLAY
    // =========================================================================
    // We need new_frame signal from raytracer_top — but it's internal.
    // WORKAROUND: tap it from the ray_marcher inside raytracer_top.
    // For now, we add an output port to raytracer_top for new_frame_out.
    // (See raytracer_top modifications)

    // Since raytracer_top doesn't expose new_frame_out yet, we'll track it
    // via a frame counter using vga_vs as a proxy for new frames.
    reg vga_vs_prev;
    reg new_frame_pulse;
    always @(posedge sys_clk) begin
        if (sys_rst) begin
            vga_vs_prev     <= 0;
            new_frame_pulse <= 0;
        end else begin
            vga_vs_prev     <= vga_vs;
            new_frame_pulse <= vga_vs && !vga_vs_prev;  // rising edge of vsync
        end
    end

    wire [31:0] fps;
    wire [12:0] fps_bcd;   // W=10 → BCD width = W + (W-4)/3 = 10 + 2 = 12, so [12:0]

    fps_counter fps_counter_inst (
        .clk_in       (sys_clk),
        .rst_in       (sys_rst),
        .new_frame_in (new_frame_pulse),
        .fps_out      (fps)
    );

    bin2bcd #(.W(10)) bin2bcd_inst (
        .bin (fps[9:0]),
        .bcd (fps_bcd)
    );

    wire [6:0] seg_cat;
    seven_segment_controller mssc (
        .clk_in  (sys_clk),
        .rst_in  (sys_rst),
        .val_in  ({19'b0, fps_bcd}),
        .cat_out (seg_cat),
        .an_out  (an)
    );

    assign {cg, cf, ce, cd, cc, cb, ca} = seg_cat;

    // =========================================================================
    // LED OUTPUT — show FPS value on LEDs
    // =========================================================================
    always @(posedge sys_clk) begin
        if (sys_rst)
            led <= 16'b0;
        else
            led <= fps[15:0];
    end

endmodule // top_level_main

`default_nettype wire

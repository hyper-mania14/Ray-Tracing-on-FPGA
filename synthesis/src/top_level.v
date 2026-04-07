// =============================================================================
// top_level.v — Board-Level Top Module for Nexys4 DDR
//
// Simplified version (no Ethernet, no user control).
// Dispatches to top_level_main which contains all system wiring.
//
// This module name matches the XDC constraints file port names.
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

`include "types.vh"

module top_level (
    input  wire        clk_100mhz,
    input  wire        cpu_resetn,
    input  wire [15:0] sw,
    output wire [15:0] led,
    output wire [3:0]  vga_r, vga_g, vga_b,
    output wire        vga_hs, vga_vs,
    output wire        ca, cb, cc, cd, ce, cf, cg,
    output wire [7:0]  an
);

    top_level_main top_level_main_inst (
        .clk_100mhz (clk_100mhz),
        .cpu_resetn  (cpu_resetn),
        .sw          (sw),
        .led         (led),
        .vga_r       (vga_r),
        .vga_g       (vga_g),
        .vga_b       (vga_b),
        .vga_hs      (vga_hs),
        .vga_vs      (vga_vs),
        .ca          (ca),
        .cb          (cb),
        .cc          (cc),
        .cd          (cd),
        .ce          (ce),
        .cf          (cf),
        .cg          (cg),
        .an          (an)
    );

endmodule // top_level

`default_nettype wire

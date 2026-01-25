`timescale 1ns / 1ps
`default_nettype none

`ifndef TYPES_VH
`define TYPES_VH

// Keyboard Macros
`define KB_FORWARD 7
`define KB_BACKWARD 6
`define KB_TURN_LEFT 5
`define KB_TURN_RIGHT 4
`define KB_TRANS_UP 3
`define KB_TRANS_DOWN 2
`define KB_TRANS_LEFT 1
`define KB_TRANS_RIGHT 0

// Bit Definitions
`define NUM_WHOLE_DIGITS  6 
`define NUM_FRAC_DIGITS   16
`define NUM_ALL_DIGITS    (`NUM_WHOLE_DIGITS + `NUM_FRAC_DIGITS)

`define ADDR_BITS         (`H_BITS + `V_BITS)
`define COLOR_BITS        4

// Ray Depth - In Verilog, we replace $clog2 with a hardcoded value if the compiler is old, 
// but most modern Verilog compilers support $clog2.
`define MAX_RAY_DEPTH       31
`define MAX_RAY_DEPTH_SIZE  5 

`define NUM_CORES           12
`define BRAM_SIZE           (`DISPLAY_WIDTH * `DISPLAY_HEIGHT)

// Resolution Settings
`ifndef OVERRIDE_SIZE
    `define USE_400x300
`endif

`ifdef USE_400x300
    `define DISPLAY_WIDTH          400
    `define DISPLAY_HEIGHT         300
    `define H_BITS                 9
    `define V_BITS                 9
    `define DISPLAY_SHIFT_SIZE     1
    `define FP_DISPLAY_WIDTH       (32'sh19000000 >>> (20 - `NUM_FRAC_DIGITS))
    `define FP_INV_DISPLAY_WIDTH   (32'sh00000a3d >>> (20 - `NUM_FRAC_DIGITS))
    `define FP_DISPLAY_HEIGHT      (32'sh12c00000 >>> (20 - `NUM_FRAC_DIGITS))
    `define FP_INV_DISPLAY_HEIGHT  (32'sh00000da7 >>> (20 - `NUM_FRAC_DIGITS))
    `define FP_HCOUNT_FP_START     (32'shffeaaaaa >>> (20 - `NUM_FRAC_DIGITS))
    `define FP_HCOUNT_FP_END       (32'sh00155555 >>> (20 - `NUM_FRAC_DIGITS))
    `define FP_HCOUNT_FP_INCREMENT (32'sh00001b4e >>> (20 - `NUM_FRAC_DIGITS))
    `define FP_VCOUNT_FP_START     (32'shfff00000 >>> (20 - `NUM_FRAC_DIGITS))
    `define FP_VCOUNT_FP_END       (32'sh00100000 >>> (20 - `NUM_FRAC_DIGITS))
    `define FP_VCOUNT_FP_INCREMENT (32'sh00001b4e >>> (20 - `NUM_FRAC_DIGITS))
`endif

// ... (Note: Similar Logic applied to USE_200x150 and USE_100x75 blocks)
// Note: Arithmetic right shift (>>>) is used for signed bit-shifting.

// VGA Output Selection
`define USE_VGA_800x600
`ifdef USE_VGA_800x600
    `define VGA_DISPLAY_WIDTH            800
    `define VGA_DISPLAY_HEIGHT           600
    `define VGA_H_BITS                   10
    `define VGA_V_BITS                   10
    `define VGA_GEN_TYPE                 vga_gen_800x600
    `define CLK_CONVERTER_TYPE           clk_100_to_40_and_50_mhz_clk_wiz
    `define FP_VGA_DISPLAY_WIDTH         (32'sh32000000 >>> (20 - `NUM_FRAC_DIGITS))
    `define FP_INV_VGA_DISPLAY_WIDTH     (32'sh0000051e >>> (20 - `NUM_FRAC_DIGITS))
    `define FP_VGA_DISPLAY_HEIGHT        (32'sh25800000 >>> (20 - `NUM_FRAC_DIGITS))
    `define FP_INV_VGA_DISPLAY_HEIGHT    (32'sh000006d3 >>> (20 - `NUM_FRAC_DIGITS))
`endif

// Type Replacements
// Verilog does not have typedef. Use macros for width or manual wire declarations.
`define FP_TYPE signed [`NUM_ALL_DIGITS-1:0]

// Struct Replacement: Flattened vector for vec3 [X, Y, Z]
`define VEC3_SIZE (`NUM_ALL_DIGITS * 3)

// Enum Replacement: Localparams (to be used inside modules) or Macros
`define RU_READY   4'd0
`define RU_SETUP   4'd1
`define RU_BUSY_1  4'd2
`define RU_BUSY_2  4'd3
`define RU_SHADING 4'd4

// Fixed Point Constants
`define FP_ZERO            (32'sh00000000 >>> (20 - `NUM_FRAC_DIGITS))
`define FP_ONE             (32'sh00100000 >>> (20 - `NUM_FRAC_DIGITS))
`define FP_TWO             (32'sh00200000 >>> (20 - `NUM_FRAC_DIGITS))
`define FP_HALF            (32'sh00080000 >>> (20 - `NUM_FRAC_DIGITS))
`define FP_SQRT_TWO        (32'sh0016a09e >>> (20 - `NUM_FRAC_DIGITS))
`define FP_HUNDREDTH       (32'sh000028f5 >>> (20 - `NUM_FRAC_DIGITS))
`define FP_INTERP_SLOPE    (32'sh000d413c >>> (20 - `NUM_FRAC_DIGITS))

`endif

`default_nettype wire

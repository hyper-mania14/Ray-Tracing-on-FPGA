`timescale 1ns / 1ps
`default_nettype none

`ifndef HSL2RGB_VH
`define HSL2RGB_VH

// =============================================================================
// ASSIGNMENT: HSL to RGB Color Conversion Library
// File: hsl2rgb.vh
// =============================================================================
//
// OBJECTIVE:
// Implement two Verilog functions that convert color-space values into 24-bit
// packed RGB output. This header file has NO external dependencies.
//
// RETURN TYPE:
// Both functions return [23:0] → a 24-bit packed RGB value:
//   Bits [23:16] = Red
//   Bits [15:8]  = Green
//   Bits [7:0]   = Blue
//
// VERILOG RULES (apply to all functions in this file):
// - Use `reg` for local variables (not `logic`)
// - Assign result to function name instead of using `return`:
//     my_func = {r, g, b};
// - Do NOT use the `automatic` keyword
// =============================================================================


// =============================================================================
// FUNCTION 1: rgb2rgb
// =============================================================================
//
// TASK: This is a trivial passthrough function. It takes three 8-bit values
//       (h, s, l) and packs them directly into a 24-bit output in that order.
//
// OUTPUT LAYOUT:
//   Bits [23:16] = h
//   Bits [15:8]  = s
//   Bits [7:0]   = l
//
// IMPLEMENTATION: Use concatenation: rgb2rgb = {h, s, l};
//
function [23:0] rgb2rgb;
    input [7:0] h;
    input [7:0] s;
    input [7:0] l;
    begin
        // TODO: Pack h, s, l into a 24-bit output using concatenation
        rgb2rgb = 0; // REPLACE THIS
    end
endfunction


// =============================================================================
// FUNCTION 2: hsl2rgb
// =============================================================================
//
// TASK: Convert HSL (Hue, Saturation, Lightness) to RGB color space.
//       All values are unsigned 8-bit integers (0–255).
//
// ALGORITHM (step by step):
//
// STEP 1: Compute l1 = l + 1  (use 16-bit to avoid overflow)
//
// STEP 2: Compute chroma c (8-bit result):
//         if (l1 < 128):
//             c = ((l1 << 1) * s) >> 8
//         else:
//             c = (512 - (l1 << 1)) * s >> 8
//         Write as a ternary:
//             c = (l1 < 128) ? ((l1<<1)*s)>>8 : (512-(l1<<1))*s>>8;
//
// STEP 3: Hh = h * 6    (use 16-bit; maps 0–255 to 0–1530)
//
// STEP 4: lo = Hh[7:0]  (lower 8 bits of Hh)
//
// STEP 5: h1 = lo + 1   (use 16-bit; linear interpolation factor)
//
// STEP 6: Compute x (8-bit; the "secondary" color component):
//         if (Hh[8] == 0):   x = (h1 * c) >> 8
//         else:               x = ((256 - h1) * c) >> 8
//         Write as ternary:  x = (Hh[8]==0) ? h1*c>>8 : (256-h1)*c>>8;
//
// STEP 7: m = l - (c >> 1)   (offset for all channels)
//
// STEP 8: Assign R, G, B based on which sextant of the color wheel we are in.
//         The sextant is encoded in Hh[9:8] (bits 9 and 8 of Hh):
//
//         R channel (c=full, x=partial, 0=absent):
//           Hh[9:8]==0 (sextant 0, R→Y): r = c
//           Hh[9:8]==1 (sextant 1, Y→G): r = x   ← NOTE: actually r=x for sextant 1
//           Hh[9:8]==2 (sextant 2, G→C): r = 0
//           Hh[9:8]==3 (sextant 3, C→B): r = 0
//           Hh[9:8]==4 (sextant 4, B→M): r = x
//           Hh[9:8]==5 (sextant 5, M→R): r = c
//
//         G channel:
//           sextant 0: g = x
//           sextant 1: g = c
//           sextant 2: g = c
//           sextant 3: g = x   ← NOTE: actually g=x for sextant 3
//           sextant 4: g = 0
//           sextant 5: g = 0
//
//         B channel:
//           sextant 0: b = 0
//           sextant 1: b = 0
//           sextant 2: b = x
//           sextant 3: b = c
//           sextant 4: b = c
//           sextant 5: b = x
//
//         HINT: Hh[9:8] encodes which of the 6 sextants. Use nested ternaries.
//         HINT: The simplified expressions used in hardware (collapsed from above):
//           r = (Hh[9:8] == 0) ? c : (Hh[9:8] == 4) ? x : 0;
//               -- but this misses sextants 1 and 5! Write the full logic.
//
// STEP 9: Final output = {(r + m), (g + m), (b + m)}
//         The +m shifts all channels uniformly by the lightness offset.
//
function [23:0] hsl2rgb;
    input [7:0] h;
    input [7:0] s;
    input [7:0] l;
    reg [7:0]  r, g, b, lo, c, x, m;
    reg [15:0] h1, l1, Hh;
    begin
        // TODO: STEP 1 — compute l1
        // TODO: STEP 2 — compute c (ternary on l1 < 128)
        // TODO: STEP 3 — compute Hh = h * 6
        // TODO: STEP 4 — lo = Hh[7:0]
        // TODO: STEP 5 — h1 = lo + 1
        // TODO: STEP 6 — compute x (ternary on Hh[8])
        // TODO: STEP 7 — m = l - (c >> 1)
        // TODO: STEP 8 — assign r, g, b based on Hh[9:8]
        // TODO: STEP 9 — hsl2rgb = {(r+m), (g+m), (b+m)}
        hsl2rgb = 0; // REPLACE THIS
    end
endfunction

`endif

`default_nettype wire

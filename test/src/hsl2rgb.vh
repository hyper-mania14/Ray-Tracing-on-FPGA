
// =============================================================================
// ASSIGNMENT: HSL to RGB Color Conversion Library
// File: hsl2rgb.vh
// =============================================================================

function [23:0] rgb2rgb;
    input [7:0] h;
    input [7:0] s;
    input [7:0] l;
    begin
        rgb2rgb = {h, s, l};
    end
endfunction

function [23:0] hsl2rgb;
    input [7:0] h;
    input [7:0] s;
    input [7:0] l;
    reg [7:0]  r, g, b, lo, c, x, m;
    reg [15:0] h1, l1, Hh;
    begin
        l1 = l + 1;
        c = (l == 0) ? 8'd0 : (l1 < 128) ? ((l1 << 1) * s) >> 8 : (512 - (l1 << 1)) * s >> 8;
        Hh = h * 6;
        lo = Hh[7:0];
        h1 = lo + 1;
        x = (Hh[8] == 0) ? (h1 * c) >> 8 : ((256 - h1) * c) >> 8;
        m = l - (c >> 1);

        // Note: The guide mentions Hh[9:8] for sextants 0-5, but 0-5 requires 3 bits.
        // We use Hh[10:8] because 255 * 6 = 1530 = 0b101_1111_1010.
        r = (Hh[10:8] == 0 || Hh[10:8] == 5) ? c : 
            (Hh[10:8] == 1 || Hh[10:8] == 4) ? x : 8'd0;
            
        g = (Hh[10:8] == 1 || Hh[10:8] == 2) ? c : 
            (Hh[10:8] == 0 || Hh[10:8] == 3) ? x : 8'd0;
            
        b = (Hh[10:8] == 3 || Hh[10:8] == 4) ? c : 
            (Hh[10:8] == 2 || Hh[10:8] == 5) ? x : 8'd0;

        hsl2rgb = {(r + m), (g + m), (b + m)};
    end
endfunction

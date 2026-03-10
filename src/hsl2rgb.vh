`timescale 1ns / 1ps
`default_nettype none

`ifndef HSL2RGB_VH
`define HSL2RGB_VH

function [23:0] rgb2rgb;
    input [7:0] h;
    input [7:0] s;
    input [7:0] l;
    begin
        rgb2rgb = {h,s,l};
    end
endfunction

function [23:0] hsl2rgb;
    input [7:0] h;
    input [7:0] s;
    input [7:0] l;
    reg [7:0]  r, g, b, lo, c, x, m;
    reg [15:0] h1, l1, Hh;
    begin
        l1 = (l==0)?l:l+1; //Ternary operation to prevent erros when l=0

        c = (l1<128) ? ((l1 << 1) * s) >> 8 : (512 - (l1 << 1)) * s >> 8 ;

        Hh = h * 6;

        lo = Hh[7:0];

        h1 = lo + 1;

        x = (Hh[8] == 0) ? (h1*c)>>8 : ((256-h1)*c)>>8;

        m = l - (c>>1);

        r = (Hh[9:8]==0 || Hh[9:8]==5)?c:((Hh[9:8]==1 || Hh[9:8]==4)?x:0);
        g = (Hh[9:8]==1 || Hh[9:8]==2)?c:((Hh[9:8]==0 || Hh[9:8]==3)?x:0);
        b = (Hh[9:8]==3 || Hh[9:8]==4)?c:((Hh[9:8]==2 || Hh[9:8]==5)?x:0);
        
        hsl2rgb = {(r+m),(g+m),(b+m)};
    end
endfunction
`endif

`default_nettype wire
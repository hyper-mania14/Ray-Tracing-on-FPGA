`timescale 1ns / 1ps
`default_nettype none

module vga_gen_800x600 #(
    parameter H_DISPLAY       = 800,
    parameter H_FRONT_PORCH   = 40,
    parameter H_SYNC_PULSE    = 128,
    parameter H_BACK_PORCH    = 88,
    parameter H_TOTAL         = 1056,

    parameter V_DISPLAY       = 600,
    parameter V_FRONT_PORCH   = 1,
    parameter V_SYNC_PULSE    = 4,
    parameter V_BACK_PORCH    = 23,
    parameter V_TOTAL         = 628
) (
    input  wire pixel_clk_in,
    output reg  [9:0] hcount_out,
    output reg  [9:0] vcount_out,
    output wire vsync_out,
    output wire hsync_out,
    output wire blank_out
);

    initial begin
        hcount_out = 0;
        vcount_out = 0;
    end

    always @(posedge pixel_clk_in) begin
        if (hcount_out == H_TOTAL - 1) begin
            hcount_out <= 0;
            if (vcount_out == V_TOTAL - 1) begin
                vcount_out <= 0;
            end else begin
                vcount_out <= vcount_out + 1;
            end
        end else begin
            hcount_out <= hcount_out + 1;
        end
    end

    // Positive polarity logic
    assign hsync_out = (hcount_out >= (H_DISPLAY + H_FRONT_PORCH)) && 
                       (hcount_out <  (H_DISPLAY + H_FRONT_PORCH + H_SYNC_PULSE));

    assign vsync_out = (vcount_out >= (V_DISPLAY + V_FRONT_PORCH)) && 
                       (vcount_out <  (V_DISPLAY + V_FRONT_PORCH + V_SYNC_PULSE));

    assign blank_out = (hcount_out >= H_DISPLAY) || (vcount_out >= V_DISPLAY);

endmodule

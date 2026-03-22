`timescale 1ns / 1ps
`default_nettype none
module vga_display (
    input  wire vga_clk_in,
    input  wire rst_in,
    input  wire [3:0]  read_data_in,
    input  wire        toggle_hue,
    input  wire        toggle_color,
    output reg  [`ADDR_BITS-1:0] read_addr_out,
    output reg  [3:0]  vga_r, vga_g, vga_b,
    output reg         vga_hs, vga_vs
);

`include "types.vh"
`include "hsl2rgb.vh"

    wire [`VGA_H_BITS-1:0] hcount;
    wire [`VGA_V_BITS-1:0] vcount;
    wire vsync, hsync, blank;

    `VGA_GEN_TYPE vga_gen_inst (
        .pixel_clk_in(vga_clk_in),
        .hcount_out(hcount),
        .vcount_out(vcount),
        .vsync_out(vsync),
        .hsync_out(hsync),
        .blank_out(blank)
    );

    reg [27:0] hue_counter;
    always @(posedge vga_clk_in) begin
        if (rst_in) hue_counter <= 0;
        else hue_counter <= hue_counter + toggle_hue;
    end

    wire [23:0] hsl;
    assign hsl = hsl2rgb(
        hue_counter[27:20],                           // hue 
        toggle_color ? 8'd165 : 8'd0,                 // saturation
        {read_data_in, 4'b0000}                       // lightness
    );

    // Pipeline registers for sync signals (2 cycles latency for BRAM)
    reg [`VGA_H_BITS-1:0] hcount_mid, hcount_out_r;
    reg [`VGA_V_BITS-1:0] vcount_mid, vcount_out_r;
    reg vsync_mid, vsync_out_r;
    reg hsync_mid, hsync_out_r;
    reg blank_mid, blank_out_r;

    always @(posedge vga_clk_in) begin
        if (rst_in) begin
            hcount_mid   <= 0; hcount_out_r   <= 0;
            vcount_mid   <= 0; vcount_out_r   <= 0;
            vsync_mid    <= 0; vsync_out_r    <= 0;
            hsync_mid    <= 0; hsync_out_r    <= 0;
            blank_mid    <= 0; blank_out_r    <= 0;
            read_addr_out <= 0;
        end else begin
          
            hcount_mid   <= hcount;     hcount_out_r <= hcount_mid;
            vcount_mid   <= vcount;     vcount_out_r <= vcount_mid;
            vsync_mid    <= vsync;      vsync_out_r  <= vsync_mid;
            hsync_mid    <= hsync;      hsync_out_r  <= hsync_mid;
            blank_mid    <= blank;      blank_out_r  <= blank_mid;

            read_addr_out <= ((vcount >> `DISPLAY_SHIFT_SIZE) * `DISPLAY_WIDTH)
                           + (hcount >> `DISPLAY_SHIFT_SIZE);
        end
    end

    always @(posedge vga_clk_in) begin
        if (rst_in) begin
            vga_r <= 0;
            vga_g <= 0;
            vga_b <= 0;
            vga_hs <= 0;
            vga_vs <= 0;
        end else begin
            vga_r  <= blank_out_r ? 4'b0 : hsl[23:20];
            vga_g  <= blank_out_r ? 4'b0 : hsl[15:12];
            vga_b  <= blank_out_r ? 4'b0 : hsl[7:4];
            vga_hs <= ~hsync_out_r;
            vga_vs <= ~vsync_out_r;
        end
    end

endmodule

`default_nettype wire

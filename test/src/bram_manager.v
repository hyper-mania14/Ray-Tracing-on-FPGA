
// bram_manager.v
// Double-buffered Block RAM manager.
//
// Maintains two BRAMs (A and B). One is the "write" buffer (ray_marcher writes
// finished pixels here) and the other is the "read/display" buffer (vga_display
// reads from here). A single `swap_buffers` pulse swaps the roles.
//
// Vivado will infer both RAMs as RAMB18E2 / RAMB36E2 primitives automatically
// when synthesised with "Block RAM" resource target.
//
// Port summary:
//   Write side  : write_addr, write_data, write_enable  (always to the write BRAM)
//   Read side   : read_addr  -> read_data_out (1-cycle registered read, from display BRAM)
//   Control     : swap_buffers (1-cycle pulse) - toggles which BRAM is write vs display
//   Status      : which_bram_out - tells caller which BRAM is currently the display BRAM


`timescale 1ns / 1ps
`default_nettype none

module bram_manager #(
    parameter WIDTH    = 4,      // data width in bits (4 for 4-bit color)
    parameter DEPTH    = 120000, // number of entries (DISPLAY_WIDTH * DISPLAY_HEIGHT)
    parameter ADDR_LEN = 17      // ceil(log2(DEPTH)); 2^17 = 131072 >= 120000
) (
    input  wire                  clk,
    input  wire                  rst,

    // Control
    input  wire                  swap_buffers,   // pulse high for 1 cycle to swap
    output reg                   which_bram_out, // 0 = BRAM_A is display, 1 = BRAM_B is display

    // Write port (from ray_marcher)
    input  wire [ADDR_LEN-1:0]   write_addr,
    input  wire [WIDTH-1:0]      write_data,
    input  wire                  write_enable,

    // Read port (to vga_display) — 1-cycle latency
    input  wire [ADDR_LEN-1:0]   read_addr,
    output reg  [WIDTH-1:0]      read_data_out
);

    always @(posedge clk) begin
        if (rst)
            which_bram_out <= 0;
        else if (swap_buffers)
            which_bram_out <= ~which_bram_out;
    end

    always @(posedge clk) begin
        if (write_enable) begin
            if (which_bram_out == 0)   // display=A, write to B
                bram_b[write_addr] <= write_data;
            else                        // display=B, write to A
                bram_a[write_addr] <= write_data;
        end
    end

    always @(posedge clk) begin
        if (rst)
            read_data_out <= {WIDTH{1'b0}};
        else begin
            if (which_bram_out == 0)   // display=A, read from A
                read_data_out <= bram_a[read_addr];
            else                        // display=B, read from B
                read_data_out <= bram_b[read_addr];
        end
    end

endmodule

`default_nettype wire

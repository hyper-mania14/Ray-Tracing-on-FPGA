// =============================================================================
// bram_manager.v — Double-Buffered Block RAM Manager (Synthesis Version)
//
// Uses two instances of xilinx_true_dual_port_read_first_1_clock_ram for proper
// BRAM inference by Vivado. Port A is the write side (ray_marcher),
// Port B is the read side (vga_display). A swap_buffers pulse toggles
// which BRAM is being written vs displayed.
//
// The which_bram pipeline adds 2 cycles of latency to match the BRAM's
// HIGH_PERFORMANCE (2-cycle) read latency.
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module bram_manager #(
    parameter WIDTH    = 4,       // data width in bits (4 for 4-bit color)
    parameter DEPTH    = 120000,  // number of entries (DISPLAY_WIDTH * DISPLAY_HEIGHT)
    parameter ADDR_LEN = 17      // address width (overridden by instantiator)
) (
    input  wire                  clk,
    input  wire                  rst,

    // Control
    input  wire                  swap_buffers,   // pulse high for 1 cycle to swap
    output wire                  which_bram_out, // which BRAM is currently the display buffer

    // Write port (from ray_marcher)
    input  wire [ADDR_LEN-1:0]   write_addr,
    input  wire [WIDTH-1:0]      write_data,
    input  wire                  write_enable,

    // Read port (to vga_display) — 2-cycle latency (HIGH_PERFORMANCE BRAM)
    input  wire [ADDR_LEN-1:0]   read_addr,
    output wire [WIDTH-1:0]      read_data_out
);

    // -------------------------------------------------------------------------
    // which_bram pipeline (matches BRAM's 2-cycle read latency)
    // -------------------------------------------------------------------------
    reg which_bram_in;
    reg which_bram_mid;
    reg which_bram_end;

    wire which_bram_next;
    assign which_bram_next = swap_buffers ? ~which_bram_mid : which_bram_mid;
    assign which_bram_out  = ~which_bram_end;

    always @(posedge clk) begin
        if (rst) begin
            which_bram_mid <= 0;
            which_bram_end <= 0;
        end else begin
            which_bram_mid <= which_bram_next;
            which_bram_end <= which_bram_mid;
        end
    end

    // -------------------------------------------------------------------------
    // Address width calculation — match BRAM primitive's clogb2(DEPTH-1)
    // -------------------------------------------------------------------------
    function integer clogb2;
        input integer depth;
        for (clogb2 = 0; depth > 0; clogb2 = clogb2 + 1)
            depth = depth >> 1;
    endfunction
    localparam BRAM_ADDR_BITS = clogb2(DEPTH - 1);

    // Truncated address wires (ADDR_LEN may be wider than BRAM needs)
    wire [BRAM_ADDR_BITS-1:0] wr_addr_trunc = write_addr[BRAM_ADDR_BITS-1:0];
    wire [BRAM_ADDR_BITS-1:0] rd_addr_trunc = read_addr[BRAM_ADDR_BITS-1:0];

    // -------------------------------------------------------------------------
    // BRAM output wires
    // -------------------------------------------------------------------------
    wire [WIDTH-1:0] bram0_douta;
    wire [WIDTH-1:0] bram0_doutb;
    wire [WIDTH-1:0] bram1_douta;
    wire [WIDTH-1:0] bram1_doutb;

    // Read data mux: select the display BRAM's port B output
    assign read_data_out = ~which_bram_out ? bram0_doutb : bram1_doutb;

    // -------------------------------------------------------------------------
    // BRAM 0
    // -------------------------------------------------------------------------
    xilinx_true_dual_port_read_first_1_clock_ram #(
        .RAM_WIDTH(WIDTH),
        .RAM_DEPTH(DEPTH)
    ) bram0 (
        .addra  (wr_addr_trunc),
        .addrb  (rd_addr_trunc),
        .dina   (write_data),
        .dinb   ({WIDTH{1'b0}}),
        .clka   (clk),
        .wea    (write_enable && (which_bram_next == 1'b0)),  // write to bram0 when which=0
        .web    (1'b0),
        .ena    (1'b1),
        .enb    (1'b1),
        .rsta   (rst),
        .rstb   (rst),
        .regcea (1'b1),
        .regceb (1'b1),
        .douta  (bram0_douta),
        .doutb  (bram0_doutb)
    );

    // -------------------------------------------------------------------------
    // BRAM 1
    // -------------------------------------------------------------------------
    xilinx_true_dual_port_read_first_1_clock_ram #(
        .RAM_WIDTH(WIDTH),
        .RAM_DEPTH(DEPTH)
    ) bram1 (
        .addra  (wr_addr_trunc),
        .addrb  (rd_addr_trunc),
        .dina   (write_data),
        .dinb   ({WIDTH{1'b0}}),
        .clka   (clk),
        .wea    (write_enable && (which_bram_next == 1'b1)),  // write to bram1 when which=1
        .web    (1'b0),
        .ena    (1'b1),
        .enb    (1'b1),
        .rsta   (rst),
        .rstb   (rst),
        .regcea (1'b1),
        .regceb (1'b1),
        .douta  (bram1_douta),
        .doutb  (bram1_doutb)
    );

endmodule // bram_manager

`default_nettype wire

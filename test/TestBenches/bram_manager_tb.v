`timescale 1ns / 1ps
`default_nettype none
// NOTE: bram_manager.v depends on xilinx_true_dual_port_read_first_1_clock_ram.
// Make sure that module is included in your iverilog command.
// For simulation, use the Xilinx simulation model or a simple Verilog behavioral model.

module bram_manager_tb;

`include "types.vh"



  parameter WIDTH    = 8;     // Smaller than real design for sim speed
  parameter DEPTH    = 32;
  parameter ADDR_LEN = 5;

  reg clk, rst;
  reg swap_buffers;
  reg [ADDR_LEN-1:0] read_addr, write_addr;
  reg write_enable;
  reg [WIDTH-1:0] write_data;

  wire [WIDTH-1:0] read_data_out;
  wire             which_bram_out;

  bram_manager #(
    .WIDTH   (WIDTH),
    .DEPTH   (DEPTH),
    .ADDR_LEN(ADDR_LEN)
  ) uut (
    .clk          (clk),
    .rst          (rst),
    .swap_buffers (swap_buffers),
    .read_addr    (read_addr),
    .write_addr   (write_addr),
    .write_enable (write_enable),
    .write_data   (write_data),
    .read_data_out(read_data_out),
    .which_bram_out(which_bram_out)
  );

  always #5 clk = ~clk;

  integer i;
  reg [WIDTH-1:0] tmp_data;

  initial begin
    $dumpfile("bram_manager.vcd");
    $dumpvars(0, bram_manager_tb);
    $display("Starting Sim");

    clk          = 0;
    rst          = 0;
    swap_buffers = 0;
    write_enable = 0;
    write_addr   = 0;
    read_addr    = 0;
    write_data   = 0;

    // Reset
    @(posedge clk); rst = 1;
    @(posedge clk); rst = 0;
    repeat(3) @(posedge clk);

    // -- PHASE 1: Write pattern to BRAM 0 (which_bram=0 means write to bram0) --
    $display("\n--- Phase 1: Writing pattern to active write BRAM ---");
    for (i = 0; i < DEPTH; i = i + 1) begin
      write_addr   = i[ADDR_LEN-1:0];
      write_data   = i[WIDTH-1:0];
      read_addr    = i[ADDR_LEN-1:0];
      write_enable = 1;
      swap_buffers = 0;
      @(posedge clk);
      $display("[%3d] write_addr=%0d write_data=0x%h read_data=0x%h which_bram=%b",
               i, write_addr, write_data, read_data_out, which_bram_out);
    end
    write_enable = 0;

    // -- PHASE 2: Swap buffers --
    $display("\n--- Phase 2: Swapping buffers ---");
    swap_buffers = 1;
    @(posedge clk);
    swap_buffers = 0;
    @(posedge clk);
    $display("  which_bram_out after swap = %b", which_bram_out);

    // -- PHASE 3: Read back from now-display BRAM (same data we wrote) --
    $display("\n--- Phase 3: Reading back from display BRAM ---");
    for (i = 0; i < 8; i = i + 1) begin
      read_addr = i[ADDR_LEN-1:0];
      @(posedge clk);
      @(posedge clk); // 2-cycle BRAM read latency
      $display("[addr=%0d] read_data=0x%h  (expected 0x%h)",
               i, read_data_out, i[WIDTH-1:0]);
    end

    // -- PHASE 4: Swap periodically (stress test) --
    $display("\n--- Phase 4: Periodic swap stress test ---");
    for (i = 0; i < 30; i = i + 1) begin
      write_addr   = i[ADDR_LEN-1:0];
      read_addr    = i[ADDR_LEN-1:0];
      write_enable = 1;
      tmp_data     = (i + 7);           // fixed: assign expression to reg first
      write_data   = tmp_data;
      swap_buffers = (i % 7 == 0) ? 1 : 0;
      @(posedge clk);
      $display("[%2d] swap=%b which_bram=%b read_data=0x%h",
               i, swap_buffers, which_bram_out, read_data_out);
    end
    write_enable = 0;

    $display("\nFinishing Sim");
    $finish;
  end
endmodule // bram_manager_tb

`default_nettype wire

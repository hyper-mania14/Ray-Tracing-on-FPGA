`timescale 1ns / 1ps
`default_nettype none

`include "hsl2rgb.vh"

module hsl2rgb_tb;

  reg [7:0] h_in, s_in, l_in;
  wire [23:0] rgb_out;
  wire [23:0] pass_out;

  reg all_passed;
  reg passed;

  // Wires to call functions — testbench uses reg assignments in initial block
  reg [23:0] result;

  initial begin
    $dumpfile("hsl2rgb.vcd");
    $dumpvars(0, hsl2rgb_tb);
    $display("Starting Sim");
    all_passed = 1;

    // ---------------------------------------------------------------
    // Test 1: rgb2rgb passthrough
    // ---------------------------------------------------------------
    result = rgb2rgb(8'hAB, 8'hCD, 8'hEF);
    $display("Test 1 - rgb2rgb(0xAB, 0xCD, 0xEF):");
    $display("  Expected: 0xABCDEF");
    $display("  Actual:   0x%06h", result);
    passed = (result == 24'hABCDEF) ? 1 : 0;
    all_passed = all_passed & passed;
    $display("  %s", passed ? "PASSED" : "FAILED");
    $display("");

    // ---------------------------------------------------------------
    // Test 2: hsl2rgb — gray (S=0 → all channels equal)
    // ---------------------------------------------------------------
    result = hsl2rgb(8'd0, 8'd0, 8'd127);
    $display("Test 2 - hsl2rgb(h=0, s=0, l=127)  [Gray, S=0]:");
    $display("  Expected: R == G == B (all channels equal)");
    $display("  Actual:   R=%0d G=%0d B=%0d",
             result[23:16], result[15:8], result[7:0]);
    passed = (result[23:16] == result[15:8] && result[15:8] == result[7:0]) ? 1 : 0;
    all_passed = all_passed & passed;
    $display("  %s", passed ? "PASSED" : "FAILED");
    $display("");

    // ---------------------------------------------------------------
    // Test 3: hsl2rgb — pure red (H=0, S=255, L=127)
    // R should be max, G and B should be min/zero
    // ---------------------------------------------------------------
    result = hsl2rgb(8'd0, 8'd255, 8'd127);
    $display("Test 3 - hsl2rgb(h=0, s=255, l=127)  [Pure Red]:");
    $display("  Expected: R >> G, R >> B");
    $display("  Actual:   R=%0d G=%0d B=%0d",
             result[23:16], result[15:8], result[7:0]);
    passed = (result[23:16] > result[15:8] && result[23:16] > result[7:0]) ? 1 : 0;
    all_passed = all_passed & passed;
    $display("  %s", passed ? "PASSED" : "FAILED");
    $display("");

    // ---------------------------------------------------------------
    // Test 4: hsl2rgb — pure green (H=85, S=255, L=127)
    // G should be max
    // ---------------------------------------------------------------
    result = hsl2rgb(8'd85, 8'd255, 8'd127);
    $display("Test 4 - hsl2rgb(h=85, s=255, l=127)  [Pure Green]:");
    $display("  Expected: G >> R, G >> B");
    $display("  Actual:   R=%0d G=%0d B=%0d",
             result[23:16], result[15:8], result[7:0]);
    passed = (result[15:8] > result[23:16] && result[15:8] > result[7:0]) ? 1 : 0;
    all_passed = all_passed & passed;
    $display("  %s", passed ? "PASSED" : "FAILED");
    $display("");

    // ---------------------------------------------------------------
    // Test 5: hsl2rgb — pure blue (H=170, S=255, L=127)
    // B should be max
    // ---------------------------------------------------------------
    result = hsl2rgb(8'd170, 8'd255, 8'd127);
    $display("Test 5 - hsl2rgb(h=170, s=255, l=127)  [Pure Blue]:");
    $display("  Expected: B >> R, B >> G");
    $display("  Actual:   R=%0d G=%0d B=%0d",
             result[23:16], result[15:8], result[7:0]);
    passed = (result[7:0] > result[23:16] && result[7:0] > result[15:8]) ? 1 : 0;
    all_passed = all_passed & passed;
    $display("  %s", passed ? "PASSED" : "FAILED");
    $display("");

    // ---------------------------------------------------------------
    // Test 6: hsl2rgb — black (L=0)
    // All channels should be zero (or very small)
    // ---------------------------------------------------------------
    result = hsl2rgb(8'd0, 8'd255, 8'd0);
    $display("Test 6 - hsl2rgb(h=0, s=255, l=0)  [Black]:");
    $display("  Expected: R=0, G=0, B=0");
    $display("  Actual:   R=%0d G=%0d B=%0d",
             result[23:16], result[15:8], result[7:0]);
    passed = (result[23:16] == 0 && result[15:8] == 0 && result[7:0] == 0) ? 1 : 0;
    all_passed = all_passed & passed;
    $display("  %s", passed ? "PASSED" : "FAILED");
    $display("");

    $display("%s", all_passed ? "ALL PASSED" : "SOME FAILED");
    $display("Finishing Sim");
    $finish;
  end
endmodule // hsl2rgb_tb

`default_nettype wire

`timescale 1ns / 1ps
`default_nettype none

`include "types.vh"
`include "fixed_point_arith.vh"

module fp_inv_sqrt_folded_tb;

  // -------------------------------------------------------------------------
  // Parameters & Types
  // -------------------------------------------------------------------------
  // Assuming 32-bit fixed point with 16 fractional bits (Q16.16)
  // Adjust these based on your specific implementation
  parameter DATA_WIDTH = 32;
  parameter FRAC_BITS  = 16;
  parameter REAL_SCALE = 65536.0; // 2^16

  // -------------------------------------------------------------------------
  // Signals (logic -> reg/wire)
  // -------------------------------------------------------------------------
  reg clk;
  reg rst;
  reg valid_in;
  
  // Inputs/Outputs in integer format (representing fixed point)
  reg  signed [DATA_WIDTH-1:0] a_in_bits;
  wire signed [DATA_WIDTH-1:0] res_out_bits;
  
  wire ready_out;
  wire valid_out;

  // Testbench variables
  real tolerance;
  reg  all_passed;

  // -------------------------------------------------------------------------
  // UUT Instantiation
  // -------------------------------------------------------------------------
  fp_inv_sqrt_folded uut (
    .clk_in    (clk),
    .rst_in    (rst),
    .a_in      (a_in_bits),    // Connect as bits
    .valid_in  (valid_in),
    .res_out   (res_out_bits), // Connect as bits
    .valid_out (valid_out),
    .ready_out (ready_out)
  );

  // -------------------------------------------------------------------------
  // Clock Generation
  // -------------------------------------------------------------------------
  always begin
    #5 clk = ~clk;
  end

  // -------------------------------------------------------------------------
  // Conversion Functions (Replacing fixed_point_arith.svh)
  // -------------------------------------------------------------------------
  
  // Convert Real to Fixed-Point Integer
  function signed [DATA_WIDTH-1:0] real_to_fp;
    input real val;
    begin
      // Multiply by scale and cast to integer
      real_to_fp = val * REAL_SCALE;
    end
  endfunction

  // Convert Fixed-Point Integer to Real
  function real fp_to_real;
    input signed [DATA_WIDTH-1:0] val;
    begin
      // Divide by scale
      fp_to_real = val / REAL_SCALE;
    end
  endfunction

  // -------------------------------------------------------------------------
  // Verification Task (Replacing the Macro)
  // -------------------------------------------------------------------------
  task test_vector;
    input real input_val;
    input real expected_val;
    
    real actual_real;
    real diff;
    reg  passed;
    
    begin
      // Wait for DUT readiness
      wait(ready_out);

      // Drive Inputs
      a_in_bits = real_to_fp(input_val);
      valid_in  = 1;

      // Pulse valid (simulating the macro's #10 #10 logic)
      #10;
      valid_in = 0; // Usually valid is pulsed, check your design spec
      #10;

      // Wait for result
      wait(valid_out);

      // Capture and Compare
      actual_real = fp_to_real(res_out_bits);
      
      // Calculate Absolute Difference (Manually, no $abs in Verilog-2001)
      diff = actual_real - expected_val;
      if (diff < 0) diff = -diff;

      passed = (diff < tolerance);
      all_passed = all_passed & passed;

      // Reporting
      $display("Input: %f", input_val);
      $display("Expected: %f", expected_val);
      $display("Actual:   %f (Hex: %h)", actual_real, res_out_bits);
      
      if (passed)
        $display("Status:   PASSED\n");
      else
        $display("Status:   FAILED\n");
    end
  endtask

  // -------------------------------------------------------------------------
  // Main Test Sequence
  // -------------------------------------------------------------------------
  initial begin
    $dumpfile("fp_inv_sqrt_folded.vcd");
    $dumpvars(0, fp_inv_sqrt_folded_tb);
    $display("Starting Sim");

    // Initialize
    clk = 0;
    rst = 0;
    valid_in = 0;
    all_passed = 1;
    tolerance = 1e-4;
    a_in_bits = 0;

    #10;
    // Reset machine
    rst = 1;
    #10;
    rst = 0;
    #100;

    // Test Cases
    // We calculate expected value here and pass it to the task
    test_vector(0.5, 1.0/$sqrt(0.5));
    test_vector(0.6, 1.0/$sqrt(0.6));
    test_vector(0.7, 1.0/$sqrt(0.7));
    test_vector(0.8, 1.0/$sqrt(0.8));
    test_vector(0.9, 1.0/$sqrt(0.9));
    test_vector(1.0, 1.0/$sqrt(1.0));
    test_vector(3.7, 1.0/$sqrt(3.7));
    test_vector(5.8, 1.0/$sqrt(5.8));
    test_vector(1.5, 1.0/$sqrt(1.5));
    test_vector(6.9, 1.0/$sqrt(6.9));

    if (all_passed)
        $display("----------------\nALL PASSED\n----------------");
    else
        $display("----------------\nSOME FAILED\n----------------");

    $display("Finishing Sim");
    $finish;
  end

endmodule
`default_nettype wire

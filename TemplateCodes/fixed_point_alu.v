`timescale 1ns / 1ps
`default_nettype none

`include "types.vh"
`include "fixed_point_arith.vh"

module fixed_point_alu (
    input wire signed [`WIDTH-1:0] d0_in,
    input wire signed [`WIDTH-1:0] d1_in,
    input wire [2:0] sel_in,
    output reg signed [`WIDTH-1:0] res_out,
    output reg gt_out,
    output reg eq_out
);

    always @* begin
        // 1. Flags
        eq_out = (d1_in == d0_in);
        // gt_out = fp_gt(d1_in, d0_in); // TODO: Uncomment when ready

        // 2. Multiplexer
        case (sel_in)
            3'b000: res_out = fp_add(d1_in, d0_in);
            3'b001: res_out = fp_mul(d1_in, d0_in);
            // 3'b010: RESERVED (Inverse Sqrt handled by separate module)
            // 3'b100: res_out = fp_sub(d1_in, d0_in);
            // TODO: Add Min/Max cases
            default: res_out = {`WIDTH{1'b0}};
        endcase
    end

endmodule



# Documentation: `ray_marcher.v` Implementation Guide

## 1. Overview & Objective

Implement `ray_marcher.v` — the **top-level rendering controller** that manages a pool of parallel `ray_unit` instances to render a full frame.

Each frame consists of `DISPLAY_WIDTH × DISPLAY_HEIGHT` pixels. Multiple `ray_unit` cores process pixels in parallel. `ray_marcher` distributes pixels to free cores and collects results for BRAM storage.

**Dependencies**: `types.vh`, `vector_arith.vh`, `ray_unit.v`

---

## 2. Port Interface

```verilog
module ray_marcher #(
    parameter DISPLAY_WIDTH  = `DISPLAY_WIDTH,
    parameter DISPLAY_HEIGHT = `DISPLAY_HEIGHT,
    parameter H_BITS         = `H_BITS,
    parameter V_BITS         = `V_BITS,
    parameter COLOR_BITS     = `COLOR_BITS,
    parameter NUM_CORES      = `NUM_CORES
) (
    input  wire clk_in, rst_in,
    input  wire [3*`W-1:0] pos_vec_in,     // camera position (vec3)
    input  wire [3*`W-1:0] dir_vec_in,     // camera forward direction (vec3)
    input  wire toggle_checker_in,          // checkerboard rendering mode
    input  wire toggle_dither_in,
    input  wire toggle_texture_in,
    input  wire [2:0] fractal_sel_in,
    output reg  [H_BITS-1:0] hcount_out,
    output reg  [V_BITS-1:0] vcount_out,
    output reg  [3:0]        color_out,
    output reg               valid_out,
    output reg               new_frame_out
);
```

---

## 3. Checkerboard Rendering (`\`ifdef USE_CHECKERBOARD_RENDERING`)

When `USE_CHECKERBOARD_RENDERING` is defined (i.e. NOT in test mode), only **half** the pixels are rendered per frame — alternating in a checkerboard pattern across frames. This doubles the frame rate at the cost of temporal pixel coverage.

```verilog
`ifndef TESTING_RAY_MARCHER
`define RAY_UNIT_TYPE ray_unit
`define USE_CHECKERBOARD_RENDERING
`else
`define RAY_UNIT_TYPE ray_unit_dummy
`endif
```

```verilog
`ifdef USE_CHECKERBOARD_RENDERING
    reg        checker_bit;    // alternates 0/1 each pixel assigned
    reg  [1:0] checker_frame;  // frame counter for inter-frame alternation
`endif
```

---

## 4. Core Array Declaration

Declare arrays of per-core output signals (Verilog 2001 unpacked arrays):

```verilog
wire [H_BITS-1:0]   core_hcount_out [0:NUM_CORES-1];
wire [V_BITS-1:0]   core_vcount_out [0:NUM_CORES-1];
wire [COLOR_BITS-1:0] core_color_out [0:NUM_CORES-1];
wire [NUM_CORES-1:0] core_ready_out;  // packed: each bit = one core's ready signal

wire all_cores_ready;
assign all_cores_ready = &core_ready_out;  // reduction AND
```

---

## 5. Core Instantiation (Generate Loop)

Use a `generate` / `genvar` loop to instantiate `NUM_CORES` ray units:

```verilog
reg assigning;
reg [4:0] assign_to;   // which core is being assigned this cycle

generate
    genvar i;
    for (i = 0; i < NUM_CORES; i = i + 1) begin : ray_marcher_core_decl
        `RAY_UNIT_TYPE #(
            .DISPLAY_WIDTH(DISPLAY_WIDTH),
            .DISPLAY_HEIGHT(DISPLAY_HEIGHT),
            .H_BITS(H_BITS), .V_BITS(V_BITS)
        ) ray_unit_inst (
            .clk_in          (clk_in),
            .rst_in          (rst_in),
            .ray_origin_in   (current_pos_vec),
            .ray_direction_in(current_dir_vec),
            .fractal_sel_in  (current_fractal),
            .hcount_in       (assign_hcount),
            .hcount_fp_in    (assign_hcount_fp),
            .vcount_in       (assign_vcount),
            .vcount_fp_in    (assign_vcount_fp),
            .toggle_dither_in(toggle_dither_in),
            .toggle_texture_in(toggle_texture_in),
            // valid_in is only high for core i when it is being assigned:
            .valid_in        (assign_to == i && assigning),
            .hcount_out      (core_hcount_out[i]),
            .vcount_out      (core_vcount_out[i]),
            .color_out       (core_color_out[i]),
            .ready_out       (core_ready_out[i])
        );
    end
endgenerate
```

---

## 6. Work Assignment State Machine

### Internal registers

```verilog
reg [3*`W-1:0] current_pos_vec, current_dir_vec;
reg [2:0] current_fractal;

// Pixel scan position
reg [H_BITS-1:0] hcount, assign_hcount;
reg [V_BITS-1:0] vcount, assign_vcount;
reg [`W-1:0] hcount_fp, vcount_fp, assign_hcount_fp, assign_vcount_fp;

reg [4:0] core_idx;   // current core being checked (cycles 0..NUM_CORES-1)
```

### Assignment Logic (`always @(posedge clk_in)`)

The controller uses `hcount`/`vcount` as the current scan position. When `vcount == DISPLAY_HEIGHT`, the full frame has been assigned.

```
On reset:
    hcount = 0, hcount_fp = FP_HCOUNT_FP_START
    vcount = DISPLAY_HEIGHT  (signals "no frame active" initially)
    new_frame_out = 0, assigning = 0, core_idx = 0
    checker_bit = 0, checker_frame = 0

Each cycle:
    CASE 1: vcount == DISPLAY_HEIGHT  (frame complete)
        assigning = 0
        if all_cores_ready:
            // Start new frame: latch new pos/dir/fractal from inputs
            current_pos_vec = pos_vec_in
            current_dir_vec = dir_vec_in
            current_fractal = fractal_sel_in
            hcount = 0, hcount_fp = FP_HCOUNT_FP_START
            vcount = 0, vcount_fp = FP_VCOUNT_FP_START
            new_frame_out = 1
            checker_bit = checker_frame[0] ^ checker_frame[1]
            checker_frame = checker_frame + 1
        // else: wait, assigning = 0

    CASE 2: hcount == DISPLAY_WIDTH  (row complete)
        vcount = vcount + 1
        vcount_fp = fp_add(vcount_fp, FP_VCOUNT_FP_INCREMENT)
        hcount = 0, hcount_fp = FP_HCOUNT_FP_START
        assigning = 0
        checker_bit = ~checker_bit   [ifdef checkerboard]

    CASE 3: Normal pixel assignment
        new_frame_out = 0
        if core_ready_out[core_idx]:
            // Assign pixel to this core
            assign_to = core_idx
            assign_hcount = hcount,    assign_hcount_fp = hcount_fp
            assign_vcount = vcount,    assign_vcount_fp = vcount_fp
            hcount = hcount + 1
            hcount_fp = fp_add(hcount_fp, FP_HCOUNT_FP_INCREMENT)
            [ifdef checkerboard]:
                checker_bit = ~checker_bit
                assigning = checker_bit | ~toggle_checker_in
            [else]:
                assigning = 1
        else:
            assigning = 0

    Always (every cycle): core_idx = (core_idx + 1 == NUM_CORES) ? 0 : core_idx + 1
```

> `FP_HCOUNT_FP_START`, `FP_VCOUNT_FP_START`, `FP_HCOUNT_FP_INCREMENT`, `FP_VCOUNT_FP_INCREMENT` are all defined in `types.vh` as fixed-point constants for the selected display resolution.

---

## 7. Result Collection

A separate `always @(posedge clk_in)` block reads completed pixel results:

```
Each cycle:
    if core_ready_out[core_idx]:
        // Core has a completed pixel — output it
        hcount_out = core_hcount_out[core_idx]
        vcount_out = core_vcount_out[core_idx]
        color_out  = core_color_out[core_idx]
        valid_out  = 1
    else:
        valid_out  = 0
```

> **Note**: `core_idx` is shared between assignment and collection. The same `core_idx` is sampled — the core that was just checked for assignment is also checked for output. Since `ready_out` on a `ray_unit` goes high one cycle after completion, reading both in the same cycle is safe.

Also print (for simulation):
```verilog
$display("CMD SAVE %d %d %d", core_hcount_out[core_idx], core_vcount_out[core_idx], core_color_out[core_idx]);
```

---

## 8. Starter Code

See `TemplateCode/ray_marcher.v` for the full template with `// TODO` markers.

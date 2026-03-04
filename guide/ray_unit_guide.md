# Documentation: `ray_unit.v` Implementation Guide

## 1. Overview & Objective

Implement `ray_unit.v` — the **core ray marching compute unit** for a single pixel.

A single `ray_unit` accepts a pixel's screen coordinates and camera state, then iteratively marches a ray through the scene until it hits a surface or escapes. It outputs the pixel's final color intensity.

This file contains **three modules**: `march_ray`, `brick_texture`, and `ray_unit`.

**Dependencies**: `types.vh`, `fixed_point_arith.vh`, `vector_arith.vh`

---

## 2. Module 1: `march_ray`

### Purpose
Advance a ray position forward along its direction by distance `t`.

### Port Interface
```verilog
module march_ray (
    input  wire [3*`W-1:0] ray_origin_in,     // current position (vec3)
    input  wire [3*`W-1:0] ray_direction_in,  // ray direction (vec3)
    input  wire [`W-1:0]   t_in,              // step distance (fp)
    output wire [3*`W-1:0] ray_origin_out     // new position (vec3)
);
```

### Algorithm
Fully combinational (no clock needed — use `assign`):
```
scaled_dir    = vec3_scaled(ray_direction_in, t_in)
ray_origin_out = vec3_add(ray_origin_in, scaled_dir)
```
Both `scaled_dir` and `ray_origin_out` are `wire [3*\`W-1:0]`.

---

## 3. Module 2: `brick_texture`

### Purpose
Given a 3D surface point and the current ray depth (number of marching steps), produce a texture-modified color that simulates a brick pattern.

### Port Interface
```verilog
module brick_texture (
    input  wire [3*`W-1:0]            point_in,    // surface point (vec3)
    input  wire [`MAX_RAY_DEPTH_SIZE-1:0] ray_depth_in,
    output wire [`MAX_RAY_DEPTH_SIZE-1:0] color_out
);
// `MAX_RAY_DEPTH_SIZE is defined in types.vh as $clog2(`MAX_RAY_DEPTH)
// For Verilog compatibility, use the constant directly: 5 bits for MAX_RAY_DEPTH=31
```

### Algorithm
All combinational. Uses scaled point coords to create a 3D brick texture:

```
scaled_point = vec3_sl(point_in, 4)    // scale up by 16 for detail level

// Mortar offset (alternating brick row offset)
o = fp_fract(fp_mul_half(fp_floor(fp_sub(scaled_point.y, FP_HALF))))

// UV coordinate within brick
u = fp_add(fp_fract(fp_add(fp_mul_half(scaled_point.x), fp_mul_half(scaled_point.z))), o)
v = fp_fract(scaled_point.y)

// Signed distance to brick edge (negative = inside mortar)
ex = fp_sub(fp_abs(fp_sub(u, FP_HALF)), FP_TENTH)
ey = fp_sub(fp_abs(fp_sub(v, FP_HALF)), FP_TENTH)

// If both ex > 0 and ey > 0, we are inside a brick → reduce depth by 2
color_out = fp_gt(fp_min(ex, ey), FP_ZERO) ? ray_depth_in - 2 : ray_depth_in
```

**Slicing scaled_point components:**
```
scaled_point.x = scaled_point[3*W-1 : 2*W]
scaled_point.y = scaled_point[2*W-1 : W]
scaled_point.z = scaled_point[W-1 : 0]
```

---

## 4. Module 3: `ray_unit` (Main State Machine)

### Purpose
For one pixel, orchestrates the full ray marching loop:
1. Accepts pixel + camera state
2. Generates a normalized ray direction
3. Repeatedly: query SDF → advance ray → check termination
4. Outputs final color and pixel coordinates

### Port Interface
```verilog
module ray_unit #(
    parameter DISPLAY_WIDTH  = `DISPLAY_WIDTH,
    parameter DISPLAY_HEIGHT = `DISPLAY_HEIGHT,
    parameter H_BITS         = `H_BITS,
    parameter V_BITS         = `V_BITS,
    parameter MAX_RAY_DEPTH  = `MAX_RAY_DEPTH
) (
    input  wire clk_in, rst_in,
    input  wire [3*`W-1:0] ray_origin_in,      // camera position
    input  wire [3*`W-1:0] ray_direction_in,   // camera forward direction
    input  wire [2:0]      fractal_sel_in,
    input  wire [H_BITS-1:0] hcount_in,
    input  wire [V_BITS-1:0] vcount_in,
    input  wire [`W-1:0]   hcount_fp_in,
    input  wire [`W-1:0]   vcount_fp_in,
    input  wire            toggle_dither_in,
    input  wire            toggle_texture_in,
    input  wire            valid_in,
    output reg  [H_BITS-1:0] hcount_out,
    output reg  [V_BITS-1:0] vcount_out,
    output reg  [3:0]        color_out,
    output wire              ready_out
);
```

### 4.1 State Machine

Replace the `RayUnitState` enum with local parameters:
```verilog
localparam RU_Ready  = 4'd0;   // Waiting for valid_in
localparam RU_Setup  = 4'd1;   // Ray generator running
localparam RU_Busy_1 = 4'd2;   // Waiting for SDF pipeline latency
localparam RU_Busy_2 = 4'd3;   // SDF done, make decision
reg [3:0] state;
```

### 4.2 Internal Registers

```verilog
reg [H_BITS-1:0] hcount;
reg [V_BITS-1:0] vcount;
reg [2:0]        current_fractal;
reg [`W-1:0]     hcount_fp, vcount_fp;
reg [3*`W-1:0]   ray_origin, ray_direction;
reg [`MAX_RAY_DEPTH_SIZE-1:0] ray_depth;

// ray_generator_folded
reg              gen_valid_in;
wire             gen_valid_out, gen_ready_out;
reg  [3*`W-1:0]  cam_forward_in;
wire [3*`W-1:0]  ray_direction_out;

// sdf_query
wire [`W-1:0]    sdf_dist;
wire [5:0]       sdf_wait_max;
reg  [5:0]       sdf_wait;

// texture and color
wire [`MAX_RAY_DEPTH_SIZE-1:0] texture_out;
wire [`MAX_RAY_DEPTH_SIZE-1:0] current_color;
assign current_color = toggle_texture_in ? texture_out : ray_depth;

// march_ray output
wire [3*`W-1:0]  next_pos_vec;

assign ready_out = (state == RU_Ready);
```

### 4.3 State Machine Logic

**`RU_Ready`**: When `valid_in` is asserted:
- Latch `hcount_in`, `vcount_in`, `hcount_fp_in`, `vcount_fp_in`
- Latch `ray_origin_in` into `ray_origin`
- Latch `fractal_sel_in` into `current_fractal`
- Set `ray_depth = 0`, `cam_forward_in = ray_direction_in`
- Assert `gen_valid_in = 1`, go to `RU_Setup`

**`RU_Setup`**: Waiting for ray generator:
- Clear `gen_valid_in = 0`
- When `gen_valid_out` is asserted: latch `ray_direction_out` → `ray_direction`, set `sdf_wait = 0`, go to `RU_Busy_1`

**`RU_Busy_1`**: Waiting for SDF pipeline to complete:
- Increment `sdf_wait`
- When `sdf_wait + 1 == sdf_wait_max`: go to `RU_Busy_2`, else stay

**`RU_Busy_2`**: SDF result is ready in `sdf_dist`:
- Advance position: `ray_origin <= next_pos_vec`
- Check termination:
  - **Hit** if `sdf_dist < (FP_HUNDREDTH >> 1)` (very close to surface)
  - **Miss** if `sdf_dist > FP_FIVE` (escaped too far) **or** `ray_depth == MAX_RAY_DEPTH`
  
  On **hit or miss**:
  ```verilog
  color_out <= hit ? (4'hF - (current_color >> 1) - dither_correction) : 4'd0;
  hcount_out <= hcount;  vcount_out <= vcount;
  state <= RU_Ready;
  ```
  
  Where `dither_correction` (applied only on hit): 
  ```
  ((current_color >> 1) != 4'hF && toggle_dither_in && current_color[0] && (hcount[0] ^ vcount[0]))
  ```
  This adds 1-bit dithering using the pixel's checkerboard position.
  
  On **continue**: `ray_depth <= ray_depth + 1`, `sdf_wait <= 0`, go to `RU_Busy_1`

### 4.4 Submodule Instantiation

```verilog
ray_generator_folded #(...) ray_gen (
    .clk_in(clk_in), .rst_in(rst_in),
    .valid_in(gen_valid_in),
    .hcount_in(hcount), .vcount_in(vcount),
    .hcount_fp_in(hcount_fp), .vcount_fp_in(vcount_fp),
    .cam_forward_in(cam_forward_in),
    .ray_direction_out(ray_direction_out),
    .valid_out(gen_valid_out), .ready_out(gen_ready_out)
);

sdf_query scene (
    .clk_in(clk_in), .rst_in(rst_in),
    .point_in(ray_origin),
    .fractal_sel_in(current_fractal),
    .sdf_out(sdf_dist),
    .sdf_wait_max_out(sdf_wait_max)
);

brick_texture texture (
    .point_in(ray_origin),
    .ray_depth_in(ray_depth),
    .color_out(texture_out)
);

march_ray marcher (
    .ray_origin_in(ray_origin),
    .ray_direction_in(ray_direction),
    .t_in(sdf_dist),
    .ray_origin_out(next_pos_vec)
);
```

---

## 5. Starter Code

See `TemplateCode/ray_unit.v` for the full template with `// TODO` markers.

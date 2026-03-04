# Documentation: `ray_generator_folded.v` Implementation Guide

## 1. Overview & Objective

Implement `ray_generator_folded.v` — a **pipelined ray direction generator** module.

Given a pixel's screen coordinates and the camera's forward direction, this module computes the **normalized 3D ray direction** that passes through that pixel. Unlike a purely combinational version, this module saves hardware area by **reusing three multipliers** across multiple clock cycles via a state machine.

**Dependencies**: `vector_arith.vh`, `fp_inv_sqrt_folded.v`

---

## 2. The 3D Camera Model

The ray tracer uses a pinhole camera. For each pixel at screen position `(px, py)`:

```
cam_right = normalize(cross((0,1,0), cam_forward))
cam_up    = normalize(cross(cam_forward, cam_right))
ray_dir   = normalize(px * cam_right + py * cam_up + cam_forward)
```

The module computes this in stages, reusing 3 multipliers.

### Cross Product Shortcuts

Since one operand is always `(0, 1, 0)`, the cross products simplify:

```
cam_right = cross((0,1,0), cam_forward):
    cam_right.x =  cam_forward.z
    cam_right.y =  0
    cam_right.z = -cam_forward.x

cam_up = cross(cam_forward, cam_right):
    cam_up.x = cam_forward.y * cam_right.z - cam_forward.z * cam_right.y
             = cam_forward.y * (-cam_forward.x) - cam_forward.z * 0
             = -(cam_forward.y * cam_forward.x)      [one multiply, then negate]
    cam_up.y = cam_forward.z * cam_right.x - cam_forward.x * cam_right.z
             = cam_forward.z * cam_forward.z + cam_forward.x * cam_forward.x
             [two multiplies added: z² + x²]
    cam_up.z = cam_forward.x * cam_right.y - cam_forward.y * cam_right.x
             = -(cam_forward.y * cam_forward.z)      [one multiply, then negate]
```

> **Note**: `cam_right` and `cam_up` are used un-normalized in this implementation. The final normalization of `ray_dir` corrects for any length difference.

---

## 3. Port Interface

```verilog
module ray_generator_folded #(
    parameter DISPLAY_WIDTH  = `DISPLAY_WIDTH,
    parameter DISPLAY_HEIGHT = `DISPLAY_HEIGHT,
    parameter H_BITS         = `H_BITS,
    parameter V_BITS         = `V_BITS
) (
    input  wire clk_in,
    input  wire rst_in,
    input  wire valid_in,                  // asserted for one cycle to start computation
    input  wire [H_BITS-1:0] hcount_in,   // pixel column (integer)
    input  wire [V_BITS-1:0] vcount_in,   // pixel row (integer)
    input  wire [`W-1:0] hcount_fp_in,    // pre-computed horizontal FP screen coordinate
    input  wire [`W-1:0] vcount_fp_in,    // pre-computed vertical FP screen coordinate
    input  wire [3*`W-1:0] cam_forward_in,// camera forward direction (vec3, flat bus)
    output reg  valid_out,                 // high for one cycle when result is ready
    output reg  ready_out,                 // high when module can accept new input
    output reg  [3*`W-1:0] ray_direction_out // normalized ray direction (vec3, flat bus)
);
```

---

## 4. Internal Architecture

### 4.1 Three Shared Multipliers

Declare three multiplier pairs — inputs are `reg`, outputs are `wire` using `fp_mul`:

```verilog
reg  [`W-1:0] mult1_a, mult1_b,  mult2_a, mult2_b,  mult3_a, mult3_b;
wire [`W-1:0] mult1_res = fp_mul(mult1_a, mult1_b);
wire [`W-1:0] mult2_res = fp_mul(mult2_a, mult2_b);
wire [`W-1:0] mult3_res = fp_mul(mult3_a, mult3_b);
```

The multiplier inputs are driven by an `always @(*)` mux block based on `stage`.

### 4.2 Stage Register

```verilog
reg [3:0] stage;   // 0 = idle, runs through 1,2,4,7,5,6 then back to 0
```

Stage transitions: **0 → 1 → 2 → 4 → 7 → 5 → 6 → 0**

### 4.3 Internal Registered Signals

```verilog
// Stage 0 latched inputs
reg [H_BITS-1:0] hcount;
reg [V_BITS-1:0] vcount;
reg [`W-1:0] px, py;          // FP screen coords (latched from inputs)
reg [3*`W-1:0] cam_forward;   // latched copy of cam_forward_in

// Computed vectors (flat vec3 regs)
reg [3*`W-1:0] cam_right;
reg [3*`W-1:0] cam_up;
reg [3*`W-1:0] scaled_right;
reg [3*`W-1:0] scaled_up;
reg [3*`W-1:0] rd1;           // unnormalized ray direction, before inv_sqrt

// fp_inv_sqrt_folded submodule signals  
reg  fisf_valid_in;
wire fisf_valid_out, fisf_ready_out;
wire [`W-1:0] fisf_res_out;
```

### 4.4 Combinational Wires for rd0 and rd1

```verilog
wire [3*`W-1:0] _rd0 = vec3_add(scaled_right, scaled_up);
wire [3*`W-1:0] _rd1 = vec3_add(_rd0, cam_forward);
```

### 4.5 fp_inv_sqrt_folded Submodule

Instantiate this to compute `1/sqrt(|rd1|²)`:

```verilog
wire [`W-1:0] rd1_dot;
assign rd1_dot = vec3_dot(rd1, rd1);   // dot product = squared length

fp_inv_sqrt_folded fisf (
    .clk_in(clk_in), .rst_in(rst_in),
    .a_in(rd1_dot),
    .valid_in(fisf_valid_in),
    .res_out(fisf_res_out),
    .valid_out(fisf_valid_out),
    .ready_out(fisf_ready_out)
);
```

---

## 5. Stage-by-Stage Operations

### Stage 0 (Idle)
- Assert `valid_out = 0`
- When `valid_in` is high: latch `hcount_in`, `vcount_in`, `cam_forward_in`, `hcount_fp_in` (→ `px`), `vcount_fp_in` (→ `py`)
- Set `ready_out = 0`, advance to stage 1

### Stage 1 — Compute `cam_right` (no multiplier needed) and begin `cam_up`:
```
cam_right.x = cam_forward.z          (slice: cam_forward[`W-1:0])
cam_right.y = 0
cam_right.z = fp_neg(cam_forward.x)  (slice: cam_forward[3*W-1:2*W])
```
Multiplier setup (for cam_up parts in stage 1, results read in stage 1 too):
```
mult1: cam_forward.y * fp_neg(cam_forward.x)   → cam_up.x (latch from mult1_res)
mult2: cam_forward.z * cam_forward.z            → part of cam_up.y
mult3: cam_forward.x * cam_forward.x            → part of cam_up.y
cam_up.y ← fp_add(mult2_res, mult3_res)
```
Advance to stage 2.

### Stage 2 — Complete `cam_up`:
```
mult1: cam_forward.y * cam_forward.z
cam_up.z ← fp_neg(mult1_res)
```
Advance to stage 4.

### Stage 4 — Scaled right: `scaled_right = cam_right * px`
```
mult1: cam_right.x * px  →  scaled_right.x
mult2: cam_right.y * px  →  scaled_right.y
mult3: cam_right.z * px  →  scaled_right.z
```
Advance to stage 7.

### Stage 7 — Scaled up: `scaled_up = cam_up * py`
```
mult1: cam_up.x * py  →  scaled_up.x   (use blocking assignment =)
mult2: cam_up.y * py  →  scaled_up.y
mult3: cam_up.z * py  →  scaled_up.z
```
Advance to stage 5.

### Stage 5 — Submit to `fp_inv_sqrt_folded` (wait if not ready)
```
if fisf_ready_out:
    rd1 ← _rd1   (latch the combinational sum)
    fisf_valid_in ← 1
    advance to stage 6
```

### Stage 6 — Wait for `fp_inv_sqrt_folded`, then scale
```
fisf_valid_in ← 0
if fisf_valid_out:
    mult1: rd1.x * fisf_res_out  →  ray_direction_out.x
    mult2: rd1.y * fisf_res_out  →  ray_direction_out.y  (NEGATE: fp_neg)
    mult3: rd1.z * fisf_res_out  →  ray_direction_out.z
    valid_out ← 1, ready_out ← 1
    advance to stage 0
```

> **Note on Y-axis flip**: The Y component of the output is negated (`fp_neg(mult2_res)`) because screen Y increases downward, but world Y increases upward.

---

## 6. Multiplier Mux Block (`always @(*)`)

```verilog
always @(*) begin
    mult1_a = 0; mult1_b = 0;
    mult2_a = 0; mult2_b = 0;
    mult3_a = 0; mult3_b = 0;
    if (stage == 1) begin
        // TODO: fill in mult inputs for stage 1 (cam_up.x and cam_up.y)
    end else if (stage == 2) begin
        // TODO: fill in mult inputs for stage 2 (cam_up.z)
    end else if (stage == 4) begin
        // TODO: fill in mult inputs for stage 4 (scaled_right)
    end else if (stage == 7) begin
        // TODO: fill in mult inputs for stage 7 (scaled_up)
    end else if (stage == 6) begin
        // TODO: fill in mult inputs for stage 6 (final scale by fisf_res_out)
    end
end
```

---

## 7. Slicing Helper Pattern

When reading components of a `[3*W-1:0]` vec3 wire, use:
```verilog
wire [`W-1:0] cf_x, cf_y, cf_z;
assign cf_x = cam_forward[3*`W-1 : 2*`W];
assign cf_y = cam_forward[2*`W-1 :   `W];
assign cf_z = cam_forward[  `W-1 :     0];
```
Do similarly for `cam_right`, `cam_up`, `rd1` as needed.

---

## 8. Starter Code

See `TemplateCode/ray_generator_folded.v` for the full template.

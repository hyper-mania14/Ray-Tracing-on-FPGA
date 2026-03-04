# Documentation: `sdf_query.v` Implementation Guide

## 1. Overview & Objective

Implement `sdf_query.v` — the **scene distance query pipeline**. Given a 3D point in space, this file returns the signed distance to the nearest surface of the selected fractal scene.

This file contains **5 modules** (plus the top-level dispatcher). Each implements a different 3D fractal or scene and runs as a pipelined, clocked module.

**Dependencies**: `types.vh`, `fixed_point_arith.vh`, `vector_arith.vh`, `sdf_primitives.vh`

---

## 2. Verilog Translation Reference

These translations apply throughout this file:

| SystemVerilog | Verilog |
|---|---|
| `logic` (clocked) | `reg` |
| `logic` (combinational) | `wire` |
| `always_ff @(posedge clk_in)` | `always @(posedge clk_in)` |
| `always_comb` | `always @(*)` |
| `vec3 v` | `wire [3*\`W-1:0] v` or `reg [3*\`W-1:0] v` |
| `fp x` | `wire [\`W-1:0] x` or `reg [\`W-1:0] x` |
| `fp arr[N]` (array) | `wire [\`W-1:0] arr [0:N-1]` |
| `.x` field access | `v[3*\`W-1 : 2*\`W]` |
| `.y` field access | `v[2*\`W-1 : \`W]` |
| `.z` field access | `v[\`W-1 : 0]` |
| `++i` | `i = i + 1` |

---

## 3. Module 1: `sdf_query` (Top-Level Dispatcher)

### Purpose
Routes the input point to 4 sub-modules (scenes 0–3) simultaneously, then muxes the correct output based on `fractal_sel_in`. Also reports the pipeline latency of the selected scene.

### Scene table

| `fractal_sel_in` | Scene | Latency (cycles) |
|---|---|---|
| 0 | `sdf_query_sponge_inf` | 4 |
| 1 | `sdf_query_cube_infinite` | 1 |
| 2 | `sdf_query_cube` | 1 |
| 3 | `sdf_query_cube_noise` | 5 |

### Implementation
```verilog
// Array of outputs from all 4 sub-modules
wire [`W-1:0] sdf_queries [0:3];

// Mux output and latency
assign sdf_out = sdf_queries[fractal_sel_in];

always @(*) begin
    case (fractal_sel_in)
        0: sdf_wait_max_out = 4;
        1: sdf_wait_max_out = 1;
        2: sdf_wait_max_out = 1;
        3: sdf_wait_max_out = 5;
        default: sdf_wait_max_out = 1;
    endcase
end
```
Then instantiate all 4 sub-modules with `point_in` and individual `sdf_out` connected to `sdf_queries[i]`.

---

## 4. Module 2: `sdf_query_cube` (1-cycle latency)

### Purpose
Scene: A single axis-aligned cube of half-size 0.5, centered at the origin.

### Algorithm
On every clock edge, sample the SDF of a box:
```
sdf_out <= sd_box_fast(point_in, FP_HALF)
```
Where `FP_HALF` is the constant 0.5 in fixed-point (defined as `` `FP_HALF `` in `types.vh`).

---

## 5. Module 3: `sdf_query_cube_infinite` (1-cycle latency)

### Purpose
Scene: Infinitely repeating cubes tiling all of space, each of half-size 0.25.

### Algorithm
The `vec3_fract` function "wraps" coordinates into a unit cell, creating infinite repetition. We then shift by 0.5 to center each cell:

```
hhh = make_vec3(FP_HALF, FP_HALF, FP_HALF)
sdf_out <= sd_box_fast(vec3_sub(vec3_fract(vec3_add(point_in, hhh)), hhh), FP_QUARTER)
```

**Intuition**: `vec3_fract(point + 0.5) - 0.5` maps each point to the range `[-0.5, 0.5]^3`, effectively evaluating a cube at the center of each unit cell.

Declare `hhh` as a `wire [3*\`W-1:0]`:
```verilog
wire [3*`W-1:0] hhh;
assign hhh = make_vec3(`FP_HALF, `FP_HALF, `FP_HALF);
```

---

## 6. Module 4: `sdf_query_sponge` (4-cycle latency, 3 iterations)

### Purpose
Scene: A bounded **Menger Sponge** fractal with 3 levels of detail.

### Background
A Menger Sponge is a fractal created by recursively removing the center and face-centers of a cube. Each iteration multiplies the scale by 3.

### Parameters
```verilog
parameter ITERATIONS = 3;  // 3 levels of fractal detail
```

### Scale Arrays
```verilog
wire [`W-1:0] scales     [0:4];
wire [`W-1:0] inv_scales [0:4];
assign scales[0] = `FP_ONE;       assign inv_scales[0] = `FP_ONE;
assign scales[1] = `FP_THREE;     assign inv_scales[1] = `FP_THIRD;
assign scales[2] = `FP_NINE;      assign inv_scales[2] = `FP_NINTH;
assign scales[3] = `FP_TWENTY_SEVEN;  assign inv_scales[3] = `FP_TWENTY_SEVENTH;
assign scales[4] = `FP_EIGHTY_ONE;    assign inv_scales[4] = `FP_EIGHTY_ONETH;
```

### Algorithm (per iteration `i` from 1 to ITERATIONS)

```
hhh = make_vec3(1.0, 1.0, 1.0)

// Fold the point into the sponge
a = vec3_sub(
      vec3_sl(vec3_fract(vec3_sr(vec3_scaled(point_in, scales[i-1]), 1)), 1),
      hhh)

// Map to octahedral distance (distance to nearest hole)
r = vec3_abs(vec3_sub(hhh, vec3_scaled_3(vec3_abs(a))))

// Compute the SDF at this iteration level:
// Find the smallest face of r (the "opening" of the sponge)
min_face = fp_min(fp_max(r.x, r.y),
                  fp_min(fp_max(r.y, r.z),
                         fp_max(r.x, r.z)))

// Distance at this level = scale the iteration's SDF
dist_i = fp_mul(fp_sub(min_face, FP_ONE), inv_scales[i])

// Accumulate: take the max of current and previous iteration
distances[i] <= fp_max(
    i == 1 ? bounds : distances[i-1],
    dist_i
)
```

Where `bounds = sd_box_fast(point_in, FP_ONE)` is computed combinationally.

### Implementation Strategy
Since `ITERATIONS=3` is constant, use a `generate` / `genvar` loop or manually unroll for `i=1,2,3`. Each iteration has one `always @(posedge clk_in)` that latches `distances[i]` — creating the 3-cycle pipeline.

```verilog
// Array for accumulated distances
reg [`W-1:0] distances [0:3];
wire [3*`W-1:0] hhh;
assign hhh = make_vec3(`FP_ONE, `FP_ONE, `FP_ONE);
wire [`W-1:0] bounds;
assign bounds = sd_box_fast(point_in, `FP_ONE);

generate
    genvar i;
    for (i = 1; i < ITERATIONS + 1; i = i + 1) begin : sponge_loop
        wire [3*`W-1:0] a, r;
        assign a = vec3_sub(
            vec3_sl(vec3_fract(vec3_sr(vec3_scaled(point_in, scales[i-1]), 1)), 1),
            hhh);
        assign r = vec3_abs(vec3_sub(hhh, vec3_scaled_3(vec3_abs(a))));
        always @(posedge clk_in) begin
            distances[i] <= fp_max(
                i == 1 ? bounds : distances[i-1],
                fp_mul(
                    fp_sub(fp_min(fp_max(r[3*`W-1:2*`W], r[2*`W-1:`W]),
                                  fp_min(fp_max(r[2*`W-1:`W], r[`W-1:0]),
                                         fp_max(r[3*`W-1:2*`W], r[`W-1:0]))),
                           `FP_ONE),
                    inv_scales[i]));
        end
    end
endgenerate
assign sdf_out = distances[ITERATIONS];
```

---

## 7. Module 5: `sdf_query_sponge_inf` (4-cycle latency, 4-layer pipeline)

### Purpose
Scene: An **infinite** Menger sponge-like fractal with 4 layers of nested detail.

### Architecture
Four combinational computation layers (using `assign`), with registered flip-flops between each to create a 4-stage pipeline.

```
[point_in] → [Layer1 comb] → FF → [Layer2 comb] → FF → [Layer3 comb] → FF → [Layer4 comb] → FF → [sdf_out]
```

### Constants Needed
- `` `FP_MAGIC_NUMBER_A `` through `` `FP_MAGIC_NUMBER_D `` — the hole-size offsets for each layer (defined in `types.vh`)
- `` `FP_ONE ``, `` `FP_HALF ``, `` `FP_QUARTER ``, `` `FP_ONE_SIXTEENTHS ``

### Layer Computations

For each layer, compute a point `p` (folded into a cell) and a distance `d`, then register the result.

**Helper function for min-of-max-pairs:**
```
mmp(v) = fp_min(fp_max(v.x, v.y),  fp_min(fp_max(v.y, v.z), fp_max(v.x, v.z)))
```

**Layer 1** (`d1` registered from `d1_`):
```
p1 = vec3_abs(vec3_sub(
         vec3_sl(vec3_fract(vec3_sr(point_in, 1)), 1),
         make_vec3(FP_ONE, FP_ONE, FP_ONE)))
d1_ = fp_add(mmp(p1), FP_MAGIC_NUMBER_A)
// d1 <= d1_  (registered)
```

**Layer 2** (`d2` registered from `d2_`, depends on `d1`):
```
p2 = vec3_abs(vec3_sub(vec3_fract(point_in), make_vec3(FP_HALF, FP_HALF, FP_HALF)))
d2_ = fp_max(d1, fp_add(mmp(p2), FP_MAGIC_NUMBER_B))
// d2 <= d2_  (registered)
```

**Layer 3** (`d3` registered from `d3_`, depends on `d2`):
```
p3 = vec3_abs(vec3_sub(
         vec3_sr(vec3_fract(vec3_sl(point_in, 1)), 1),
         make_vec3(FP_QUARTER, FP_QUARTER, FP_QUARTER)))
d3_ = fp_max(d2, fp_add(mmp(p3), FP_MAGIC_NUMBER_C))
// d3 <= d3_  (registered)
```

**Layer 4** (`sdf_out` registered from `sdf_out_`, depends on `d3`):
```
p4 = vec3_abs(vec3_sub(
         vec3_sr(vec3_fract(vec3_sl(point_in, 3)), 3),
         make_vec3(FP_ONE_SIXTEENTHS, FP_ONE_SIXTEENTHS, FP_ONE_SIXTEENTHS)))
sdf_out_ = fp_max(d3, fp_add(mmp(p4), FP_MAGIC_NUMBER_D))
// sdf_out <= sdf_out_  (registered)
```

---

## 8. Module 6: `sdf_query_cube_noise` (5-cycle latency)

### Purpose
Scene: A cube lattice where each cube has a procedurally placed "hole" based on a hash of its integer grid position. Creates a labyrinth-like appearance.

### 5-Stage Pipeline

Declare pipeline-delay registers for `poke` (the sub-cell position of the point) and `cube_s?` (the grid cell center). Pass them forward each stage:

```verilog
// Pipeline delay regs for poke (5 stages)
reg [3*`W-1:0] poke_s2, poke_s3, poke_s4, poke_s5;
// Pipeline delay regs for cube (3 stages)
reg [3*`W-1:0] cube_s2, cube_s3;
```

**Stage 1 — Divide space into cubes:**
```
hhh   = make_vec3(FP_HALF, FP_HALF, FP_HALF)
cube  = vec3_add(vec3_floor(point_in), hhh)   // integer grid center (vec3)
poke  = vec3_sub(point_in, cube)               // offset within the cube [-0.5, 0.5]
_octa1 = vec3_abs(poke)                        // fold into positive octant
```
Register: `octa1 <= _octa1`. Also pipeline: `poke_s2 <= poke`, `cube_s2 <= cube`.

**Stage 2 — Find dominant face (octahedral classification):**
```
octa2 = vec3_step(make_vec3(octa1.y, octa1.z, octa1.x), octa1)
        // vec3_step(b, a) returns 1.0 where a >= b, 0.0 where a < b
octa3 = vec3_step(make_vec3(octa1.z, octa1.x, octa1.y), octa1)
_octa4 = octa2 & octa3   // bitwise AND of the two step results
```
Register: `octa4 <= _octa4`. Pipeline: `poke_s3 <= poke_s2`, `cube_s3 <= cube_s2`.

**Stage 3 — Compute unique sub-cube ID:**
```
_id = vec3_add(cube_s3, vec3_apply_sign(vec3_scaled_half(octa4), poke_s3))
```
`vec3_apply_sign(a, b)` copies the sign of `b` onto `a` component-wise.  
Register: `id <= _id`. Pipeline: `poke_s4 <= poke_s3`.

**Stage 4 — Hash the ID to a single float:**
```
_hash = fp_fract(vec3_dot(id, make_vec3(FP_THREE_HALFS, FP_THIRD, FP_QUARTER)))
```
The dot product with irrational-ish constants creates a pseudo-random hash.  
Register: `hash <= _hash`. Pipeline: `poke_s5 <= poke_s4`.

**Stage 5 — Select hole axis from hash, compute SDF:**
Based on `hash`:
- If `hash <= 1/3`: use poke_s5.x and poke_s5.y
- If `1/3 < hash <= 1/2`: use poke_s5.y and poke_s5.z
- If `hash > 1/2`: use poke_s5.x and poke_s5.z

```
x = fp_abs(fp_gt(hash, FP_THIRD) ? (fp_gt(hash, FP_HALF) ? poke_s5.x : poke_s5.y) : poke_s5.x)
y = fp_abs(fp_gt(hash, FP_THIRD) ? (fp_gt(hash, FP_HALF) ? poke_s5.z : poke_s5.z) : poke_s5.y)
_sdf_out = fp_sub(fp_max(x, y), FP_ONE_SIXTEENTHS)
```
Register: `sdf_out <= _sdf_out`.

---

## 9. Starter Code

See `TemplateCode/sdf_query.v` for the full template with `// TODO` markers.

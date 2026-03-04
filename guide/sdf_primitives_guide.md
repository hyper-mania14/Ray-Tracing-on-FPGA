# Documentation: `sdf_primitives.vh` Implementation Guide

## 1. Overview & Objective

Implement `sdf_primitives.vh` — a Verilog library of **Signed Distance Functions (SDFs)** for 3D primitive shapes.

This file is `include`d by `sdf_query.v`. It provides building blocks used during ray marching to determine how close a point in space is to a scene object.

**Dependencies**: `types.vh`, `fixed_point_arith.vh` (both already implemented)

---

## 2. Background: What is an SDF?

A **Signed Distance Function** takes a 3D point and returns the signed distance to the nearest surface of a shape:
- **Positive**: point is *outside* the shape
- **Negative**: point is *inside* the shape  
- **Zero**: point is exactly *on* the surface

The ray marcher uses this value to know how far it can safely step along the ray without overshooting into geometry.

---

## 3. Data Types

All values in this file use the **fixed-point** format defined in `types.vh`.

| Type | Verilog representation | Width |
|------|----------------------|-------|
| `fp` (fixed-point scalar) | `[`W-1:0]` | `W = `\`NUM_ALL_DIGITS`` |
| `vec3` (3D vector) | flat `[3*`W-1:0]` bus | 3 × W bits |

**Slicing a vec3 to get components:**
```verilog
px = point[3*`W-1 : 2*`W];   // X (high bits)
py = point[2*`W-1 :   `W];   // Y (middle bits)
pz = point[  `W-1 :     0];  // Z (low bits)
```

**Available fp math functions** (from `fixed_point_arith.vh`):
- `fp_abs(a)` — absolute value
- `fp_max(a, b)` — maximum
- `fp_sub(a, b)` — subtraction

---

## 4. Function to Implement: `sd_box_fast`

### Signature
```verilog
function [`W-1:0] sd_box_fast;
    input [3*`W-1:0] point;       // query point (vec3)
    input [`W-1:0]   halfExtents; // half-size of box (fp scalar)
```

### What it Does
Returns the signed distance from `point` to a **cube centered at the origin**, where the cube extends from `-halfExtents` to `+halfExtents` on all three axes.

This uses the **L-infinity norm** — the max of coordinate absolute values — as the distance metric, which naturally produces a cube shape.

### Algorithm

**Step 1 — Extract X, Y, Z from the flat vec3 bus:**
```
px = point[3*W-1 : 2*W]
py = point[2*W-1 : W]
pz = point[W-1 : 0]
```

**Step 2 — Take the absolute value of each coordinate:**
```
x_abs = |px|
y_abs = |py|
z_abs = |pz|
```

**Step 3 — Find the L-infinity norm (maximum across all axes):**
```
xy_max  = max(x_abs, y_abs)
xyz_max = max(xy_max, z_abs)
```

**Step 4 — Subtract the box half-size to get signed distance:**
```
result = xyz_max − halfExtents
```

**Worked example:**
- Point = (0.3, 0.1, 0.2), halfExtents = 0.5
- Absolute values: (0.3, 0.1, 0.2)
- xyz_max = 0.3
- Distance = 0.3 − 0.5 = **−0.2** → point is *inside* the box ✓

- Point = (0.6, 0.1, 0.2), halfExtents = 0.5
- xyz_max = 0.6
- Distance = 0.6 − 0.5 = **+0.1** → point is *outside* the box ✓

---

## 5. Starter Code

See `TemplateCode/sdf_primitives.vh` for the full template with `// TODO` markers.

```verilog
function [`W-1:0] sd_box_fast;
    input [3*`W-1:0] point;
    input [`W-1:0]   halfExtents;
    reg [`W-1:0] px, py, pz;
    reg [`W-1:0] x_abs, y_abs, z_abs, xy_max, xyz_max;
    begin
        // TODO: Implement the 4-step algorithm above
        sd_box_fast = 0; // REPLACE THIS
    end
endfunction
```

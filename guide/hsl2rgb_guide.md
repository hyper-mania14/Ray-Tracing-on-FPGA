# Documentation: `hsl2rgb.vh` Implementation Guide

## 1. Overview & Objective

Implement the file `hsl2rgb.vh` — a Verilog color conversion library.

This file contains **two functions** that are included by `vga_display.v` to convert color values into 24-bit RGB output for the VGA display. It has **no external dependencies**.

The VGA display uses these functions to colorize the grayscale ray-marching output using an animated hue shift.

---

## 2. Data Types

All inputs are **unsigned 8-bit integers** (`[7:0]`). The return type of both functions is a **24-bit packed RGB bus** `[23:0]`:

```
Output: [23:0]
  Bits [23:16] = Red channel (R)
  Bits [15:8]  = Green channel (G)
  Bits [7:0]   = Blue channel (B)
```

---

## 3. Verilog Function Rules

These apply to every function in this file:

| Rule | Detail |
|------|--------|
| Return type | `[23:0]` (NOT `[7:0][2:0]` — that's SystemVerilog only) |
| Local variables | Use `reg`, not `logic` |
| No `return` statement | Assign to the function name: `func_name = value;` |
| No `automatic` keyword | Remove it |
| 16-bit intermediates | Use `reg [15:0]` for values that can exceed 255 |

---

## 4. Function 1: `rgb2rgb`

**Purpose**: A trivial passthrough that packs three 8-bit values into one 24-bit bus.

**Inputs**: `h [7:0]`, `s [7:0]`, `l [7:0]`  
**Output**: `{h, s, l}` packed as `[23:0]`

**Implementation**: One line using Verilog concatenation.

---

## 5. Function 2: `hsl2rgb` — Full Algorithm

**Purpose**: Convert HSL (Hue, Saturation, Lightness) color space to RGB.  
**Inputs**: `h`, `s`, `l` — all `[7:0]` unsigned (range 0–255)  
**Output**: 24-bit packed `{R, G, B}`

### Step-by-Step Algorithm

> All arithmetic is integer arithmetic. Use `reg [15:0]` for `l1`, `h1`, `Hh` to avoid overflow. All others are `reg [7:0]`.

**Step 1 — Compute `l1`:**
```
l1 = l + 1
```

**Step 2 — Compute chroma `c` (how colorful the output is):**
```
if l1 < 128:
    c = ((l1 << 1) * s) >> 8
else:
    c = (512 - (l1 << 1)) * s >> 8
```
Write as a Verilog ternary expression.

**Step 3 — Scale hue into sextant space:**
```
Hh = h * 6      (range: 0 to 1530)
```

**Step 4 — Extract low byte:**
```
lo = Hh[7:0]    (lower 8 bits of Hh)
```

**Step 5 — Interpolation factor:**
```
h1 = lo + 1
```

**Step 6 — Compute secondary component `x`:**
```
if Hh[8] == 0:  x = (h1 * c) >> 8
else:           x = ((256 - h1) * c) >> 8
```
`Hh[8]` is bit index 8 of the 16-bit `Hh` — it indicates odd vs even sextant.

**Step 7 — Lightness offset:**
```
m = l - (c >> 1)
```

**Step 8 — Assign R, G, B based on color wheel sextant:**

The sextant is `Hh[9:8]` (values 0–5). Use it to select which component gets full chroma (`c`), partial (`x`), or zero:

| `Hh[9:8]` | Color Range | R | G | B |
|-----------|-------------|---|---|---|
| 0 | Red → Yellow | c | x | 0 |
| 1 | Yellow → Green | x | c | 0 |
| 2 | Green → Cyan | 0 | c | x |
| 3 | Cyan → Blue | 0 | x | c |
| 4 | Blue → Magenta | x | 0 | c |
| 5 | Magenta → Red | c | 0 | x |

Use nested ternary expressions in Verilog to implement this table.

**Step 9 — Apply offset and return:**
```
output = {(r + m), (g + m), (b + m)}
```

---

## 6. Starter Code

See `TemplateCode/hsl2rgb.vh` for the full starter code template with `// TODO` markers.

---

## 7. Testing

After implementation, mentally verify:
- `hsl2rgb(0, 255, 127)` → pure red `{255, 0, 0}` (approximately)
- `hsl2rgb(85, 255, 127)` → pure green (approximately)
- `hsl2rgb(170, 255, 127)` → pure blue (approximately)
- `hsl2rgb(0, 0, 127)` → medium gray `{127, 127, 127}` (approximately)

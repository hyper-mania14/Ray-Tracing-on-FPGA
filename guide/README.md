# FPGA Ray Marcher — Verilog Port: Junior Assignment Index

## Overview

This is a term project to port an FPGA ray marcher from SystemVerilog to standard **Verilog-2001**. You will implement the Verilog files described below from scratch, guided only by this index and the individual guide documents in this folder.

**You will not be given the original SystemVerilog source files.** Each guide contains a complete algorithmic description and starter code template — everything you need to implement the correct behavior.

---

## Files Already Completed ✅

These are available in the project `src/` directory for reference:

| File | Description |
|---|---|
| `types.vh` | All constants, macro definitions, fixed-point parameters |
| `fixed_point_arith.vh` | Fixed-point math functions (fp_add, fp_mul, fp_inv_sqrt, etc.) |
| `vector_arith.vh` | 3D vector functions (vec3_add, vec3_dot, vec3_normed, etc.) |
| `fixed_point_alu.v` | Combinational ALU for FP operations |
| `fp_inv_sqrt_folded.v` | Multi-stage pipelined inverse square root |
| `ray_generator.v` | Combinational (non-pipelined) ray direction generator |

---

## Your Assignment: Files to Implement

### Tier 1 — Easier (Start Here)

| File to Create | Guide | Difficulty |
|---|---|---|
| `iverilog_hack.vh` | `simpler_modules_guide.md` §1 | ⭐ — one macro, no logic |
| `hsl2rgb.vh` | `hsl2rgb_guide.md` + `hsl2rgb.vh` template | ⭐⭐ — 2 functions, no dependencies |
| `sdf_primitives.vh` | `sdf_primitives_guide.md` + `sdf_primitives.vh` template | ⭐⭐ — 1 function, clear math |
| `aggregate.v` | `simpler_modules_guide.md` §2 | ⭐⭐ — counter + shift register |

### Tier 2 — Intermediate

| File to Create | Guide | Difficulty |
|---|---|---|
| `vga_display.v` | `vga_display_guide.md` | ⭐⭐⭐ — pipeline + color conversion |
| `bram_manager.v` | `simpler_modules_guide.md` §3 | ⭐⭐⭐ — double-buffer logic |
| `ray_generator_folded.v` | `ray_generator_folded_guide.md` + `.v` template | ⭐⭐⭐⭐ — state machine + 3D math |

### Tier 3 — Advanced

| File to Create | Guide | Difficulty |
|---|---|---|
| `sdf_query.v` | `sdf_query_guide.md` | ⭐⭐⭐⭐ — 5 fractal modules, pipelines |
| `ray_unit.v` | `ray_unit_guide.md` | ⭐⭐⭐⭐⭐ — ray march state machine |
| `ray_marcher.v` | `ray_marcher_guide.md` | ⭐⭐⭐⭐⭐ — multi-core controller |
| `top_level_main.v` | `simpler_modules_guide.md` §4 | ⭐⭐⭐⭐ — wiring everything together |

### Simple Port-Only Files (minimal guide needed)

These files use only standard `logic`/`always_ff` patterns with no custom types. Port them by:
1. Renaming `.sv` → `.v`
2. Replacing `logic` with `reg`/`wire`
3. Replacing `always_ff @(posedge clk)` → `always @(posedge clk)`
4. Replacing `always_comb` → `always @(*)`

> Ask your project lead for the allowed `.sv` files to reference for these modules.

---

## Build Order (Dependency Chain)

```
1. iverilog_hack.vh
2. types.vh             ✅
3. fixed_point_arith.vh ✅
4. vector_arith.vh      ✅
     ↓
5. hsl2rgb.vh
6. sdf_primitives.vh
7. fp_inv_sqrt_folded.v ✅
8. fixed_point_alu.v    ✅
     ↓ (simple port-only files: debouncer, fps_counter, etc.)
9.  ray_generator.v     ✅
10. ray_generator_folded.v
11. sdf_query.v
12. ray_unit.v
13. ray_marcher.v
14. vga_display.v
15. bram_manager.v
16. top_level_main.v    (last — depends on everything)
```

---

## Key Verilog-2001 Rules (Always Apply)

| Concept | SystemVerilog (NOT allowed) | Verilog-2001 (use this) |
|---|---|---|
| Sequential | `always_ff @(posedge clk)` | `always @(posedge clk)` |
| Combinational | `always_comb` | `always @(*)` |
| Wire type | `logic` | `wire` |
| Reg type | `logic` | `reg` |
| Return | `return x;` | `func_name = x;` |
| Loop increment | `++i` | `i = i + 1` |
| Integer loop var | `int i` | `integer i` |
| vec3 access | `v.x` | `v[3*W-1 : 2*W]` |
| Enum type | `typedef enum {...} State` | `localparam` + `reg [N:0]` |
| Local in generate | `vec3 a` inside `begin:loop` | Use `wire [3*W-1:0] gen_a [0:N-1]` outside |

# Documentation: Simpler Modules Implementation Guide

This guide covers modules without `vec3`/`fp` types. Translation is mostly mechanical.

---

## Universal Translation Rules

| SystemVerilog | Verilog-2001 |
|---|---|
| `logic` (combinational) | `wire` |
| `logic` (sequential) | `reg` |
| `always_ff @(posedge clk)` | `always @(posedge clk)` |
| `always_comb` | `always @(*)` |
| `logic [N][M] arr` (packed 2D) | `reg [M-1:0] arr [0:N-1]` (unpacked) |
| `++i` | `i = i + 1` |
| `int i` | `integer i` |
| Initialize in declaration (`logic x = val`) | Separate `always @(posedge clk)` reset |

---

## Module 1: `iverilog_hack.vh`

**Purpose**: Defines the `` `FPATH(X) `` macro used to reference data files in simulation.

**Task**: Create `iverilog_hack.vh`. The file should:
1. Have include guard `` `ifndef IVERILOG_HACK_VH `` / `` `define IVERILOG_HACK_VH `` / `` `endif ``
2. Define the macro: `` `define FPATH(X) `"data/X`" ``

That is the entire file. No logic, no modules.

---

## Module 2: `aggregate.v`

**Purpose**: Accumulate 2-bit serial inputs (`axiid`) into 32-bit parallel words (`axiod`). Outputs the word once 32 two-bit groups are received.

**Port Interface**:
```verilog
module aggregate (
    input  wire clk, rst,
    input  wire axiiv,       // input valid
    input  wire [1:0] axiid, // 2-bit input data
    output reg  axiov,       // output valid
    output reg  [31:0] axiod // 32-bit accumulated output
);
```

**Algorithm (`always @(posedge clk)`):**
- On `rst`: set `cnt = 0`, `axiov = 0`
- When `axiiv`:
  - If `cnt < 31`: store `axiid` in `buffer[31 - cnt]`, increment `cnt`
  - If `cnt == 31`: increment `cnt`, set `axiov = 1`, store `axiid` in `buffer[0]`; output `axiod` from buffer
  - If `cnt > 31`: `axiov = 0`
- When NOT `axiiv`: reset `cnt = 0`, `axiov = 0`

**Verilog 2D array**: Use `reg [1:0] buffer [0:31];` — this is an unpacked array where `buffer[i]` is 2 bits wide.  

**Reconstructing axiod**: After filling `buffer[0..31]`, you cannot directly slice an unpacked array as `buffer[31:0]`. Instead, build the 32-bit word by concatenating sequentially in a `begin..end` block or use a generate loop. Alternatively, use a single `reg [63:0]` packed bus and index with `2*i` slices.

---

## Module 3: `bram_manager.v`

**Purpose**: Manages double-buffering of two BRAMs. The ray marcher writes into one BRAM while the VGA display reads from the other. On `swap_buffers`, the write/read assignment flips.

**Port Interface**:
```verilog
module bram_manager #(
    parameter WIDTH    = `COLOR_BITS,
    parameter DEPTH    = `BRAM_SIZE,
    parameter ADDR_LEN = `ADDR_BITS
) (
    input  wire clk, rst,
    input  wire swap_buffers,              // pulse high for one cycle to swap
    input  wire [ADDR_LEN-1:0] read_addr,
    input  wire write_enable,
    input  wire [ADDR_LEN-1:0] write_addr,
    input  wire [WIDTH-1:0]    write_data,
    output reg  [WIDTH-1:0]    read_data_out,
    output wire                which_bram_out
);
```

**Double-Buffer Logic**:
```
which_bram_in  = swap_buffers ? !which_bram_mid : which_bram_mid
which_bram_out = !which_bram_end     (exposed so VGA knows which BRAM to read)
read_data_out  = !which_bram_out ? bram0_doutb : bram1_doutb

always @(posedge clk):
    which_bram_mid <= which_bram_in
    which_bram_end <= which_bram_mid
```

**BRAM Instantiation**: Instantiate two `xilinx_true_dual_port_read_first_1_clock_ram` modules. Write-enable is steered:
```
bram0.wea = write_enable && (which_bram_in == 1'b0)
bram1.wea = write_enable && (which_bram_in == 1'b1)
```
Both BRAMs always receive the same write address/data, but only one gets `wea` asserted.  
Read port (port B) connects to `read_addr` for both. You select from the output using `which_bram_out`.

Use `` `FPATH(pop_cat.mem) `` as the `INIT_FILE` parameter (the macro resolves to `"data/pop_cat.mem"`).

---

## Module 4: `top_level_main.v`

**Purpose**: Top-level FPGA module connecting all subsystems: clocks, buttons, keyboard, ray marcher pipeline, VGA output, BRAM, Ethernet export, and FPS counter.

This module is **mostly instantiation and wiring**. The main challenge is translating SV types.

### Key Translations

**`vec3` port signals** → flat buses:
```verilog
// Instead of: vec3 pos_vec, dir_vec;
wire [3*`NUM_ALL_DIGITS-1:0] pos_vec, dir_vec;
```

**`logic sys_rst = !cpu_resetn`** → must separate:
```verilog
wire sys_rst;
assign sys_rst = !cpu_resetn;
```

**`logic [7:0] ps2_buffer [3:0]`** → unpacked array:
```verilog
reg [7:0] ps2_buffer [0:3];
```

**`always_ff @(posedge sys_clk)`** → `always @(posedge sys_clk)`

### Clock Instantiation
Use the `` `CLK_CONVERTER_TYPE `` macro (resolves from `types.vh`):
```verilog
`CLK_CONVERTER_TYPE clk_converter (
    .clk_100mhz_in(clk_100mhz),
    .clk_50mhz_out(eth_refclk),
    .clk_40mhz_out(sys_clk),
    .reset(sys_rst)
);
```

### Port Declaration Order
In Verilog-2001, you cannot have initialization in port declarations. Remove any `= value` from `output` and `logic` declarations; handle reset in `always @(posedge clk)` blocks.

### Submodule Connections
Connect all submodules exactly as described in each module's own guide. Pass `pos_vec`/`dir_vec` flat buses directly to `ray_marcher` (which also expects flat buses after you port it).

> **Recommended approach**: Port this module **last**, after all submodules are working and tested individually.

#!/bin/bash
# =============================================================================
# run_tests.sh — Run Verilog testbenches using iverilog + vvp
#
# Usage: ./run_tests.sh [test_name]
#   Examples:
#     ./run_tests.sh               (runs all tests)
#     ./run_tests.sh hsl2rgb       (runs only hsl2rgb test)
#
# Requirements: iverilog and vvp must be installed
#   Ubuntu:  sudo apt install iverilog
#   macOS:   brew install icarus-verilog
#
# Directory structure assumed:
#   guide/          ← this folder (guides + testbenches)
#   src/            ← completed .vh and .v files (types, fixed_point_arith, etc.)
# =============================================================================

set -e

SRC="../src"        # Path to completed src files
GUIDE="."           # This directory (guide folder)
OUT="./sim_out"     # Where compiled simulation binaries go

mkdir -p "$OUT"

# Shared include flags — always add both src and guide dirs
INC="-I$SRC -I$GUIDE"

# Helper: compile + run one test
run_test() {
  local name="$1"
  shift
  local files="$@"
  echo ""
  echo "======================================================"
  echo " Running: $name"
  echo "======================================================"
  iverilog -g2001 $INC -o "$OUT/${name}.out" $files \
    && vvp "$OUT/${name}.out" \
    && echo "[OK] $name passed" \
    || echo "[FAIL] $name failed"
}

# Determine which test to run
TARGET="${1:-all}"

case "$TARGET" in

  hsl2rgb|all)
    run_test "hsl2rgb" \
      "$GUIDE/hsl2rgb_tb.v"
    ;;&  # fall through if "all"

  sdf_primitives|all)
    run_test "sdf_primitives" \
      "$GUIDE/sdf_primitives_tb.v"
    ;;&

  ray_generator_folded|all)
    run_test "ray_generator_folded" \
      "$SRC/fp_inv_sqrt_folded.v" \
      "$GUIDE/ray_generator_folded.v" \
      "$GUIDE/ray_generator_folded_tb.v"
    ;;&

  sdf_query|all)
    run_test "sdf_query" \
      "$GUIDE/sdf_query.v" \
      "$GUIDE/sdf_query_tb.v"
    ;;&

  ray_unit|all)
    run_test "ray_unit" \
      "$SRC/fp_inv_sqrt_folded.v" \
      "$GUIDE/ray_generator_folded.v" \
      "$GUIDE/sdf_query.v" \
      "$GUIDE/ray_unit.v" \
      "$GUIDE/ray_unit_tb.v"
    ;;&

  ray_marcher|all)
    run_test "ray_marcher" \
      "$SRC/fp_inv_sqrt_folded.v" \
      "$GUIDE/ray_generator_folded.v" \
      "$GUIDE/sdf_query.v" \
      "$GUIDE/ray_unit.v" \
      "$GUIDE/ray_marcher.v" \
      "$GUIDE/ray_marcher_tb.v"
    ;;&

  bram_manager|all)
    # Note: bram_manager needs Xilinx BRAM model or a stub
    # Provide xilinx_true_dual_port_read_first_1_clock_ram.v in src/ or guide/
    run_test "bram_manager" \
      "$SRC/xilinx_true_dual_port_read_first_1_clock_ram.v" \
      "$GUIDE/bram_manager.v" \
      "$GUIDE/bram_manager_tb.v"
    ;;&

  all)
    echo ""
    echo "======================================================"
    echo " All tests complete."
    echo "======================================================"
    ;;

  *)
    echo "Unknown test: $TARGET"
    echo "Valid options: hsl2rgb, sdf_primitives, ray_generator_folded, sdf_query, ray_unit, ray_marcher, bram_manager, all"
    exit 1
    ;;
esac

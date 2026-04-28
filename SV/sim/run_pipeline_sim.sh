#!/usr/bin/env bash
# run_pipeline_sim.sh — compile and run the MIPS 5-stage pipeline testbench.
#
# Usage (from project root):
#   bash SV/sim/run_pipeline_sim.sh           # compile + run
#   bash SV/sim/run_pipeline_sim.sh --wave    # compile + run + VCD waveform
#
# Requirements:
#   iverilog >= 11 (SystemVerilog packages, structs, enum)
#   vvp       (ships with iverilog)
#
# Install: sudo apt install iverilog   OR   brew install icarus-verilog

set -e

OUT="SV/sim/work/pipeline_sim.vvp"
WAVE_FLAGS=""
VCD_FILE="SV/sim/pipeline_wave.vcd"
if [[ "$1" == "--wave" ]]; then
    WAVE_FLAGS="-DDUMP_VCD"
fi

if ! command -v iverilog &>/dev/null; then
    echo "ERROR: iverilog not found."
    echo "  Ubuntu: sudo apt install iverilog"
    echo "  macOS:  brew install icarus-verilog"
    exit 1
fi

mkdir -p SV/sim/work

echo "=== Compiling pipeline sources ==="
iverilog -g2012 -Wall \
    $WAVE_FLAGS \
    -o "$OUT" \
    SV/MIPS_package.sv \
    SV/pipeline/pipe_pkg.sv \
    SV/pipeline/pipe_regfile.sv \
    SV/pipeline/pipe_imem.sv \
    SV/pipeline/pipe_dmem.sv \
    SV/pipeline/mips_pipeline.sv \
    SV/decoder7seg.sv \
    SV/pipeline/mips_pipe_top.sv \
    SV/sim/pipeline_tb.sv

echo ""
echo "=== Running pipeline simulation ==="
if [[ -n "$WAVE_FLAGS" ]]; then
    vvp "$OUT" "+dumpfile=$VCD_FILE"
else
    vvp "$OUT"
fi

echo ""
echo "=== Done ==="
[[ -n "$WAVE_FLAGS" ]] && echo "Waveform: $VCD_FILE  (open with gtkwave)"

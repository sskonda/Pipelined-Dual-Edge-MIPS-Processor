#!/usr/bin/env bash
# run_sim.sh — compile and run the MIPS SystemVerilog design with iverilog.
#
# Usage (from project root):
#   bash SV/sim/run_sim.sh           # compile + run
#   bash SV/sim/run_sim.sh --wave    # compile + run + dump VCD waveform
#
# Requirements:
#   iverilog >= 11 (for SystemVerilog package / enum support)
#   vvp       (ships with iverilog)
#
# Install on Ubuntu/Debian:  sudo apt install iverilog
# Install on macOS (brew):   brew install icarus-verilog

set -e

TOP_TB="MIPS_full_tb"
OUT="SV/sim/work/sim.vvp"

# Waveform flag
WAVE_FLAGS=""
VCD_FILE="SV/sim/wave.vcd"
if [[ "$1" == "--wave" ]]; then
    WAVE_FLAGS="-DDUMP_VCD"
fi

# Check iverilog is available
if ! command -v iverilog &>/dev/null; then
    echo "ERROR: iverilog not found. Install with:"
    echo "  Ubuntu/Debian: sudo apt install iverilog"
    echo "  macOS:         brew install icarus-verilog"
    exit 1
fi

mkdir -p SV/sim/work

echo "=== Compiling SystemVerilog sources ==="
iverilog -g2012 -Wall \
    $WAVE_FLAGS \
    -o "$OUT" \
    SV/MIPS_package.sv \
    SV/mux_2x1.sv \
    SV/mux_3x1.sv \
    SV/mux_4x1.sv \
    SV/mips_reg.sv \
    SV/sign_extend.sv \
    SV/shift_left2.sv \
    SV/shift_left_concat.sv \
    SV/decoder7seg.sv \
    SV/MIPS_Instruction_Reg.sv \
    SV/registerfile.sv \
    SV/MIPS_ALU.sv \
    SV/ALU_Control.sv \
    SV/RAM.sv \
    SV/MIPS_memory.sv \
    SV/MIPS_datapath.sv \
    SV/MIPS_ctrl.sv \
    SV/MIPS_top_level.sv \
    SV/sim/MIPS_full_tb.sv

echo ""
echo "=== Running simulation ==="
if [[ -n "$WAVE_FLAGS" ]]; then
    vvp "$OUT" "+dumpfile=$VCD_FILE"
else
    vvp "$OUT"
fi

echo ""
echo "=== Done ==="
if [[ -n "$WAVE_FLAGS" ]]; then
    echo "Waveform written to: $VCD_FILE"
    echo "Open with:  gtkwave $VCD_FILE &"
fi

#!/usr/bin/env bash
# run_pipeline_sim.sh  —  GHDL compile + simulate the VHDL 5-stage pipeline.
#
# Usage (from project root):
#   bash VHDL/sim/run_pipeline_sim.sh           # compile + run
#   bash VHDL/sim/run_pipeline_sim.sh --wave    # compile + run + VCD waveform
#
# Requirements:
#   ghdl >= 0.37 with VHDL-2008 support  (process(all) syntax)
#
#   Ubuntu: sudo apt install ghdl
#   macOS:  brew install ghdl
#   Build:  https://github.com/ghdl/ghdl

set -e

WORK_DIR="VHDL/sim/work"
VCD_FILE="VHDL/sim/pipeline_wave.vcd"
VCD_FLAG=""

if [[ "$1" == "--wave" ]]; then
    VCD_FLAG="--vcd=$VCD_FILE"
fi

# Locate ghdl — check PATH first, then common local install locations
if ! command -v ghdl &>/dev/null; then
    LOCAL_GHDL=$(find "$HOME/.local/ghdl" -name "ghdl" -type f 2>/dev/null | head -1)
    if [[ -n "$LOCAL_GHDL" ]]; then
        alias ghdl="$LOCAL_GHDL"
        export PATH="$(dirname "$LOCAL_GHDL"):$PATH"
    else
        echo "ERROR: ghdl not found."
        echo "  Ubuntu: sudo apt install ghdl"
        echo "  macOS:  brew install ghdl"
        echo "  Or download from https://github.com/ghdl/ghdl/releases"
        exit 1
    fi
fi

mkdir -p "$WORK_DIR"

# ── 1. Analyse all sources in dependency order ──────────────────────────────
echo "=== Analysing VHDL pipeline sources ==="
ghdl -a --std=08 --work=work --workdir="$WORK_DIR" \
    VHDL/MIPS_package.vhd         \
    VHDL/pipeline/pipe_pkg.vhd    \
    VHDL/pipeline/pipe_regfile.vhd \
    VHDL/pipeline/pipe_imem.vhd   \
    VHDL/pipeline/pipe_dmem.vhd   \
    VHDL/pipeline/mips_pipeline.vhd \
    VHDL/decoder7seg.vhd          \
    VHDL/pipeline/mips_pipe_top.vhd \
    VHDL/sim/pipeline_tb.vhd

# ── 2. Elaborate the testbench ───────────────────────────────────────────────
echo ""
echo "=== Elaborating pipeline_tb ==="
ghdl -e --std=08 --work=work --workdir="$WORK_DIR" pipeline_tb

# ── 3. Run simulation ────────────────────────────────────────────────────────
echo ""
echo "=== Running simulation ==="
ghdl -r --std=08 --work=work --workdir="$WORK_DIR" \
    pipeline_tb \
    --stop-time=200us \
    $VCD_FLAG

echo ""
echo "=== Done ==="
if [[ -n "$VCD_FLAG" ]]; then
    echo "Waveform written to: $VCD_FILE"
    echo "Open with: gtkwave $VCD_FILE"
fi

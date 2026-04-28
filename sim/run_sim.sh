#!/usr/bin/env bash
# run_sim.sh – compile every VHDL source with GHDL then run the full testbench.
#
# Uses the behavioral RAM in sim/RAM.vhd instead of the Altera megafunction
# in VHDL/RAM.vhd, which depends on altera_mf and cannot be simulated with GHDL.
#
# Usage:
#   cd <project-root>
#   bash sim/run_sim.sh           # compile + run
#   bash sim/run_sim.sh --wave    # compile + run + dump waveform (sim/wave.ghw)

set -e

GHDL="${HOME}/.local/ghdl/ghdl-mcode-6.0.0-ubuntu24.04-x86_64/bin/ghdl"
STD="--std=08"
WORK="--work=work"
WORKDIR="sim/work"

# Top-level testbench entity (must match the entity name in MIPS_full_tb.vhd)
TB_ENTITY="MIPS_full_tb"

# Waveform flag
WAVE_FLAGS=""
if [[ "$1" == "--wave" ]]; then
    WAVE_FLAGS="--wave=sim/wave.ghw"
fi

# --------------------------------------------------------------------
# Compilation order (dependencies first)
# --------------------------------------------------------------------
SOURCES=(
    # Package
    "VHDL/MIPS_package.vhd"

    # Leaf components (no inter-component dependencies)
    "VHDL/mux2x1.vhd"
    "VHDL/mux_3x1.vhd"
    "VHDL/mux_4x1.vhd"
    "VHDL/register_entity.vhd"
    "VHDL/sign_extend.vhd"
    "VHDL/shift_left2.vhd"
    "VHDL/shift_left_concat.vhd"
    "VHDL/decoder7seg.vhd"
    "VHDL/MIPS_Instruction_Reg.vhd"
    "VHDL/registerfile_v2.vhd"
    "VHDL/MIPS_ALU.vhd"
    "VHDL/ALU_Control.vhd"

    # Behavioral RAM (replaces VHDL/RAM.vhd which uses altera_mf)
    "sim/RAM.vhd"

    # Memory subsystem
    "VHDL/MIPS_memory.vhd"

    # Core components
    "VHDL/MIPS_datapath.vhd"
    "VHDL/MIPS_ctrl.vhd"
    "VHDL/MIPS_top_level.vhd"

    # Testbench
    "sim/MIPS_full_tb.vhd"
)

# --------------------------------------------------------------------
# Setup
# --------------------------------------------------------------------
mkdir -p "$WORKDIR"

echo "=== Analyzing sources ==="
for SRC in "${SOURCES[@]}"; do
    echo "  $SRC"
    "$GHDL" -a $STD $WORK "--workdir=$WORKDIR" "$SRC"
done

echo ""
echo "=== Elaborating $TB_ENTITY ==="
"$GHDL" -e $STD $WORK "--workdir=$WORKDIR" "$TB_ENTITY"

echo ""
echo "=== Running simulation ==="
"$GHDL" -r $STD $WORK "--workdir=$WORKDIR" "$TB_ENTITY" \
    --stop-time=2000ns \
    $WAVE_FLAGS

echo ""
echo "=== Done ==="

// MIPS multi-cycle datapath — SystemVerilog translation of VHDL/MIPS_datapath.vhd
//
// Key design decisions carried over from VHDL:
//  - Register file uses synchronous read (REG_A/REG_B pipeline regs removed).
//  - IorD mux uses live ALU_out (not registered ALU_out_reg).
//  - MEMORY_DATA_REGISTER always enabled (wr_en='1').
//  - IR_funct_or_opcode: IR[5:0] when ALU_Op=="10" (R-type), else IR[31:26].
//  - InPort0/InPort1 both source from switches[8:0] (sign-extended to 32-bit).
//  - InPort0_en = ~switches[9] & button[0], InPort1_en = switches[9] & button[0].
module MIPS_datapath
  import MIPS_package::*;
(
  input  logic        clk,
  input  logic        rst,

  // Control signals from FSM
  input  logic        PC_writeCond,
  input  logic        PC_write,
  input  logic        IorD,
  input  logic        Mem_Read,
  input  logic        Mem_Write,
  input  logic        Mem_ToReg,
  input  logic        IRWrite,
  input  logic        JumpAndLink,
  input  logic        IsSigned,
  input  logic [1:0]  PC_Source,
  input  logic [1:0]  ALU_Op,
  input  logic [1:0]  ALU_SrcB,
  input  logic        ALU_SrcA,
  input  logic        Reg_Write,
  input  logic        Reg_Dst,

  // External I/O
  input  logic [9:0]  switches,
  input  logic [1:0]  button,
  output logic [31:0] LEDs,
  output logic [5:0]  IR_31_26,
  output logic [5:0]  IR_5_0
);

  // -------------------------------------------------------------------------
  // Internal signals
  // -------------------------------------------------------------------------
  // Program Counter
  logic        PC_en;
  logic [31:0] PC_in, PC_out;

  // I/O
  logic        InPort0_en, InPort1_en;
  logic [31:0] InPort0, InPort1, OutPort;

  // Memory
  logic [31:0] mem_addr, mem_data_out, mem_data_reg_out;

  // Instruction Register slices
  logic [31:0] IR;
  logic [25:0] w_IR_25_0;
  logic [5:0]  w_IR_31_26;
  logic [4:0]  w_IR_25_21, w_IR_20_16, w_IR_15_11;
  logic [15:0] w_IR_15_0;

  // Register file
  logic [4:0]  w_RF_wr_reg;
  logic [31:0] w_RF_wr_data, w_RF_rd0, w_RF_rd1;

  // ALU
  logic [31:0] ALU_inA, ALU_inB;
  logic [31:0] ALU_result, ALU_result_hi;
  logic        branch_taken;
  logic [31:0] ALU_out;           // registered ALU output
  logic [31:0] ALU_selected_out;  // after HI/LO mux

  // Sign-extend / shift
  logic [31:0] signext_out, shiftl2_out;

  // HI/LO registers
  logic        LO_en, HI_en;
  logic [31:0] LO_out, HI_out;
  logic [1:0]  ALU_LO_HI;

  // ALU controller
  logic [4:0]  OPselect;
  logic [5:0]  IR_funct_or_opcode;

  // Jump target
  logic [31:0] w_concat_out;

  // -------------------------------------------------------------------------
  // I/O interface
  // -------------------------------------------------------------------------
  assign InPort0     = {23'b0, switches[8:0]};
  assign InPort1     = {23'b0, switches[8:0]};
  assign InPort0_en  = ~switches[9] & button[0];
  assign InPort1_en  =  switches[9] & button[0];

  assign PC_en       = PC_write | (PC_writeCond & branch_taken);
  assign IR_31_26    = w_IR_31_26;
  assign IR_5_0      = IR[5:0];

  // -------------------------------------------------------------------------
  // Program Counter
  // -------------------------------------------------------------------------
  mips_reg #(.WIDTH(32)) PC (
    .clk   (clk),
    .rst   (rst),
    .wr_en (PC_en),
    .d     (PC_in),
    .q     (PC_out)
  );

  // -------------------------------------------------------------------------
  // IorD mux: selects instruction fetch address (PC) or data address (ALU_out)
  // -------------------------------------------------------------------------
  mux_2x1 #(.WIDTH(32)) IorD_MUX (
    .sel (IorD),
    .in0 (PC_out),
    .in1 (ALU_out),
    .q   (mem_addr)
  );

  // -------------------------------------------------------------------------
  // Memory subsystem
  // -------------------------------------------------------------------------
  MIPS_memory MEMORY_INST (
    .clk        (clk),
    .byte_addr  (mem_addr),
    .data_in    (w_RF_rd1),
    .write_en   (Mem_Write),
    .data_out   (mem_data_out),
    .InPort0_en (InPort0_en),
    .InPort1_en (InPort1_en),
    .InPort0    (InPort0),
    .InPort1    (InPort1),
    .OutPort    (OutPort)
  );

  // -------------------------------------------------------------------------
  // Instruction Register
  // -------------------------------------------------------------------------
  MIPS_Instruction_Reg IR_INST (
    .clk     (clk),
    .rst     (rst),
    .wr_en   (IRWrite),
    .d       (mem_data_out),
    .IR      (IR),
    .o_25_0  (w_IR_25_0),
    .o_31_26 (w_IR_31_26),
    .o_25_21 (w_IR_25_21),
    .o_20_16 (w_IR_20_16),
    .o_15_11 (w_IR_15_11),
    .o_15_0  (w_IR_15_0)
  );

  // -------------------------------------------------------------------------
  // Memory Data Register (always-enabled pipeline register for load data)
  // -------------------------------------------------------------------------
  mips_reg #(.WIDTH(32)) MEMORY_DATA_REGISTER (
    .clk   (clk),
    .rst   (rst),
    .wr_en (1'b1),
    .d     (mem_data_out),
    .q     (mem_data_reg_out)
  );

  // -------------------------------------------------------------------------
  // Register file write-port muxes
  // -------------------------------------------------------------------------
  mux_2x1 #(.WIDTH(5)) REG_DST_MUX (
    .sel (Reg_Dst),
    .in0 (w_IR_20_16),  // rt (I-type destination)
    .in1 (w_IR_15_11),  // rd (R-type destination)
    .q   (w_RF_wr_reg)
  );

  mux_2x1 #(.WIDTH(32)) MEM_TO_REG_MUX (
    .sel (Mem_ToReg),
    .in0 (ALU_selected_out),
    .in1 (mem_data_reg_out),
    .q   (w_RF_wr_data)
  );

  // -------------------------------------------------------------------------
  // Register file
  // -------------------------------------------------------------------------
  registerfile REGISTER_FILE (
    .clk         (clk),
    .rst         (rst),
    .rd_addr0    (w_IR_25_21),
    .rd_addr1    (w_IR_20_16),
    .wr_addr     (w_RF_wr_reg),
    .wr_en       (Reg_Write),
    .wr_data     (w_RF_wr_data),
    .rd_data0    (w_RF_rd0),
    .rd_data1    (w_RF_rd1),
    .JumpAndLink (JumpAndLink)
  );

  // -------------------------------------------------------------------------
  // ALU input muxes
  // -------------------------------------------------------------------------
  mux_2x1 #(.WIDTH(32)) ALU_SRC_A_MUX (
    .sel (ALU_SrcA),
    .in0 (PC_out),     // 0: PC (for PC+4 and branch address)
    .in1 (w_RF_rd0),   // 1: rs
    .q   (ALU_inA)
  );

  mux_4x1 #(.WIDTH(32)) ALU_SRC_B_MUX (
    .sel (ALU_SrcB),
    .in0 (w_RF_rd1),      // 00: rt
    .in1 (32'd4),          // 01: constant 4 (PC+4)
    .in2 (signext_out),   // 10: sign/zero-extended immediate
    .in3 (shiftl2_out),   // 11: shift-left-2(sign-ext) branch offset
    .q   (ALU_inB)
  );

  // -------------------------------------------------------------------------
  // Sign extender and branch-offset shifter
  // -------------------------------------------------------------------------
  sign_extend SIGN_EXTEND_INST (
    .isSigned (IsSigned),
    .imm16    (w_IR_15_0),
    .imm32    (signext_out)
  );

  shift_left2 SHIFT_LEFT2_INST (
    .d (signext_out),
    .q (shiftl2_out)
  );

  // -------------------------------------------------------------------------
  // ALU
  // -------------------------------------------------------------------------
  MIPS_ALU #(.WIDTH(32)) ALU_INST (
    .input1       (ALU_inA),
    .input2       (ALU_inB),
    .IR           (IR[10:6]),   // shamt field
    .sel          (OPselect),
    .result       (ALU_result),
    .result_hi    (ALU_result_hi),
    .branch_taken (branch_taken)
  );

  // Registered ALU output (used as memory address for LW/SW and branch target)
  mips_reg #(.WIDTH(32)) ALU_OUTPUT (
    .clk   (clk),
    .rst   (rst),
    .wr_en (1'b1),
    .d     (ALU_result),
    .q     (ALU_out)
  );

  // -------------------------------------------------------------------------
  // HI/LO registers (for mult/mfhi/mflo)
  // -------------------------------------------------------------------------
  mips_reg #(.WIDTH(32)) LO_REG (
    .clk   (clk),
    .rst   (rst),
    .wr_en (LO_en),
    .d     (ALU_result),
    .q     (LO_out)
  );

  mips_reg #(.WIDTH(32)) HI_REG (
    .clk   (clk),
    .rst   (rst),
    .wr_en (HI_en),
    .d     (ALU_result_hi),
    .q     (HI_out)
  );

  // ALU / HI / LO output mux (feeds register-file write-data path)
  mux_3x1 #(.WIDTH(32)) ALU_LO_HI_MUX (
    .sel  (ALU_LO_HI),
    .in0  (ALU_out),   // 00: normal ALU result
    .in1  (LO_out),    // 01: mflo
    .in2  (HI_out),    // 10: mfhi
    .q    (ALU_selected_out)
  );

  // -------------------------------------------------------------------------
  // ALU Controller
  // -------------------------------------------------------------------------
  // IR_funct_or_opcode: feed funct to ALU controller for R-type, opcode otherwise
  assign IR_funct_or_opcode = (ALU_Op == 2'b10) ? IR[5:0] : IR[31:26];

  ALU_Control ALU_CTRL (
    .IR        (IR_funct_or_opcode),
    .ALU_Op    (ALU_Op),
    .OPSelect  (OPselect),
    .LO_en     (LO_en),
    .HI_en     (HI_en),
    .ALU_LO_HI (ALU_LO_HI)
  );

  // -------------------------------------------------------------------------
  // Jump target: {PC[31:28], IR[25:0], 2'b00}
  // -------------------------------------------------------------------------
  shift_left_concat JUMP_TARGET (
    .i_IR_25_0  (w_IR_25_0),
    .i_PC_31_28 (PC_out[31:28]),
    .q          (w_concat_out)
  );

  // -------------------------------------------------------------------------
  // PC source mux
  //   00: ALU_result   — PC+4 (during INST_FETCH)
  //   01: ALU_out      — branch target (registered, computed in BRANCH_CALC)
  //   10: w_concat_out — jump target
  // -------------------------------------------------------------------------
  mux_3x1 #(.WIDTH(32)) PC_SOURCE_MUX (
    .sel  (PC_Source),
    .in0  (ALU_result),
    .in1  (ALU_out),
    .in2  (w_concat_out),
    .q    (PC_in)
  );

  // -------------------------------------------------------------------------
  // LED output
  // -------------------------------------------------------------------------
  assign LEDs = OutPort;

endmodule

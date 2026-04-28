// MIPS processor package — SystemVerilog translation of VHDL/MIPS_package.vhd
package MIPS_package;

  localparam DATA_WIDTH = 32;

  // ---------------------------------------------------------------------------
  // ALU operation select codes (5-bit)
  // ---------------------------------------------------------------------------
  localparam logic [4:0] ALU_ADD_unsign         = 5'b00000; // A + B (unsigned)
  localparam logic [4:0] ALU_ADD_sign           = 5'b00001; // A + B (signed)
  localparam logic [4:0] ALU_SUB_unsign         = 5'b00010; // A - B (unsigned)
  localparam logic [4:0] ALU_SUB_sign           = 5'b00011; // A - B (signed)
  localparam logic [4:0] ALU_mult_unsign        = 5'b00100; // A * B (unsigned)
  localparam logic [4:0] ALU_mult_sign          = 5'b00101; // A * B (signed)
  localparam logic [4:0] ALU_AND                = 5'b00110; // A AND B
  localparam logic [4:0] ALU_OR                 = 5'b00111; // A OR B
  localparam logic [4:0] ALU_XOR                = 5'b01000; // A XOR B
  localparam logic [4:0] ALU_NOT_A              = 5'b01001; // NOT A
  localparam logic [4:0] ALU_LOG_SHIFT_R        = 5'b01010; // Logical shift right
  localparam logic [4:0] ALU_LOG_SHIFT_L        = 5'b01011; // Logical shift left
  localparam logic [4:0] ALU_ARITH_SHIFT_R      = 5'b01100; // Arithmetic shift right
  localparam logic [4:0] ALU_comp_A_lt_B_unsign = 5'b01101; // A < B (unsigned)
  localparam logic [4:0] ALU_comp_A_lt_B_sign   = 5'b01110; // A < B (signed)
  localparam logic [4:0] ALU_A_gt_0             = 5'b01111; // A > 0 (signed)
  localparam logic [4:0] ALU_A_eq_0             = 5'b10000; // A == 0
  localparam logic [4:0] ALU_gteq_0             = 5'b10001; // A >= 0 (signed)
  localparam logic [4:0] ALU_lteq_0             = 5'b10010; // A <= 0 (signed)
  localparam logic [4:0] ALU_A_eq_B             = 5'b10011; // A == B
  localparam logic [4:0] ALU_A_ne_B             = 5'b10100; // A != B
  localparam logic [4:0] ALU_A_lt_0             = 5'b10101; // A < 0 (signed)
  localparam logic [4:0] ALU_PASS_A_BRANCH      = 5'b10110; // pass A (jr)
  localparam logic [4:0] ALU_PASS_B_BRANCH      = 5'b10111; // pass B
  localparam logic [4:0] ALU_NOP                = 5'b11111; // no operation

  // ---------------------------------------------------------------------------
  // ALU_Op 2-bit FSM control codes
  // ---------------------------------------------------------------------------
  localparam logic [1:0] ALUOp_addu  = 2'b00; // fetch / PC+4
  localparam logic [1:0] ALUOp_adds  = 2'b01; // signed add (decode)
  localparam logic [1:0] ALUOp_rtype = 2'b10; // R-type funct decode
  localparam logic [1:0] ALUOp_nonr  = 2'b11; // I-type / branch opcode decode

  // ---------------------------------------------------------------------------
  // Opcode constants (IR[31:26])
  // ---------------------------------------------------------------------------
  localparam logic [5:0] R_OP     = 6'b000000;
  localparam logic [5:0] I_ADDIU  = 6'b001001;
  localparam logic [5:0] I_SUBIU  = 6'b010000;
  localparam logic [5:0] I_ANDI   = 6'b001100;
  localparam logic [5:0] I_ORI    = 6'b001101;
  localparam logic [5:0] I_XORI   = 6'b001110;
  localparam logic [5:0] I_SLTI   = 6'b001010;
  localparam logic [5:0] I_SLTIU  = 6'b001011;
  localparam logic [5:0] I_BEQ    = 6'b000100;
  localparam logic [5:0] I_BNE    = 6'b000101;
  localparam logic [5:0] I_BLEZ   = 6'b000110;
  localparam logic [5:0] I_BGTZ   = 6'b000111;
  localparam logic [5:0] I_REGIMM = 6'b000001; // bltz/bgez, check rt field
  localparam logic [5:0] J_JUMP   = 6'b000010;
  localparam logic [5:0] J_JAL    = 6'b000011;

  // ---------------------------------------------------------------------------
  // R-type function codes (IR[5:0])
  // ---------------------------------------------------------------------------
  localparam logic [5:0] R_FUNC_ADDU  = 6'b100001;
  localparam logic [5:0] R_FUNC_SUBU  = 6'b100011;
  localparam logic [5:0] R_FUNC_AND   = 6'b100100;
  localparam logic [5:0] R_FUNC_OR    = 6'b100101;
  localparam logic [5:0] R_FUNC_XOR   = 6'b100110;
  localparam logic [5:0] R_FUNC_SLT   = 6'b101010;
  localparam logic [5:0] R_FUNC_SLTU  = 6'b101011;
  localparam logic [5:0] R_FUNC_SLL   = 6'b000000;
  localparam logic [5:0] R_FUNC_SRL   = 6'b000010;
  localparam logic [5:0] R_FUNC_SRA   = 6'b000011;
  localparam logic [5:0] R_FUNC_MULT  = 6'b011000;
  localparam logic [5:0] R_FUNC_MULTU = 6'b011001;
  localparam logic [5:0] R_FUNC_MFHI  = 6'h10; // 6'b010000
  localparam logic [5:0] R_FUNC_MFLO  = 6'h12; // 6'b010010
  localparam logic [5:0] R_FUNC_JR    = 6'b001000;

endpackage

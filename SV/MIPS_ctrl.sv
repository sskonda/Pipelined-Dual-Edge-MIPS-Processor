// MIPS multi-cycle FSM controller — SystemVerilog translation of VHDL/MIPS_ctrl.vhd
// LW_wait2 state has been removed (it corrupted loaded data; see project notes).
// The VHDL case-insensitive typo 'BRANCh_WAIT' is normalised to BRANCH_WAIT here.
module MIPS_ctrl
  import MIPS_package::*;
(
  input  logic        clk,
  input  logic        reset,

  // From Instruction Register
  input  logic [5:0]  opcode,  // IR[31:26]
  input  logic [5:0]  funct,   // IR[5:0]

  // Control outputs to datapath
  output logic        PC_writeCond,
  output logic        PC_write,
  output logic        IorD,
  output logic        Mem_Read,
  output logic        Mem_Write,
  output logic        Mem_ToReg,
  output logic        IRWrite,
  output logic        JumpAndLink,
  output logic        IsSigned,
  output logic [1:0]  PC_Source,
  output logic [1:0]  ALU_Op,
  output logic [1:0]  ALU_SrcB,
  output logic        ALU_SrcA,
  output logic        Reg_Write,
  output logic        Reg_Dst
);

  typedef enum logic [4:0] {
    INIT,
    ADDITIONAL_MEM_WAIT,
    INST_FETCH,
    STORE_IN_IR_WAIT,
    DECODE_REG_FETCH,
    LW_SW,
    LW_1,
    LW_WAIT,
    LW_2,
    SW,
    RTYPE_1,
    RTYPE_2,
    RTYPE_MF,
    ALU_IMM_1,
    ALU_IMM_2,
    BRANCH_CALC,
    BRANCH_EXEC,
    BRANCH_WAIT,
    JUMP
  } state_t;

  state_t cur_state, next_state;

  // -------------------------------------------------------------------------
  // State register
  // -------------------------------------------------------------------------
  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      cur_state <= INIT;
    else
      cur_state <= next_state;
  end

  // -------------------------------------------------------------------------
  // Next-state logic
  // -------------------------------------------------------------------------
  always_comb begin
    next_state = cur_state; // default: hold state
    case (cur_state)
      INIT:              next_state = INST_FETCH;
      INST_FETCH:        next_state = STORE_IN_IR_WAIT;
      STORE_IN_IR_WAIT:  next_state = DECODE_REG_FETCH;

      DECODE_REG_FETCH: begin
        case (opcode)
          R_OP:                                              next_state = RTYPE_1;
          I_ADDIU, I_SUBIU, I_ANDI, I_ORI,
          I_XORI,  I_SLTI,  I_SLTIU:                        next_state = ALU_IMM_1;
          6'b100011, 6'b101011:                              next_state = LW_SW;  // lw/sw
          I_BEQ, I_BNE, I_BLEZ, I_BGTZ, I_REGIMM:          next_state = BRANCH_CALC;
          J_JUMP, J_JAL:                                     next_state = JUMP;
          default:                                           next_state = INST_FETCH;
        endcase
      end

      LW_SW:               next_state = (opcode == 6'b100011) ? LW_1 : SW;
      LW_1:                next_state = LW_WAIT;
      LW_WAIT:             next_state = LW_2;     // LW_wait2 removed — data ready here
      LW_2:                next_state = INST_FETCH;
      SW:                  next_state = ADDITIONAL_MEM_WAIT;
      ADDITIONAL_MEM_WAIT: next_state = INST_FETCH;

      RTYPE_1:  next_state = RTYPE_2;
      RTYPE_2:  next_state = (funct == R_FUNC_MFLO || funct == R_FUNC_MFHI)
                             ? RTYPE_MF : INST_FETCH;
      RTYPE_MF: next_state = INST_FETCH;

      ALU_IMM_1: next_state = ALU_IMM_2;
      ALU_IMM_2: next_state = INST_FETCH;

      BRANCH_CALC: next_state = BRANCH_EXEC;
      BRANCH_EXEC: next_state = BRANCH_WAIT;
      BRANCH_WAIT: next_state = INST_FETCH;

      JUMP:        next_state = ADDITIONAL_MEM_WAIT;

      default:     next_state = INST_FETCH;
    endcase
  end

  // -------------------------------------------------------------------------
  // Output logic (Moore)
  // -------------------------------------------------------------------------
  always_comb begin
    // Defaults — all inactive
    PC_writeCond = 1'b0;
    PC_write     = 1'b0;
    IorD         = 1'b0;
    Mem_Read     = 1'b0;
    Mem_Write    = 1'b0;
    Mem_ToReg    = 1'b0;
    IRWrite      = 1'b0;
    JumpAndLink  = 1'b0;
    IsSigned     = 1'b0;
    PC_Source    = 2'b00;
    ALU_Op       = ALUOp_nonr;
    ALU_SrcB     = 2'b00;
    ALU_SrcA     = 1'b0;
    Reg_Write    = 1'b0;
    Reg_Dst      = 1'b0;

    case (cur_state)
      INST_FETCH: begin
        Mem_Read  = 1'b1;
        IRWrite   = 1'b1;
        ALU_SrcA  = 1'b0;
        ALU_SrcB  = 2'b01;    // PC + 4: ALU_inB = 4
        ALU_Op    = ALUOp_addu;
        PC_write  = 1'b1;
        PC_Source = 2'b00;    // PC_in = ALU_result (PC+4)
      end

      STORE_IN_IR_WAIT: begin
        IRWrite = 1'b1;
      end

      DECODE_REG_FETCH: begin
        ALU_SrcA = 1'b0;
        ALU_SrcB = 2'b11;     // branch offset pre-calc (shift-left-2(sign-ext))
        ALU_Op   = ALUOp_adds;
      end

      LW_SW: begin
        ALU_SrcA = 1'b1;      // rs
        ALU_SrcB = 2'b10;     // sign-extended immediate
        ALU_Op   = ALUOp_addu;
        IsSigned = 1'b1;      // sign-extend offset
        IorD     = 1'b1;      // use ALU result as memory address
      end

      LW_1: begin
        Mem_Read = 1'b1;
        IorD     = 1'b1;
      end

      LW_WAIT: begin
        Mem_Read = 1'b1;      // keep read asserted while RAM latches
      end

      LW_2: begin
        Reg_Write = 1'b1;
        Reg_Dst   = 1'b0;     // write to rt
        Mem_ToReg = 1'b1;     // data from MEMORY_DATA_REGISTER
      end

      SW: begin
        IorD      = 1'b1;
        Mem_Write = 1'b1;
      end

      ADDITIONAL_MEM_WAIT: ; // pipeline bubble after SW / JUMP

      RTYPE_1: begin
        ALU_SrcA = 1'b1;      // rs
        ALU_SrcB = 2'b00;     // rt
        ALU_Op   = ALUOp_rtype;
      end

      RTYPE_2: begin
        Reg_Write = 1'b1;
        Reg_Dst   = 1'b1;     // write to rd
        Mem_ToReg = 1'b0;
        ALU_Op    = ALUOp_nonr;
      end

      RTYPE_MF: begin
        Reg_Write = 1'b1;
        Reg_Dst   = 1'b1;     // write to rd
        Mem_ToReg = 1'b0;     // ALU_selected_out has HI or LO via mux_3x1
        ALU_Op    = ALUOp_rtype;
      end

      ALU_IMM_1: begin
        ALU_SrcA = 1'b1;      // rs
        ALU_SrcB = 2'b10;     // sign/zero-extended immediate
        ALU_Op   = 2'b11;     // ALUOp_nonr — I-type opcode decode
      end

      ALU_IMM_2: begin
        Reg_Write = 1'b1;
        Reg_Dst   = 1'b0;     // write to rt
        Mem_ToReg = 1'b0;
      end

      BRANCH_CALC: begin
        ALU_SrcA  = 1'b0;     // PC
        ALU_SrcB  = 2'b11;    // shift-left-2(sign-ext(immediate))
        ALU_Op    = ALUOp_addu;
      end

      BRANCH_EXEC: begin
        ALU_SrcA     = 1'b1;  // rs
        ALU_SrcB     = 2'b00; // rt
        ALU_Op       = ALUOp_nonr;
        PC_writeCond = 1'b1;
        PC_Source    = 2'b01; // branch target from ALU_out (BRANCH_CALC result)
      end

      BRANCH_WAIT: ; // pipeline bubble

      JUMP: begin
        PC_write  = 1'b1;
        PC_Source = 2'b10;    // jump target from shift_left_concat
        if (opcode == J_JAL)
          JumpAndLink = 1'b1;
      end

      default: ; // INIT and others: all outputs remain at defaults
    endcase
  end

endmodule

// ALU Controller — SystemVerilog translation of VHDL/ALU_Control.vhd
// Maps 2-bit ALU_Op + 6-bit IR (funct or opcode) to 5-bit OPSelect plus HI/LO enables.
module ALU_Control
  import MIPS_package::*;
(
  input  logic [5:0] IR,        // funct field (R-type) or opcode (I-type/branch)
  input  logic [1:0] ALU_Op,   // 2-bit control from FSM
  output logic [4:0] OPSelect,
  output logic       LO_en,
  output logic       HI_en,
  output logic [1:0] ALU_LO_HI
);
  always_comb begin
    OPSelect  = ALU_NOP;
    ALU_LO_HI = 2'b00;
    LO_en     = 1'b0;
    HI_en     = 1'b0;

    case (ALU_Op)
      // 2'b00 — fetch/PC+4 (unsigned add)
      ALUOp_addu: OPSelect = ALU_ADD_unsign;

      // 2'b01 — decode/branch address (signed add, unused post-refactor)
      ALUOp_adds: OPSelect = ALU_SUB_sign;

      // 2'b10 — R-type: decode funct field
      ALUOp_rtype: begin
        case (IR)
          R_FUNC_ADDU:  OPSelect = ALU_ADD_unsign;
          R_FUNC_SUBU:  OPSelect = ALU_SUB_unsign;
          R_FUNC_AND:   OPSelect = ALU_AND;
          R_FUNC_OR:    OPSelect = ALU_OR;
          R_FUNC_XOR:   OPSelect = ALU_XOR;
          R_FUNC_SLT:   OPSelect = ALU_comp_A_lt_B_sign;
          R_FUNC_SLTU:  OPSelect = ALU_comp_A_lt_B_unsign;
          R_FUNC_SLL:   OPSelect = ALU_LOG_SHIFT_L;
          R_FUNC_SRL:   OPSelect = ALU_LOG_SHIFT_R;
          R_FUNC_SRA:   OPSelect = ALU_ARITH_SHIFT_R;
          R_FUNC_MULT: begin
            OPSelect = ALU_mult_sign;
            LO_en    = 1'b1;
            HI_en    = 1'b1;
          end
          R_FUNC_MULTU: begin
            OPSelect = ALU_mult_unsign;
            LO_en    = 1'b1;
            HI_en    = 1'b1;
          end
          R_FUNC_MFHI: begin
            OPSelect  = ALU_NOP;
            ALU_LO_HI = 2'b10;
          end
          R_FUNC_MFLO: begin
            OPSelect  = ALU_NOP;
            ALU_LO_HI = 2'b01;
          end
          R_FUNC_JR:   OPSelect = ALU_PASS_A_BRANCH;
          default:     OPSelect = ALU_NOP;
        endcase
      end

      // 2'b11 — I-type / branches: decode opcode field
      ALUOp_nonr: begin
        case (IR)
          I_ADDIU:  OPSelect = ALU_ADD_unsign;
          I_SUBIU:  OPSelect = ALU_SUB_unsign;
          I_ANDI:   OPSelect = ALU_AND;
          I_ORI:    OPSelect = ALU_OR;
          I_XORI:   OPSelect = ALU_XOR;
          I_SLTI:   OPSelect = ALU_comp_A_lt_B_sign;
          I_SLTIU:  OPSelect = ALU_comp_A_lt_B_unsign;
          I_BEQ:    OPSelect = ALU_A_eq_B;
          I_BNE:    OPSelect = ALU_A_ne_B;
          I_BLEZ:   OPSelect = ALU_lteq_0;
          I_BGTZ:   OPSelect = ALU_A_gt_0;
          // REGIMM: bltz (rt=0) -> ALU_A_lt_0, bgez (rt=1) -> ALU_gteq_0
          I_REGIMM: OPSelect = (IR[0] == 1'b0) ? ALU_A_lt_0 : ALU_gteq_0;
          default:  OPSelect = ALU_NOP;
        endcase
      end

      default: OPSelect = ALU_NOP;
    endcase
  end
endmodule

// MIPS ALU — SystemVerilog translation of VHDL/MIPS_ALU.vhd
// Port 'output' -> 'result', 'output_High' -> 'result_hi' (SV keywords / naming).
// IR[4:0] carries the shamt field (IR[10:6] from the full instruction word,
//   sliced externally before being fed here).
module MIPS_ALU
  import MIPS_package::*;
#(
  parameter WIDTH = 32
)(
  input  logic [WIDTH-1:0] input1,
  input  logic [WIDTH-1:0] input2,
  input  logic [4:0]       IR,          // shamt field
  input  logic [4:0]       sel,         // ALU operation select
  output logic [WIDTH-1:0] result,
  output logic [WIDTH-1:0] result_hi,
  output logic             branch_taken
);
  // Pre-compute both signed and unsigned 64-bit products so they are
  // available inside the case without declaring variables mid-block.
  logic signed [2*WIDTH-1:0] s_prod;
  logic        [2*WIDTH-1:0] u_prod;

  always_comb begin
    s_prod = $signed(input1) * $signed(input2);
    u_prod = input1 * input2;
  end

  always_comb begin
    result       = '0;
    result_hi    = '0;
    branch_taken = 1'b0;

    case (sel)
      // Arithmetic
      ALU_ADD_unsign: result = input1 + input2;
      ALU_ADD_sign:   result = $signed(input1) + $signed(input2);
      ALU_SUB_unsign: result = input1 - input2;
      ALU_SUB_sign:   result = $signed(input1) - $signed(input2);

      // Multiply — low word to result, high word to result_hi
      ALU_mult_unsign: begin
        result    = u_prod[WIDTH-1:0];
        result_hi = u_prod[2*WIDTH-1:WIDTH];
      end
      ALU_mult_sign: begin
        result    = s_prod[WIDTH-1:0];
        result_hi = s_prod[2*WIDTH-1:WIDTH];
      end

      // Bitwise
      ALU_AND:   result = input1 & input2;
      ALU_OR:    result = input1 | input2;
      ALU_XOR:   result = input1 ^ input2;
      ALU_NOT_A: result = ~input1;

      // Shifts — operand is input2, amount is IR (shamt)
      ALU_LOG_SHIFT_R:   result = input2 >> IR;
      ALU_LOG_SHIFT_L:   result = input2 << IR;
      ALU_ARITH_SHIFT_R: result = $signed(input2) >>> IR;

      // Set-less-than
      ALU_comp_A_lt_B_unsign: result = (input1 < input2)                   ? 32'd1 : 32'd0;
      ALU_comp_A_lt_B_sign:   result = ($signed(input1) < $signed(input2)) ? 32'd1 : 32'd0;

      // Branch conditions — set branch_taken, result stays 0
      ALU_A_gt_0: branch_taken = ($signed(input1) >  0);
      ALU_A_eq_0: branch_taken = ($signed(input1) == 0);
      ALU_gteq_0: branch_taken = ($signed(input1) >= 0);
      ALU_lteq_0: branch_taken = ($signed(input1) <= 0);
      ALU_A_eq_B: branch_taken = ($signed(input1) == $signed(input2));
      ALU_A_ne_B: branch_taken = ($signed(input1) != $signed(input2));
      ALU_A_lt_0: branch_taken = ($signed(input1) <  0);

      // Pass-through (jr)
      ALU_PASS_A_BRANCH: result = input1;
      ALU_PASS_B_BRANCH: result = input2;

      // NOP / default
      default: begin
        result       = '0;
        result_hi    = '0;
        branch_taken = 1'b0;
      end
    endcase
  end
endmodule

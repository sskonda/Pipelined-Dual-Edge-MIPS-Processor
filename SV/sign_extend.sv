// Sign/zero extender (16->32 bit) — SystemVerilog translation of VHDL/sign_extend.vhd
// Port 'input' -> 'imm16', 'output' -> 'imm32' ('input'/'output' are SV keywords).
module sign_extend (
  input  logic        isSigned,
  input  logic [15:0] imm16,
  output logic [31:0] imm32
);
  always_comb begin
    if (isSigned)
      imm32 = {{16{imm16[15]}}, imm16}; // sign-extend
    else
      imm32 = {16'b0, imm16};           // zero-extend
  end
endmodule

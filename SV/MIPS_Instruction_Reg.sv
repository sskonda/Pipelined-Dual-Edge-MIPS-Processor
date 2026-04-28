// Instruction Register — SystemVerilog translation of VHDL/MIPS_Instruction_Reg.vhd
// Port 'input' -> 'd' (SV keyword).
// Output slice widths match the VHDL: o_31_26 is 6 bits (31-26), etc.
module MIPS_Instruction_Reg (
  input  logic        clk,
  input  logic        rst,
  input  logic        wr_en,
  input  logic [31:0] d,
  output logic [31:0] IR,
  output logic [25:0] o_25_0,
  output logic [5:0]  o_31_26,
  output logic [4:0]  o_25_21,
  output logic [4:0]  o_20_16,
  output logic [4:0]  o_15_11,
  output logic [15:0] o_15_0
);
  logic [31:0] IR_reg;

  always_ff @(posedge clk or posedge rst) begin
    if (rst)
      IR_reg <= '0;
    else if (wr_en)
      IR_reg <= d;
  end

  assign IR      = IR_reg;
  assign o_31_26 = IR_reg[31:26];
  assign o_25_21 = IR_reg[25:21];
  assign o_20_16 = IR_reg[20:16];
  assign o_15_11 = IR_reg[15:11];
  assign o_25_0  = IR_reg[25:0];
  assign o_15_0  = IR_reg[15:0];
endmodule

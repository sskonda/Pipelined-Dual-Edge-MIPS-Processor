// Jump-target assembler: {PC[31:28], IR[25:0], 2'b00}
// SystemVerilog translation of VHDL/shift_left_concat.vhd
// Port 'output' -> 'q' (SV keyword).
module shift_left_concat (
  input  logic [25:0] i_IR_25_0,
  input  logic [3:0]  i_PC_31_28,
  output logic [31:0] q
);
  assign q = {i_PC_31_28, i_IR_25_0, 2'b00};
endmodule

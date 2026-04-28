// Left-shift-by-2 — SystemVerilog translation of VHDL/shift_left2.vhd
// Port 'input' -> 'd', 'output' -> 'q' (SV keywords).
module shift_left2 (
  input  logic [31:0] d,
  output logic [31:0] q
);
  assign q = {d[29:0], 2'b00}; // logical left shift by 2
endmodule

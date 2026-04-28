// General-purpose register with synchronous reset — SystemVerilog translation of VHDL/register_entity.vhd
// Renamed from 'reg' to 'mips_reg' because 'reg' is a reserved keyword in SystemVerilog.
// Port 'input' -> 'd', 'output' -> 'q' (both reserved words in SV).
module mips_reg #(
  parameter WIDTH = 16
)(
  input  logic             clk,
  input  logic             rst,
  input  logic             wr_en,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q
);
  always_ff @(posedge clk or posedge rst) begin
    if (rst)
      q <= '0;
    else if (wr_en)
      q <= d;
  end
endmodule

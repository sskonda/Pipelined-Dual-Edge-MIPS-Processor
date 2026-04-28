// 3-to-1 multiplexer — SystemVerilog translation of VHDL/mux_3x1.vhd
module mux_3x1 #(
  parameter WIDTH = 8
)(
  input  logic [1:0]       sel,
  input  logic [WIDTH-1:0] in0,
  input  logic [WIDTH-1:0] in1,
  input  logic [WIDTH-1:0] in2,
  output logic [WIDTH-1:0] q
);
  always_comb begin
    case (sel)
      2'b00:   q = in0;
      2'b01:   q = in1;
      2'b10:   q = in2;
      default: q = '0;
    endcase
  end
endmodule

// 2-to-1 multiplexer — SystemVerilog translation of VHDL/mux2x1.vhd
// Port names: input0/input1 -> in0/in1, output -> q  (VHDL keywords in SV)
module mux_2x1 #(
  parameter WIDTH = 16
)(
  input  logic [WIDTH-1:0] in0,
  input  logic [WIDTH-1:0] in1,
  input  logic             sel,
  output logic [WIDTH-1:0] q
);
  always_comb begin
    case (sel)
      1'b0:    q = in0;
      1'b1:    q = in1;
      default: q = '0;
    endcase
  end
endmodule

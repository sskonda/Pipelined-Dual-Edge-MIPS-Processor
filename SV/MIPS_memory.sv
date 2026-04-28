// MIPS memory subsystem — SystemVerilog translation of VHDL/MIPS_memory.vhd
// Wraps RAM and handles memory-mapped I/O:
//   0xFFF8 = InPort0, 0xFFFA = InPort1, 0xFFFC = OutPort
// data_out is registered (1-cycle latency), matching the VHDL r_data_out register.
module MIPS_memory
  import MIPS_package::*;
(
  input  logic        clk,
  input  logic [31:0] byte_addr,
  input  logic [31:0] data_in,
  input  logic        write_en,
  output logic [31:0] data_out,
  input  logic        InPort0_en,
  input  logic        InPort1_en,
  input  logic [31:0] InPort0,
  input  logic [31:0] InPort1,
  output logic [31:0] OutPort
);
  localparam logic [15:0] ADDR_INPORT0 = 16'hFFF8;
  localparam logic [15:0] ADDR_INPORT1 = 16'hFFFA;
  localparam logic [15:0] ADDR_OUTPORT = 16'hFFFC;

  logic [7:0]  w_RAM_addr;
  logic [31:0] w_RAM_data_out;
  logic [31:0] r_data_out;
  logic [31:0] r_InPort0, r_InPort1, r_OutPort;
  logic [1:0]  w_data_sel;
  logic        w_ram_write, w_outport_write;

  // RAM instance (behavioral replacement for Altera altsyncram)
  RAM ram_inst (
    .address (w_RAM_addr),
    .clock   (clk),
    .data    (data_in),
    .wren    (w_ram_write),
    .q       (w_RAM_data_out)
  );

  assign w_RAM_addr = byte_addr[9:2]; // word-addressed (byte_addr / 4)
  assign OutPort    = r_OutPort;

  // Combinational address decode
  always_comb begin
    w_ram_write     = 1'b0;
    w_outport_write = 1'b0;
    w_data_sel      = 2'b10; // default: read from RAM

    if (byte_addr[15:0] == ADDR_INPORT0) begin
      if (!write_en) w_data_sel = 2'b00;
    end else if (byte_addr[15:0] == ADDR_INPORT1) begin
      if (!write_en) w_data_sel = 2'b01;
    end else if (byte_addr[15:0] == ADDR_OUTPORT) begin
      if (write_en) w_outport_write = 1'b1;
    end else begin
      if (write_en) w_ram_write = 1'b1;
    end
  end

  // Sequential: capture InPorts, OutPort, and latch read data
  always_ff @(posedge clk) begin
    if (InPort0_en)     r_InPort0 <= InPort0;
    if (InPort1_en)     r_InPort1 <= InPort1;
    if (w_outport_write) r_OutPort <= data_in;

    case (w_data_sel)
      2'b00:   r_data_out <= r_InPort0;
      2'b01:   r_data_out <= r_InPort1;
      default: r_data_out <= w_RAM_data_out;
    endcase
  end

  assign data_out = r_data_out;
endmodule

// =============================================================================
// pipe_dmem.sv  –  Data memory with memory-mapped I/O for the pipeline.
//
// Separate from instruction memory (Harvard architecture) → no structural
// hazard with the IF stage.
//
// Memory map (lower 16 bits of byte address):
//   0xFFF8  = InPort0 (read-only, driven by switches)
//   0xFFFA  = InPort1 (read-only, driven by switches)
//   0xFFFC  = OutPort (write-only, drives LEDs)
//   other   = 256×32 word RAM (byte_addr[9:2] = word index)
//
// Read interface:  ASYNCHRONOUS (combinatorial) — data available in same
//   cycle as address.  This gives the MEM stage a single-cycle latency with
//   no stall needed for LW.
//
// Write interface: SYNCHRONOUS (rising edge).
//
// Ready/valid:  mem_ready is always 1 because memory responds in one cycle.
// =============================================================================
module pipe_dmem
  import MIPS_package::*;
(
  input  logic        clk,
  // Port to pipeline MEM stage
  input  logic [31:0] byte_addr,
  input  logic [31:0] wr_data,
  input  logic        mem_read,
  input  logic        mem_write,
  output logic [31:0] rd_data,
  output logic        mem_ready,    // always 1 (single-cycle memory)
  // Memory-mapped I/O
  input  logic [31:0] in_port0,    // from switches / external
  input  logic [31:0] in_port1,
  output logic [31:0] out_port     // to LEDs
);
  localparam logic [15:0] ADDR_INPORT0 = 16'hFFF8;
  localparam logic [15:0] ADDR_INPORT1 = 16'hFFFA;
  localparam logic [15:0] ADDR_OUTPORT = 16'hFFFC;

  logic [31:0] ram   [0:255];
  logic [31:0] r_out_port;
  logic [7:0]  word_addr;
  logic        is_in0, is_in1, is_out, is_ram;

  assign word_addr = byte_addr[9:2];
  assign is_in0    = (byte_addr[15:0] == ADDR_INPORT0);
  assign is_in1    = (byte_addr[15:0] == ADDR_INPORT1);
  assign is_out    = (byte_addr[15:0] == ADDR_OUTPORT);
  assign is_ram    = !is_in0 & !is_in1 & !is_out;

  assign mem_ready = 1'b1;
  assign out_port  = r_out_port;

  // Synchronous writes
  always_ff @(posedge clk) begin
    if (mem_write) begin
      if (is_out)
        r_out_port <= wr_data;
      else if (is_ram)
        ram[word_addr] <= wr_data;
      // writes to InPort addresses are silently discarded
    end
  end

  // Asynchronous reads (combinatorial)
  always_comb begin
    if (is_in0)
      rd_data = in_port0;
    else if (is_in1)
      rd_data = in_port1;
    else if (is_out)
      rd_data = r_out_port;  // reading OutPort returns its last-written value
    else
      rd_data = ram[word_addr];
  end

  // Initialise all RAM and OutPort to 0
  initial begin
    for (int i = 0; i < 256; i++) ram[i] = 32'd0;
    r_out_port = 32'd0;
  end

endmodule

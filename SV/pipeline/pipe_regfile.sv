// =============================================================================
// pipe_regfile.sv  –  32×32-bit register file with ASYNCHRONOUS reads.
//
// Asynchronous read is required for a single-cycle ID stage: the register
// values must be available combinatorially within the same cycle that the
// instruction is being decoded.
//
// Write-before-read:  if the write address equals a read address in the same
// cycle (WB forwarding into ID), the NEW data is returned — this avoids an
// extra register-file read hazard.
//
// $0 is hardwired to zero:  reading always returns 0, writes are silently
// discarded.  Forwarding from $0 is never asserted (wr_addr==0 guard).
// =============================================================================
module pipe_regfile (
  input  logic        clk,
  input  logic        rst,
  // Write port (from WB stage)
  input  logic [4:0]  wr_addr,
  input  logic        wr_en,
  input  logic [31:0] wr_data,
  // Read ports (used in ID stage, combinatorial)
  input  logic [4:0]  rd_addr0,
  input  logic [4:0]  rd_addr1,
  output logic [31:0] rd_data0,
  output logic [31:0] rd_data1
);
  logic [31:0] regs [1:31]; // index 0 is hardwired zero; regs[1..31] are real

  // Synchronous write (GPR 0 writes are silently dropped)
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      for (int i = 1; i < 32; i++)
        regs[i] <= 32'd0;
    end else if (wr_en && wr_addr != 5'd0) begin
      regs[wr_addr] <= wr_data;
    end
  end

  // Asynchronous read with write-before-read forwarding
  always_comb begin
    if (rd_addr0 == 5'd0)
      rd_data0 = 32'd0;
    else if (wr_en && wr_addr == rd_addr0)
      rd_data0 = wr_data; // WB → ID bypass
    else
      rd_data0 = regs[rd_addr0];

    if (rd_addr1 == 5'd0)
      rd_data1 = 32'd0;
    else if (wr_en && wr_addr == rd_addr1)
      rd_data1 = wr_data; // WB → ID bypass
    else
      rd_data1 = regs[rd_addr1];
  end

endmodule

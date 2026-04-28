// 32x32-bit synchronous-read register file — SystemVerilog translation of VHDL/registerfile_v2.vhd
// Synchronous read: rd_data0/rd_data1 are registered on the rising edge (REG_A/REG_B implicit).
// $0 is kept zero by re-zeroing after every write.
module registerfile (
  input  logic        clk,
  input  logic        rst,
  input  logic [4:0]  rd_addr0,  // read port 1
  input  logic [4:0]  rd_addr1,  // read port 2
  input  logic [4:0]  wr_addr,
  input  logic        wr_en,
  input  logic [31:0] wr_data,
  output logic [31:0] rd_data0,
  output logic [31:0] rd_data1,
  input  logic        JumpAndLink // writes wr_data into $31 when high
);
  logic [31:0] regs [0:31];

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      for (int i = 0; i < 32; i++)
        regs[i] <= '0;
    end else begin
      if (wr_en) begin
        regs[wr_addr] <= wr_data;
        regs[0]       <= '0; // $0 always zero
      end
      if (JumpAndLink)
        regs[31] <= wr_data; // JAL saves return address in $31
      rd_data0 <= regs[rd_addr0];
      rd_data1 <= regs[rd_addr1];
    end
  end
endmodule

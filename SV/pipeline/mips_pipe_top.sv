// =============================================================================
// mips_pipe_top.sv  –  Top-level wrapper for the 5-stage pipelined MIPS CPU.
//
// Preserves the same external interface as the multi-cycle MIPS_top_level.sv
// so the two implementations are drop-in compatible at the board level.
//
// Internal change:  uses mips_pipeline (5-stage pipeline with hazard
// protection and ready/valid) instead of the multi-cycle MIPS_ctrl/datapath.
// =============================================================================
module mips_pipe_top
  import MIPS_package::*;
  import pipe_pkg::*;
(
  input  logic        clk,
  input  logic        rst,
  input  logic [9:0]  switches,
  input  logic [1:0]  button,
  output logic [31:0] LEDs,     // wired to OutPort (memory-mapped 0xFFFC)
  output logic [6:0]  led0,
  output logic        led0_dp,
  output logic [6:0]  led1,
  output logic        led1_dp,
  output logic [6:0]  led2,
  output logic        led2_dp,
  output logic [6:0]  led3,
  output logic        led3_dp,
  output logic [6:0]  led4,
  output logic        led4_dp,
  output logic [6:0]  led5,
  output logic        led5_dp
);

  logic [31:0] out_port;
  pipe_rv_t    pipe_rv;

  mips_pipeline pipeline (
    .clk      (clk),
    .rst      (rst),
    .switches (switches),
    .button   (button),
    .out_port (out_port),
    .pipe_rv  (pipe_rv),
    .dbg_pc   (),
    .dbg_instr()
  );

  assign LEDs = out_port;

  // 7-segment display: decode lower 24 bits of OutPort into 6 hex digits
  logic [3:0] nibble0, nibble1, nibble2, nibble3, nibble4, nibble5;
  assign nibble0 = out_port[3:0];
  assign nibble1 = out_port[7:4];
  assign nibble2 = out_port[11:8];
  assign nibble3 = out_port[15:12];
  assign nibble4 = out_port[19:16];
  assign nibble5 = out_port[23:20];

  decoder7seg u_led0 (.d(nibble0), .seg(led0));
  decoder7seg u_led1 (.d(nibble1), .seg(led1));
  decoder7seg u_led2 (.d(nibble2), .seg(led2));
  decoder7seg u_led3 (.d(nibble3), .seg(led3));
  decoder7seg u_led4 (.d(nibble4), .seg(led4));
  decoder7seg u_led5 (.d(nibble5), .seg(led5));

  assign led0_dp = 1'b1;
  assign led1_dp = 1'b1;
  assign led2_dp = 1'b1;
  assign led3_dp = 1'b1;
  assign led4_dp = 1'b1;
  assign led5_dp = 1'b1;

endmodule

// MIPS Full-System Testbench — SystemVerilog translation of sim/MIPS_full_tb.vhd
//
// Checks OutPort (mapped to LEDs) after each program phase:
//
//  Check 1  addiu/addu/subu/and/or/sll + beq (taken)  -> OutPort = 15
//  Check 2  ori / xori                                 -> OutPort =  2
//  Check 3  srl / slti                                 -> OutPort =  1
//  Check 4  bne (taken)                                -> OutPort =  5
//  Check 5  mult / mflo                                -> OutPort = 50
//  Check 6  lw / sw round-trip                         -> OutPort = 77
//
// Timing matches the VHDL testbench (5 ns clock, 2-cycle reset):
//   Check 1 at 280 ns, Check 2 at 360 ns, Check 3 at 440 ns,
//   Check 4 at 500 ns, Check 5 at 590 ns, Check 6 at 720 ns,
//   Loop2   at 1370 ns

`timescale 1ns/1ps

module MIPS_full_tb;
  import MIPS_package::*;

  localparam CLK_PERIOD = 5; // ns

  logic        clk      = 1'b0;
  logic        rst      = 1'b1;
  logic [9:0]  switches = '0;
  logic [1:0]  button   = 2'b11;
  logic [31:0] LEDs;

  logic [6:0] led0, led1, led2, led3, led4, led5;
  logic       led0_dp, led1_dp, led2_dp, led3_dp, led4_dp, led5_dp;

  // Free-running clock
  always #(CLK_PERIOD / 2) clk = ~clk;

  // DUT
  MIPS_top_level dut (
    .clk      (clk),
    .rst      (rst),
    .switches (switches),
    .button   (button),
    .LEDs     (LEDs),
    .led0 (led0), .led0_dp (led0_dp),
    .led1 (led1), .led1_dp (led1_dp),
    .led2 (led2), .led2_dp (led2_dp),
    .led3 (led3), .led3_dp (led3_dp),
    .led4 (led4), .led4_dp (led4_dp),
    .led5 (led5), .led5_dp (led5_dp)
  );

  // Check task — prints [PASS] or [FAIL]
  task automatic check_leds(
    input logic [31:0] observed,
    input logic [31:0] expected,
    input string       tag
  );
    if (observed === expected)
      $display("[PASS] %s -> 0x%08h", tag, observed);
    else begin
      $display("[FAIL] %s  expected=0x%08h  got=0x%08h", tag, expected, observed);
      $display("       at time %0t ns", $time);
    end
  endtask

  // -----------------------------------------------------------------------
  // Stimulus
  // -----------------------------------------------------------------------
  initial begin
    // 2-cycle reset
    rst = 1'b1;
    repeat (2) @(posedge clk);
    rst = 1'b0;
    $display("[INFO] Reset released - program executing.");

    // Check 1 — addiu/addu/subu/and/or/sll + beq (taken) -> OutPort = 15
    #270;
    check_leds(LEDs, 32'h0000000F, "Phase1 addu+beq: OutPort=15");
    if (LEDs == 32'h00000063)
      $display("[FAIL] beq NOT taken - word 8 was not skipped");

    // Check 2 — ori / xori -> OutPort = 2
    #80;
    check_leds(LEDs, 32'h00000002, "Phase2 xori: OutPort=2");

    // Check 3 — srl / slti -> OutPort = 1
    #80;
    check_leds(LEDs, 32'h00000001, "Phase3 srl+slti: OutPort=1");

    // Check 4 — bne (taken) -> OutPort = 5
    #60;
    check_leds(LEDs, 32'h00000005, "Phase4 bne: OutPort=5");

    // Check 5 — mult / mflo -> OutPort = 50
    #90;
    check_leds(LEDs, 32'h00000032, "Phase5 mult+mflo: OutPort=50");

    // Check 6 — lw/sw round-trip -> OutPort = 77
    #130;
    check_leds(LEDs, 32'h0000004D, "Phase6 lw/sw round-trip: OutPort=77");

    // Second loop iteration — OutPort should still be 77
    #650;
    check_leds(LEDs, 32'h0000004D, "Loop2 Phase6: OutPort=77 stable on second iteration");

    $display("==================================================");
    $display("  Simulation complete - review [PASS]/[FAIL] above");
    $display("==================================================");
    $finish;
  end

endmodule

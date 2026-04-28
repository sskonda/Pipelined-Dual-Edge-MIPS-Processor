// MIPS top-level — SystemVerilog translation of VHDL/MIPS_top_level.vhd
// Instantiates MIPS_ctrl + MIPS_datapath and wires 7-segment LED display.
module MIPS_top_level
  import MIPS_package::*;
(
  input  logic        clk,
  input  logic        rst,
  input  logic [9:0]  switches,
  input  logic [1:0]  button,
  output logic [31:0] LEDs,
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

  // Control signals (FSM -> datapath)
  logic        s_PC_writeCond;
  logic        s_PC_write;
  logic        s_IorD;
  logic        s_MemRead;
  logic        s_MemWrite;
  logic        s_MemToReg;
  logic        s_IRWrite;
  logic        s_JumpAndLink;
  logic        s_IsSigned;
  logic [1:0]  s_PC_Source;
  logic [1:0]  s_ALU_Op;
  logic [1:0]  s_ALU_SrcB;
  logic        s_ALU_SrcA;
  logic        s_Reg_Write;
  logic        s_Reg_Dst;

  // IR slices (datapath -> FSM)
  logic [5:0]  w_IR_31_26;
  logic [5:0]  w_IR_5_0;

  logic [31:0] datapath_out;

  // Nibbles for 7-segment display (lower 24 bits = 6 hex digits)
  logic [3:0] nibble0, nibble1, nibble2, nibble3, nibble4, nibble5;

  // -------------------------------------------------------------------------
  // Controller
  // -------------------------------------------------------------------------
  MIPS_ctrl ctrl_inst (
    .clk          (clk),
    .reset        (rst),
    .opcode       (w_IR_31_26),
    .funct        (w_IR_5_0),
    .PC_writeCond (s_PC_writeCond),
    .PC_write     (s_PC_write),
    .IorD         (s_IorD),
    .Mem_Read     (s_MemRead),
    .Mem_Write    (s_MemWrite),
    .Mem_ToReg    (s_MemToReg),
    .IRWrite      (s_IRWrite),
    .JumpAndLink  (s_JumpAndLink),
    .IsSigned     (s_IsSigned),
    .PC_Source    (s_PC_Source),
    .ALU_Op       (s_ALU_Op),
    .ALU_SrcB     (s_ALU_SrcB),
    .ALU_SrcA     (s_ALU_SrcA),
    .Reg_Write    (s_Reg_Write),
    .Reg_Dst      (s_Reg_Dst)
  );

  // -------------------------------------------------------------------------
  // Datapath
  // -------------------------------------------------------------------------
  MIPS_datapath datapath_inst (
    .clk          (clk),
    .rst          (rst),
    .PC_writeCond (s_PC_writeCond),
    .PC_write     (s_PC_write),
    .IorD         (s_IorD),
    .Mem_Read     (s_MemRead),
    .Mem_Write    (s_MemWrite),
    .Mem_ToReg    (s_MemToReg),
    .IRWrite      (s_IRWrite),
    .JumpAndLink  (s_JumpAndLink),
    .IsSigned     (s_IsSigned),
    .PC_Source    (s_PC_Source),
    .ALU_Op       (s_ALU_Op),
    .ALU_SrcB     (s_ALU_SrcB),
    .ALU_SrcA     (s_ALU_SrcA),
    .Reg_Write    (s_Reg_Write),
    .Reg_Dst      (s_Reg_Dst),
    .switches     (switches),
    .button       (button),
    .LEDs         (datapath_out),
    .IR_31_26     (w_IR_31_26),
    .IR_5_0       (w_IR_5_0)
  );

  assign LEDs = datapath_out;

  // -------------------------------------------------------------------------
  // 7-segment display: lower 24 bits -> 6 hex digits
  // -------------------------------------------------------------------------
  assign nibble0 = datapath_out[3:0];
  assign nibble1 = datapath_out[7:4];
  assign nibble2 = datapath_out[11:8];
  assign nibble3 = datapath_out[15:12];
  assign nibble4 = datapath_out[19:16];
  assign nibble5 = datapath_out[23:20];

  decoder7seg u_led0 (.d(nibble0), .seg(led0));
  decoder7seg u_led1 (.d(nibble1), .seg(led1));
  decoder7seg u_led2 (.d(nibble2), .seg(led2));
  decoder7seg u_led3 (.d(nibble3), .seg(led3));
  decoder7seg u_led4 (.d(nibble4), .seg(led4));
  decoder7seg u_led5 (.d(nibble5), .seg(led5));

  // Decimal points unused
  assign led0_dp = 1'b1;
  assign led1_dp = 1'b1;
  assign led2_dp = 1'b1;
  assign led3_dp = 1'b1;
  assign led4_dp = 1'b1;
  assign led5_dp = 1'b1;

endmodule

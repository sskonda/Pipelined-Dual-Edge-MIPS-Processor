library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.MIPS_package.all;

entity MIPS_top_level is
  port (
    clk : in std_logic;
    rst : in std_logic; --(button 1)

    switches : in std_logic_vector(9 downto 0);
    button   : in std_logic_vector(1 downto 0);
    LEDs     : out std_logic_vector(DATA_WIDTH - 1 downto 0);
    led0     : out std_logic_vector(6 downto 0);
    led0_dp  : out std_logic;
    led1     : out std_logic_vector(6 downto 0);
    led1_dp  : out std_logic;
    led2     : out std_logic_vector(6 downto 0);
    led2_dp  : out std_logic;
    led3     : out std_logic_vector(6 downto 0);
    led3_dp  : out std_logic;
    led4     : out std_logic_vector(6 downto 0);
    led4_dp  : out std_logic;
    led5     : out std_logic_vector(6 downto 0);
    led5_dp  : out std_logic
  );
end entity MIPS_top_level;

architecture Swiss of MIPS_top_level is

  signal s_PC_writeCond : std_logic;
  signal s_PC_write     : std_logic;
  signal s_IorD         : std_logic;
  signal s_MemRead      : std_logic;
  signal s_MemWrite     : std_logic;
  signal s_MemToReg     : std_logic;
  signal s_IRWrite      : std_logic;
  signal s_JumpAndLink  : std_logic;
  signal s_IsSigned     : std_logic;
  signal s_PC_Source    : std_logic_vector(1 downto 0);
  signal s_ALU_Op       : std_logic_vector(1 downto 0);
  signal s_ALU_SrcB     : std_logic_vector(1 downto 0);
  signal s_ALU_SrcA     : std_logic;
  signal s_Reg_Write    : std_logic;
  signal s_Reg_Dst      : std_logic;
  signal s_opcode       : std_logic_vector(5 downto 0);
  signal w_IR_31_26     : std_logic_vector(31 downto 26);
  signal w_IR_5_0       : std_logic_vector(5 downto 0);
  signal datapath_out   : std_logic_vector(31 downto 0);

  -- Nibbles for LED decoding
  signal nibble0, nibble1, nibble2, nibble3, nibble4, nibble5 : std_logic_vector(3 downto 0);

  -- Constant 0 for unused digits
  constant C0 : std_logic_vector(3 downto 0) := (others => '0');

begin

  -- Controller
  MIPS_ctrl_inst : entity work.MIPS_ctrl
    port map
    (
      clk          => clk,
      reset        => rst,
      opcode       => w_IR_31_26,
      funct        => w_IR_5_0,
      PC_writeCond => s_PC_writeCond,
      PC_write     => s_PC_write,
      IorD         => s_IorD,
      Mem_Read     => s_MemRead,
      Mem_Write    => s_MemWrite,
      Mem_ToReg    => s_MemToReg,
      IRWrite      => s_IRWrite,
      JumpAndLink  => s_JumpAndLink,
      IsSigned     => s_IsSigned,
      PC_Source    => s_PC_Source,
      ALU_Op       => s_ALU_Op,
      ALU_SrcB     => s_ALU_SrcB,
      ALU_SrcA     => s_ALU_SrcA,
      Reg_Write    => s_Reg_Write,
      Reg_Dst      => s_Reg_Dst
    );

  -- Datapath
  MIPS_datapath_inst : entity work.MIPS_datapath
    port map
    (
      clk          => clk,
      rst          => rst,
      PC_writeCond => s_PC_writeCond,
      PC_write     => s_PC_write,
      IorD         => s_IorD,
      Mem_Read     => s_MemRead,
      Mem_Write    => s_MemWrite,
      Mem_ToReg    => s_MemToReg,
      IRWrite      => s_IRWrite,
      JumpAndLink  => s_JumpAndLink,
      IsSigned     => s_IsSigned,
      PC_Source    => s_PC_Source,
      ALU_Op       => s_ALU_Op,
      ALU_SrcB     => s_ALU_SrcB,
      ALU_SrcA     => s_ALU_SrcA,
      Reg_Write    => s_Reg_Write,
      Reg_Dst      => s_Reg_Dst,
      switches     => switches,
      button       => button,
      LEDs         => datapath_out,
      IR_31_26     => w_IR_31_26,
      IR_5_0       => w_IR_5_0
    );

  -- LED output for debug
  LEDs <= datapath_out;

  ----------------------------------------------------------------------
  -- Slice the 32-bit datapath output into 6 nibbles for LED display
  ----------------------------------------------------------------------
  nibble0 <= datapath_out(3 downto 0);
  nibble1 <= datapath_out(7 downto 4);
  nibble2 <= datapath_out(11 downto 8);
  nibble3 <= datapath_out(15 downto 12);
  nibble4 <= datapath_out(19 downto 16);
  nibble5 <= datapath_out(23 downto 20);

  ----------------------------------------------------------------------
  -- 7-Segment Decoder Instantiations
  ----------------------------------------------------------------------
  U_LED0 : entity work.decoder7seg
  PORT map(input => nibble0, output => led0);
  U_LED1 : entity work.decoder7seg
  PORT map(input => nibble1, output => led1);
  U_LED2 : entity work.decoder7seg
  PORT map(input => nibble2, output => led2);
  U_LED3 : entity work.decoder7seg
  PORT map(input => nibble3, output => led3);
  U_LED4 : entity work.decoder7seg
  PORT map(input => nibble4, output => led4);
  U_LED5 : entity work.decoder7seg
  PORT map(input => nibble5, output => led5);

  ----------------------------------------------------------------------
  -- Decimal Point Assignments (Customize as needed)
  ----------------------------------------------------------------------
  led0_dp <= '1';
  led1_dp <= '1';
  led2_dp <= '1';
  led3_dp <= '1';
  led4_dp <= '1';
  led5_dp <= '1';

end architecture Swiss;

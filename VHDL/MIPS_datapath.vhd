library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.MIPS_package.all;

entity MIPS_datapath is
  port (
    clk, rst : in std_logic;

    --control signals
    PC_writeCond : in std_logic;
    PC_write     : in std_logic;
    IorD         : in std_logic;
    Mem_Read     : in std_logic;
    Mem_Write    : in std_logic;
    Mem_ToReg    : in std_logic;
    IRWrite      : in std_logic;
    JumpAndLink  : in std_logic;
    IsSigned     : in std_logic;
    PC_Source    : in std_logic_vector(1 downto 0);
    ALU_Op       : in std_logic_vector(1 downto 0);
    ALU_SrcB     : in std_logic_vector(1 downto 0);
    ALU_SrcA     : in std_logic;
    Reg_Write    : in std_logic;
    Reg_Dst      : in std_logic;

    -- External I/0
    switches : in std_logic_vector(9 downto 0);
    button   : in std_logic_vector (1 downto 0);
    LEDs     : out std_logic_vector(DATA_WIDTH - 1 downto 0);
    IR_31_26 : out std_logic_vector (31 downto 26);
    IR_5_0   : out std_logic_vector(5 downto 0)

  );
end MIPS_datapath;

architecture cheese_Grater of MIPS_datapath is

  -- Program Counter Signals
  signal PC_en      : std_logic;
  signal PC_inData  : std_logic_vector (DATA_WIDTH - 1 downto 0);
  signal PC_outData : std_logic_vector (DATA_WIDTH - 1 downto 0);

  signal InPort0_en : std_logic;
  signal InPort0    : std_logic_vector (DATA_WIDTH - 1 downto 0);
  signal InPort1_en : std_logic;
  signal InPort1    : std_logic_vector (DATA_WIDTH - 1 downto 0);
  signal OutPort    : std_logic_vector (DATA_WIDTH - 1 downto 0);

  -- memory signals
  signal mem_addr         : std_logic_vector (DATA_WIDTH - 1 downto 0);
  signal mem_dataOut      : std_logic_vector (DATA_WIDTH - 1 downto 0);
  signal mem_data_reg_out : std_logic_vector (DATA_WIDTH - 1 downto 0);

  -- ALU
  signal ALU_out_reg      : std_logic_vector(DATA_WIDTH - 1 downto 0); -- NEW registered ALU output
  signal ALU_out          : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal ALU_inA          : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal ALU_inB          : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal ALU_result       : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal ALU_resultHi     : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal branch_taken     : std_logic;
  signal signExtend_out   : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal shiftLeft2_out   : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal ALU_selected_out : std_logic_vector(DATA_WIDTH - 1 downto 0);

  -- ALU Controller
  signal OPselect    : std_logic_vector(4 downto 0);
  signal LO_en       : std_logic;
  signal LO_out      : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal HI_en       : std_logic;
  signal HI_out      : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal ALU_LO_HI   : std_logic_vector(1 downto 0);
  signal w_concatOut : std_logic_vector(DATA_WIDTH - 1 downto 0);

  -- Register File Signals
  signal w_IR_25_0  : std_logic_vector(25 downto 0);
  signal w_IR_31_26 : std_logic_vector(31 downto 26);
  signal w_IR_25_21 : std_logic_vector(25 downto 21);
  signal w_IR_20_16 : std_logic_vector(20 downto 16);
  signal w_IR_15_11 : std_logic_vector(15 downto 11);
  signal w_IR_15_0  : std_logic_vector(15 downto 0);

  signal w_RF_Write_register : std_logic_vector(4 downto 0);
  --signal wr_data_mux         : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal w_RF_Write_data     : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal w_RF_Read_Data_1    : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal w_RF_Read_Data_2    : std_logic_vector(DATA_WIDTH - 1 downto 0);

  -- Between Register file and ALU
  signal regA_out : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal regB_out : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal IR       : std_logic_vector(DATA_WIDTH - 1 downto 0);

  signal IR_funct_or_opcode : std_logic_vector(5 downto 0);


begin
  -- Add architecture implementation here, e.g., component instantiations or signal assignments.
  IR_5_0 <= IR(5 downto 0);

  --interface Logic
  -- Drive input ports from switches (extended to 32 bits)
  InPort0 <= std_logic_vector(resize(unsigned(switches(8 downto 0)), DATA_WIDTH));
  InPort1 <= std_logic_vector(resize(unsigned(switches(8 downto 0)), DATA_WIDTH));

  InPort0_en <= (not switches(9)) and button(0);
  InPort1_en <= switches(9) and button(0);

  --datapath connections
  PC_en    <= PC_write or (PC_writeCond and branch_taken);
  IR_31_26 <= w_IR_31_26;

  --program counter
  PC : reg
  generic map(WIDTH => DATA_WIDTH)
  port map
  (
    clk    => clk,
    rst    => rst,
    wr_en  => PC_en,
    input  => PC_inData,
    output => PC_outData
  );

  IorD_MUX_2x1 : mux_2x1
  generic map(WIDTH => DATA_WIDTH)
  port map
  (
    sel    => IorD,
    input0 => PC_outData,
    input1 => ALU_out,
    output => mem_addr
  );

  -- -- Use registered ALU result as memory address (important for sw and OutPort)
  -- IorD_MUX_2x1 : mux_2x1
  -- generic map(WIDTH => DATA_WIDTH)
  -- port map
  -- (
  --   sel    => IorD,
  --   input0 => PC_outData,
  --   input1 => ALU_out_reg, -- use registered ALU output
  --   output => mem_addr
  -- );
  MEMORY_INST : MIPS_memory
  port map
  (
    clk        => clk,
    byte_addr  => mem_addr,
    data_in    => w_RF_Read_Data_2,
    write_en   => Mem_Write,
    data_out   => mem_dataOut,
    InPort0_en => InPort0_en,
    InPort1_en => InPort1_en,
    InPort0    => InPort0,
    InPort1    => InPort1,
    OutPort    => OutPort
  );

  -- instruction register
  INSTRUCTION_REGISTER_INST : Instruction_Register
  port map
  (
    clk     => clk,
    rst     => rst,
    wr_en   => IRWrite,
    input   => mem_dataOut,
    IR      => IR,
    o_25_0  => w_IR_25_0,
    o_31_26 => w_IR_31_26,
    o_25_21 => w_IR_25_21,
    o_20_16 => w_IR_20_16,
    o_15_11 => w_IR_15_11,
    o_15_0  => w_IR_15_0
  );

  MEMORY_DATA_REGISTER_INST : reg
  generic map(WIDTH => DATA_WIDTH)
  port map
  (
    clk    => clk,
    rst    => rst,
    wr_en  => '1',
    input  => mem_dataOut,
    output => mem_data_reg_out
  );

  REG_DST_MUX_2x1 : mux_2x1
  generic map(WIDTH => 5)
  port map
  (
    sel    => Reg_Dst,
    input0 => w_IR_20_16,
    input1 => w_IR_15_11,
    output => w_RF_Write_register
  );

  MEM_TO_REG_MUX_2x1 : mux_2x1
  generic map(WIDTH => DATA_WIDTH)
  port map
  (
    sel    => Mem_ToReg,
    input0 => ALU_selected_out,
    input1 => mem_data_reg_out,
    output => w_RF_Write_data
  );

  -- -- wr_data_mux determines what is written into the register file
  -- wr_data_mux <= std_logic_vector(unsigned(PC_outData) + 4) when JumpAndLink = '1'
  --   else
  --   w_RF_Write_data;

  REGISTER_FILE_INST : registerfile
  port map
  (
    clk         => clk,
    rst         => rst,
    rd_addr0    => w_IR_25_21,
    rd_addr1    => w_IR_20_16,
    wr_addr     => w_RF_Write_register,
    wr_en       => Reg_Write,
    wr_data     => w_RF_Write_data, -- changed from w_RF_Write_data
    rd_data0    => w_RF_Read_Data_1,
    rd_data1    => w_RF_Read_Data_2,
    JumpAndLink => JumpAndLink
  );
  -- REG_A : reg
  -- generic map(WIDTH => DATA_WIDTH)
  -- port map
  -- (
  --   clk    => clk,
  --   rst    => rst,
  --   wr_en  => '1',
  --   input  => w_RF_Read_Data_1,
  --   output => regA_out
  -- );

  -- REG_B : reg
  -- generic map(WIDTH => DATA_WIDTH)
  -- port map
  -- (
  --   clk    => clk,
  --   rst    => rst,
  --   wr_en  => '1',
  --   input  => w_RF_Read_Data_2,
  --   output => regB_out
  -- );

  ALU_FROM_REG_A_MUX_2x1 : mux_2x1
  generic map(WIDTH => DATA_WIDTH)
  port map
  (
    sel    => ALU_SrcA,
    input0 => PC_outData,
    input1 => w_RF_Read_Data_1,
    output => ALU_inA
  );

  ALU_FROM_REG_B_MUX_2x1 : mux_4x1
  generic map(WIDTH => DATA_WIDTH)
  port map
  (
    sel    => ALU_SrcB,
    input0 => w_RF_Read_Data_2,
    input1 => std_logic_vector(to_unsigned(4, DATA_WIDTH)),
    input2 => signExtend_out,
    input3 => shiftLeft2_out,
    output => ALU_inB
  );

  SIGN_EXTEND_INST : sign_extend
  port map
  (
    isSigned => IsSigned,
    input    => w_IR_15_0,
    output   => signExtend_out
  );

  SHIFT_LEFT_2_INST : shift_left2
  port map
  (
    input  => signExtend_out,
    output => shiftLeft2_out
  );

  ALU_INST : MIPS_alu
  generic map(WIDTH => DATA_WIDTH)
  port map
  (
    input1       => ALU_inA,
    input2       => ALU_inB,
    IR           => IR (10 downto 6),
    sel          => OPselect,
    output       => ALU_result,
    output_High  => ALU_resultHi,
    branch_taken => branch_taken
  );

  ALU_OUTPUT : reg
  generic map(WIDTH => DATA_WIDTH)
  port map
  (
    clk    => clk,
    rst    => rst,
    wr_en  => '1',
    input  => ALU_result,
    output => ALU_out
  );

  -- -- Register ALU result into ALU_out_reg for memory addressing
  -- ALU_OUTPUT : reg
  -- generic map(WIDTH => DATA_WIDTH)
  -- port map
  -- (
  --   clk    => clk,
  --   rst    => rst,
  --   wr_en  => '1',
  --   input  => ALU_result,
  --   output => ALU_out_reg  -- use in IorD mux
  -- );

  -- ALU_OUTPUT : reg
  -- generic map(WIDTH => DATA_WIDTH)
  -- port map(
  --   clk    => clk,
  --   rst    => rst,
  --   wr_en  => '1',
  --   input  => ALU_result,
  --   output => ALU_out_reg
  -- );


  -- MUX for choosing final ALU output (with HI/LO muxing)
  ALU_LO_HI_MUX_3x1 : mux_3x1
  generic map(WIDTH => DATA_WIDTH)
  port map
  (
    sel    => ALU_LO_HI,
    input0 => ALU_out,  -- registered value
    input1 => LO_out,
    input2 => HI_out,
    output => ALU_selected_out
  );

  LO_REG : reg
  generic map(WIDTH => DATA_WIDTH)
  port map
  (
    clk    => clk,
    rst    => rst,
    wr_en  => LO_en,
    input  => ALU_result,
    output => LO_out
  );

  HI_REG : reg
  generic map(WIDTH => DATA_WIDTH)
  port map
  (
    clk    => clk,
    rst    => rst,
    wr_en  => HI_en,
    input  => ALU_resultHI,
    output => HI_out
  );

  IR_funct_or_opcode <= IR(5 downto 0) when ALU_Op = "10" else IR(31 downto 26);


  ALU_CONTROLLER_INST : ALU_controller
  port map
  (
    IR        => IR_funct_or_opcode,
    ALU_Op    => ALU_Op,
    ALU_LO_HI => ALU_LO_HI,
    LO_en     => LO_en,
    HI_en     => HI_en,
    OPSelect  => OPselect
  );


  -- ALU_LO_HI_MUX_3x1 : mux_3x1
  -- generic map(WIDTH => DATA_WIDTH)
  -- port map
  -- (
  --   sel    => ALU_LO_HI,
  --   input0 => ALU_out,
  --   input1 => LO_out,
  --   input2 => HI_out,
  --   output => ALU_selected_out
  -- );

  shift_left_concat_inst : shift_left_concat
  port map
  (
    i_IR_25_0  => w_IR_25_0,
    i_PC_31_28 => PC_outData(31 downto 28),
    output     => w_concatOut
  );

  PC_SOURCE_MUX_3X1 : mux_3x1
  generic map(WIDTH => DATA_WIDTH)
  port map
  (
    sel    => PC_Source,
    input0 => ALU_result,
    input1 => ALU_out,
    input2 => w_concatOut,
    output => PC_inData
  );

  -- PC_SOURCE_MUX_3X1 : mux_3x1
  -- generic map(WIDTH => DATA_WIDTH)
  -- port map(
  --   sel    => PC_Source,
  --   input0 => ALU_out_reg,   -- change from ALU_result
  --   input1 => ALU_out,       -- possibly unused
  --   input2 => w_concatOut,
  --   output => PC_inData
  -- );


  LEDs <= OutPort;

end cheese_Grater;

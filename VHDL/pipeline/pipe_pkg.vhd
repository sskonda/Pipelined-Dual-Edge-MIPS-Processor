-- =============================================================================
-- pipe_pkg.vhd  –  Pipeline data types for the 5-stage MIPS pipeline (VHDL).
--
-- VHDL equivalent of SV/pipeline/pipe_pkg.sv.  Records replace packed structs;
-- reset constants replace SV parameterised default values.
--
-- See SV/pipeline/pipe_pkg.sv for full architecture documentation.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.MIPS_package.all;

package pipe_pkg is

  -- ---------------------------------------------------------------------------
  -- Branch type encoding (3-bit)
  -- ---------------------------------------------------------------------------
  constant BR_BEQ  : std_logic_vector(2 downto 0) := "000"; -- A == B
  constant BR_BNE  : std_logic_vector(2 downto 0) := "001"; -- A /= B
  constant BR_BLEZ : std_logic_vector(2 downto 0) := "010"; -- A <= 0
  constant BR_BGTZ : std_logic_vector(2 downto 0) := "011"; -- A > 0
  constant BR_BLTZ : std_logic_vector(2 downto 0) := "100"; -- A < 0
  constant BR_BGEZ : std_logic_vector(2 downto 0) := "101"; -- A >= 0

  -- ---------------------------------------------------------------------------
  -- Forwarding mux select (2-bit)
  -- ---------------------------------------------------------------------------
  constant FWD_ID  : std_logic_vector(1 downto 0) := "00"; -- register file
  constant FWD_EXM : std_logic_vector(1 downto 0) := "01"; -- EX/MEM ALU result
  constant FWD_MWB : std_logic_vector(1 downto 0) := "10"; -- MEM/WB write data

  -- ---------------------------------------------------------------------------
  -- IF/ID pipeline register record
  -- ---------------------------------------------------------------------------
  type if_id_t is record
    valid    : std_logic;
    pc_plus4 : std_logic_vector(31 downto 0);
    instr    : std_logic_vector(31 downto 0);
  end record;

  constant IF_ID_NOP : if_id_t := (
    valid    => '0',
    pc_plus4 => (others => '0'),
    instr    => (others => '0')
  );

  -- ---------------------------------------------------------------------------
  -- ID/EX pipeline register record
  -- ---------------------------------------------------------------------------
  type id_ex_t is record
    valid       : std_logic;
    pc_plus4    : std_logic_vector(31 downto 0);
    rs_data     : std_logic_vector(31 downto 0);
    rt_data     : std_logic_vector(31 downto 0);
    imm32       : std_logic_vector(31 downto 0);
    rs          : std_logic_vector(4 downto 0);
    rt          : std_logic_vector(4 downto 0);
    rd          : std_logic_vector(4 downto 0);
    shamt       : std_logic_vector(4 downto 0);
    alu_op      : std_logic_vector(4 downto 0);
    alu_src_b   : std_logic;
    alu_lo_hi   : std_logic_vector(1 downto 0);
    hi_write    : std_logic;
    lo_write    : std_logic;
    mem_read    : std_logic;
    mem_write   : std_logic;
    reg_write   : std_logic;
    mem_to_reg  : std_logic;
    branch      : std_logic;
    branch_type : std_logic_vector(2 downto 0);
    jump        : std_logic;
    jump_reg    : std_logic;
    is_jal      : std_logic;
  end record;

  constant ID_EX_NOP : id_ex_t := (
    valid       => '0',
    pc_plus4    => (others => '0'),
    rs_data     => (others => '0'),
    rt_data     => (others => '0'),
    imm32       => (others => '0'),
    rs          => (others => '0'),
    rt          => (others => '0'),
    rd          => (others => '0'),
    shamt       => (others => '0'),
    alu_op      => ALU_NOP,
    alu_src_b   => '0',
    alu_lo_hi   => "00",
    hi_write    => '0',
    lo_write    => '0',
    mem_read    => '0',
    mem_write   => '0',
    reg_write   => '0',
    mem_to_reg  => '0',
    branch      => '0',
    branch_type => BR_BEQ,
    jump        => '0',
    jump_reg    => '0',
    is_jal      => '0'
  );

  -- ---------------------------------------------------------------------------
  -- EX/MEM pipeline register record
  -- ---------------------------------------------------------------------------
  type ex_mem_t is record
    valid         : std_logic;
    pc_plus4      : std_logic_vector(31 downto 0);
    alu_result    : std_logic_vector(31 downto 0);
    alu_result_hi : std_logic_vector(31 downto 0);
    rt_fwd        : std_logic_vector(31 downto 0);
    rd            : std_logic_vector(4 downto 0);
    mem_read      : std_logic;
    mem_write     : std_logic;
    reg_write     : std_logic;
    mem_to_reg    : std_logic;
    hi_write      : std_logic;
    lo_write      : std_logic;
    is_load       : std_logic;
    take_branch   : std_logic;
    take_jump     : std_logic;
    pc_target     : std_logic_vector(31 downto 0);
  end record;

  constant EX_MEM_NOP : ex_mem_t := (
    valid         => '0',
    pc_plus4      => (others => '0'),
    alu_result    => (others => '0'),
    alu_result_hi => (others => '0'),
    rt_fwd        => (others => '0'),
    rd            => (others => '0'),
    mem_read      => '0',
    mem_write     => '0',
    reg_write     => '0',
    mem_to_reg    => '0',
    hi_write      => '0',
    lo_write      => '0',
    is_load       => '0',
    take_branch   => '0',
    take_jump     => '0',
    pc_target     => (others => '0')
  );

  -- ---------------------------------------------------------------------------
  -- MEM/WB pipeline register record
  -- ---------------------------------------------------------------------------
  type mem_wb_t is record
    valid      : std_logic;
    wr_data    : std_logic_vector(31 downto 0);
    wr_data_hi : std_logic_vector(31 downto 0);
    rd         : std_logic_vector(4 downto 0);
    reg_write  : std_logic;
    hi_write   : std_logic;
    lo_write   : std_logic;
  end record;

  constant MEM_WB_NOP : mem_wb_t := (
    valid      => '0',
    wr_data    => (others => '0'),
    wr_data_hi => (others => '0'),
    rd         => (others => '0'),
    reg_write  => '0',
    hi_write   => '0',
    lo_write   => '0'
  );

end package pipe_pkg;

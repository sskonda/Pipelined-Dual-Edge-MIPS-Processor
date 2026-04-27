library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package MIPS_package is

  constant CLK_PERIOD : time     := 5 ns;
  constant DATA_WIDTH : positive := 32;

  --------------------------------------- ALU Constants ---------------------------------------
  constant ALU_ADD_unsign         : std_logic_vector(4 downto 0)  := "00000"; -- A + B
  constant ALU_ADD_sign           : std_logic_vector(4 downto 0)  := "00001"; -- A + B
  constant ALU_SUB_unsign         : std_logic_vector(4 downto 0)  := "00010"; -- A - B
  constant ALU_SUB_sign           : std_logic_vector(4 downto 0)  := "00011"; -- A - B
  constant ALU_mult_unsign        : std_logic_vector(4 downto 0)  := "00100"; -- A * B (unsigned)
  constant ALU_mult_sign          : std_logic_vector(4 downto 0)  := "00101"; -- A * B (signed)
  constant ALU_AND                : std_logic_vector(4 downto 0)  := "00110"; -- A AND B
  constant ALU_OR                 : std_logic_vector(4 downto 0)  := "00111"; -- A OR B
  constant ALU_XOR                : std_logic_vector(4 downto 0)  := "01000"; -- A XOR B
  constant ALU_NOT_A              : std_logic_vector(4 downto 0)  := "01001"; -- NOT A
  constant ALU_LOG_SHIFT_R        : std_logic_vector(4 downto 0)  := "01010"; -- Logical Shift Right
  constant ALU_LOG_SHIFT_L        : std_logic_vector(4 downto 0)  := "01011"; -- Logical Shift Left
  constant ALU_ARITH_SHIFT_R      : std_logic_vector(4 downto 0)  := "01100"; --Arithmatic Shift Right
  constant ALU_comp_A_lt_B_unsign : std_logic_vector (4 downto 0) := "01101"; -- compare A < B unsigned
  constant ALU_comp_A_lt_B_sign   : std_logic_vector (4 downto 0) := "01110"; -- compare A < B signed
  constant ALU_A_gt_0             : std_logic_vector (4 downto 0) := "01111"; -- compare A > 0 signed
  constant ALU_A_eq_0             : std_logic_vector (4 downto 0) := "10000"; -- compare A = 0 signed
  constant ALU_gteq_0             : std_logic_vector (4 downto 0) := "10001"; -- compare A >= 0 signed
  constant ALU_lteq_0             : std_logic_vector (4 downto 0) := "10010"; -- compare A <= 0 signed
  constant ALU_A_eq_B             : std_logic_vector (4 downto 0) := "10011"; -- compare A == B
  constant ALU_A_ne_B             : std_logic_vector (4 downto 0) := "10100"; -- compare A != B
  constant ALU_A_lt_0             : std_logic_vector (4 downto 0) := "10101"; -- compare A < 0 (signed)
  constant ALU_PASS_A_BRANCH      : std_logic_vector (4 downto 0) := "10110"; -- pass input A (used for jr)
  constant ALU_PASS_B_BRANCH      : std_logic_vector (4 downto 0) := "10111"; -- pass input B (used for jr)
  constant ALU_NOP                : std_logic_vector(4 downto 0)  := "11111"; -- no operation / bypass ALU

  -- constant ALUOp_addu   : std_logic_vector(2 downto 0) := "000"; -- used in fetch
  -- constant ALUOp_adds   : std_logic_vector(2 downto 0) := "001"; -- used in decode/lw/sw
  -- constant ALUOp_rtype  : std_logic_vector(2 downto 0) := "010"; -- used in R-type
  -- constant ALUOp_nonr   : std_logic_vector(2 downto 0) := "011"; -- used in all others (branch/I-type)
  -- constant ALUOp_passA : std_logic_vector(2 downto 0) := "100"; -- pass input A
  -- constant ALUOp_passB : std_logic_vector(2 downto 0) := "101"; -- pass input B

  constant ALUOp_addu   : std_logic_vector(1 downto 0) := "00"; -- used in fetch
  constant ALUOp_adds   : std_logic_vector(1 downto 0) := "01"; -- used in decode/lw/sw
  constant ALUOp_rtype  : std_logic_vector(1 downto 0) := "10"; -- used in R-type
  constant ALUOp_nonr   : std_logic_vector(1 downto 0) := "11"; -- used in all others (branch/I-type)




  --------------------------------------- ALU_Op Control Field Constants ---------------------------------------

  -- R-type instructions
  constant R_OP : std_logic_vector(5 downto 0) := "000000"; -- Used for all R-type instructions (funct field needed)

  -- I-type instructions
  constant I_ADDIU : std_logic_vector(5 downto 0) := "001001";
  constant I_SUBIU : std_logic_vector(5 downto 0) := "010000"; -- subiu
  constant I_ANDI  : std_logic_vector(5 downto 0) := "001100";
  constant I_ORI   : std_logic_vector(5 downto 0) := "001101";
  constant I_XORI  : std_logic_vector(5 downto 0) := "001110";
  constant I_SLTI  : std_logic_vector(5 downto 0) := "001010";
  constant I_SLTIU : std_logic_vector(5 downto 0) := "001011";

  constant I_BEQ    : std_logic_vector(5 downto 0) := "000100";
  constant I_BNE    : std_logic_vector(5 downto 0) := "000101";
  constant I_BLEZ   : std_logic_vector(5 downto 0) := "000110";
  constant I_BGTZ   : std_logic_vector(5 downto 0) := "000111";
  constant I_REGIMM : std_logic_vector(5 downto 0) := "000001"; -- bgez/bltz, check rt field

  -- J-type instructions (for completeness, even if unused in ALU controller)
  constant J_JUMP : std_logic_vector(5 downto 0) := "000010";
  constant J_JAL  : std_logic_vector(5 downto 0) := "000011";

  --------------------------------------- R-Type Function Constants ---------------------------------------

  constant R_FUNC_ADDU : std_logic_vector(5 downto 0) := "100001";
  constant R_FUNC_SUBU : std_logic_vector(5 downto 0) := "100011";
  constant R_FUNC_AND  : std_logic_vector(5 downto 0) := "100100";
  constant R_FUNC_OR   : std_logic_vector(5 downto 0) := "100101";
  constant R_FUNC_XOR  : std_logic_vector(5 downto 0) := "100110";
  constant R_FUNC_SLT  : std_logic_vector(5 downto 0) := "101010";
  constant R_FUNC_SLTU : std_logic_vector(5 downto 0) := "101011";

  constant R_FUNC_SLL : std_logic_vector(5 downto 0) := "000000";
  constant R_FUNC_SRL : std_logic_vector(5 downto 0) := "000010";
  constant R_FUNC_SRA : std_logic_vector(5 downto 0) := "000011";

  constant R_FUNC_MULT  : std_logic_vector(5 downto 0) := "011000";
  constant R_FUNC_MULTU : std_logic_vector(5 downto 0) := "011001";

  constant R_FUNC_MFHI : std_logic_vector(5 downto 0) := std_logic_vector(to_unsigned(16#10#, 6));
  constant R_FUNC_MFLO : std_logic_vector(5 downto 0) := std_logic_vector(to_unsigned(16#12#, 6));

  constant R_FUNC_JR : std_logic_vector(5 downto 0) := "001000";
  --------------------------------------- Component Initializations ---------------------------------------

  -------------------------------------- MUX Components --------------------------------------
  component mux_2x1 is
    generic (WIDTH : positive := 8);
    port (
      input0 : in std_logic_vector(WIDTH - 1 downto 0);
      input1 : in std_logic_vector(WIDTH - 1 downto 0);
      sel    : in std_logic;
      output : out std_logic_vector(WIDTH - 1 downto 0)
    );
  end component;

  component mux_3x1 is
    generic (
      WIDTH : positive := 8 -- Default data width is 8 bits
    );
    port (
      sel    : in std_logic_vector(1 downto 0); -- 2-bit selector
      input0 : in std_logic_vector(WIDTH - 1 downto 0);
      input1 : in std_logic_vector(WIDTH - 1 downto 0);
      input2 : in std_logic_vector(WIDTH - 1 downto 0);
      output : out std_logic_vector(WIDTH - 1 downto 0)
    );
  end component;

  component mux_4x1 is
    generic (
      WIDTH : positive := 32 -- Default data width is 32 bits
    );
    port (
      sel    : in std_logic_vector(1 downto 0);
      input0 : in std_logic_vector(WIDTH - 1 downto 0);
      input1 : in std_logic_vector(WIDTH - 1 downto 0);
      input2 : in std_logic_vector(WIDTH - 1 downto 0);
      input3 : in std_logic_vector(WIDTH - 1 downto 0);
      output : out std_logic_vector(WIDTH - 1 downto 0)
    );
  end component;
  -------------------------------------- ALU Components --------------------------------------
  -- ALU component for MIPS
  component MIPS_alu is
    generic (WIDTH : positive := 32);
    port (
      input1       : in std_logic_vector(WIDTH - 1 downto 0);
      input2       : in std_logic_vector(WIDTH - 1 downto 0);
      IR           : in std_logic_vector(4 downto 0);
      sel          : in std_logic_vector(4 downto 0);
      output       : out std_logic_vector(WIDTH - 1 downto 0);
      output_High  : out std_logic_vector(WIDTH - 1 downto 0);
      branch_taken : out std_logic
    );
  end component;

  component ALU_controller is
  port (
    IR        : in std_logic_vector(5 downto 0);  -- funct or rt depending on opcode
    ALU_Op    : in std_logic_vector(1 downto 0);  -- opcode from instruction
    OPSelect  : out std_logic_vector(4 downto 0); -- ALU operation select
    LO_en     : out std_logic;
    HI_en     : out std_logic;
    ALU_LO_HI : out std_logic_vector(1 downto 0)
  );
  end component;

  --------------------------------------- Data Path ---------------------------------------------
  component MIPS_datapath is
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
    ALU_Op       : in std_logic_vector(2 downto 0);
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
  end component;

    --------------------------------------- MIPS Controller --------------------------------------
  component MIPS_ctrl is
  port(
      clk     : in  std_logic;
      reset   : in  std_logic;

      -- From IR
      opcode  : in  std_logic_vector(5 downto 0); -- IR(31:26)
      funct   : in  std_logic_vector(5 downto 0); -- IR(5:0)

      -- Control signals to datapath
      PC_writeCond : out std_logic;
      PC_write     : out std_logic;
      IorD         : out std_logic;
      Mem_Read     : out std_logic;
      Mem_Write    : out std_logic;
      Mem_ToReg    : out std_logic;
      IRWrite      : out std_logic;
      JumpAndLink  : out std_logic;
      IsSigned     : out std_logic;
      PC_Source    : out std_logic_vector(1 downto 0);
      ALU_Op       : out std_logic_vector(5 downto 0);
      ALU_SrcB     : out std_logic_vector(1 downto 0);
      ALU_SrcA     : out std_logic;
      Reg_Write    : out std_logic;
      Reg_Dst      : out std_logic
  );
  end component;

  --------------------------------------- Memory Components --------------------------------------
  -- Memory component for MIPS
  component RAM is
    port (
      address : in std_logic_vector(7 downto 0);
      clock   : in std_logic;
      data    : in std_logic_vector(DATA_WIDTH - 1 downto 0);
      wren    : in std_logic;
      q       : out std_logic_vector(DATA_WIDTH - 1 downto 0)
    );
  end component;

  component MIPS_memory is
    port (
      clk        : in std_logic;
      byte_addr  : in std_logic_vector(31 downto 0);
      data_in    : in std_logic_vector(31 downto 0);
      write_en   : in std_logic;
      data_out   : out std_logic_vector(31 downto 0);
      InPort0_en : in std_logic;
      InPort1_en : in std_logic;
      InPort0    : in std_logic_vector(31 downto 0);
      InPort1    : in std_logic_vector(31 downto 0);
      OutPort    : out std_logic_vector(31 downto 0)
    );
  end component;
  -------------------------------------- Register Components --------------------------------------
  -- Register for Program Counter
  component reg is
    generic (WIDTH : positive := 8);
    port (
      clk    : in std_logic;
      rst    : in std_logic;
      wr_en  : in std_logic;
      input  : in std_logic_vector(DATA_WIDTH - 1 downto 0);
      output : out std_logic_vector(DATA_WIDTH - 1 downto 0)
    );
  end component;

  -- Register File Component
  component registerfile is
    port(
        clk : in std_logic;
        rst : in std_logic;
		  
        rd_addr0 : in std_logic_vector(4 downto 0); --read reg 1
        rd_addr1 : in std_logic_vector(4 downto 0); --read reg 2
		  
        wr_addr : in std_logic_vector(4 downto 0); --write register
        wr_en : in std_logic;
        wr_data : in std_logic_vector(31 downto 0); --write data
		  
        rd_data0 : out std_logic_vector(31 downto 0); --read data 1
        rd_data1 : out std_logic_vector(31 downto 0); --read data 2
	
        --JAL	
        JumpAndLink : in std_logic
        );
  end component;

  component OLD_registerfile is
    port(
        clk : in std_logic;
        rst : in std_logic;
		  
        rd_addr0 : in std_logic_vector(4 downto 0); --read reg 1
        rd_addr1 : in std_logic_vector(4 downto 0); --read reg 2
		  
        wr_addr : in std_logic_vector(4 downto 0); --write register
        wr_en : in std_logic;
        wr_data : in std_logic_vector(31 downto 0); --write data
		  
        rd_data0 : out std_logic_vector(31 downto 0); --read data 1
        rd_data1 : out std_logic_vector(31 downto 0); --read data 2
		  --JAL
		  PC_4 : in std_logic_vector(31 downto 0);
		  JumpAndLink : in std_logic
      );
    end component;

  component Instruction_Register is
    port (
      clk     : in std_logic;
      rst     : in std_logic;
      wr_en   : in std_logic;
      input   : in std_logic_vector(31 downto 0);
      IR      : out std_logic_vector(31 downto 0);
      o_25_0  : out std_logic_vector(25 downto 0);
      o_31_26 : out std_logic_vector(31 downto 26);
      o_25_21 : out std_logic_vector(25 downto 21);
      o_20_16 : out std_logic_vector(20 downto 16);
      o_15_11 : out std_logic_vector(15 downto 11);
      o_15_0  : out std_logic_vector(15 downto 0)
    );
  end component;
  --------------------------------------- Sign Extend and Shift Components --------------------------------------
  component sign_extend is
    port (
      isSigned : in std_logic;
      input    : in std_logic_vector(15 downto 0);
      output   : out std_logic_vector(31 downto 0)
    );
  end component;

  component shift_left2 is
    port (
      input  : in std_logic_vector(31 downto 0);
      output : out std_logic_vector(31 downto 0)
    );
  end component;

  component shift_left_concat is
    port (
      i_IR_25_0  : in std_logic_vector(25 downto 0);
      i_PC_31_28 : in std_logic_vector(3 downto 0);
      output     : out std_logic_vector(31 downto 0)
    );
  end component;

  -------------------------------------------------7 segment Decoder-------------------------------------
  component decoder7seg is
      port 
      (
        input  : in  std_logic_vector(3 downto 0);
        output : out std_logic_vector(6 downto 0)
      );
  end component;

end MIPS_package;

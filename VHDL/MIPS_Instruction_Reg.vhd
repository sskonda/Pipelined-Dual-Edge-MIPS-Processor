library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Instruction_Register is
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
end Instruction_Register;

architecture Asiago of Instruction_Register is
  signal IR_reg : std_logic_vector(31 downto 0) := (others => '0');

  begin
    process (clk, rst)
    begin
      if rst = '1' then
        IR_reg <= (others => '0');

      elsif rising_edge(clk) then
        if wr_en = '1' then
          IR_reg <= input;
        end if;
        
      end if;
    end process;

  -- Outputs
  IR      <= IR_reg;
  o_31_26 <= IR_reg(31 downto 26);
  o_25_21 <= IR_reg(25 downto 21);
  o_20_16 <= IR_reg(20 downto 16);
  o_15_11 <= IR_reg(15 downto 11);
  o_25_0  <= IR_reg(25 downto 0);
  o_15_0  <= IR_reg(15 downto 0);
end Asiago;

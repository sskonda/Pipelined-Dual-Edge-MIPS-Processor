library ieee;
use ieee.std_logic_1164.all;

entity mux_4x1 is
    generic (
        WIDTH : positive := 32 -- Default data width is 32 bits
    );
  port (
    sel    : in std_logic_vector(1 downto 0);
    input0 : in std_logic_vector(WIDTH-1 downto 0);
    input1 : in std_logic_vector(WIDTH-1 downto 0);
    input2 : in std_logic_vector(WIDTH-1 downto 0);
    input3 : in std_logic_vector(WIDTH-1 downto 0);
    output : out std_logic_vector(WIDTH-1 downto 0)
  );
end entity;

architecture Gouda of mux_4x1 is
begin
  process (sel, input0, input1, input2, input3)
  begin
    case sel is
      when "00"   => output <= input0;
      when "01"   => output <= input1;
      when "10"   => output <= input2;
      when "11"   => output <= input3;
      when others => output <= (others => '0'); -- Default case to avoid latches
    end case;
  end process;
end Gouda;

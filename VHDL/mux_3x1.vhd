library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mux_3x1 is
  generic (
    WIDTH : positive := 8  -- Default data width is 8 bits
  );
  port (
    sel    : in  std_logic_vector(1 downto 0); -- 2-bit selector
    input0 : in  std_logic_vector(WIDTH-1 downto 0);
    input1 : in  std_logic_vector(WIDTH-1 downto 0);
    input2 : in  std_logic_vector(WIDTH-1 downto 0);
    output : out std_logic_vector(WIDTH-1 downto 0)
  );
end entity mux_3x1;

architecture Brie of mux_3x1 is
begin
  process (sel, input0, input1, input2)
  begin
    case sel is
      when "00"   => output <= input0;
      when "01"   => output <= input1;
      when "10"   => output <= input2;
      when others => output <= (others => '0'); -- Default case
    end case;
  end process;
end Brie;

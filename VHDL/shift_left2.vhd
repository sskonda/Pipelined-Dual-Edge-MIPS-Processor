library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.MIPS_package.all;

entity shift_left2 is
  port (
    input  : in std_logic_vector(31 downto 0);
    output : out std_logic_vector(31 downto 0)
  );
end shift_left2;

architecture Feta of shift_left2 is
begin
  output <= std_logic_vector(shift_left(signed(input), 2));
end Feta;

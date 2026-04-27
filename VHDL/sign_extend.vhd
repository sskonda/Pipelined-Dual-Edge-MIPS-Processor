library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.MIPS_package.all;

entity sign_extend is
  port (
    isSigned  : in std_logic;
    input : in std_logic_vector(15 downto 0);
    output    : out std_logic_vector(31 downto 0)
  );
end sign_extend;

architecture Parmesean of sign_extend is
begin

  with isSigned select
    output <= std_logic_vector(resize(signed(input), 32)) when '1',
    std_logic_vector(resize(unsigned(input), 32)) when others;

end architecture;

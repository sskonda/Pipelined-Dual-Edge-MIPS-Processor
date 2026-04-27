library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity mux_2x1 is
  generic (WIDTH : positive := 16);
  port (
    input0 : in std_logic_vector(WIDTH - 1 downto 0);
    input1 : in std_logic_vector(WIDTH - 1 downto 0);
    sel    : in std_logic;
    output      : out std_logic_vector(WIDTH - 1 downto 0)
  );
end entity;

architecture Gruyere of mux_2x1 is
begin
  with sel select
    output <= input0 when '0',
    input1 when '1',
    (others => 'X') when others;
end Gruyere;

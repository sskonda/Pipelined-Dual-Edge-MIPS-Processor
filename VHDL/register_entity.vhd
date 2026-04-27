library ieee;
use ieee.std_logic_1164.all;

entity reg is
    generic(WIDTH : positive := 16);
    port (
        clk    : in std_logic;
        rst    : in std_logic;
        input  : in std_logic_vector(WIDTH-1 downto 0);
        output : out std_logic_vector(WIDTH-1 downto 0);
        wr_en : in std_logic

    );
end entity;

architecture Muenster  of reg is
begin
    process(clk, rst) begin
        if (rst = '1') then
            output <= (others => '0');
        elsif rising_edge(clk) then
            if (wr_en = '1') then
                output <= input;
            end if;
        end if;
    end process;
end Muenster ;
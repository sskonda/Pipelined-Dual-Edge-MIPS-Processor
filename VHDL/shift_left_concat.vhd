library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity shift_left_concat is
    Port (
        i_IR_25_0  : in  STD_LOGIC_VECTOR(25 downto 0);
        i_PC_31_28 : in  STD_LOGIC_VECTOR(3 downto 0);
        output     : out STD_LOGIC_VECTOR(31 downto 0)
    );
end shift_left_concat;

architecture Cheddar of shift_left_concat is
begin
    output <= i_PC_31_28 & i_IR_25_0 & "00";     
end Cheddar;

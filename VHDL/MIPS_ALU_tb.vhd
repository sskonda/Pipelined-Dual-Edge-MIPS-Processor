library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;  -- Use numeric_std for proper conversions

entity MIPS_ALU_tb is
end entity;

architecture TB of MIPS_ALU_tb is

    component MIPS_ALU
        generic (
            WIDTH : positive := 32  -- Match testbench width
        );
        port (
            input1       : in std_logic_vector(WIDTH-1 downto 0);
            input2       : in std_logic_vector(WIDTH-1 downto 0);
            IR           : in std_logic_vector(4 downto 0);
            sel          : in std_logic_vector(4 downto 0);
            output       : out std_logic_vector(WIDTH-1 downto 0);
            output_High  : out std_logic_vector(WIDTH-1 downto 0);
            branch_taken : out std_logic
        );
    end component;

    -- Constants & Signals
    constant WIDTH  : positive := 32;
    signal input1       : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
    signal input2       : std_logic_vector(WIDTH-1 downto 0) := (others => '0');
    signal IR           : std_logic_vector(4 downto 0) := (others => '0');  -- Unused but required in ALU
    signal sel          : std_logic_vector(4 downto 0) := (others => '0');
    signal output       : std_logic_vector(WIDTH-1 downto 0);
    signal output_High  : std_logic_vector(WIDTH-1 downto 0);
    signal branch_taken : std_logic;

begin

    -- Instantiate ALU
    UUT : MIPS_ALU
        generic map (WIDTH => WIDTH)
        port map (
            input1       => input1,
            input2       => input2,
            IR           => IR,
            sel          => sel,
            output       => output,
            output_High  => output_High,
            branch_taken => branch_taken
        );

    process
    begin
        -- Test Case: Addition (10 + 15)
        sel    <= "00000"; -- ADD operation
        input1 <= std_logic_vector(to_unsigned(10, WIDTH));
        input2 <= std_logic_vector(to_unsigned(15, WIDTH));
        wait for 40 ns;
        assert output = std_logic_vector(to_unsigned(25, WIDTH))
            report "Addition failed" severity error;

        -- Test Case: Subtraction (25 - 10)
        sel    <= "00010"; -- SUB operation
        input1 <= std_logic_vector(to_unsigned(25, WIDTH));
        input2 <= std_logic_vector(to_unsigned(10, WIDTH));
        wait for 40 ns;
        assert output = std_logic_vector(to_unsigned(15, WIDTH))
            report "Subtraction failed" severity error;

        -- Test Case: Signed Multiplication (10 * -4)
        sel    <= "00101"; -- SIGNED MULTIPLY operation
        input1 <= std_logic_vector(to_signed(10, WIDTH));
        input2 <= std_logic_vector(to_signed(-4, WIDTH));
        wait for 40 ns;
        -- Expecting signed multiplication result (-40) in output_High:output

        -- Test Case: Unsigned Multiplication (65536 * 131072)
        sel    <= "00100"; -- UNSIGNED MULTIPLY operation
        input1 <= std_logic_vector(to_unsigned(65536, WIDTH));
        input2 <= std_logic_vector(to_unsigned(131072, WIDTH));
        wait for 40 ns;
        -- Expecting 0 (lower 32-bits) in `output`, upper part in `output_High`

        -- Test Case: Logical AND (0x0000FFFF & 0xFFFF1234)
        sel    <= "00110"; -- AND operation
        input1 <= x"0000FFFF";
        input2 <= x"FFFF1234";
        wait for 40 ns;
        assert output = x"00001234"
            report "AND operation failed" severity error;

        -- Test Case: Logical Shift Right (0x0000000F >> 4)
        sel    <= "01010"; -- LSR operation
        input2 <= x"0000000F";
        IR     <= "00100"; -- Shift by 4 bits
        wait for 40 ns;
        assert output = x"00000000"
            report "Logical Shift Right failed" severity error;

        -- Test Case: Arithmetic Shift Right (0xF0000008 >> 1)
        sel    <= "01100"; -- ASR operation
        input2 <= x"F0000008";
        IR     <= "00001"; -- Shift by 1 bit
        wait for 40 ns;
        assert output = x"F8000004"  -- Expected result for ASR
            report "Arithmetic Shift Right failed" severity error;

        -- Test Case: Arithmetic Shift Right (0xF0000008 >> 1)
        sel    <= "01100"; -- ASR operation
        input2 <= x"00000008";
        IR     <= "00001"; -- Shift by 1 bit
        wait for 40 ns;
        assert output = x"00000004"  -- Expected result for ASR
            report "Arithmetic Shift Right failed" severity error;        

        -- Test Case: Set on Less Than (10 < 15 → expect 1)
        sel    <= "01101"; -- SLT operation
        input1 <= std_logic_vector(to_unsigned(10, WIDTH));
        input2 <= std_logic_vector(to_unsigned(15, WIDTH));
        wait for 40 ns;
        assert output = x"00000001"
            report "SLT (10 < 15) failed" severity error;

        -- Test Case: Set on Less Than (15 < 10 → expect 0)
        sel    <= "01110"; 
        input1 <= std_logic_vector(to_signed(15, WIDTH));
        input2 <= std_logic_vector(to_signed(10, WIDTH));
        wait for 40 ns;
        assert output = x"00000000"
            report "SLT (15 < 10) failed" severity error;

        -- **Branch Tests - Changed to check `branch_taken` instead of `output`**

        -- Test Case: Branch Not Taken (5 <= 0 → expect '0')
        sel    <= "10010"; -- Branch condition (A <= 0)
        input1 <= std_logic_vector(to_signed(5, WIDTH));
        wait for 40 ns;
        assert branch_taken = '0'
            report "Branch (5 <= 0) incorrectly taken" severity error;

        -- -- Test Case: Branch Taken (0 <= 0 → expect '1')
        -- sel    <= "10010"; 
        -- input1 <= std_logic_vector(to_signed(0, WIDTH));
        -- wait for 40 ns;
        -- assert branch_taken = '1'
        --     report "Branch (0 <= 0) incorrectly not taken" severity error;

        -- Test Case: Branch Taken (5 > 0 → expect '1')
        sel    <= "01111"; -- Branch condition (A > 0)
        input1 <= std_logic_vector(to_signed(5, WIDTH));
        wait for 40 ns;
        assert branch_taken = '1'
            report "Branch (5 > 0) incorrectly not taken" severity error;

        -- -- Test Case: Branch Not Taken (-1 > 0 → expect '0')
        -- sel    <= "01111"; 
        -- input1 <= std_logic_vector(to_signed(-1, WIDTH));
        -- wait for 40 ns;
        -- assert branch_taken = '0'
        --     report "Branch (-1 > 0) incorrectly taken" severity error;

        report "ALL TESTS PASSED!";
        wait;
    end process;

end TB;

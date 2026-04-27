library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.MIPS_package.all;

entity MIPS_top_level_tb is
end;

architecture bench of MIPS_top_level_tb is
    constant CLK_PERIOD : time := 5 ns;

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '0';  -- Driven by inverted button(1)
    signal switches : std_logic_vector(9 downto 0) := (others => '0');
    signal button   : std_logic_vector(1 downto 0) := "11";  -- Active-low
    signal LEDs     : std_logic_vector(DATA_WIDTH - 1 downto 0);

    -- Unused but required 7-seg bindings
    signal led0, led1, led2, led3, led4, led5 : std_logic_vector(6 downto 0);
    signal led0_dp, led1_dp, led2_dp, led3_dp, led4_dp, led5_dp : std_logic;

    -- Test values
    constant INPORT0_VAL : std_logic_vector(8 downto 0) := "000000101"; -- 0x05
    constant INPORT1_VAL : std_logic_vector(8 downto 0) := "000111111"; -- 0x1FF

begin

    -- Clock generation
    clk_proc : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    -- Reset logic (active-low via button(1))
    rst <= not button(1);

    -- DUT instantiation
    DUT : entity work.MIPS_top_level
        port map (
            clk      => clk,
            rst      => rst,
            switches => switches,
            button   => button,
            LEDs     => LEDs,
            led0     => led0,
            led0_dp  => led0_dp,
            led1     => led1,
            led1_dp  => led1_dp,
            led2     => led2,
            led2_dp  => led2_dp,
            led3     => led3,
            led3_dp  => led3_dp,
            led4     => led4,
            led4_dp  => led4_dp,
            led5     => led5,
            led5_dp  => led5_dp
        );

    -- Stimulus process
    stimulus : process
    begin
        -------------------------------------------------------
        -- Step 0: Apply reset first
        -------------------------------------------------------
        button(1) <= '0';       -- Assert reset (active-low)
        wait for 2 * CLK_PERIOD;
        button(1) <= '1';       -- Deassert reset
        wait for 2 * CLK_PERIOD;

        -------------------------------------------------------
        -- Step 1: Load INPORT0 (SW9 = '0', value = 0x05)
        -------------------------------------------------------
        switches(8 downto 0) <= INPORT0_VAL;
        switches(9)          <= '0';
        button(0)            <= '0';  -- Assert load
        wait for CLK_PERIOD;
        button(0)            <= '1';  -- Deassert
        wait for 2 * CLK_PERIOD;

        -------------------------------------------------------
        -- Step 2: Load INPORT1 (SW9 = '1', value = 0x1FF)
        -------------------------------------------------------
        switches(8 downto 0) <= INPORT1_VAL;
        switches(9)          <= '1';
        button(0)            <= '0';  -- Assert load
        wait for CLK_PERIOD;
        button(0)            <= '1';  -- Deassert
        wait for 2 * CLK_PERIOD;

        -------------------------------------------------------
        -- Step 3: Let the program run
        -------------------------------------------------------
        wait for 9000 ns;

        -------------------------------------------------------
        -- Step 4: End simulation
        -------------------------------------------------------
        assert false report "Simulation complete." severity failure;
    end process;

end bench;


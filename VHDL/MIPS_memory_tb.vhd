library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.MIPS_package.all;

entity MIPS_memory_tb is
end MIPS_memory_tb;

architecture test of MIPS_memory_tb is

    -- Testbench Signals
    signal clk        : std_logic := '0';
    signal byte_addr  : std_logic_vector(31 downto 0);
    signal data_in    : std_logic_vector(31 downto 0);
    signal write_en   : std_logic := '0';
    signal data_out   : std_logic_vector(31 downto 0);
    signal InPort0_en : std_logic := '0';
    signal InPort1_en : std_logic := '0';
    signal InPort0    : std_logic_vector(31 downto 0);
    signal InPort1    : std_logic_vector(31 downto 0);
    signal OutPort    : std_logic_vector(31 downto 0);

    -- Clock Process
    constant clk_period : time := 10 ns;
    constant k : integer := 3; -- Number of clk periods between every action
    signal stop_sim : boolean := false;

begin

    -- Instantiate MIPS_memory
    memory_inst: MIPS_memory
    port map (
        clk        => clk,
        byte_addr  => byte_addr,
        data_in    => data_in,
        write_en   => write_en,
        data_out   => data_out,
        InPort0_en => InPort0_en,
        InPort1_en => InPort1_en,
        InPort0    => InPort0,
        InPort1    => InPort1,
        OutPort    => OutPort
    );

    -- Clock Process
    process
    begin
        while not stop_sim loop
            clk <= '1';
            wait for clk_period / 2;
            clk <= '0';
            wait for clk_period / 2;
        end loop;
        wait;
    end process;

    -- Stimulus Process
    process
    begin
        -- Write 0x0A0A0A0A to address 0x00000000
        byte_addr <= x"00000000";
        data_in   <= x"0A0A0A0A";
        wait for clk_period;
        write_en  <= '1';
        wait for k*clk_period;
        write_en  <= '0';

        wait for clk_period;

        -- Write 0xF0F0F0F0 to address 0x00000004
        byte_addr <= x"00000004";
        data_in   <= x"F0F0F0F0";
        wait for clk_period;
        write_en  <= '1';
        wait for k*clk_period;
        write_en  <= '0';

        wait for clk_period;

        -- Read from address 0x00000000 (should be 0x0A0A0A0A)
        byte_addr <= x"00000000";
        wait for k*clk_period;
        assert data_out = x"0A0A0A0A"
            report "ERROR: Read from 0x00000000 incorrect!" severity warning;

        -- Read from address 0x00000001 (should be 0x0A0A0A0A)
        byte_addr <= x"00000001";
        wait for k*clk_period;
        assert data_out = x"0A0A0A0A"
            report "ERROR: Read from 0x00000001 incorrect!" severity warning;

        -- Read from address 0x00000004 (should be 0xF0F0F0F0)
        byte_addr <= x"00000004";
        wait for k*clk_period;
        assert data_out = x"F0F0F0F0"
            report "ERROR: Read from 0x00000004 incorrect!" severity warning;

        -- Read from address 0x00000005 (should be 0xF0F0F0F0)
        byte_addr <= x"00000005";
        wait for k*clk_period;
        assert data_out = x"F0F0F0F0"
            report "ERROR: Read from 0x00000005 incorrect!" severity warning;

        -- Write 0x00001111 to the OutPort
        byte_addr <= x"FFFFFFFF";  -- Assuming this address is for OutPort
        data_in  <= x"00001111";
        write_en <= '1';
        wait for k*clk_period;
        write_en <= '0';
        assert OutPort = x"00001111"
            report "ERROR: OutPort did not receive 0x00001111!" severity warning;

        -- Load 0x00010000 into InPort0
        InPort0    <= x"00010000";
        InPort0_en <= '1';
        wait for k*clk_period;
        InPort0_en <= '0';

        -- Load 0x00000001 into InPort1
        InPort1    <= x"00000001";
        InPort1_en <= '1';
        wait for k*clk_period;
        InPort1_en <= '0';

        -- Read from InPort0 (should be 0x00010000)
        byte_addr <= x"00000400";  -- Assuming address for InPort0
        wait for k*clk_period;
        assert data_out = x"00010000"
            report "ERROR: Read from InPort0 incorrect!" severity warning;

        -- Read from InPort1 (should be 0x00000001)
        byte_addr <= x"00000404";  -- Assuming address for InPort1
        wait for k*clk_period;
        assert data_out = x"00000001"
            report "ERROR: Read from InPort1 incorrect!" severity warning;

        -- End simulation
        report "Simulation Complete!" severity note;
        stop_sim <= true;
        wait;

    end process;

end test;

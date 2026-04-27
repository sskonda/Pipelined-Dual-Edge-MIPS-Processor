
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.MIPS_package.all;

entity MIPS_memory is
    port(
        clk        : in  std_logic;
        byte_addr  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        data_in    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        write_en   : in  std_logic;
        data_out   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        -- I/O ports
        InPort0_en : in  std_logic;
        InPort1_en : in  std_logic;
        InPort0    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        InPort1    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        OutPort    : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity;

architecture Behavioral of MIPS_memory is

    signal w_RAM_addr     : std_logic_vector(7 downto 0);
    signal w_RAM_data_out : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal r_data_out     : std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Input registers
    signal r_InPort0 : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal r_InPort1 : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal r_OutPort : std_logic_vector(DATA_WIDTH-1 downto 0);

    signal w_data_sel      : std_logic_vector(1 downto 0);
    signal w_ram_write     : std_logic;
    signal w_outport_write : std_logic;

    constant ADDR_INPORT0 : std_logic_vector(15 downto 0) := x"FFF8";
    constant ADDR_OUTPORT : std_logic_vector(15 downto 0) := x"FFFC";
    constant ADDR_INPORT1 : std_logic_vector(15 downto 0) := x"FFFA";


begin

    -- RAM instance
    ram_inst : RAM
    port map (
        address => w_RAM_addr,
        clock   => clk,
        data    => data_in,
        wren    => w_ram_write,
        q       => w_RAM_data_out
    );

    -- Address mapping
    w_RAM_addr <= byte_addr(9 downto 2);
    OutPort <= r_OutPort;

    -- Control Logic
    process(byte_addr, write_en)
    begin
        w_ram_write     <= '0';
        w_outport_write <= '0';
        w_data_sel      <= "10"; -- default to RAM

        if byte_addr(15 downto 0) = ADDR_INPORT0 then
            if write_en = '0' then
                w_data_sel <= "00"; -- read from InPort0
            end if;

        elsif byte_addr(15 downto 0) = ADDR_INPORT1 then
            if write_en = '0' then
                w_data_sel <= "01"; -- read from InPort1
            end if;

        elsif byte_addr(15 downto 0) = ADDR_OUTPORT then
            if write_en = '1' then
                w_outport_write <= '1'; -- write to OutPort
            end if;

        else
            if write_en = '1' then
                w_ram_write <= '1';
            end if;
        end if;
    end process;


    -- Sequential register logic
    process(clk)
    begin
        if rising_edge(clk) then
            -- capture inputs
            if InPort0_en = '1' then
                r_InPort0 <= InPort0;
            end if;
            if InPort1_en = '1' then
                r_InPort1 <= InPort1;
            end if;
            if w_outport_write = '1' then
                r_OutPort <= data_in;
            end if;

            -- select read output
            case w_data_sel is
                when "00" => r_data_out <= r_InPort0;
                when "01" => r_data_out <= r_InPort1;
                when others => r_data_out <= w_RAM_data_out;
            end case;
        end if;
    end process;

    data_out <= r_data_out;

end Behavioral;


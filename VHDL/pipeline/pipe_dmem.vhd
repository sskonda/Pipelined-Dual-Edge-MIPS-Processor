-- =============================================================================
-- pipe_dmem.vhd  –  Data memory with memory-mapped I/O for the pipeline.
--
-- VHDL equivalent of SV/pipeline/pipe_dmem.sv.
-- Asynchronous reads (combinatorial), synchronous writes.
-- Memory map: 0xFFF8=InPort0, 0xFFFA=InPort1, 0xFFFC=OutPort, other=RAM.
-- mem_ready is always '1' (single-cycle memory, no structural stall).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.MIPS_package.all;

entity pipe_dmem is
  port (
    clk       : in  std_logic;
    byte_addr : in  std_logic_vector(31 downto 0);
    wr_data   : in  std_logic_vector(31 downto 0);
    mem_read  : in  std_logic;
    mem_write : in  std_logic;
    rd_data   : out std_logic_vector(31 downto 0);
    mem_ready : out std_logic;  -- always '1'
    in_port0  : in  std_logic_vector(31 downto 0);
    in_port1  : in  std_logic_vector(31 downto 0);
    out_port  : out std_logic_vector(31 downto 0)
  );
end pipe_dmem;

architecture Behavioral of pipe_dmem is

  constant ADDR_INPORT0 : std_logic_vector(15 downto 0) := x"FFF8";
  constant ADDR_INPORT1 : std_logic_vector(15 downto 0) := x"FFFA";
  constant ADDR_OUTPORT : std_logic_vector(15 downto 0) := x"FFFC";

  type mem_array is array(0 to 255) of std_logic_vector(31 downto 0);
  signal ram       : mem_array := (others => (others => '0'));
  signal r_out_port: std_logic_vector(31 downto 0) := (others => '0');

  signal word_addr  : integer range 0 to 255;
  signal is_in0, is_in1, is_out : std_logic;

begin

  word_addr <= to_integer(unsigned(byte_addr(9 downto 2)));
  is_in0    <= '1' when byte_addr(15 downto 0) = ADDR_INPORT0 else '0';
  is_in1    <= '1' when byte_addr(15 downto 0) = ADDR_INPORT1 else '0';
  is_out    <= '1' when byte_addr(15 downto 0) = ADDR_OUTPORT  else '0';

  mem_ready <= '1';
  out_port  <= r_out_port;

  -- Synchronous writes
  process(clk)
  begin
    if rising_edge(clk) then
      if mem_write = '1' then
        if is_out = '1' then
          r_out_port <= wr_data;
        elsif is_in0 = '0' and is_in1 = '0' then
          ram(word_addr) <= wr_data;
        end if;
      end if;
    end if;
  end process;

  -- Asynchronous reads
  process(byte_addr, is_in0, is_in1, is_out, in_port0, in_port1,
          r_out_port, ram, word_addr)
  begin
    if is_in0 = '1' then
      rd_data <= in_port0;
    elsif is_in1 = '1' then
      rd_data <= in_port1;
    elsif is_out = '1' then
      rd_data <= r_out_port;
    else
      rd_data <= ram(word_addr);
    end if;
  end process;

end Behavioral;

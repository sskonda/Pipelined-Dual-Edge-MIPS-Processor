-- =============================================================================
-- pipe_regfile.vhd  –  32×32-bit register file with asynchronous reads.
--
-- VHDL equivalent of SV/pipeline/pipe_regfile.sv.
-- Asynchronous reads: combinational process sensitive to all inputs.
-- Write-before-read: if wr_addr == rd_addr0/1 and wr_en, return wr_data.
-- $0 is hardwired to zero (writes silently ignored, reads return 0).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pipe_regfile is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    -- Write port (WB stage)
    wr_addr  : in  std_logic_vector(4 downto 0);
    wr_en    : in  std_logic;
    wr_data  : in  std_logic_vector(31 downto 0);
    -- Read ports (ID stage, combinatorial)
    rd_addr0 : in  std_logic_vector(4 downto 0);
    rd_addr1 : in  std_logic_vector(4 downto 0);
    rd_data0 : out std_logic_vector(31 downto 0);
    rd_data1 : out std_logic_vector(31 downto 0)
  );
end pipe_regfile;

architecture Behavioral of pipe_regfile is

  type reg_array is array(0 to 31) of std_logic_vector(31 downto 0);
  signal regs : reg_array := (others => (others => '0'));

begin

  -- Synchronous write ($0 writes discarded)
  process(clk, rst)
  begin
    if rst = '1' then
      regs <= (others => (others => '0'));
    elsif rising_edge(clk) then
      if wr_en = '1' and wr_addr /= "00000" then
        regs(to_integer(unsigned(wr_addr))) <= wr_data;
      end if;
    end if;
  end process;

  -- Asynchronous read with write-before-read forwarding
  process(rd_addr0, rd_addr1, wr_addr, wr_en, wr_data, regs)
  begin
    -- Port 0 (rs)
    if rd_addr0 = "00000" then
      rd_data0 <= (others => '0');
    elsif wr_en = '1' and wr_addr = rd_addr0 then
      rd_data0 <= wr_data;  -- WB→ID bypass
    else
      rd_data0 <= regs(to_integer(unsigned(rd_addr0)));
    end if;

    -- Port 1 (rt)
    if rd_addr1 = "00000" then
      rd_data1 <= (others => '0');
    elsif wr_en = '1' and wr_addr = rd_addr1 then
      rd_data1 <= wr_data;  -- WB→ID bypass
    else
      rd_data1 <= regs(to_integer(unsigned(rd_addr1)));
    end if;
  end process;

end Behavioral;

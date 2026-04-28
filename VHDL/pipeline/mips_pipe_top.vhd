-- =============================================================================
-- mips_pipe_top.vhd  –  Top-level wrapper for the 5-stage pipelined MIPS CPU.
--
-- Preserves the same external interface as MIPS_top_level.vhd so the two
-- implementations are drop-in compatible at the board level.
--
-- Internal change: uses mips_pipeline (5-stage pipeline with hazard
-- protection and ready/valid) instead of the multi-cycle FSM.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.MIPS_package.all;

entity mips_pipe_top is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    switches : in  std_logic_vector(9 downto 0);
    button   : in  std_logic_vector(1 downto 0);
    LEDs     : out std_logic_vector(31 downto 0);   -- OutPort (0xFFFC)
    led0     : out std_logic_vector(6 downto 0);
    led0_dp  : out std_logic;
    led1     : out std_logic_vector(6 downto 0);
    led1_dp  : out std_logic;
    led2     : out std_logic_vector(6 downto 0);
    led2_dp  : out std_logic;
    led3     : out std_logic_vector(6 downto 0);
    led3_dp  : out std_logic;
    led4     : out std_logic_vector(6 downto 0);
    led4_dp  : out std_logic;
    led5     : out std_logic_vector(6 downto 0);
    led5_dp  : out std_logic
  );
end mips_pipe_top;

architecture Structural of mips_pipe_top is

  signal out_port : std_logic_vector(31 downto 0);

begin

  pipeline : entity work.mips_pipeline
    port map (
      clk       => clk,
      rst       => rst,
      switches  => switches,
      button    => button,
      out_port  => out_port,
      dbg_pc    => open,
      dbg_instr => open
    );

  LEDs <= out_port;

  -- 7-segment display: lower 24 bits of OutPort decoded into 6 hex digits
  u_led0 : entity work.decoder7seg
    port map (input => out_port(3 downto 0),   output => led0);
  u_led1 : entity work.decoder7seg
    port map (input => out_port(7 downto 4),   output => led1);
  u_led2 : entity work.decoder7seg
    port map (input => out_port(11 downto 8),  output => led2);
  u_led3 : entity work.decoder7seg
    port map (input => out_port(15 downto 12), output => led3);
  u_led4 : entity work.decoder7seg
    port map (input => out_port(19 downto 16), output => led4);
  u_led5 : entity work.decoder7seg
    port map (input => out_port(23 downto 20), output => led5);

  led0_dp <= '1';
  led1_dp <= '1';
  led2_dp <= '1';
  led3_dp <= '1';
  led4_dp <= '1';
  led5_dp <= '1';

end Structural;

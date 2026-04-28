-- MIPS Full-System Testbench – 6 instruction-group checks
--
-- Checks OutPort (mapped to LEDs) after each program phase:
--
--  Check 1  addiu/addu/subu/and/or/sll + beq (taken)  -> OutPort = 15
--  Check 2  ori / xori                                 -> OutPort =  2
--  Check 3  srl / slti                                 -> OutPort =  1
--  Check 4  bne (taken)                                -> OutPort =  5
--  Check 5  mult / mflo                                -> OutPort = 50
--  Check 6  lw / sw round-trip                         -> OutPort = 77
--
-- Timing (5 ns clock, 2-cycle reset, 1 INIT cycle):
--   Phase 1 sw fires at ~242 ns  -> check at 280 ns
--   Phase 2 sw fires at ~322 ns  -> check at 360 ns
--   Phase 3 sw fires at ~402 ns  -> check at 440 ns
--   Phase 4 sw fires at ~462 ns  -> check at 500 ns
--   Phase 5 sw fires at ~547 ns  -> check at 590 ns
--   Phase 6 sw fires at ~667 ns  -> check at 720 ns  (lw is now 7 cycles)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.MIPS_package.all;

entity MIPS_full_tb is
end entity;

architecture bench of MIPS_full_tb is

    constant CLK_PERIOD : time := 5 ns;

    signal clk     : std_logic := '0';
    signal rst     : std_logic := '1';
    signal switches : std_logic_vector(9 downto 0) := (others => '0');
    signal button   : std_logic_vector(1 downto 0) := "11";
    signal LEDs     : std_logic_vector(DATA_WIDTH - 1 downto 0);

    signal led0, led1, led2, led3, led4, led5 : std_logic_vector(6 downto 0);
    signal led0_dp, led1_dp, led2_dp, led3_dp, led4_dp, led5_dp : std_logic;

    procedure check_leds(
        signal   observed : in std_logic_vector(31 downto 0);
        constant expected : in std_logic_vector(31 downto 0);
        constant tag      : in string) is
    begin
        if observed = expected then
            report "[PASS] " & tag &
                   " -> 0x" & to_hstring(observed) severity note;
        else
            report "[FAIL] " & tag &
                   " expected=0x" & to_hstring(expected) &
                   " got=0x"      & to_hstring(observed) severity error;
        end if;
    end procedure;

begin

    clk_proc : process
    begin
        loop
            clk <= '0'; wait for CLK_PERIOD / 2;
            clk <= '1'; wait for CLK_PERIOD / 2;
        end loop;
    end process;

    DUT : entity work.MIPS_top_level
        port map (
            clk      => clk,
            rst      => rst,
            switches => switches,
            button   => button,
            LEDs     => LEDs,
            led0 => led0, led0_dp => led0_dp,
            led1 => led1, led1_dp => led1_dp,
            led2 => led2, led2_dp => led2_dp,
            led3 => led3, led3_dp => led3_dp,
            led4 => led4, led4_dp => led4_dp,
            led5 => led5, led5_dp => led5_dp
        );

    stimulus : process
    begin
        -- --------------------------------------------------------
        -- Reset: 2 clock cycles (10 ns)
        -- --------------------------------------------------------
        rst <= '1';
        wait for 2 * CLK_PERIOD;
        rst <= '0';
        report "[INFO] Reset released - program executing." severity note;

        -- --------------------------------------------------------
        -- CHECK 1: addiu/addu/subu/and/or/sll + beq (taken)
        --   $3 = 5 + 10 = 15.  Word-8 (addiu $8,$0,99) must be SKIPPED.
        --   OutPort = 15  (beq $1,$4 branches because $1=$4=5)
        -- --------------------------------------------------------
        -- Phase 1: ~242 ns. Check at 280 ns (Phase 2 will overwrite at ~322 ns)
        wait for 270 ns;         -- 10 + 270 = 280 ns total
        check_leds(LEDs, x"0000000F", "Phase1 addu+beq: OutPort=15");

        if LEDs = x"00000063" then
            report "[FAIL] beq NOT taken - word 8 was not skipped" severity error;
        end if;

        -- --------------------------------------------------------
        -- CHECK 2: ori / xori  -> OutPort = 2
        -- --------------------------------------------------------
        -- Phase 2 sw at ~322 ns. Check at 360 ns (Phase 3 overwrites at ~402 ns)
        wait for 80 ns;          -- 360 ns total
        check_leds(LEDs, x"00000002", "Phase2 xori: OutPort=2");

        -- --------------------------------------------------------
        -- CHECK 3: srl / slti  -> OutPort = 1
        -- --------------------------------------------------------
        -- Phase 3 sw at ~402 ns. Check at 440 ns (Phase 4 overwrites at ~462 ns)
        wait for 80 ns;          -- 440 ns total
        check_leds(LEDs, x"00000001", "Phase3 srl+slti: OutPort=1");

        -- --------------------------------------------------------
        -- CHECK 4: bne (taken) -> OutPort = 5
        -- --------------------------------------------------------
        -- Phase 4 sw at ~462 ns. Check at 500 ns (Phase 5 overwrites at ~547 ns)
        wait for 60 ns;          -- 500 ns total
        check_leds(LEDs, x"00000005", "Phase4 bne: OutPort=5");

        -- --------------------------------------------------------
        -- CHECK 5: mult / mflo -> OutPort = 50
        -- --------------------------------------------------------
        -- Phase 5 sw at ~547 ns. Check at 590 ns (Phase 6 overwrites at ~667 ns)
        wait for 90 ns;          -- 590 ns total
        check_leds(LEDs, x"00000032", "Phase5 mult+mflo: OutPort=50");

        -- --------------------------------------------------------
        -- CHECK 6: lw / sw round-trip -> OutPort = 77
        --   addiu $17,$0,77 | sw $17,0x80($0) | lw $18,0x80($0) | sw $18,-4($0)
        --   lw now takes 7 cycles (LW_wait2 removed, data latency fixed)
        -- --------------------------------------------------------
        -- Phase 6 sw at ~667 ns. Check at 720 ns (loop j0 restarts at ~697 ns)
        wait for 130 ns;         -- 720 ns total
        check_leds(LEDs, x"0000004D", "Phase6 lw/sw round-trip: OutPort=77");

        -- --------------------------------------------------------
        -- Loop check: second pass through Phase 6 -> still 77
        -- --------------------------------------------------------
        -- Second loop Phase 6 sw at ~667+660=1327 ns. Check at 1370 ns.
        wait for 650 ns;         -- 1370 ns total
        check_leds(LEDs, x"0000004D",
                   "Loop2 Phase6: OutPort=77 stable on second iteration");

        -- --------------------------------------------------------
        -- Final report
        -- --------------------------------------------------------
        report "==================================================" severity note;
        report "  Simulation complete - review [PASS]/[FAIL] above" severity note;
        report "==================================================" severity note;

        wait;
    end process;

end bench;

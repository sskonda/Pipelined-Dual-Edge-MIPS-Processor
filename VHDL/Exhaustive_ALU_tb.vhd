library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Exhaustive_ALU_tb is
end entity;

architecture TB of Exhaustive_ALU_tb is

  component MIPS_ALU
    generic (
      WIDTH : positive := 8 -- Reduce to 8 bits for exhaustive testing
    );
    port (
      input1       : in std_logic_vector(WIDTH - 1 downto 0);
      input2       : in std_logic_vector(WIDTH - 1 downto 0);
      IR           : in std_logic_vector(4 downto 0);
      sel          : in std_logic_vector(4 downto 0);
      output       : out std_logic_vector(WIDTH - 1 downto 0);
      output_High  : out std_logic_vector(WIDTH - 1 downto 0);
      branch_taken : out std_logic
    );
  end component;

  -- Constants & Signals
  constant WIDTH      : positive                             := 8;
  signal input1       : std_logic_vector(WIDTH - 1 downto 0) := (others => '0');
  signal input2       : std_logic_vector(WIDTH - 1 downto 0) := (others => '0');
  signal IR           : std_logic_vector(4 downto 0)         := (others => '0');
  signal sel          : std_logic_vector(4 downto 0)         := (others => '0');
  signal output       : std_logic_vector(WIDTH - 1 downto 0);
  signal output_High  : std_logic_vector(WIDTH - 1 downto 0);
  signal branch_taken : std_logic;

begin

  -- Instantiate ALU
  UUT : MIPS_ALU
  generic map(WIDTH => WIDTH)
  port map
  (
    input1       => input1,
    input2       => input2,
    IR           => IR,
    sel          => sel,
    output       => output,
    output_High  => output_High,
    branch_taken => branch_taken
  );

  -- **Exhaustive Testing Process**
  process
    variable expected_output : std_logic_vector(WIDTH - 1 downto 0);
    variable expected_branch : std_logic;
  begin
    for sel_value in 0 to 31 loop -- Iterate over all ALU operations
      sel <= std_logic_vector(to_unsigned(sel_value, 5));
      for input1_value in 0 to 255 loop -- Iterate over all 8-bit values for input1
        input1 <= std_logic_vector(to_unsigned(input1_value, WIDTH));
        for input2_value in 0 to 255 loop -- Iterate over all 8-bit values for input2
          input2 <= std_logic_vector(to_unsigned(input2_value, WIDTH));

          -- Wait for ALU to process
          wait for 10 ns;

          -- Compute expected result based on ALU sel
          case sel_value is
            when 0  => expected_output  := std_logic_vector(to_unsigned(input1_value + input2_value, WIDTH)); -- ADD
            when 2  => expected_output  := std_logic_vector(to_unsigned(input1_value - input2_value, WIDTH)); -- SUB
            when 4  => expected_output  := std_logic_vector(to_signed(input1_value, WIDTH) * to_signed(input2_value, WIDTH)); -- Signed MUL
            when 5  => expected_output  := std_logic_vector(to_unsigned(input1_value * input2_value, WIDTH)); -- Unsigned MUL
            when 6  => expected_output  := std_logic_vector(unsigned(input1) and unsigned(input2)); -- AND
            when 7  => expected_output  := std_logic_vector(unsigned(input1) or unsigned(input2)); -- OR
            when 8  => expected_output  := std_logic_vector(unsigned(input1) xor unsigned(input2)); -- XOR
            when 10 => expected_output := std_logic_vector(shift_right(unsigned(input1), to_integer(unsigned(input2)))); -- Logical Shift Right
            when 12 => expected_output := std_logic_vector(shift_right(signed(input1), to_integer(unsigned(input2)))); -- Arithmetic Shift Right
            when 13 => -- SLT (Set Less Than)
              if signed(input1) < signed(input2) then
                expected_output := x"01";
              else
                expected_output := x"00";
              end if;
            when 14 => -- SLTU (Set Less Than Unsigned)
              if unsigned(input1) < unsigned(input2) then
                expected_output := x"01";
              else
                expected_output := x"00";
              end if;
            when 16 => expected_output := std_logic_vector(not (unsigned(input1) or unsigned(input2))); -- NOR
            when 18 => -- Branch if Less Than or Equal
              if signed(input1) <= signed(input2) then
                expected_branch := '1';
              else
                expected_branch := '0';
              end if;
            when others                =>
              expected_output := (others => '0'); -- Default case
          end case;

          -- Assertions for ALU outputs
          assert output = expected_output
          report "ALU Mismatch! SEL=" & integer'image(sel_value) &
            " input1=" & integer'image(input1_value) &
            " input2=" & integer'image(input2_value) &
            " Expected=" & integer'image(to_integer(unsigned(expected_output))) &
            " Got=" & integer'image(to_integer(unsigned(output)))
            severity error;
          -- Branch assertions
          if sel = "10010" then -- Only check branch_taken for branch operations
            assert branch_taken = expected_branch
            report "Branch Condition Mismatch! input1=" & integer'image(input1_value) &
              " input2=" & integer'image(input2_value) &
              " Expected=" & std_logic'image(expected_branch) &
              " Got=" & std_logic'image(branch_taken)
              severity error;

          end if;
        end loop;
      end loop;
    end loop;

    report "ALL TESTS PASSED!";
    wait;
  end process;

end TB;

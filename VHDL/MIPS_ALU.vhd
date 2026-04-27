library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MIPS_alu is
  generic (WIDTH : positive := 32);
  port (
    input1       : in std_logic_vector(WIDTH - 1 downto 0);
    input2       : in std_logic_vector(WIDTH - 1 downto 0);
    IR           : in std_logic_vector(4 downto 0);
    sel          : in std_logic_vector(4 downto 0);
    output       : out std_logic_vector(WIDTH - 1 downto 0);
    output_High  : out std_logic_vector(WIDTH - 1 downto 0);
    branch_taken : out std_logic
  );
end MIPS_alu;

architecture Ricotta of MIPS_alu is
begin
  process (input1, input2, sel, IR)

    -- Signed arithmetic operations
    variable in1    : signed(WIDTH - 1 downto 0);
    variable in2    : signed(WIDTH - 1 downto 0);
    variable result : signed(WIDTH - 1 downto 0);
    variable prod   : signed(2 * WIDTH - 1 downto 0);

    -- Unsigned arithmetic operations
    variable uin1    : unsigned(WIDTH - 1 downto 0);
    variable uin2    : unsigned(WIDTH - 1 downto 0);
    variable uresult : unsigned(WIDTH - 1 downto 0);
    variable uprod   : unsigned(2 * WIDTH - 1 downto 0);

    variable temp_output : std_logic_vector(WIDTH - 1 downto 0);

  begin
    -- Convert std_logic_vector to signed and unsigned
    in1  := signed(input1);
    in2  := signed(input2);
    uin1 := unsigned(input1);
    uin2 := unsigned(input2);

    -- Default assignments
    result  := (others => '0');
    uresult := (others => '0');
    temp_output := (others => '0');
    branch_taken <= '0';
    output_High  <= (others => '0');

    -- ALU operation based on the sel input
    case sel is
      when "00000" => -- A + B (unsigned)
        uresult := uin1 + uin2;
        temp_output := std_logic_vector(uresult);

      when "00001" => -- A + B (signed)
        result := in1 + in2;
        temp_output := std_logic_vector(result);

      when "00010" => -- A - B (unsigned)
        uresult := uin1 - uin2;
        temp_output := std_logic_vector(uresult);

      when "00011" => -- A - B (signed)
        result := in1 - in2;
        temp_output := std_logic_vector(result);

      when "00100" => -- A * B (unsigned)
        uprod := uin1 * uin2;
        output_High <= std_logic_vector(uprod(2 * WIDTH - 1 downto WIDTH)); -- Upper bits
        temp_output := std_logic_vector(uprod(WIDTH - 1 downto 0));

      when "00101" => -- A * B (signed)
        prod := in1 * in2;
        output_High <= std_logic_vector(prod(2 * WIDTH - 1 downto WIDTH)); -- Upper bits
        temp_output := std_logic_vector(prod(WIDTH - 1 downto 0));

      when "00110" => -- A AND B
        uresult := uin1 and uin2;
        temp_output := std_logic_vector(uresult);

      when "00111" => -- A OR B
        uresult := uin1 or uin2;
        temp_output := std_logic_vector(uresult);

      when "01000" => -- A XOR B
        uresult := uin1 xor uin2;
        temp_output := std_logic_vector(uresult);

      when "01001" => -- NOT A
        uresult := not uin1;
        temp_output := std_logic_vector(uresult);

      when "01010" => -- Logical Shift Right (SRL B by IR)
        uresult := shift_right(uin2, to_integer(unsigned(IR))); -- Shift B
        temp_output := std_logic_vector(uresult);

      when "01011" => -- Logical Shift Left (SLL B by IR)
        uresult := shift_left(uin2, to_integer(unsigned(IR))); -- Shift B
        temp_output := std_logic_vector(uresult);

      when "01100" => -- Arithmetic Shift Right (SRA B by IR)
        result := shift_right(in2, to_integer(unsigned(IR))); -- Shift B
        temp_output := std_logic_vector(result);

      when "01101" => -- Compare A < B (unsigned)
        if uin1 < uin2 then
          temp_output := (0 => '1', others => '0'); -- Set LSB to 1
        else
          temp_output := (others => '0');
        end if;

      when "01110" => -- Compare A < B (signed)
        if in1 < in2 then
          result    := (others => '0');
          result(0) := '1'; -- Set LSB to 1 if A < B
        else
          result := (others => '0');
        end if;
        temp_output := std_logic_vector(result);

      when "01111" => -- Compare A > 0 (signed)
        if in1 > 0 then
          branch_taken <= '1'; -- Set branch_taken if A > 0
        else
          branch_taken <= '0';
        end if;

      when "10000" => -- Compare A = 0 (signed)
        if in1 = 0 then
          branch_taken <= '1'; -- Set branch_taken if A = 0
        else
          branch_taken <= '0';
        end if;

      when "10001" => -- Compare A >= 0 (signed)
        if in1 >= 0 then
          branch_taken <= '1'; -- Set branch_taken if A >= 0
        else
          branch_taken <= '0';
        end if;

      when "10010" => -- Compare A <= 0 (signed)
        if in1 <= 0 then
          branch_taken <= '1'; -- Set branch_taken if A <= 0
        else
          branch_taken <= '0';
        end if;
      
          when "10011" => -- ALU_A_eq_B
        if in1 = in2 then
          branch_taken <= '1';
        else
          branch_taken <= '0';
        end if;

      when "10100" => -- ALU_A_ne_B
        if in1 /= in2 then
          branch_taken <= '1';
        else
          branch_taken <= '0';
        end if;

      when "10101" => -- ALU_A_lt_0
        if in1 < 0 then
          branch_taken <= '1';
        else
          branch_taken <= '0';
        end if;

      when "10110" => -- ALU_PASS_A_BRANCH
        temp_output := input1;

      When "10111" => -- ALU_PASS_B_BRANCH
        temp_output := input2;

      when "11111" => -- ALU_NOP
        temp_output := (others => '0'); -- No computation
        output_High <= (others => '0');
        branch_taken <= '0';

      when others => -- Default case, output 0
        -- temp_output := (others => '0');
        -- output_High  <= (others => '0');
        -- branch_taken <= '0'; -- Reset branch_taken signal
        null;

    end case;

    -- Assign temp_output to output at the end of the process
    output <= temp_output;

  end process;
end Ricotta;

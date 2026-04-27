
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.MIPS_package.all;

entity ALU_controller is
  port (
    IR        : in std_logic_vector(5 downto 0);  -- funct or rt
    ALU_Op    : in std_logic_vector(1 downto 0);  -- control signal from FSM (2-bit ALUOp)
    OPSelect  : out std_logic_vector(4 downto 0); -- to ALU
    LO_en     : out std_logic;
    HI_en     : out std_logic;
    ALU_LO_HI : out std_logic_vector(1 downto 0)
  );
end entity;

architecture Mozzarella of ALU_controller is
begin
  process(IR, ALU_Op)
  begin
    -- Default values
    OPSelect   <= ALU_NOP;
    ALU_LO_HI  <= "00";
    LO_en      <= '0';
    HI_en      <= '0';

    if ALU_Op = "00" then
      -- Used for LW/SW or PC + 4 (unsigned add)
      OPSelect <= ALU_ADD_unsign;

    elsif ALU_Op = "01" then
      -- Used for BEQ/BNE (signed sub)
      OPSelect <= ALU_SUB_sign;

    elsif ALU_Op = "10" then
      -- R-type: decode funct field
      case IR is
        when R_FUNC_ADDU  => OPSelect <= ALU_ADD_unsign;
        when R_FUNC_SUBU  => OPSelect <= ALU_SUB_unsign;
        when R_FUNC_AND   => OPSelect <= ALU_AND;
        when R_FUNC_OR    => OPSelect <= ALU_OR;
        when R_FUNC_XOR   => OPSelect <= ALU_XOR;
        when R_FUNC_SLT   => OPSelect <= ALU_comp_A_lt_B_sign;
        when R_FUNC_SLTU  => OPSelect <= ALU_comp_A_lt_B_unsign;
        when R_FUNC_SLL   => OPSelect <= ALU_LOG_SHIFT_L;
        when R_FUNC_SRL   => OPSelect <= ALU_LOG_SHIFT_R;
        when R_FUNC_SRA   => OPSelect <= ALU_ARITH_SHIFT_R;
        when R_FUNC_MULT  =>
          OPSelect <= ALU_mult_sign;
          LO_en    <= '1';
          HI_en    <= '1';
        when R_FUNC_MULTU =>
          OPSelect <= ALU_mult_unsign;
          LO_en    <= '1';
          HI_en    <= '1';
        when R_FUNC_MFHI =>
          OPSelect  <= ALU_NOP;
          ALU_LO_HI <= "10";
        when R_FUNC_MFLO =>
          OPSelect  <= ALU_NOP;
          ALU_LO_HI <= "01";
        when R_FUNC_JR =>
          OPSelect  <= ALU_PASS_A_BRANCH;
        when others =>
          OPSelect <= ALU_NOP;
      end case;

    else -- ALU_Op = "11" → non-R-type opcode decoding (I-type, branches)
      case IR is
        -- I-type arithmetic
        when I_ADDIU  => OPSelect <= ALU_ADD_unsign;
        when I_SUBIU  => OPSelect <= ALU_SUB_unsign;
        when I_ANDI   => OPSelect <= ALU_AND;
        when I_ORI    => OPSelect <= ALU_OR;
        when I_XORI   => OPSelect <= ALU_XOR;
        when I_SLTI   => OPSelect <= ALU_comp_A_lt_B_sign;
        when I_SLTIU  => OPSelect <= ALU_comp_A_lt_B_unsign;

        -- Branch instructions
        when I_BEQ    => OPSelect <= ALU_A_eq_B;
        when I_BNE    => OPSelect <= ALU_A_ne_B;
        when I_BLEZ   => OPSelect <= ALU_lteq_0;
        when I_BGTZ   => OPSelect <= ALU_A_gt_0;

        -- REGIMM-style
        when I_REGIMM =>
          if IR(IR'low) = '0' then -- bltz
            OPSelect <= ALU_A_lt_0;
          else -- bgez
            OPSelect <= ALU_gteq_0;
          end if;

        when others =>
          OPSelect <= ALU_NOP;
      end case;
    end if;
  end process;
end Mozzarella;


-- architecture Mozzarella of ALU_controller is
-- begin
--   process(IR, ALU_Op)
--   begin
--     -- Default values
--     OPSelect   <= ALU_NOP;
--     ALU_LO_HI  <= "00";
--     LO_en      <= '0';
--     HI_en      <= '0';

--     case ALU_Op is

--       -- 000: LW/SW or PC + 4 (unsigned add)
--       when "000" =>
--         OPSelect <= ALU_ADD_unsign;

--       -- 001: Branch logic (signed sub)
--       when "001" =>
--         OPSelect <= ALU_SUB_sign;

--       -- 010: R-type (decode funct)
--       when "010" =>
--         case IR is
--           when R_FUNC_ADDU  => OPSelect <= ALU_ADD_unsign;
--           when R_FUNC_SUBU  => OPSelect <= ALU_SUB_unsign;
--           when R_FUNC_AND   => OPSelect <= ALU_AND;
--           when R_FUNC_OR    => OPSelect <= ALU_OR;
--           when R_FUNC_XOR   => OPSelect <= ALU_XOR;
--           when R_FUNC_SLT   => OPSelect <= ALU_comp_A_lt_B_sign;
--           when R_FUNC_SLTU  => OPSelect <= ALU_comp_A_lt_B_unsign;
--           when R_FUNC_SLL   => OPSelect <= ALU_LOG_SHIFT_L;
--           when R_FUNC_SRL   => OPSelect <= ALU_LOG_SHIFT_R;
--           when R_FUNC_SRA   => OPSelect <= ALU_ARITH_SHIFT_R;

--           when R_FUNC_MULT =>
--             OPSelect <= ALU_mult_sign;
--             LO_en    <= '1';
--             HI_en    <= '1';

--           when R_FUNC_MULTU =>
--             OPSelect <= ALU_mult_unsign;
--             LO_en    <= '1';
--             HI_en    <= '1';

--           when R_FUNC_MFHI =>
--             OPSelect  <= ALU_NOP;
--             ALU_LO_HI <= "10";

--           when R_FUNC_MFLO =>
--             OPSelect  <= ALU_NOP;
--             ALU_LO_HI <= "01";

--           when R_FUNC_JR =>
--             OPSelect  <= ALU_PASS_A_BRANCH;

--           when others =>
--             OPSelect <= ALU_NOP;
--         end case;

--       -- 011: I-type / branch (decode opcode)
--       when "011" =>
--         case IR is
--           when I_ADDIU  => OPSelect <= ALU_ADD_unsign;
--           when I_SUBIU  => OPSelect <= ALU_SUB_unsign;
--           when I_ANDI   => OPSelect <= ALU_AND;
--           when I_ORI    => OPSelect <= ALU_OR;
--           when I_XORI   => OPSelect <= ALU_XOR;
--           when I_SLTI   => OPSelect <= ALU_comp_A_lt_B_sign;
--           when I_SLTIU  => OPSelect <= ALU_comp_A_lt_B_unsign;

--           when I_BEQ    => OPSelect <= ALU_A_eq_B;
--           when I_BNE    => OPSelect <= ALU_A_ne_B;
--           when I_BLEZ   => OPSelect <= ALU_lteq_0;
--           when I_BGTZ   => OPSelect <= ALU_A_gt_0;

--           when I_REGIMM =>
--             if IR(IR'low) = '0' then
--               OPSelect <= ALU_A_lt_0;
--             else
--               OPSelect <= ALU_gteq_0;
--             end if;

--           when others =>
--             OPSelect <= ALU_NOP;
--         end case;

--       -- 100: Explicit Pass-A
--       when "100" =>
--         OPSelect <= ALU_PASS_A_BRANCH;

--       -- 101: Explicit Pass-B
--       when "101" =>
--         OPSelect <= ALU_PASS_B_BRANCH;

--       -- 110 or 111: Reserved for future, default to NOP
--       when others =>
--         OPSelect <= ALU_NOP;

--     end case;
--   end process;
-- end Mozzarella;


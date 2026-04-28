library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- We use your MIPS_package for opcode constants:
use work.MIPS_package.all;

entity MIPS_ctrl is
    port (
        clk     : in  std_logic;
        reset   : in  std_logic;

        -- From IR
        opcode  : in  std_logic_vector(5 downto 0); -- IR(31:26)
        funct   : in  std_logic_vector(5 downto 0); -- IR(5:0)

        -- Control signals to datapath
        PC_writeCond : out std_logic;
        PC_write     : out std_logic;
        IorD         : out std_logic;
        Mem_Read     : out std_logic;
        Mem_Write    : out std_logic;
        Mem_ToReg    : out std_logic;
        IRWrite      : out std_logic;
        JumpAndLink  : out std_logic;
        IsSigned     : out std_logic;
        PC_Source    : out std_logic_vector(1 downto 0);
        --ALU_Op       : out std_logic_vector(5 downto 0);
        ALU_Op       : out std_logic_vector(1 downto 0);
        ALU_SrcB     : out std_logic_vector(1 downto 0);
        ALU_SrcA     : out std_logic;
        Reg_Write    : out std_logic;
        Reg_Dst      : out std_logic
    );
end MIPS_ctrl;

-- architecture Behavioral of MIPS_ctrl is 

--     type state_type is (
--         INIT, ADDITIONAL_MEM_WAIT, INST_FETCH, STORE_IN_IR_WAIT,
--         DECODE_REG_FETCH, LW_SW, LW_1, LW_wait, LW_2, LW_wait2, SW,
--         RTYPE_1, RTYPE_2, RTYPE_MF,
--         ALU_IMM_1, ALU_IMM_2,
--         BRANCH_CALC, BRANCH_EXEC, BRANCH_WAIT,
--         JUMP, JAL_SAVE, JAL_JUMP -- dded new states
--     );

--     signal cur_state, next_state : state_type := INIT;

-- begin

--     process(clk, reset)
--     begin
--         if reset = '1' then
--             cur_state <= INIT;
--         elsif rising_edge(clk) then
--             cur_state <= next_state;
--         end if;
--     end process;

--     -- FSM TRANSITIONS
--     process(cur_state, opcode, funct)
--     begin
--         next_state <= cur_state;
--         case cur_state is
--             when INIT => next_state <= INST_FETCH;
--             when INST_FETCH => next_state <= STORE_IN_IR_WAIT;
--             when STORE_IN_IR_WAIT => next_state <= DECODE_REG_FETCH;

--             when DECODE_REG_FETCH =>
--                 case opcode is
--                     when R_OP => next_state <= RTYPE_1;
--                     when J_JAL => next_state <= JAL_SAVE; -- route to JAL SAVE
--                     when J_JUMP => next_state <= JUMP;
--                     when I_ADDIU | I_SUBIU | I_ANDI | I_ORI | I_XORI | I_SLTI | I_SLTIU =>
--                         next_state <= ALU_IMM_1;
--                     when "100011" | "101011" =>
--                         next_state <= LW_SW;
--                     when I_BEQ | I_BNE | I_BLEZ | I_BGTZ | I_REGIMM =>
--                         next_state <= BRANCH_CALC;
--                     when others =>
--                         next_state <= INST_FETCH;
--                 end case;

--             when LW_SW => if opcode = "100011" then next_state <= LW_1; else next_state <= SW; end if;
--             when LW_1 => next_state <= LW_wait;
--             when LW_wait => next_state <= LW_wait2;
--             when LW_wait2 => next_state <= LW_2;
--             when LW_2 => next_state <= INST_FETCH;
--             when SW => next_state <= ADDITIONAL_MEM_WAIT;
--             when ADDITIONAL_MEM_WAIT => next_state <= INST_FETCH;
--             when RTYPE_1 => next_state <= RTYPE_2;
--             when RTYPE_2 =>
--                 if funct = R_FUNC_MFLO or funct = R_FUNC_MFHI then
--                     next_state <= RTYPE_MF;
--                 else
--                     next_state <= INST_FETCH;
--                 end if;
--             when RTYPE_MF => next_state <= INST_FETCH;
--             when ALU_IMM_1 => next_state <= ALU_IMM_2;
--             when ALU_IMM_2 => next_state <= INST_FETCH;
--             when BRANCH_CALC => next_state <= BRANCH_EXEC;
--             when BRANCH_EXEC => next_state <= BRANCH_WAIT;
--             when BRANCH_WAIT => next_state <= INST_FETCH;
--             when JUMP => next_state <= ADDITIONAL_MEM_WAIT;
--             when JAL_SAVE => next_state <= JAL_JUMP; -- go to jump state next
--             when JAL_JUMP => next_state <= INST_FETCH;
--             when others => next_state <= INST_FETCH;
--         end case;
--     end process;

--     -- FSM OUTPUTS
--     process(cur_state)
--     begin
--         -- defaults
--         PC_writeCond <= '0';
--         PC_write     <= '0';
--         IorD         <= '0';
--         Mem_Read     <= '0';
--         Mem_Write    <= '0';
--         Mem_ToReg    <= '0';
--         IRWrite      <= '0';
--         JumpAndLink  <= '0';
--         IsSigned     <= '0';
--         PC_Source    <= "00";
--         ALU_Op       <= ALUOp_nonr;
--         ALU_SrcB     <= "00";
--         ALU_SrcA     <= '0';
--         Reg_Write    <= '0';
--         Reg_Dst      <= '0';

--         case cur_state is
--             when INST_FETCH =>
--                 Mem_Read   <= '1';
--                 IRWrite    <= '1';
--                 ALU_SrcA   <= '0';
--                 ALU_SrcB   <= "01";
--                 ALU_Op     <= ALUOp_addu;
--                 PC_write   <= '1'; 
--                 PC_Source  <= "00";

--             when STORE_IN_IR_WAIT =>
--                 IRWrite <= '1';

--             when DECODE_REG_FETCH =>
--                 ALU_SrcA <= '0';
--                 ALU_SrcB <= "11";
--                 ALU_Op   <= ALUOp_adds;

--             when LW_SW =>
--                 ALU_SrcA <= '1';
--                 ALU_SrcB <= "10";
--                 ALU_Op   <= ALUOp_addu;
--                 IsSigned <= '1';
--                 IorD     <= '1';

--             when LW_1 =>
--                 Mem_Read <= '1';
--                 IorD     <= '1';

--             when LW_wait =>
--                 Mem_Read <= '1';

--             when LW_2 =>
--                 Reg_Write <= '1';
--                 Reg_Dst   <= '0';
--                 Mem_ToReg <= '1';

--             when SW =>
--                 IorD      <= '1';
--                 Mem_Write <= '1';

--             when RTYPE_1 =>
--                 ALU_SrcA <= '1';
--                 ALU_SrcB <= "00";
--                 ALU_Op   <= ALUOp_rtype;

--             when RTYPE_2 =>
--                 Reg_Write <= '1';
--                 Reg_Dst   <= '1';
--                 Mem_ToReg <= '0';
--                 ALU_Op    <= ALUOp_nonr;

--             when RTYPE_MF =>
--                 Reg_Write <= '1';
--                 Reg_Dst   <= '1';
--                 Mem_ToReg <= '0';
--                 ALU_Op    <= ALUOp_rtype;

--             when ALU_IMM_1 =>
--                 ALU_SrcA <= '1';
--                 ALU_SrcB <= "10";
--                 ALU_Op   <= "011";

--             when ALU_IMM_2 =>
--                 Reg_Write <= '1';
--                 Reg_Dst   <= '0';
--                 Mem_ToReg <= '0';

--             when BRANCH_CALC =>
--                 ALU_SrcA  <= '0';
--                 ALU_SrcB  <= "11";
--                 ALU_Op    <= ALUOp_addu;

--             when BRANCH_EXEC =>
--                 ALU_SrcA     <= '1';
--                 ALU_SrcB     <= "00";
--                 ALU_Op       <= ALUOp_nonr;
--                 PC_writeCond <= '1';
--                 PC_Source    <= "01";

--             when JUMP =>
--                 PC_write  <= '1';
--                 PC_Source <= "10";
--                 --ALU_Op    <= ALUOp_passA;

            
--             when JAL_SAVE =>
--                 --JumpAndLink <= '1';
--                 --Mem_ToReg   <= '0'; -- select PC+4
--                 ALU_Op      <= ALUOp_passA; -- ALU operation to calculate PC+4
--                 -- Reg_Write <= '1'; -- write to regfile
--                 -- No Reg_Write = '1' needed, it's handled inside regfile

--             --NEW STATE: Actually perform the jump
--             when JAL_JUMP =>
--                 PC_write  <= '1';
--                 PC_Source <= "10";
--                 JumpAndLink <= '1';
--                 Mem_ToReg   <= '0'; -- select PC+4
--                 Reg_Write <= '1'; 
--                 ALU_SrcB <= "11"; -- ALU operation to calculate PC+4
--                 ALU_Op <= ALUOp_passB;

--             when others => null;
--         end case;
--     end process;

-- end Behavioral;

architecture Behavioral of MIPS_ctrl is 

    type state_type is (
        INIT, ADDITIONAL_MEM_WAIT, INST_FETCH, STORE_IN_IR_WAIT,
        DECODE_REG_FETCH, LW_SW, LW_1, LW_wait, LW_2, SW,
        RTYPE_1, RTYPE_2, RTYPE_MF,
        ALU_IMM_1, ALU_IMM_2,
        BRANCH_CALC, BRANCH_EXEC, BRANCH_WAIT, JUMP
    );


    signal cur_state, next_state : state_type := INIT;

begin

    process(clk, reset)
    begin
        if reset = '1' then
            cur_state <= INIT;
        elsif rising_edge(clk) then
            cur_state <= next_state;
        end if;
    end process;

    process(cur_state, opcode, funct)
    begin
        next_state <= cur_state;
        case cur_state is
            when INIT => next_state <= INST_FETCH;
            when INST_FETCH => next_state <= STORE_IN_IR_WAIT;
            when STORE_IN_IR_WAIT => next_state <= DECODE_REG_FETCH;
            when DECODE_REG_FETCH =>
                case opcode is
                    when R_OP => next_state <= RTYPE_1;
                    when I_ADDIU | I_SUBIU | I_ANDI | I_ORI | I_XORI | I_SLTI | I_SLTIU =>
                        next_state <= ALU_IMM_1;
                    when "100011" | "101011" =>
                        next_state <= LW_SW;
                    when I_BEQ | I_BNE | I_BLEZ | I_BGTZ | I_REGIMM =>
                        next_state <= BRANCH_CALC;
                    when J_JUMP | J_JAL =>
                        next_state <= JUMP;
                    when others =>
                        next_state <= INST_FETCH;
                end case;

            when LW_SW       => if opcode = "100011" then next_state <= LW_1; else next_state <= SW; end if;
            when LW_1        => next_state <= LW_wait;
            when LW_wait     => next_state <= LW_2;
            when LW_2        => next_state <= INST_FETCH;
            when SW          => next_state <= ADDITIONAL_MEM_WAIT;
            when ADDITIONAL_MEM_WAIT => next_state <= INST_FETCH;
            when RTYPE_1     => next_state <= RTYPE_2;
            when RTYPE_2  =>
            -- Branch to separate state for mfhi/mflo
            if funct = R_FUNC_MFLO or funct = R_FUNC_MFHI then
                next_state <= RTYPE_MF;
            else
                next_state <= INST_FETCH;
            end if;
            when RTYPE_MF    => next_state <= INST_FETCH;
            when ALU_IMM_1   => next_state <= ALU_IMM_2;
            when ALU_IMM_2   => next_state <= INST_FETCH;
            --when BRANCH      => next_state <= ADDITIONAL_MEM_WAIT;
            when BRANCH_CALC => next_state <= BRANCH_EXEC;
            when BRANCH_EXEC => next_state <= BRANCh_WAIT;
            when BRANCH_WAIT => next_state <= INST_FETCH;
            when JUMP        => next_state <= ADDITIONAL_MEM_WAIT;
            when others      => next_state <= INST_FETCH;
        end case;
    end process;

    process(cur_state, opcode)
    begin
        -- defaults
        PC_writeCond <= '0';
        PC_write     <= '0';
        IorD         <= '0';
        Mem_Read     <= '0';
        Mem_Write    <= '0';
        Mem_ToReg    <= '0';
        IRWrite      <= '0';
        JumpAndLink  <= '0';
        IsSigned     <= '0';
        PC_Source    <= "00";
        ALU_Op       <= ALUOp_nonr;
        ALU_SrcB     <= "00";
        ALU_SrcA     <= '0';
        Reg_Write    <= '0';
        Reg_Dst      <= '0';

        case cur_state is

            when INST_FETCH =>
                Mem_Read   <= '1';
                IRWrite    <= '1';
                ALU_SrcA   <= '0';
                ALU_SrcB   <= "01";
                --ALU_Op     <= I_ADDIU;
                ALU_Op <= ALUOp_addu;
                PC_write   <= '1'; 
                PC_Source  <= "00";

            when STORE_IN_IR_WAIT =>
                IRWrite <= '1';

                null;  -- no control signals needed

            when DECODE_REG_FETCH =>
                ALU_SrcA <= '0';
                ALU_SrcB <= "11";
                --ALU_Op   <= ALU_OP_NOP;
                ALU_Op <= ALUOp_adds;

            when LW_SW =>
                ALU_SrcA <= '1';
                ALU_SrcB <= "10";
                --ALU_Op   <= I_ADDIU;
                ALU_Op <= ALUOp_addu;
                IsSigned <= '1';
                IorD     <= '1';

            when LW_1 =>
                Mem_Read <= '1';
                IorD     <= '1';

            when LW_wait =>
                Mem_Read <= '1';
                null;  -- No control signals needed, just wait for memory to finish
                -- IorD can remain default since memory already addressed
                -- No control signals needed, just wait for memory to finish

            when LW_2 =>
                Reg_Write <= '1';
                Reg_Dst   <= '0';
                Mem_ToReg <= '1';

            when SW =>
                IorD      <= '1';
                Mem_Write <= '1';

            when ADDITIONAL_MEM_WAIT =>
                --Mem_Write <= '1';  -- crucial fix
                -- IorD can remain default since memory already addressed

            when RTYPE_1 =>
                ALU_SrcA <= '1';
                ALU_SrcB <= "00";
                --ALU_Op   <= ALU_OP_RTYPE;
                ALU_Op <= ALUOp_rtype;

            when RTYPE_2 =>
                Reg_Write <= '1';
                Reg_Dst   <= '1';
                Mem_ToReg <= '0';
                ALU_Op <= ALUOp_nonr;

            when RTYPE_MF =>
                Reg_Write <= '1';
                Reg_Dst   <= '1';
                Mem_ToReg <= '0'; -- Selects ALU_selected_out, which now contains HI/LO via mux_3x1
                ALU_Op    <= ALUOp_rtype;

            when ALU_IMM_1 =>
                ALU_SrcA <= '1';
                ALU_SrcB <= "10";
                --ALU_Op   <= ALU_OP_IMM;
                ALU_Op   <= "11";

            when ALU_IMM_2 =>
                Reg_Write <= '1';
                Reg_Dst   <= '0';
                Mem_ToReg <= '0';

            when BRANCH_CALC =>
                -- Calculate target: PC + offset
                ALU_SrcA  <= '0';     -- use PC
                ALU_SrcB  <= "11";    -- use shift-left-2(sign-ext(immediate))
                ALU_Op    <= ALUOp_addu;
                --PC_Source <= "01";    -- candidate PC update from ALU_result

            when BRANCH_EXEC =>
                ALU_SrcA     <= '1';  -- register comparison
                ALU_SrcB     <= "00"; -- register
                ALU_Op       <= ALUOp_nonr;
                PC_writeCond <= '1';
                PC_Source <= "01";

            when BRANCH_WAIT =>
                -- No control signals needed, just wait for memory to finish
                null;  -- No control signals needed, just wait for memory to finish

            when JUMP =>
                PC_write     <= '1';
                PC_Source    <= "10";
                if opcode = J_JAL then
                    JumpAndLink <= '1';
                end if;

            when others => null;
        end case;
    end process;

end Behavioral;


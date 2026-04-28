-- =============================================================================
-- mips_pipeline.vhd  –  5-stage pipelined MIPS CPU (VHDL)
--
--  Stage  Function
--  ─────  ──────────────────────────────────────────────────────────────────
--   IF    Fetch instruction from IMEM at PC, compute PC+4
--   ID    Decode instruction, read register file, sign-extend immediate,
--          generate all control signals for downstream stages
--   EX    Execute ALU op, resolve branch/jump, apply forwarding
--   MEM   Data-memory read (LW) or write (SW), pass-through for others
--   WB    Write result back to register file, update HI/LO
--
-- VHDL equivalent of SV/pipeline/mips_pipeline.sv.
-- Requires VHDL-2008 (process(all) sensitivity syntax).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.MIPS_package.all;
use work.pipe_pkg.all;

entity mips_pipeline is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    switches : in  std_logic_vector(9 downto 0);
    button   : in  std_logic_vector(1 downto 0);
    out_port : out std_logic_vector(31 downto 0);
    dbg_pc   : out std_logic_vector(31 downto 0);
    dbg_instr: out std_logic_vector(31 downto 0)
  );
end mips_pipeline;

architecture Behavioral of mips_pipeline is

  -- ── PC ─────────────────────────────────────────────────────────────────────
  signal pc_reg      : std_logic_vector(31 downto 0) := (others => '0');
  signal pc_next     : std_logic_vector(31 downto 0);
  signal if_pc_plus4 : std_logic_vector(31 downto 0);

  -- ── IF stage ───────────────────────────────────────────────────────────────
  signal if_instr    : std_logic_vector(31 downto 0);

  -- ── Pipeline registers ─────────────────────────────────────────────────────
  signal if_id_reg  : if_id_t  := IF_ID_NOP;
  signal id_ex_reg  : id_ex_t  := ID_EX_NOP;
  signal ex_mem_reg : ex_mem_t := EX_MEM_NOP;
  signal mem_wb_reg : mem_wb_t := MEM_WB_NOP;

  -- ── HI / LO registers (written in WB, read in ID) ─────────────────────────
  signal HI_reg : std_logic_vector(31 downto 0) := (others => '0');
  signal LO_reg : std_logic_vector(31 downto 0) := (others => '0');

  -- ── Hazard / stall / flush ─────────────────────────────────────────────────
  signal stall_if    : std_logic;
  signal stall_id    : std_logic;
  signal bubble_ex   : std_logic;
  signal flush_if_id : std_logic;
  signal flush_id_ex : std_logic;

  -- ── Forwarding mux selects ─────────────────────────────────────────────────
  signal fwd_a : std_logic_vector(1 downto 0);
  signal fwd_b : std_logic_vector(1 downto 0);

  -- ── ID stage decode outputs (feeds ID/EX register) ────────────────────────
  signal id_alu_op      : std_logic_vector(4 downto 0);
  signal id_alu_src_b   : std_logic;
  signal id_alu_lo_hi   : std_logic_vector(1 downto 0);
  signal id_hi_write    : std_logic;
  signal id_lo_write    : std_logic;
  signal id_mem_read    : std_logic;
  signal id_mem_write   : std_logic;
  signal id_reg_write   : std_logic;
  signal id_mem_to_reg  : std_logic;
  signal id_branch      : std_logic;
  signal id_branch_type : std_logic_vector(2 downto 0);
  signal id_jump        : std_logic;
  signal id_jump_reg    : std_logic;
  signal id_is_jal      : std_logic;
  signal id_imm32       : std_logic_vector(31 downto 0);
  signal id_rs          : std_logic_vector(4 downto 0);
  signal id_rt          : std_logic_vector(4 downto 0);
  signal id_rd          : std_logic_vector(4 downto 0);
  signal id_shamt       : std_logic_vector(4 downto 0);
  signal id_rs_data     : std_logic_vector(31 downto 0); -- after HI/LO mux

  -- ── Register-file raw read ports ──────────────────────────────────────────
  signal rf_rs_data : std_logic_vector(31 downto 0);
  signal rf_rt_data : std_logic_vector(31 downto 0);

  -- ── EX stage results (captured into EX/MEM register) ─────────────────────
  signal ex_alu_result    : std_logic_vector(31 downto 0);
  signal ex_alu_result_hi : std_logic_vector(31 downto 0);
  signal ex_rt_fwd        : std_logic_vector(31 downto 0);
  signal ex_take_branch   : std_logic;
  signal ex_take_jump     : std_logic;
  signal ex_pc_target     : std_logic_vector(31 downto 0);

  -- ── MEM stage ──────────────────────────────────────────────────────────────
  signal mem_rd_data : std_logic_vector(31 downto 0);

  -- ── WB stage wires ─────────────────────────────────────────────────────────
  signal wb_wr_addr : std_logic_vector(4 downto 0);
  signal wb_wr_data : std_logic_vector(31 downto 0);
  signal wb_wr_en   : std_logic;

  -- ── I/O port construction ──────────────────────────────────────────────────
  signal in_port0 : std_logic_vector(31 downto 0);
  signal in_port1 : std_logic_vector(31 downto 0);

begin

  -- ===========================================================================
  -- I/O and sub-module instantiation
  -- ===========================================================================

  in_port0 <= "00000000000000000000000" & switches(8 downto 0);
  in_port1 <= "00000000000000000000000" & switches(8 downto 0);

  imem : entity work.pipe_imem
    port map (
      addr  => pc_reg(9 downto 2),
      instr => if_instr
    );

  dmem : entity work.pipe_dmem
    port map (
      clk       => clk,
      byte_addr => ex_mem_reg.alu_result,
      wr_data   => ex_mem_reg.rt_fwd,
      mem_read  => ex_mem_reg.mem_read  and ex_mem_reg.valid,
      mem_write => ex_mem_reg.mem_write and ex_mem_reg.valid,
      rd_data   => mem_rd_data,
      mem_ready => open,
      in_port0  => in_port0,
      in_port1  => in_port1,
      out_port  => out_port
    );

  rf : entity work.pipe_regfile
    port map (
      clk      => clk,
      rst      => rst,
      wr_addr  => wb_wr_addr,
      wr_en    => wb_wr_en,
      wr_data  => wb_wr_data,
      rd_addr0 => if_id_reg.instr(25 downto 21),
      rd_addr1 => if_id_reg.instr(20 downto 16),
      rd_data0 => rf_rs_data,
      rd_data1 => rf_rt_data
    );

  -- ===========================================================================
  -- WB stage — combinatorial write-back signals fed back to register file
  -- ===========================================================================

  wb_wr_addr <= mem_wb_reg.rd;
  wb_wr_en   <= mem_wb_reg.reg_write and mem_wb_reg.valid;
  wb_wr_data <= mem_wb_reg.wr_data;

  -- ===========================================================================
  -- HI / LO registers (written at end of WB)
  -- ===========================================================================

  process (clk, rst)
  begin
    if rst = '1' then
      HI_reg <= (others => '0');
      LO_reg <= (others => '0');
    elsif rising_edge(clk) then
      if mem_wb_reg.hi_write = '1' and mem_wb_reg.valid = '1' then
        HI_reg <= mem_wb_reg.wr_data_hi;
      end if;
      if mem_wb_reg.lo_write = '1' and mem_wb_reg.valid = '1' then
        LO_reg <= mem_wb_reg.wr_data;
      end if;
    end if;
  end process;

  -- ===========================================================================
  -- ID stage — instruction decode and control generation (combinatorial)
  -- Variables are used for is_signed/use_hi/use_lo because they are set
  -- earlier in the case statement and read at the end of the same process.
  -- ===========================================================================

  process (all)
    variable v_is_signed : std_logic;
    variable v_use_hi    : std_logic;
    variable v_use_lo    : std_logic;
  begin
    -- Defaults (safe / inactive)
    id_alu_op      <= ALU_NOP;
    id_alu_src_b   <= '0';
    id_alu_lo_hi   <= "00";
    id_hi_write    <= '0';
    id_lo_write    <= '0';
    id_mem_read    <= '0';
    id_mem_write   <= '0';
    id_reg_write   <= '0';
    id_mem_to_reg  <= '0';
    id_branch      <= '0';
    id_branch_type <= BR_BEQ;
    id_jump        <= '0';
    id_jump_reg    <= '0';
    id_is_jal      <= '0';
    id_rs          <= if_id_reg.instr(25 downto 21);
    id_rt          <= if_id_reg.instr(20 downto 16);
    id_rd          <= if_id_reg.instr(15 downto 11);
    id_shamt       <= if_id_reg.instr(10 downto 6);

    v_is_signed := '1';    -- default: sign-extend immediate
    v_use_hi    := '0';
    v_use_lo    := '0';

    case if_id_reg.instr(31 downto 26) is

      -- ── R-type (opcode = 0) ────────────────────────────────────────────────
      when R_OP =>
        id_rd <= if_id_reg.instr(15 downto 11);
        case if_id_reg.instr(5 downto 0) is
          when R_FUNC_ADDU  => id_alu_op <= ALU_ADD_unsign;          id_reg_write <= '1';
          when R_FUNC_SUBU  => id_alu_op <= ALU_SUB_unsign;          id_reg_write <= '1';
          when R_FUNC_AND   => id_alu_op <= ALU_AND;                  id_reg_write <= '1';
          when R_FUNC_OR    => id_alu_op <= ALU_OR;                   id_reg_write <= '1';
          when R_FUNC_XOR   => id_alu_op <= ALU_XOR;                  id_reg_write <= '1';
          when R_FUNC_SLT   => id_alu_op <= ALU_comp_A_lt_B_sign;    id_reg_write <= '1';
          when R_FUNC_SLTU  => id_alu_op <= ALU_comp_A_lt_B_unsign;  id_reg_write <= '1';
          when R_FUNC_SLL   => id_alu_op <= ALU_LOG_SHIFT_L;         id_reg_write <= '1';
          when R_FUNC_SRL   => id_alu_op <= ALU_LOG_SHIFT_R;         id_reg_write <= '1';
          when R_FUNC_SRA   => id_alu_op <= ALU_ARITH_SHIFT_R;       id_reg_write <= '1';
          when R_FUNC_MULT  =>
            id_alu_op   <= ALU_mult_sign;
            id_hi_write <= '1';
            id_lo_write <= '1';
          when R_FUNC_MULTU =>
            id_alu_op   <= ALU_mult_unsign;
            id_hi_write <= '1';
            id_lo_write <= '1';
          when R_FUNC_MFHI  =>
            id_alu_op    <= ALU_PASS_A_BRANCH;
            id_reg_write <= '1';
            v_use_hi     := '1';
          when R_FUNC_MFLO  =>
            id_alu_op    <= ALU_PASS_A_BRANCH;
            id_reg_write <= '1';
            v_use_lo     := '1';
          when R_FUNC_JR    =>
            id_jump     <= '1';
            id_jump_reg <= '1';
          when others => null;
        end case;

      -- ── I-type arithmetic / logical ────────────────────────────────────────
      when I_ADDIU =>
        id_alu_op <= ALU_ADD_unsign;  id_alu_src_b <= '1';
        v_is_signed := '1';           id_reg_write <= '1';
        id_rd       <= if_id_reg.instr(20 downto 16);

      when I_ANDI =>
        id_alu_op <= ALU_AND;   id_alu_src_b <= '1';
        v_is_signed := '0';     id_reg_write <= '1';
        id_rd       <= if_id_reg.instr(20 downto 16);

      when I_ORI =>
        id_alu_op <= ALU_OR;    id_alu_src_b <= '1';
        v_is_signed := '0';     id_reg_write <= '1';
        id_rd       <= if_id_reg.instr(20 downto 16);

      when I_XORI =>
        id_alu_op <= ALU_XOR;   id_alu_src_b <= '1';
        v_is_signed := '0';     id_reg_write <= '1';
        id_rd       <= if_id_reg.instr(20 downto 16);

      when I_SLTI =>
        id_alu_op <= ALU_comp_A_lt_B_sign;  id_alu_src_b <= '1';
        v_is_signed := '1';                  id_reg_write <= '1';
        id_rd       <= if_id_reg.instr(20 downto 16);

      when I_SLTIU =>
        id_alu_op <= ALU_comp_A_lt_B_unsign;  id_alu_src_b <= '1';
        v_is_signed := '0';                    id_reg_write <= '1';
        id_rd       <= if_id_reg.instr(20 downto 16);

      when I_SUBIU =>
        id_alu_op <= ALU_SUB_unsign;  id_alu_src_b <= '1';
        v_is_signed := '1';           id_reg_write <= '1';
        id_rd       <= if_id_reg.instr(20 downto 16);

      -- ── Load / Store ───────────────────────────────────────────────────────
      when "100011" =>  -- LW
        id_alu_op    <= ALU_ADD_unsign;  id_alu_src_b  <= '1';
        v_is_signed  := '1';             id_mem_read   <= '1';
        id_reg_write <= '1';             id_mem_to_reg <= '1';
        id_rd        <= if_id_reg.instr(20 downto 16);

      when "101011" =>  -- SW
        id_alu_op   <= ALU_ADD_unsign;  id_alu_src_b <= '1';
        v_is_signed := '1';             id_mem_write <= '1';

      -- ── Branches (comparison done by ALU in EX, 2-cycle flush penalty) ─────
      when I_BEQ =>
        id_branch <= '1';  id_branch_type <= BR_BEQ;
        id_alu_op <= ALU_A_eq_B;  v_is_signed := '1';

      when I_BNE =>
        id_branch <= '1';  id_branch_type <= BR_BNE;
        id_alu_op <= ALU_A_ne_B;  v_is_signed := '1';

      when I_BLEZ =>
        id_branch <= '1';  id_branch_type <= BR_BLEZ;
        id_alu_op <= ALU_lteq_0;  v_is_signed := '1';

      when I_BGTZ =>
        id_branch <= '1';  id_branch_type <= BR_BGTZ;
        id_alu_op <= ALU_A_gt_0;  v_is_signed := '1';

      when I_REGIMM =>   -- bltz (rt=0) / bgez (rt=1)
        id_branch   <= '1';  v_is_signed := '1';
        if if_id_reg.instr(20 downto 16) = "00000" then
          id_alu_op <= ALU_A_lt_0;  id_branch_type <= BR_BLTZ;
        else
          id_alu_op <= ALU_gteq_0;  id_branch_type <= BR_BGEZ;
        end if;

      -- ── Jumps ──────────────────────────────────────────────────────────────
      when J_JUMP =>
        id_jump <= '1';

      when J_JAL =>
        id_jump      <= '1';  id_is_jal    <= '1';
        id_reg_write <= '1';  id_rd        <= "11111";  -- $ra = $31

      when others => null;
    end case;

    -- Sign / zero-extend immediate (using variable for sign flag)
    if v_is_signed = '1' then
      id_imm32 <= std_logic_vector(resize(signed(if_id_reg.instr(15 downto 0)), 32));
    else
      id_imm32 <= std_logic_vector(resize(unsigned(if_id_reg.instr(15 downto 0)), 32));
    end if;

    -- HI / LO override for mfhi / mflo (uses variable to read same-cycle result)
    if v_use_hi = '1' then
      id_rs_data <= HI_reg;
    elsif v_use_lo = '1' then
      id_rs_data <= LO_reg;
    else
      id_rs_data <= rf_rs_data;
    end if;
  end process;

  -- ===========================================================================
  -- Hazard detection unit (combinatorial)
  -- Priority: branch/jump flush  >  load-use stall  >  mult stall
  -- ===========================================================================

  process (all)
  begin
    stall_if    <= '0';
    stall_id    <= '0';
    bubble_ex   <= '0';
    flush_if_id <= '0';
    flush_id_ex <= '0';

    -- Load-use stall: EX stage is a load whose destination matches an ID source
    if id_ex_reg.mem_read = '1' and id_ex_reg.valid = '1' and
       id_ex_reg.rd /= "00000" and
       (id_ex_reg.rd = if_id_reg.instr(25 downto 21) or
        id_ex_reg.rd = if_id_reg.instr(20 downto 16)) then
      stall_if  <= '1';
      stall_id  <= '1';
      bubble_ex <= '1';
    end if;

    -- mult → mfhi/mflo stall: mult/multu in EX, mfhi/mflo being decoded in ID
    if id_ex_reg.valid = '1' and
       (id_ex_reg.hi_write = '1' or id_ex_reg.lo_write = '1') and
       if_id_reg.valid = '1' and
       if_id_reg.instr(31 downto 26) = R_OP and
       (if_id_reg.instr(5 downto 0) = R_FUNC_MFHI or
        if_id_reg.instr(5 downto 0) = R_FUNC_MFLO) then
      stall_if  <= '1';
      stall_id  <= '1';
      bubble_ex <= '1';
    end if;

    -- Branch/jump flush: discard wrong-path instructions in IF and ID
    if ex_mem_reg.valid = '1' and
       (ex_mem_reg.take_branch = '1' or ex_mem_reg.take_jump = '1') then
      flush_if_id <= '1';
      flush_id_ex <= '1';
      stall_if    <= '0';   -- override any active load-use stall
      stall_id    <= '0';
      bubble_ex   <= '0';
    end if;
  end process;

  -- ===========================================================================
  -- Forwarding unit (combinatorial)
  -- EX/MEM takes priority over MEM/WB; $0 is never forwarded.
  -- ===========================================================================

  process (all)
  begin
    fwd_a <= FWD_ID;
    fwd_b <= FWD_ID;

    -- Forward to input A (rs)
    if ex_mem_reg.valid = '1' and ex_mem_reg.reg_write = '1' and
       ex_mem_reg.rd /= "00000" and ex_mem_reg.rd = id_ex_reg.rs then
      fwd_a <= FWD_EXM;
    elsif mem_wb_reg.valid = '1' and mem_wb_reg.reg_write = '1' and
          mem_wb_reg.rd /= "00000" and mem_wb_reg.rd = id_ex_reg.rs then
      fwd_a <= FWD_MWB;
    end if;

    -- Forward to input B (rt)
    if ex_mem_reg.valid = '1' and ex_mem_reg.reg_write = '1' and
       ex_mem_reg.rd /= "00000" and ex_mem_reg.rd = id_ex_reg.rt then
      fwd_b <= FWD_EXM;
    elsif mem_wb_reg.valid = '1' and mem_wb_reg.reg_write = '1' and
          mem_wb_reg.rd /= "00000" and mem_wb_reg.rd = id_ex_reg.rt then
      fwd_b <= FWD_MWB;
    end if;
  end process;

  -- ===========================================================================
  -- EX stage — forwarding muxes, ALU, branch/jump resolution (combinatorial)
  --
  -- All intermediate values are process variables so that same-process reads
  -- reflect the values computed in this activation (not the previous one).
  -- ===========================================================================

  process (all)
    variable v_alu_a         : std_logic_vector(31 downto 0);
    variable v_rt_fwd        : std_logic_vector(31 downto 0);
    variable v_alu_b         : std_logic_vector(31 downto 0);
    variable v_result        : std_logic_vector(31 downto 0);
    variable v_result_hi     : std_logic_vector(31 downto 0);
    variable v_branch_taken  : std_logic;
    variable v_take_branch   : std_logic;
    variable v_take_jump     : std_logic;
    variable v_branch_target : std_logic_vector(31 downto 0);
    variable v_jump_target   : std_logic_vector(31 downto 0);
    variable v_jr_target     : std_logic_vector(31 downto 0);
    variable v_pc_target     : std_logic_vector(31 downto 0);
    variable s_prod          : signed(63 downto 0);
    variable u_prod          : unsigned(63 downto 0);
  begin
    -- Initialise all variables to safe defaults
    v_result        := (others => '0');
    v_result_hi     := (others => '0');
    v_branch_taken  := '0';
    v_take_branch   := '0';
    v_take_jump     := '0';
    v_branch_target := (others => '0');
    v_jump_target   := (others => '0');
    v_jr_target     := (others => '0');
    v_pc_target     := (others => '0');

    -- ── Forwarding mux A (rs) ────────────────────────────────────────────────
    case fwd_a is
      when FWD_EXM => v_alu_a := ex_mem_reg.alu_result;
      when FWD_MWB => v_alu_a := mem_wb_reg.wr_data;
      when others  => v_alu_a := id_ex_reg.rs_data;
    end case;

    -- ── Forwarding mux B (rt, register operand) ──────────────────────────────
    case fwd_b is
      when FWD_EXM => v_rt_fwd := ex_mem_reg.alu_result;
      when FWD_MWB => v_rt_fwd := mem_wb_reg.wr_data;
      when others  => v_rt_fwd := id_ex_reg.rt_data;
    end case;

    -- ── ALU input B: forwarded register or sign-extended immediate ────────────
    if id_ex_reg.alu_src_b = '1' then
      v_alu_b := id_ex_reg.imm32;
    else
      v_alu_b := v_rt_fwd;
    end if;

    -- ── Signed / unsigned 64-bit products (32-bit * 32-bit = 64-bit) ─────────
    s_prod := signed(v_alu_a)   * signed(v_alu_b);
    u_prod := unsigned(v_alu_a) * unsigned(v_alu_b);

    -- ── ALU operation ─────────────────────────────────────────────────────────
    case id_ex_reg.alu_op is
      when ALU_ADD_unsign =>
        v_result := std_logic_vector(unsigned(v_alu_a) + unsigned(v_alu_b));
      when ALU_ADD_sign =>
        v_result := std_logic_vector(signed(v_alu_a) + signed(v_alu_b));
      when ALU_SUB_unsign =>
        v_result := std_logic_vector(unsigned(v_alu_a) - unsigned(v_alu_b));
      when ALU_SUB_sign =>
        v_result := std_logic_vector(signed(v_alu_a) - signed(v_alu_b));
      when ALU_mult_sign =>
        v_result    := std_logic_vector(s_prod(31 downto 0));
        v_result_hi := std_logic_vector(s_prod(63 downto 32));
      when ALU_mult_unsign =>
        v_result    := std_logic_vector(u_prod(31 downto 0));
        v_result_hi := std_logic_vector(u_prod(63 downto 32));
      when ALU_AND => v_result := v_alu_a and v_alu_b;
      when ALU_OR  => v_result := v_alu_a or  v_alu_b;
      when ALU_XOR => v_result := v_alu_a xor v_alu_b;
      when ALU_NOT_A => v_result := not v_alu_a;
      when ALU_LOG_SHIFT_R =>
        v_result := std_logic_vector(
          shift_right(unsigned(v_alu_b), to_integer(unsigned(id_ex_reg.shamt))));
      when ALU_LOG_SHIFT_L =>
        v_result := std_logic_vector(
          shift_left(unsigned(v_alu_b), to_integer(unsigned(id_ex_reg.shamt))));
      when ALU_ARITH_SHIFT_R =>
        v_result := std_logic_vector(
          shift_right(signed(v_alu_b), to_integer(unsigned(id_ex_reg.shamt))));
      when ALU_comp_A_lt_B_unsign =>
        if unsigned(v_alu_a) < unsigned(v_alu_b) then
          v_result := x"00000001";
        end if;
      when ALU_comp_A_lt_B_sign =>
        if signed(v_alu_a) < signed(v_alu_b) then
          v_result := x"00000001";
        end if;
      when ALU_A_gt_0 =>
        if to_integer(signed(v_alu_a)) > 0  then v_branch_taken := '1'; end if;
      when ALU_A_eq_0 =>
        if to_integer(signed(v_alu_a)) = 0  then v_branch_taken := '1'; end if;
      when ALU_gteq_0 =>
        if to_integer(signed(v_alu_a)) >= 0 then v_branch_taken := '1'; end if;
      when ALU_lteq_0 =>
        if to_integer(signed(v_alu_a)) <= 0 then v_branch_taken := '1'; end if;
      when ALU_A_eq_B =>
        if v_alu_a = v_alu_b  then v_branch_taken := '1'; end if;
      when ALU_A_ne_B =>
        if v_alu_a /= v_alu_b then v_branch_taken := '1'; end if;
      when ALU_A_lt_0 =>
        if to_integer(signed(v_alu_a)) < 0  then v_branch_taken := '1'; end if;
      when ALU_PASS_A_BRANCH => v_result := v_alu_a;  -- mfhi / mflo / jr pass
      when ALU_PASS_B_BRANCH => v_result := v_alu_b;
      when others => null;
    end case;

    -- ── Branch / jump target computation ─────────────────────────────────────
    -- Branch target = PC+4 + sign_ext(imm16)*4 = PC+4 + imm32[29:0]&"00"
    v_branch_target := std_logic_vector(
      unsigned(id_ex_reg.pc_plus4) +
      unsigned(id_ex_reg.imm32(29 downto 0) & "00"));

    -- Jump target = {PC+4[31:28], IR[25:0], 2'b00}
    -- id_ex_reg.imm32 holds the raw jump field zero-extended in the J case
    v_jump_target := id_ex_reg.pc_plus4(31 downto 28) &
                     id_ex_reg.imm32(25 downto 0) & "00";

    -- JR target = forwarded rs
    v_jr_target := v_alu_a;

    -- ── Take-branch / take-jump decisions ────────────────────────────────────
    if id_ex_reg.valid = '1' and id_ex_reg.branch = '1' and v_branch_taken = '1' then
      v_take_branch := '1';
    end if;
    if id_ex_reg.valid = '1' and id_ex_reg.jump = '1' then
      v_take_jump := '1';
    end if;

    -- ── PC target (JR > J/JAL > branch) ─────────────────────────────────────
    if id_ex_reg.valid = '1' and id_ex_reg.jump = '1' and id_ex_reg.jump_reg = '1' then
      v_pc_target := v_jr_target;
    elsif id_ex_reg.valid = '1' and id_ex_reg.jump = '1' then
      v_pc_target := v_jump_target;
    elsif v_take_branch = '1' then
      v_pc_target := v_branch_target;
    end if;

    -- ── Drive output signals ─────────────────────────────────────────────────
    ex_alu_result    <= v_result;
    ex_alu_result_hi <= v_result_hi;
    ex_rt_fwd        <= v_rt_fwd;
    ex_take_branch   <= v_take_branch;
    ex_take_jump     <= v_take_jump;
    ex_pc_target     <= v_pc_target;
  end process;

  -- ===========================================================================
  -- PC update (combinatorial)
  -- ===========================================================================

  process (all)
  begin
    if_pc_plus4 <= std_logic_vector(unsigned(pc_reg) + 4);

    if ex_mem_reg.valid = '1' and
       (ex_mem_reg.take_branch = '1' or ex_mem_reg.take_jump = '1') then
      pc_next <= ex_mem_reg.pc_target;
    elsif stall_if = '0' then
      pc_next <= std_logic_vector(unsigned(pc_reg) + 4);
    else
      pc_next <= pc_reg;   -- stall: hold PC
    end if;
  end process;

  -- ===========================================================================
  -- PC register
  -- ===========================================================================

  process (clk, rst)
  begin
    if rst = '1' then
      pc_reg <= (others => '0');
    elsif rising_edge(clk) then
      pc_reg <= pc_next;
    end if;
  end process;

  -- ===========================================================================
  -- IF/ID pipeline register
  -- ===========================================================================

  process (clk, rst)
  begin
    if rst = '1' then
      if_id_reg <= IF_ID_NOP;
    elsif rising_edge(clk) then
      if flush_if_id = '1' then
        if_id_reg <= IF_ID_NOP;          -- discard wrong-path instruction
      elsif stall_if = '0' then
        if_id_reg.valid    <= '1';
        if_id_reg.pc_plus4 <= if_pc_plus4;
        if_id_reg.instr    <= if_instr;
      end if;
      -- stall_if='1' and no flush: hold current value
    end if;
  end process;

  -- ===========================================================================
  -- ID/EX pipeline register
  -- ===========================================================================

  process (clk, rst)
  begin
    if rst = '1' then
      id_ex_reg <= ID_EX_NOP;
    elsif rising_edge(clk) then
      if bubble_ex = '1' or flush_id_ex = '1' then
        id_ex_reg <= ID_EX_NOP;          -- insert bubble or flush wrong-path
      elsif stall_id = '0' then
        id_ex_reg.valid       <= if_id_reg.valid;
        id_ex_reg.pc_plus4    <= if_id_reg.pc_plus4;
        id_ex_reg.rs_data     <= id_rs_data;   -- already includes HI/LO mux
        id_ex_reg.rt_data     <= rf_rt_data;
        id_ex_reg.imm32       <= id_imm32;
        id_ex_reg.rs          <= id_rs;
        id_ex_reg.rt          <= id_rt;
        id_ex_reg.rd          <= id_rd;
        id_ex_reg.shamt       <= id_shamt;
        id_ex_reg.alu_op      <= id_alu_op;
        id_ex_reg.alu_src_b   <= id_alu_src_b;
        id_ex_reg.alu_lo_hi   <= id_alu_lo_hi;
        id_ex_reg.hi_write    <= id_hi_write;
        id_ex_reg.lo_write    <= id_lo_write;
        id_ex_reg.mem_read    <= id_mem_read;
        id_ex_reg.mem_write   <= id_mem_write;
        id_ex_reg.reg_write   <= id_reg_write;
        id_ex_reg.mem_to_reg  <= id_mem_to_reg;
        id_ex_reg.branch      <= id_branch;
        id_ex_reg.branch_type <= id_branch_type;
        id_ex_reg.jump        <= id_jump;
        id_ex_reg.jump_reg    <= id_jump_reg;
        id_ex_reg.is_jal      <= id_is_jal;
      end if;
      -- stall_id='1': hold current value
    end if;
  end process;

  -- ===========================================================================
  -- EX/MEM pipeline register
  -- ===========================================================================

  process (clk, rst)
  begin
    if rst = '1' then
      ex_mem_reg <= EX_MEM_NOP;
    elsif rising_edge(clk) then
      ex_mem_reg.valid         <= id_ex_reg.valid;
      ex_mem_reg.pc_plus4      <= id_ex_reg.pc_plus4;
      -- JAL: alu_result carries PC+4 so MEM/WB naturally writes it to $ra
      if id_ex_reg.is_jal = '1' then
        ex_mem_reg.alu_result  <= id_ex_reg.pc_plus4;
      else
        ex_mem_reg.alu_result  <= ex_alu_result;
      end if;
      ex_mem_reg.alu_result_hi <= ex_alu_result_hi;
      ex_mem_reg.rt_fwd        <= ex_rt_fwd;
      ex_mem_reg.rd            <= id_ex_reg.rd;
      ex_mem_reg.mem_read      <= id_ex_reg.mem_read  and id_ex_reg.valid;
      ex_mem_reg.mem_write     <= id_ex_reg.mem_write and id_ex_reg.valid;
      ex_mem_reg.reg_write     <= id_ex_reg.reg_write and id_ex_reg.valid;
      ex_mem_reg.mem_to_reg    <= id_ex_reg.mem_to_reg;
      ex_mem_reg.hi_write      <= id_ex_reg.hi_write  and id_ex_reg.valid;
      ex_mem_reg.lo_write      <= id_ex_reg.lo_write  and id_ex_reg.valid;
      ex_mem_reg.is_load       <= id_ex_reg.mem_read  and id_ex_reg.valid;
      ex_mem_reg.take_branch   <= ex_take_branch;
      ex_mem_reg.take_jump     <= ex_take_jump;
      ex_mem_reg.pc_target     <= ex_pc_target;
    end if;
  end process;

  -- ===========================================================================
  -- MEM/WB pipeline register
  -- ===========================================================================

  process (clk, rst)
  begin
    if rst = '1' then
      mem_wb_reg <= MEM_WB_NOP;
    elsif rising_edge(clk) then
      mem_wb_reg.valid      <= ex_mem_reg.valid;
      if ex_mem_reg.mem_to_reg = '1' then
        mem_wb_reg.wr_data  <= mem_rd_data;            -- LW: data from DMEM
      else
        mem_wb_reg.wr_data  <= ex_mem_reg.alu_result;  -- ALU / JAL(PC+4)
      end if;
      mem_wb_reg.wr_data_hi <= ex_mem_reg.alu_result_hi;
      mem_wb_reg.rd         <= ex_mem_reg.rd;
      mem_wb_reg.reg_write  <= ex_mem_reg.reg_write and ex_mem_reg.valid;
      mem_wb_reg.hi_write   <= ex_mem_reg.hi_write  and ex_mem_reg.valid;
      mem_wb_reg.lo_write   <= ex_mem_reg.lo_write  and ex_mem_reg.valid;
    end if;
  end process;

  -- ===========================================================================
  -- Debug outputs
  -- ===========================================================================

  dbg_pc    <= pc_reg;
  dbg_instr <= if_id_reg.instr;

end Behavioral;

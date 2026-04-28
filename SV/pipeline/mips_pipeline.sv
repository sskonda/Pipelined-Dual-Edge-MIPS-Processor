// =============================================================================
// mips_pipeline.sv  –  5-stage pipelined MIPS CPU
//
//  Stage │ Function
//  ──────┼──────────────────────────────────────────────────────────────────
//   IF   │ Fetch instruction from IMEM at PC, compute PC+4
//   ID   │ Decode instruction, read register file, sign-extend immediate,
//         │ generate all control signals for downstream stages
//   EX   │ Execute ALU op, resolve branch/jump, apply forwarding
//   MEM  │ Data-memory read (LW) or write (SW), pass-through for others
//   WB   │ Write result back to register file, update HI/LO
//
// ── Hazard protection ──────────────────────────────────────────────────────
//  Load-use stall:   EX stage is a load (LW) and its destination register
//                    matches a source of the instruction currently in ID.
//                    Action: hold PC and IF/ID, insert bubble into ID/EX
//                    (one-cycle stall).
//
//  mult→mfhi/mflo:   When mult/multu is in EX and the ID stage is decoding
//                    mfhi or mflo, stall ID one cycle so that HI/LO are
//                    written before they are read.
//
//  Branch/jump flush:When a branch (resolved in EX) is taken, or when a
//                    jump is decoded, the two younger wrong-path instructions
//                    in IF and ID are flushed (their valid bits cleared).
//
// ── Forwarding ─────────────────────────────────────────────────────────────
//  EX/MEM  → EX  :  Forward ALU result to EX input A or B when the previous
//                    instruction wrote a GPR that EX needs to read.
//  MEM/WB  → EX  :  Forward write-back data (ALU or load data) when the
//                    instruction two cycles earlier wrote a GPR that EX needs.
//  $0 forwarding is never asserted (wr_reg == 5'b0 guard).
//
// ── Ready/Valid ────────────────────────────────────────────────────────────
//  Each pipeline register carries a valid bit.  An invalid register entry
//  must not commit any side effect (RegWrite, MemWrite, branch, jump).
//  Stall signals implement backpressure:
//    stall_if → hold PC and IF/ID register
//    stall_id → hold ID/EX register (re-decode same instruction)
//    bubble_ex → force ID/EX to NOP instead of advancing
//  When no stall or flush: every stage advances on every clock edge.
// =============================================================================
module mips_pipeline
  import MIPS_package::*;
  import pipe_pkg::*;
(
  input  logic        clk,
  input  logic        rst,
  // External I/O
  input  logic [9:0]  switches,
  input  logic [1:0]  button,
  output logic [31:0] out_port,   // memory-mapped OutPort (drives LEDs)
  // Ready/valid observation port
  output pipe_rv_t    pipe_rv,
  // Debug visibility
  output logic [31:0] dbg_pc,
  output logic [31:0] dbg_instr   // instruction in ID stage
);

  // ── Structural hazard note ────────────────────────────────────────────────
  // Harvard architecture: IMEM and DMEM are separate.  There is NO structural
  // hazard between the IF and MEM stages.

  // =========================================================================
  // Signal declarations
  // =========================================================================

  // PC
  logic [31:0] pc_reg, pc_next;

  // IF outputs (combinational)
  logic [31:0] if_instr;
  logic [31:0] if_pc_plus4;

  // Pipeline registers
  if_id_t  if_id_reg,  if_id_next;
  id_ex_t  id_ex_reg,  id_ex_next;
  ex_mem_t ex_mem_reg, ex_mem_next;
  mem_wb_t mem_wb_reg, mem_wb_next;

  // HI / LO registers (written in WB, read in ID)
  logic [31:0] HI_reg, LO_reg;

  // Hazard / stall / flush signals
  logic stall_if;   // hold PC and IF/ID
  logic stall_id;   // hold ID/EX (re-present same instruction to EX)
  logic bubble_ex;  // force ID/EX → NOP next cycle
  logic flush_if_id; // clear IF/ID valid
  logic flush_id_ex; // clear ID/EX valid

  // Forwarding mux selects
  logic [1:0] fwd_a, fwd_b;

  // ID stage decode outputs
  logic [4:0]  id_alu_op;
  logic        id_alu_src_b;
  logic [1:0]  id_alu_lo_hi;
  logic        id_hi_write, id_lo_write;
  logic        id_mem_read, id_mem_write;
  logic        id_reg_write, id_mem_to_reg;
  logic        id_branch;
  logic [2:0]  id_branch_type;
  logic        id_jump, id_jump_reg, id_is_jal;
  logic        id_is_signed;
  logic [31:0] id_imm32;
  logic [4:0]  id_rs, id_rt, id_rd;
  logic [4:0]  id_shamt;
  logic [31:0] id_rs_data, id_rt_data;
  logic        id_use_hi, id_use_lo; // mfhi/mflo: read HI/LO instead of GPR

  // EX stage internal signals
  logic [31:0] ex_alu_a, ex_alu_b, ex_alu_b_pre;
  logic [31:0] ex_alu_result, ex_alu_result_hi;
  logic        ex_branch_taken;
  logic [31:0] ex_branch_target;
  logic [31:0] ex_jump_target;
  logic [31:0] ex_jr_target;
  logic        ex_take_branch, ex_take_jump;
  logic [31:0] ex_pc_target;
  logic [31:0] ex_rt_fwd; // forwarded rt (for SW)

  // MEM stage
  logic [31:0] mem_rd_data;
  logic [31:0] mem_wr_data; // WB writeback data

  // WB stage
  logic [4:0]  wb_wr_addr;
  logic [31:0] wb_wr_data;
  logic        wb_wr_en;

  // InPort construction from switches/buttons
  logic [31:0] in_port0, in_port1;

  // =========================================================================
  // Support module instantiations
  // =========================================================================

  pipe_imem imem (
    .addr  (pc_reg[9:2]),
    .instr (if_instr)
  );

  pipe_dmem dmem (
    .clk       (clk),
    .byte_addr (ex_mem_reg.alu_result),
    .wr_data   (ex_mem_reg.rt_fwd),
    .mem_read  (ex_mem_reg.mem_read  & ex_mem_reg.valid),
    .mem_write (ex_mem_reg.mem_write & ex_mem_reg.valid),
    .rd_data   (mem_rd_data),
    .mem_ready (),                  // always 1 — unused
    .in_port0  (in_port0),
    .in_port1  (in_port1),
    .out_port  (out_port)
  );

  pipe_regfile rf (
    .clk      (clk),
    .rst      (rst),
    .wr_addr  (wb_wr_addr),
    .wr_en    (wb_wr_en),
    .wr_data  (wb_wr_data),
    .rd_addr0 (if_id_reg.instr[25:21]), // rs
    .rd_addr1 (if_id_reg.instr[20:16]), // rt
    .rd_data0 (id_rs_data),
    .rd_data1 (id_rt_data)
  );

  // I/O interface (same mapping as multi-cycle design)
  assign in_port0 = {23'b0, switches[8:0]};
  assign in_port1 = {23'b0, switches[8:0]};

  // =========================================================================
  // WB stage — wire writeback before pipeline registers so RF has it combinatorially
  // =========================================================================
  always_comb begin
    wb_wr_addr = mem_wb_reg.rd;
    wb_wr_en   = mem_wb_reg.reg_write & mem_wb_reg.valid;
    // JAL: wr_data is already PC+4 stored in wr_data (set in MEM/WB)
    wb_wr_data = mem_wb_reg.wr_data;
  end

  // HI/LO registers written at end of WB stage
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      HI_reg <= 32'd0;
      LO_reg <= 32'd0;
    end else begin
      if (mem_wb_reg.hi_write & mem_wb_reg.valid)
        HI_reg <= mem_wb_reg.wr_data_hi;
      if (mem_wb_reg.lo_write & mem_wb_reg.valid)
        LO_reg <= mem_wb_reg.wr_data;
    end
  end

  // =========================================================================
  // ID stage — instruction decode and control generation
  // =========================================================================
  always_comb begin
    // Defaults (safe/inactive values)
    id_alu_op      = ALU_NOP;
    id_alu_src_b   = 1'b0;
    id_alu_lo_hi   = 2'b00;
    id_hi_write    = 1'b0;
    id_lo_write    = 1'b0;
    id_mem_read    = 1'b0;
    id_mem_write   = 1'b0;
    id_reg_write   = 1'b0;
    id_mem_to_reg  = 1'b0;
    id_branch      = 1'b0;
    id_branch_type = BR_BEQ;
    id_jump        = 1'b0;
    id_jump_reg    = 1'b0;
    id_is_jal      = 1'b0;
    id_is_signed   = 1'b0;
    id_use_hi      = 1'b0;
    id_use_lo      = 1'b0;

    // Decode fields
    id_rs    = if_id_reg.instr[25:21];
    id_rt    = if_id_reg.instr[20:16];
    id_rd    = if_id_reg.instr[15:11]; // default for R-type
    id_shamt = if_id_reg.instr[10:6];

    // Sign/zero-extend immediate
    // Default: sign-extend
    id_is_signed = 1'b1;

    case (if_id_reg.instr[31:26]) // opcode

      // ─────────────────────────────────────────────────────────────────────
      // R-type (opcode = 0)
      // ─────────────────────────────────────────────────────────────────────
      R_OP: begin
        id_rd = if_id_reg.instr[15:11]; // rd field
        case (if_id_reg.instr[5:0]) // funct
          R_FUNC_ADDU: begin id_alu_op=ALU_ADD_unsign; id_reg_write=1'b1; end
          R_FUNC_SUBU: begin id_alu_op=ALU_SUB_unsign; id_reg_write=1'b1; end
          R_FUNC_AND:  begin id_alu_op=ALU_AND;         id_reg_write=1'b1; end
          R_FUNC_OR:   begin id_alu_op=ALU_OR;          id_reg_write=1'b1; end
          R_FUNC_XOR:  begin id_alu_op=ALU_XOR;         id_reg_write=1'b1; end
          R_FUNC_SLT:  begin id_alu_op=ALU_comp_A_lt_B_sign;   id_reg_write=1'b1; end
          R_FUNC_SLTU: begin id_alu_op=ALU_comp_A_lt_B_unsign; id_reg_write=1'b1; end
          R_FUNC_SLL:  begin id_alu_op=ALU_LOG_SHIFT_L; id_reg_write=1'b1; end
          R_FUNC_SRL:  begin id_alu_op=ALU_LOG_SHIFT_R; id_reg_write=1'b1; end
          R_FUNC_SRA:  begin id_alu_op=ALU_ARITH_SHIFT_R; id_reg_write=1'b1; end
          R_FUNC_MULT: begin
            id_alu_op   = ALU_mult_sign;
            id_hi_write = 1'b1;
            id_lo_write = 1'b1;
            // No GPR write for mult
          end
          R_FUNC_MULTU: begin
            id_alu_op   = ALU_mult_unsign;
            id_hi_write = 1'b1;
            id_lo_write = 1'b1;
          end
          R_FUNC_MFHI: begin
            // Pass HI register through ALU_PASS_A; rs_data will be HI
            id_alu_op    = ALU_PASS_A_BRANCH;
            id_reg_write = 1'b1;
            id_use_hi    = 1'b1; // override rs_data with HI_reg
          end
          R_FUNC_MFLO: begin
            id_alu_op    = ALU_PASS_A_BRANCH;
            id_reg_write = 1'b1;
            id_use_lo    = 1'b1; // override rs_data with LO_reg
          end
          R_FUNC_JR: begin
            // Jump-register: target = rs (forwarded in EX)
            id_jump     = 1'b1;
            id_jump_reg = 1'b1;
          end
          default: ; // NOP
        endcase
      end

      // ─────────────────────────────────────────────────────────────────────
      // I-type arithmetic and logical
      // ─────────────────────────────────────────────────────────────────────
      I_ADDIU: begin
        id_alu_op    = ALU_ADD_unsign;
        id_alu_src_b = 1'b1; // immediate
        id_is_signed = 1'b1;
        id_reg_write = 1'b1;
        id_rd        = if_id_reg.instr[20:16]; // destination = rt
      end
      I_ANDI: begin
        id_alu_op    = ALU_AND;
        id_alu_src_b = 1'b1;
        id_is_signed = 1'b0; // zero-extend
        id_reg_write = 1'b1;
        id_rd        = if_id_reg.instr[20:16];
      end
      I_ORI: begin
        id_alu_op    = ALU_OR;
        id_alu_src_b = 1'b1;
        id_is_signed = 1'b0;
        id_reg_write = 1'b1;
        id_rd        = if_id_reg.instr[20:16];
      end
      I_XORI: begin
        id_alu_op    = ALU_XOR;
        id_alu_src_b = 1'b1;
        id_is_signed = 1'b0;
        id_reg_write = 1'b1;
        id_rd        = if_id_reg.instr[20:16];
      end
      I_SLTI: begin
        id_alu_op    = ALU_comp_A_lt_B_sign;
        id_alu_src_b = 1'b1;
        id_is_signed = 1'b1;
        id_reg_write = 1'b1;
        id_rd        = if_id_reg.instr[20:16];
      end
      I_SLTIU: begin
        id_alu_op    = ALU_comp_A_lt_B_unsign;
        id_alu_src_b = 1'b1;
        id_is_signed = 1'b0;
        id_reg_write = 1'b1;
        id_rd        = if_id_reg.instr[20:16];
      end
      I_SUBIU: begin
        id_alu_op    = ALU_SUB_unsign;
        id_alu_src_b = 1'b1;
        id_is_signed = 1'b1;
        id_reg_write = 1'b1;
        id_rd        = if_id_reg.instr[20:16];
      end

      // ─────────────────────────────────────────────────────────────────────
      // Load / Store
      // ─────────────────────────────────────────────────────────────────────
      6'b100011: begin // LW
        id_alu_op    = ALU_ADD_unsign; // address = rs + sign_ext(imm)
        id_alu_src_b = 1'b1;
        id_is_signed = 1'b1;
        id_mem_read  = 1'b1;
        id_reg_write = 1'b1;
        id_mem_to_reg= 1'b1;
        id_rd        = if_id_reg.instr[20:16]; // destination = rt
      end
      6'b101011: begin // SW
        id_alu_op    = ALU_ADD_unsign; // address = rs + sign_ext(imm)
        id_alu_src_b = 1'b1;
        id_is_signed = 1'b1;
        id_mem_write = 1'b1;
        // no reg_write
      end

      // ─────────────────────────────────────────────────────────────────────
      // Branch instructions (comparison performed in EX with ALU)
      // ─────────────────────────────────────────────────────────────────────
      I_BEQ: begin
        id_branch      = 1'b1;
        id_branch_type = BR_BEQ;
        id_alu_op      = ALU_A_eq_B;
        id_is_signed   = 1'b1;
      end
      I_BNE: begin
        id_branch      = 1'b1;
        id_branch_type = BR_BNE;
        id_alu_op      = ALU_A_ne_B;
        id_is_signed   = 1'b1;
      end
      I_BLEZ: begin
        id_branch      = 1'b1;
        id_branch_type = BR_BLEZ;
        id_alu_op      = ALU_lteq_0;
        id_is_signed   = 1'b1;
        // rt field is $0 in the encoding; rs compared against 0
      end
      I_BGTZ: begin
        id_branch      = 1'b1;
        id_branch_type = BR_BGTZ;
        id_alu_op      = ALU_A_gt_0;
        id_is_signed   = 1'b1;
      end
      I_REGIMM: begin // bltz / bgez — rt field selects which
        id_branch    = 1'b1;
        id_is_signed = 1'b1;
        if (if_id_reg.instr[20:16] == 5'd0) begin // bltz
          id_alu_op      = ALU_A_lt_0;
          id_branch_type = BR_BLTZ;
        end else begin // bgez (rt = 1)
          id_alu_op      = ALU_gteq_0;
          id_branch_type = BR_BGEZ;
        end
      end

      // ─────────────────────────────────────────────────────────────────────
      // Jump instructions
      // ─────────────────────────────────────────────────────────────────────
      J_JUMP: begin
        id_jump = 1'b1;
      end
      J_JAL: begin
        id_jump      = 1'b1;
        id_is_jal    = 1'b1;
        id_reg_write = 1'b1;
        id_rd        = 5'd31; // $ra
      end

      default: ; // undefined opcode → NOP (all defaults)
    endcase

    // Sign/zero extend immediate
    if (id_is_signed)
      id_imm32 = {{16{if_id_reg.instr[15]}}, if_id_reg.instr[15:0]};
    else
      id_imm32 = {16'd0, if_id_reg.instr[15:0]};

    // Override rs_data with HI or LO for mfhi/mflo
    // (Forwarding for HI/LO is not implemented; a 1-cycle stall is inserted
    //  by the hazard unit when mult is still in EX.)
    if (id_use_hi)
      id_rs_data = HI_reg; // read from RF is overridden
    else if (id_use_lo)
      id_rs_data = LO_reg;
    // else id_rs_data comes from pipe_regfile (combinatorial)
    // Note: id_rs_data declared as output of pipe_regfile and overridden
  end

  // Effective rs_data going into ID/EX (mux between RF output and HI/LO)
  // The actual mux is in the always_ff for id_ex_reg.

  // =========================================================================
  // HAZARD DETECTION UNIT  (combinatorial)
  // =========================================================================
  // Inputs:  id_ex_reg (EX stage), if_id_reg (ID stage)
  // Outputs: stall_if, stall_id, bubble_ex, flush_if_id, flush_id_ex
  //
  // Priority: branch/jump flush > load-use stall > mult-stall
  always_comb begin
    stall_if   = 1'b0;
    stall_id   = 1'b0;
    bubble_ex  = 1'b0;
    flush_if_id = 1'b0;
    flush_id_ex = 1'b0;

    // ── Load-use stall ─────────────────────────────────────────────────────
    // EX stage is a load (LW) and its destination is read by the current ID.
    // Only stall if the load destination is a real register ($0 is always 0).
    if (id_ex_reg.mem_read && id_ex_reg.valid &&
        id_ex_reg.rd != 5'd0 &&
        (id_ex_reg.rd == if_id_reg.instr[25:21] || // rs
         id_ex_reg.rd == if_id_reg.instr[20:16])) // rt
    begin
      stall_if  = 1'b1; // hold PC
      stall_id  = 1'b1; // hold IF/ID (re-decode after bubble clears)
      bubble_ex = 1'b1; // insert NOP into ID/EX
    end

    // ── mult → mfhi/mflo stall ─────────────────────────────────────────────
    // EX stage is mult/multu (hi_write or lo_write) and ID is mfhi/mflo.
    // HI/LO are written in WB; stall until the mult has committed.
    if (id_ex_reg.valid && (id_ex_reg.hi_write | id_ex_reg.lo_write) &&
        if_id_reg.valid &&
        if_id_reg.instr[31:26] == R_OP &&
        (if_id_reg.instr[5:0] == R_FUNC_MFHI ||
         if_id_reg.instr[5:0] == R_FUNC_MFLO))
    begin
      // Only stall when mult is in EX (one cycle gap needed)
      stall_if  = 1'b1;
      stall_id  = 1'b1;
      bubble_ex = 1'b1;
    end

    // ── Branch / jump flush ────────────────────────────────────────────────
    // Branch resolution is in EX.  When a branch/jump is taken, the two
    // instructions fetched after the branch (currently in ID and IF) are
    // wrong-path → flush them.
    // (stall takes priority only in the first condition; flush can override
    //  the stall flags because wrong-path instructions must be discarded.)
    if (ex_mem_reg.valid && (ex_mem_reg.take_branch | ex_mem_reg.take_jump)) begin
      flush_if_id = 1'b1; // discard whatever is in IF/ID
      flush_id_ex = 1'b1; // discard whatever is in ID/EX
      // Override any load-use stall that would hold IF/ID
      stall_if  = 1'b0;
      stall_id  = 1'b0;
      bubble_ex = 1'b0;
    end
  end

  // =========================================================================
  // EX stage — forwarding unit (combinatorial)
  // =========================================================================
  always_comb begin
    fwd_a = FWD_ID;
    fwd_b = FWD_ID;

    // Forward to input A (rs)
    // Priority: EX/MEM before MEM/WB (more recent data wins)
    if (ex_mem_reg.valid && ex_mem_reg.reg_write &&
        ex_mem_reg.rd != 5'd0 && ex_mem_reg.rd == id_ex_reg.rs)
      fwd_a = FWD_EXM;
    else if (mem_wb_reg.valid && mem_wb_reg.reg_write &&
             mem_wb_reg.rd != 5'd0 && mem_wb_reg.rd == id_ex_reg.rs)
      fwd_a = FWD_MWB;

    // Forward to input B (rt) — only when alu_src_b = 0 (register operand)
    if (ex_mem_reg.valid && ex_mem_reg.reg_write &&
        ex_mem_reg.rd != 5'd0 && ex_mem_reg.rd == id_ex_reg.rt)
      fwd_b = FWD_EXM;
    else if (mem_wb_reg.valid && mem_wb_reg.reg_write &&
             mem_wb_reg.rd != 5'd0 && mem_wb_reg.rd == id_ex_reg.rt)
      fwd_b = FWD_MWB;
  end

  // =========================================================================
  // EX stage — ALU and branch/jump resolution (combinatorial)
  // =========================================================================
  always_comb begin
    // ── Apply forwarding to rs (ALU input A) ─────────────────────────────
    unique case (fwd_a)
      FWD_EXM: ex_alu_a = ex_mem_reg.alu_result;
      FWD_MWB: ex_alu_a = mem_wb_reg.wr_data;
      default: ex_alu_a = id_ex_reg.rs_data;
    endcase

    // ── Apply forwarding to rt (register operand, before imm mux) ────────
    unique case (fwd_b)
      FWD_EXM: ex_rt_fwd = ex_mem_reg.alu_result;
      FWD_MWB: ex_rt_fwd = mem_wb_reg.wr_data;
      default: ex_rt_fwd = id_ex_reg.rt_data;
    endcase

    // ALU input B mux: register or sign-extended immediate
    ex_alu_b_pre = id_ex_reg.alu_src_b ? id_ex_reg.imm32 : ex_rt_fwd;

    // For shift instructions the shamt comes from IR[10:6] (in the ID/EX
    // register), not from the register file.  The ALU uses sel=01011 or
    // 01010 and reads the shamt from the IR field passed separately.
    ex_alu_b = ex_alu_b_pre;

    // ── ALU operation ──────────────────────────────────────────────────────
    // Inline ALU logic (mirrors MIPS_ALU.sv) to avoid an extra module port.
    // Signed / unsigned products computed combinatorially.
    begin : alu_block
      logic signed [63:0] s_prod;
      logic        [63:0] u_prod;
      s_prod = $signed(ex_alu_a) * $signed(ex_alu_b);
      u_prod = ex_alu_a * ex_alu_b;

      ex_alu_result    = 32'd0;
      ex_alu_result_hi = 32'd0;
      ex_branch_taken  = 1'b0;

      case (id_ex_reg.alu_op)
        ALU_ADD_unsign: ex_alu_result = ex_alu_a + ex_alu_b;
        ALU_ADD_sign:   ex_alu_result = $signed(ex_alu_a) + $signed(ex_alu_b);
        ALU_SUB_unsign: ex_alu_result = ex_alu_a - ex_alu_b;
        ALU_SUB_sign:   ex_alu_result = $signed(ex_alu_a) - $signed(ex_alu_b);
        ALU_mult_unsign: begin
          ex_alu_result    = u_prod[31:0];
          ex_alu_result_hi = u_prod[63:32];
        end
        ALU_mult_sign: begin
          ex_alu_result    = s_prod[31:0];
          ex_alu_result_hi = s_prod[63:32];
        end
        ALU_AND:  ex_alu_result = ex_alu_a & ex_alu_b;
        ALU_OR:   ex_alu_result = ex_alu_a | ex_alu_b;
        ALU_XOR:  ex_alu_result = ex_alu_a ^ ex_alu_b;
        ALU_NOT_A:ex_alu_result = ~ex_alu_a;
        ALU_LOG_SHIFT_R:   ex_alu_result = ex_alu_b >> id_ex_reg.shamt;
        ALU_LOG_SHIFT_L:   ex_alu_result = ex_alu_b << id_ex_reg.shamt;
        ALU_ARITH_SHIFT_R: ex_alu_result = $signed(ex_alu_b) >>> id_ex_reg.shamt;
        ALU_comp_A_lt_B_unsign: ex_alu_result = (ex_alu_a < ex_alu_b) ? 32'd1 : 32'd0;
        ALU_comp_A_lt_B_sign:   ex_alu_result = ($signed(ex_alu_a) < $signed(ex_alu_b)) ? 32'd1 : 32'd0;
        ALU_A_gt_0:  ex_branch_taken = ($signed(ex_alu_a) >  0);
        ALU_A_eq_0:  ex_branch_taken = ($signed(ex_alu_a) == 0);
        ALU_gteq_0:  ex_branch_taken = ($signed(ex_alu_a) >= 0);
        ALU_lteq_0:  ex_branch_taken = ($signed(ex_alu_a) <= 0);
        ALU_A_eq_B:  ex_branch_taken = (ex_alu_a == ex_alu_b);
        ALU_A_ne_B:  ex_branch_taken = (ex_alu_a != ex_alu_b);
        ALU_A_lt_0:  ex_branch_taken = ($signed(ex_alu_a) <  0);
        ALU_PASS_A_BRANCH: ex_alu_result = ex_alu_a; // mfhi/mflo / jr
        ALU_PASS_B_BRANCH: ex_alu_result = ex_alu_b;
        default: begin
          ex_alu_result    = 32'd0;
          ex_alu_result_hi = 32'd0;
          ex_branch_taken  = 1'b0;
        end
      endcase
    end

    // ── JAL: writeback value is PC+4 (override alu_result in WB) ──────────
    // The ALU result for JAL is not used; wr_data is set to PC+4 in MEM/WB.

    // ── Branch/Jump target computation ─────────────────────────────────────
    // Branch target  = PC+4 + sign_ext(imm16) * 4  = PC+4 + imm32<<2
    ex_branch_target = id_ex_reg.pc_plus4 + {id_ex_reg.imm32[29:0], 2'b00};

    // Jump target    = {PC+4[31:28], IR[25:0], 2'b00}
    ex_jump_target   = {id_ex_reg.pc_plus4[31:28], id_ex_reg.imm32[25:0], 2'b00};
    // Note: imm32 was zero-extended from the 26-bit jump field in ID stage.
    // For j/jal: id_imm32 = {6'b0, IR[25:0]} → [25:0] == IR[25:0]. ✓

    // JR target = forwarded rs_data
    ex_jr_target = ex_alu_a; // rs forwarded through fwd_a mux

    // ── Effective branch/jump decision ─────────────────────────────────────
    // An invalid ID/EX entry must never take a branch or jump
    // (it could be a bubble or flushed instruction).
    ex_take_branch = id_ex_reg.valid && id_ex_reg.branch && ex_branch_taken;
    ex_take_jump   = id_ex_reg.valid && id_ex_reg.jump;

    unique case (1'b1)
      ex_take_jump && id_ex_reg.jump_reg: ex_pc_target = ex_jr_target;
      ex_take_jump:                        ex_pc_target = ex_jump_target;
      ex_take_branch:                      ex_pc_target = ex_branch_target;
      default:                             ex_pc_target = 32'd0; // unused
    endcase
  end

  // =========================================================================
  // MEM stage — pass-through for non-memory instructions (combinatorial)
  // =========================================================================
  always_comb begin
    // rd_data from pipe_dmem is used if mem_to_reg, else ALU result
    if (ex_mem_reg.mem_to_reg)
      mem_wr_data = mem_rd_data; // LW: load from data memory
    else if (ex_mem_reg.is_load & ~ex_mem_reg.mem_to_reg)
      mem_wr_data = ex_mem_reg.alu_result; // shouldn't happen but safe
    else if (ex_mem_reg.valid && ex_mem_reg.is_load == 1'b0 && ex_mem_reg.lo_write == 1'b0)
      // JAL: if JAL, wr_data = PC+4 (stored in pc_plus4 field)
      // This is handled below in MEM/WB register update
      mem_wr_data = ex_mem_reg.alu_result;
    else
      mem_wr_data = ex_mem_reg.alu_result;
  end

  // =========================================================================
  // PC update logic (combinatorial)
  // =========================================================================
  always_comb begin
    if_pc_plus4 = pc_reg + 32'd4;

    if (ex_mem_reg.valid && (ex_mem_reg.take_branch || ex_mem_reg.take_jump))
      pc_next = ex_mem_reg.pc_target;
    else if (!stall_if)
      pc_next = if_pc_plus4;
    else
      pc_next = pc_reg; // hold
  end

  // =========================================================================
  // Pipeline register sequential logic
  // =========================================================================

  // ── PC register ───────────────────────────────────────────────────────────
  always_ff @(posedge clk or posedge rst) begin
    if (rst)
      pc_reg <= 32'd0;
    else
      pc_reg <= pc_next;
  end

  // ── IF/ID register ────────────────────────────────────────────────────────
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      if_id_reg <= IF_ID_NOP;
    end else if (flush_if_id) begin
      if_id_reg <= IF_ID_NOP; // discard wrong-path instruction
    end else if (!stall_if) begin
      if_id_reg.valid    <= 1'b1;
      if_id_reg.pc_plus4 <= if_pc_plus4;
      if_id_reg.instr    <= if_instr;
    end
    // else: stall → hold current IF/ID value
  end

  // ── ID/EX register ────────────────────────────────────────────────────────
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      id_ex_reg <= ID_EX_NOP;
    end else if (bubble_ex || flush_id_ex) begin
      id_ex_reg <= ID_EX_NOP; // insert NOP bubble or flush wrong-path
    end else if (!stall_id) begin
      // Advance: latch decoded instruction into ID/EX
      id_ex_reg.valid       <= if_id_reg.valid;
      id_ex_reg.pc_plus4    <= if_id_reg.pc_plus4;
      id_ex_reg.rs_data     <= (id_use_hi) ? HI_reg :
                               (id_use_lo) ? LO_reg  : id_rs_data;
      id_ex_reg.rt_data     <= id_rt_data;
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
    end
    // else: stall → hold current ID/EX value
  end

  // ── EX/MEM register ───────────────────────────────────────────────────────
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      ex_mem_reg <= EX_MEM_NOP;
    end else begin
      ex_mem_reg.valid         <= id_ex_reg.valid;
      ex_mem_reg.pc_plus4      <= id_ex_reg.pc_plus4;
      ex_mem_reg.alu_result    <= id_ex_reg.is_jal ? id_ex_reg.pc_plus4 : ex_alu_result;
      ex_mem_reg.alu_result_hi <= ex_alu_result_hi;
      ex_mem_reg.rt_fwd        <= ex_rt_fwd; // forwarded store data
      ex_mem_reg.rd            <= id_ex_reg.rd;
      ex_mem_reg.mem_read      <= id_ex_reg.mem_read  & id_ex_reg.valid;
      ex_mem_reg.mem_write     <= id_ex_reg.mem_write & id_ex_reg.valid;
      ex_mem_reg.reg_write     <= id_ex_reg.reg_write & id_ex_reg.valid;
      ex_mem_reg.mem_to_reg    <= id_ex_reg.mem_to_reg;
      ex_mem_reg.hi_write      <= id_ex_reg.hi_write  & id_ex_reg.valid;
      ex_mem_reg.lo_write      <= id_ex_reg.lo_write  & id_ex_reg.valid;
      ex_mem_reg.is_load       <= id_ex_reg.mem_read  & id_ex_reg.valid;
      ex_mem_reg.take_branch   <= ex_take_branch;
      ex_mem_reg.take_jump     <= ex_take_jump;
      ex_mem_reg.pc_target     <= ex_pc_target;
    end
  end

  // ── MEM/WB register ───────────────────────────────────────────────────────
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      mem_wb_reg <= MEM_WB_NOP;
    end else begin
      mem_wb_reg.valid      <= ex_mem_reg.valid;
      // Select write-back data:
      //   JAL: pc_plus4 (already stored in alu_result for JAL)
      //   LW:  loaded data from DMEM
      //   else: ALU result
      if (ex_mem_reg.mem_to_reg)
        mem_wb_reg.wr_data <= mem_rd_data;
      else
        mem_wb_reg.wr_data <= ex_mem_reg.alu_result;
      mem_wb_reg.wr_data_hi <= ex_mem_reg.alu_result_hi;
      mem_wb_reg.rd         <= ex_mem_reg.rd;
      mem_wb_reg.reg_write  <= ex_mem_reg.reg_write & ex_mem_reg.valid;
      mem_wb_reg.hi_write   <= ex_mem_reg.hi_write  & ex_mem_reg.valid;
      mem_wb_reg.lo_write   <= ex_mem_reg.lo_write  & ex_mem_reg.valid;
    end
  end

  // =========================================================================
  // Ready/valid output signals (for external observation)
  // =========================================================================
  assign pipe_rv.if_valid  = if_id_reg.valid;
  assign pipe_rv.if_ready  = ~stall_if;
  assign pipe_rv.id_valid  = id_ex_reg.valid;
  assign pipe_rv.id_ready  = ~stall_id;
  assign pipe_rv.ex_valid  = ex_mem_reg.valid;
  assign pipe_rv.ex_ready  = 1'b1; // single-cycle EX
  assign pipe_rv.mem_valid = mem_wb_reg.valid;
  assign pipe_rv.mem_ready = 1'b1; // single-cycle memory
  assign pipe_rv.wb_valid  = mem_wb_reg.valid & mem_wb_reg.reg_write;
  assign pipe_rv.wb_ready  = 1'b1; // WB always completes

  // Debug outputs
  assign dbg_pc    = pc_reg;
  assign dbg_instr = if_id_reg.instr;

endmodule

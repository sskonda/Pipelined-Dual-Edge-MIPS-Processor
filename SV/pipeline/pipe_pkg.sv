// =============================================================================
// pipe_pkg.sv  –  Pipeline data types, control constants, and ready/valid
//                 interface definitions for the 5-stage MIPS pipeline.
//
// Pipeline stages:  IF → ID → EX → MEM → WB
// Pipeline registers: IF/ID, ID/EX, EX/MEM, MEM/WB
//
// All pipeline registers carry a valid bit.  An invalid entry must NOT
// commit any side effect (no RegWrite, no MemWrite, no branch/jump taken).
// =============================================================================
package pipe_pkg;

  import MIPS_package::*;

  // ---------------------------------------------------------------------------
  // Branch type encoding (3-bit)
  // ---------------------------------------------------------------------------
  localparam logic [2:0] BR_BEQ  = 3'd0; // beq  – A == B
  localparam logic [2:0] BR_BNE  = 3'd1; // bne  – A != B
  localparam logic [2:0] BR_BLEZ = 3'd2; // blez – A <= 0 (signed)
  localparam logic [2:0] BR_BGTZ = 3'd3; // bgtz – A > 0  (signed)
  localparam logic [2:0] BR_BLTZ = 3'd4; // bltz – A < 0  (signed)
  localparam logic [2:0] BR_BGEZ = 3'd5; // bgez – A >= 0 (signed)

  // ---------------------------------------------------------------------------
  // Forwarding mux select (for EX-stage input muxes)
  // ---------------------------------------------------------------------------
  localparam logic [1:0] FWD_ID  = 2'b00; // use ID/EX register value
  localparam logic [1:0] FWD_EXM = 2'b01; // forward from EX/MEM ALU result
  localparam logic [1:0] FWD_MWB = 2'b10; // forward from MEM/WB write-data

  // ---------------------------------------------------------------------------
  // IF/ID pipeline register
  // ---------------------------------------------------------------------------
  typedef struct packed {
    logic        valid;
    logic [31:0] pc_plus4; // PC + 4  (used for branch-delay, JAL)
    logic [31:0] instr;    // raw 32-bit instruction word
  } if_id_t;

  localparam if_id_t IF_ID_NOP = '{
    valid    : 1'b0,
    pc_plus4 : 32'd0,
    instr    : 32'd0   // all-zero = SLL $0,$0,0 = NOP
  };

  // ---------------------------------------------------------------------------
  // ID/EX pipeline register
  // ---------------------------------------------------------------------------
  typedef struct packed {
    logic        valid;
    logic [31:0] pc_plus4;   // forwarded for JAL return-address
    // Data values decoded in ID
    logic [31:0] rs_data;    // register-file read port 0 (or HI/LO for mf*)
    logic [31:0] rt_data;    // register-file read port 1
    logic [31:0] imm32;      // sign/zero-extended 16-bit immediate
    // Register addresses (kept for forwarding comparisons)
    logic [4:0]  rs;
    logic [4:0]  rt;
    logic [4:0]  rd;         // actual writeback destination (rt or rd after RegDst)
    logic [4:0]  shamt;      // shift amount IR[10:6]
    // EX-stage control
    logic [4:0]  alu_op;     // 5-bit ALU OPSelect (from MIPS_package)
    logic        alu_src_b;  // 0 = rt_data (forwarded), 1 = imm32
    logic [1:0]  alu_lo_hi;  // 00=ALU result, 01=LO reg, 10=HI reg
    logic        hi_write;   // mult/multu: update HI
    logic        lo_write;   // mult/multu: update LO
    // MEM-stage control
    logic        mem_read;   // 1 for LW
    logic        mem_write;  // 1 for SW
    // WB-stage control
    logic        reg_write;  // 1 if instruction writes a GPR
    logic        mem_to_reg; // 0 = ALU result, 1 = memory load data
    // Branch / Jump
    logic        branch;
    logic [2:0]  branch_type;
    logic        jump;       // j / jal
    logic        jump_reg;   // jr (target = forwarded rs_data)
    logic        is_jal;     // jal: rd=$31, wr_data=PC+4
  } id_ex_t;

  localparam id_ex_t ID_EX_NOP = '{
    valid      : 1'b0,
    pc_plus4   : 32'd0,
    rs_data    : 32'd0,
    rt_data    : 32'd0,
    imm32      : 32'd0,
    rs         : 5'd0,
    rt         : 5'd0,
    rd         : 5'd0,
    shamt      : 5'd0,
    alu_op     : ALU_NOP,
    alu_src_b  : 1'b0,
    alu_lo_hi  : 2'b00,
    hi_write   : 1'b0,
    lo_write   : 1'b0,
    mem_read   : 1'b0,
    mem_write  : 1'b0,
    reg_write  : 1'b0,
    mem_to_reg : 1'b0,
    branch     : 1'b0,
    branch_type: 3'd0,
    jump       : 1'b0,
    jump_reg   : 1'b0,
    is_jal     : 1'b0
  };

  // ---------------------------------------------------------------------------
  // EX/MEM pipeline register
  // ---------------------------------------------------------------------------
  typedef struct packed {
    logic        valid;
    logic [31:0] pc_plus4;      // JAL: writeback PC+4 to $31
    logic [31:0] alu_result;    // ALU output (LO word for mult)
    logic [31:0] alu_result_hi; // HI word for mult/multu
    logic [31:0] rt_fwd;        // forwarded rt value (for SW store data)
    logic [4:0]  rd;            // writeback destination register
    // MEM-stage control
    logic        mem_read;      // LW
    logic        mem_write;     // SW
    // WB-stage control
    logic        reg_write;
    logic        mem_to_reg;
    logic        hi_write;
    logic        lo_write;
    logic        is_load;       // for load-use hazard detection next cycle
    // Branch / Jump resolution
    logic        take_branch;   // branch taken → flush IF/ID and ID/EX
    logic        take_jump;     // unconditional jump
    logic [31:0] pc_target;     // new PC if branch/jump taken
  } ex_mem_t;

  localparam ex_mem_t EX_MEM_NOP = '{
    valid         : 1'b0,
    pc_plus4      : 32'd0,
    alu_result    : 32'd0,
    alu_result_hi : 32'd0,
    rt_fwd        : 32'd0,
    rd            : 5'd0,
    mem_read      : 1'b0,
    mem_write     : 1'b0,
    reg_write     : 1'b0,
    mem_to_reg    : 1'b0,
    hi_write      : 1'b0,
    lo_write      : 1'b0,
    is_load       : 1'b0,
    take_branch   : 1'b0,
    take_jump     : 1'b0,
    pc_target     : 32'd0
  };

  // ---------------------------------------------------------------------------
  // MEM/WB pipeline register
  // ---------------------------------------------------------------------------
  typedef struct packed {
    logic        valid;
    logic [31:0] wr_data;    // data to write into GPR (ALU result or load data)
    logic [31:0] wr_data_hi; // HI register write data (from mult)
    logic [4:0]  rd;
    logic        reg_write;
    logic        hi_write;
    logic        lo_write;
  } mem_wb_t;

  localparam mem_wb_t MEM_WB_NOP = '{
    valid      : 1'b0,
    wr_data    : 32'd0,
    wr_data_hi : 32'd0,
    rd         : 5'd0,
    reg_write  : 1'b0,
    hi_write   : 1'b0,
    lo_write   : 1'b0
  };

  // ---------------------------------------------------------------------------
  // Ready/valid per-stage bundle (for external monitoring / backpressure)
  // ---------------------------------------------------------------------------
  typedef struct packed {
    logic if_valid;
    logic if_ready;
    logic id_valid;
    logic id_ready;
    logic ex_valid;
    logic ex_ready;
    logic mem_valid;
    logic mem_ready;
    logic wb_valid;
    logic wb_ready;
  } pipe_rv_t;

endpackage

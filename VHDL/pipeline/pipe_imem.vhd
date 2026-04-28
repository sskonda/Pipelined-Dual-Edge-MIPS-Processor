-- =============================================================================
-- pipe_imem.vhd  –  256×32-bit instruction memory (ROM) for the pipeline.
--
-- VHDL equivalent of SV/pipeline/pipe_imem.sv.
-- Harvard architecture: separate from data memory, no structural hazard.
-- Asynchronous (combinatorial) read: data available in same cycle.
-- Initialized with the same 27-word test program as SV/pipeline/pipe_imem.sv.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pipe_imem is
  port (
    addr  : in  std_logic_vector(7 downto 0);  -- word address (PC[9:2])
    instr : out std_logic_vector(31 downto 0)  -- instruction (combinatorial)
  );
end pipe_imem;

architecture ROM of pipe_imem is

  type mem_array is array(0 to 255) of std_logic_vector(31 downto 0);

  constant mem : mem_array := (
    -- Phase 1
    0  => x"24010005",  -- addiu $1,  $0,  5
    1  => x"2402000A",  -- addiu $2,  $0, 10
    2  => x"00221821",  -- addu  $3,  $1, $2   ($3=15)
    3  => x"00412023",  -- subu  $4,  $2, $1   ($4=5)
    4  => x"00222824",  -- and   $5,  $1, $2   ($5=0)
    5  => x"00223025",  -- or    $6,  $1, $2   ($6=15)
    6  => x"00013880",  -- sll   $7,  $1, 2    ($7=20)
    7  => x"10240001",  -- beq   $1,  $4, +1   (taken, skip word 8)
    8  => x"24080063",  -- addiu $8,  $0, 99   [SKIPPED]
    9  => x"AC03FFFC",  -- sw    $3,  -4($0)   OutPort=15
    -- Phase 2
    10 => x"340800F0",  -- ori   $8,  $0, 0xF0 ($8=240)
    11 => x"382A0007",  -- xori  $10, $1,  7   ($10=2)
    12 => x"AC0AFFFC",  -- sw    $10, -4($0)   OutPort=2
    -- Phase 3
    13 => x"00075882",  -- srl   $11, $7,  2   ($11=5)
    14 => x"282C0008",  -- slti  $12, $1,  8   ($12=1)
    15 => x"AC0CFFFC",  -- sw    $12, -4($0)   OutPort=1
    -- Phase 4
    16 => x"14220001",  -- bne   $1,  $2, +1   (taken, skip word 17)
    17 => x"240F0063",  -- addiu $15, $0, 99   [SKIPPED]
    18 => x"AC01FFFC",  -- sw    $1,  -4($0)   OutPort=5
    -- Phase 5 (mult-mflo stall)
    19 => x"00220018",  -- mult  $1,  $2        HI:LO=50
    20 => x"00008012",  -- mflo  $16            $16=50
    21 => x"AC10FFFC",  -- sw    $16, -4($0)   OutPort=50
    -- Phase 6 (load-use stall)
    22 => x"2411004D",  -- addiu $17, $0, 77   $17=77
    23 => x"AC110080",  -- sw    $17, 0x80($0) mem[0x20]=77
    24 => x"8C120080",  -- lw    $18, 0x80($0) $18=77  <- LOAD
    25 => x"AC12FFFC",  -- sw    $18, -4($0)   OutPort=77 <- USE
    -- Loop
    26 => x"08000000",  -- j     0
    -- Others
    others => x"00000000"
  );

begin

  -- Asynchronous read
  instr <= mem(to_integer(unsigned(addr)));

end ROM;

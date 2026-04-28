-- Behavioral RAM for GHDL simulation (replaces altera_mf altsyncram).
-- 256 words x 32 bits, synchronous write, asynchronous read.
--
-- Test program (all immediates positive so IsSigned polarity does not matter):
--
--  Word  ByteAddr  Encoding    Assembly                  Expected
--   0    0x00      24010005    addiu $1,  $0,  5          $1  =  5
--   1    0x04      2402000A    addiu $2,  $0, 10          $2  = 10
--   2    0x08      00221821    addu  $3,  $1, $2           $3  = 15
--   3    0x0C      00412023    subu  $4,  $2, $1           $4  =  5
--   4    0x10      00222824    and   $5,  $1, $2           $5  =  0
--   5    0x14      00223025    or    $6,  $1, $2           $6  = 15
--   6    0x18      00013880    sll   $7,  $1,  2           $7  = 20
--   7    0x1C      10240001    beq   $1,  $4, +1           taken->skip 8
--   8    0x20      24080063    addiu $8,  $0, 99           SKIPPED
--   9    0x24      AC03FFFC    sw    $3,  -4($0)           OutPort=15  [1]
--  10    0x28      340800F0    ori   $8,  $0, 0xF0         $8  =240
--  11    0x2C      382A0007    xori  $10, $1,  7           $10 =  2
--  12    0x30      AC0AFFFC    sw    $10, -4($0)           OutPort= 2  [2]
--  13    0x34      00075882    srl   $11, $7,  2           $11 =  5
--  14    0x38      282C0008    slti  $12, $1,  8           $12 =  1
--  15    0x3C      AC0CFFFC    sw    $12, -4($0)           OutPort= 1  [3]
--  16    0x40      14220001    bne   $1,  $2, +1           taken->skip 17
--  17    0x44      240F0063    addiu $15, $0, 99           SKIPPED
--  18    0x48      AC01FFFC    sw    $1,  -4($0)           OutPort= 5  [4]
--  19    0x4C      00220018    mult  $1,  $2                HI:LO=50
--  20    0x50      00008012    mflo  $16                    $16 =50
--  21    0x54      AC10FFFC    sw    $16, -4($0)           OutPort=50  [5]
--  22    0x58      2411004D    addiu $17, $0, 77            $17 =77
--  23    0x5C      AC110080    sw    $17, 0x80($0)          mem[0x80]=77
--  24    0x60      8C120080    lw    $18, 0x80($0)          $18 =77
--  25    0x64      AC12FFFC    sw    $18, -4($0)           OutPort=77  [6]
--  26    0x68      08000000    j     0                      loop

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity RAM is
    port (
        address : in  std_logic_vector(7 downto 0);
        clock   : in  std_logic;
        data    : in  std_logic_vector(31 downto 0);
        wren    : in  std_logic;
        q       : out std_logic_vector(31 downto 0)
    );
end RAM;

architecture behavioral of RAM is

    type mem_array is array(0 to 255) of std_logic_vector(31 downto 0);

    signal mem : mem_array := (
        -- Phase 1: addiu, addu, subu, and, or, sll + beq (taken) + sw OutPort=15
        0  => x"24010005",   -- addiu $1,  $0,  5
        1  => x"2402000A",   -- addiu $2,  $0, 10
        2  => x"00221821",   -- addu  $3,  $1, $2
        3  => x"00412023",   -- subu  $4,  $2, $1
        4  => x"00222824",   -- and   $5,  $1, $2
        5  => x"00223025",   -- or    $6,  $1, $2
        6  => x"00013880",   -- sll   $7,  $1,  2
        7  => x"10240001",   -- beq   $1,  $4, +1
        8  => x"24080063",   -- addiu $8,  $0, 99  [SKIPPED]
        9  => x"AC03FFFC",   -- sw    $3,  -4($0)  OutPort=15

        -- Phase 2: ori, xori + sw OutPort=2
        10 => x"340800F0",   -- ori   $8,  $0, 0xF0
        11 => x"382A0007",   -- xori  $10, $1,  7
        12 => x"AC0AFFFC",   -- sw    $10, -4($0)  OutPort=2

        -- Phase 3: srl, slti + sw OutPort=1
        13 => x"00075882",   -- srl   $11, $7,  2
        14 => x"282C0008",   -- slti  $12, $1,  8
        15 => x"AC0CFFFC",   -- sw    $12, -4($0)  OutPort=1

        -- Phase 4: bne (taken) + sw OutPort=5
        16 => x"14220001",   -- bne   $1,  $2, +1
        17 => x"240F0063",   -- addiu $15, $0, 99  [SKIPPED]
        18 => x"AC01FFFC",   -- sw    $1,  -4($0)  OutPort=5

        -- Phase 5: mult, mflo + sw OutPort=50
        19 => x"00220018",   -- mult  $1,  $2
        20 => x"00008012",   -- mflo  $16
        21 => x"AC10FFFC",   -- sw    $16, -4($0)  OutPort=50

        -- Phase 6: addiu, sw-to-data, lw-from-data + sw OutPort=77
        22 => x"2411004D",   -- addiu $17, $0, 77
        23 => x"AC110080",   -- sw    $17, 0x80($0)  mem[word32]=77
        24 => x"8C120080",   -- lw    $18, 0x80($0)  $18=77
        25 => x"AC12FFFC",   -- sw    $18, -4($0)  OutPort=77

        -- Loop
        26 => x"08000000",   -- j     0

        others => x"00000000"
    );

begin

    -- Synchronous write
    process(clock)
    begin
        if rising_edge(clock) then
            if wren = '1' then
                mem(to_integer(unsigned(address))) <= data;
            end if;
        end if;
    end process;

    -- Asynchronous read (altsyncram OUTDATA_REG_A = "UNREGISTERED")
    q <= mem(to_integer(unsigned(address)));

end behavioral;

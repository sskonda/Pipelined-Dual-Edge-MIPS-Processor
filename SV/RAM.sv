// Behavioral RAM for simulation — SystemVerilog translation of sim/RAM.vhd
// Replaces Altera altsyncram megafunction (not portable).
// 256 words x 32 bits, synchronous write, asynchronous read.
//
// Test program (27 words, loops):
//   Phase 1: addiu/addu/subu/and/or/sll + beq (taken)  -> OutPort = 15
//   Phase 2: ori / xori                                 -> OutPort =  2
//   Phase 3: srl / slti                                 -> OutPort =  1
//   Phase 4: bne (taken)                                -> OutPort =  5
//   Phase 5: mult / mflo                                -> OutPort = 50
//   Phase 6: lw / sw round-trip                         -> OutPort = 77
//   Word 26: j 0 (loop)

module RAM (
  input  logic [7:0]  address,
  input  logic        clock,
  input  logic [31:0] data,
  input  logic        wren,
  output logic [31:0] q
);
  logic [31:0] mem [0:255];

  initial begin
    // Phase 1
    mem[0]  = 32'h24010005; // addiu $1,  $0,  5
    mem[1]  = 32'h2402000A; // addiu $2,  $0, 10
    mem[2]  = 32'h00221821; // addu  $3,  $1, $2   ($3=15)
    mem[3]  = 32'h00412023; // subu  $4,  $2, $1   ($4=5)
    mem[4]  = 32'h00222824; // and   $5,  $1, $2   ($5=0)
    mem[5]  = 32'h00223025; // or    $6,  $1, $2   ($6=15)
    mem[6]  = 32'h00013880; // sll   $7,  $1,  2   ($7=20)
    mem[7]  = 32'h10240001; // beq   $1,  $4, +1   (taken, skip word 8)
    mem[8]  = 32'h24080063; // addiu $8,  $0, 99   [SKIPPED]
    mem[9]  = 32'hAC03FFFC; // sw    $3,  -4($0)   OutPort=15  [1]
    // Phase 2
    mem[10] = 32'h340800F0; // ori   $8,  $0, 0xF0 ($8=240)
    mem[11] = 32'h382A0007; // xori  $10, $1,  7   ($10=2)
    mem[12] = 32'hAC0AFFFC; // sw    $10, -4($0)   OutPort=2   [2]
    // Phase 3
    mem[13] = 32'h00075882; // srl   $11, $7,  2   ($11=5)
    mem[14] = 32'h282C0008; // slti  $12, $1,  8   ($12=1)
    mem[15] = 32'hAC0CFFFC; // sw    $12, -4($0)   OutPort=1   [3]
    // Phase 4
    mem[16] = 32'h14220001; // bne   $1,  $2, +1   (taken, skip word 17)
    mem[17] = 32'h240F0063; // addiu $15, $0, 99   [SKIPPED]
    mem[18] = 32'hAC01FFFC; // sw    $1,  -4($0)   OutPort=5   [4]
    // Phase 5
    mem[19] = 32'h00220018; // mult  $1,  $2        HI:LO=50
    mem[20] = 32'h00008012; // mflo  $16            $16=50
    mem[21] = 32'hAC10FFFC; // sw    $16, -4($0)   OutPort=50  [5]
    // Phase 6
    mem[22] = 32'h2411004D; // addiu $17, $0, 77   $17=77
    mem[23] = 32'hAC110080; // sw    $17, 0x80($0) mem[0x20]=77
    mem[24] = 32'h8C120080; // lw    $18, 0x80($0) $18=77
    mem[25] = 32'hAC12FFFC; // sw    $18, -4($0)   OutPort=77  [6]
    // Loop
    mem[26] = 32'h08000000; // j     0
    // Remaining words
    for (int i = 27; i < 256; i++) mem[i] = 32'h0;
  end

  // Synchronous write
  always_ff @(posedge clock) begin
    if (wren)
      mem[address] <= data;
  end

  // Asynchronous read (mirrors altsyncram OUTDATA_REG_A = "UNREGISTERED")
  assign q = mem[address];
endmodule

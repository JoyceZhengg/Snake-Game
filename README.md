# Snake-Game

429h final project - Snake running on an FPGA.

- 8 registers: `r0` through `r7`
- Registers are 16 bits wide
- Instructions are 16 bits wide
- Instruction fetch uses a word-addressed PC internally, but branch targets are
  supplied as byte addresses in registers. The CPU uses `r[t][15:1]` as the
  next PC, so branch targets should be even addresses.
- `r0` always reads as zero.
- Writing `r0` does not store a value; in simulation it prints the written
  value as a character.

## Immediate And Memory Behavior
- Most immediates are 8 bits
- `MOVL`, `MOVH` 
- `STRI` and `STR` write only one byte to memory.
- `LDR` reads two consecutive bytes and returns `{mem[a], mem[a + 1]}`.

`snakeGame.s` uses padded 2 byte slots for scalar game state b/c we want byte sized values, but the current load path returns 16 bits per read

## Assembler Syntax

The current assembler is `tools/assemble.cpp`.

- Registers are written as `r0` through `r7`.
- Comments use `//`.
- Labels use `label:`.
- Immediates may be decimal, hex like `0x40`, or character literals like
  `'A'` and `'\n'`.
- Branch target helpers `lo(label)` and `hi(label)` are supported.

## ISA
- `NOP`
  - 0000000000000000
  - This is treated as an inert squashed word by the current CPU pipeline.

- `HALT`
  - 000001xxxxxxxxxx
  - Assembler emits the canonical encoding `0000011111111111`

- `RAND rT` or `MOVR rT`
  - 0000100000000ttt
  - r[t] = sign_extend(random_byte)

### Arithmetic

- `ADDI rT, imm`
  - 0010iiiiiiiittt
  - r[t] = r[t] + zero_extend(imm)

- `SUBI rT, imm`
  - 00011iiiiiiiittt
  -  r[t] = r[t] - zero_extend(imm)

- `ADD rT, rA, rB`
  - 0010000aaabbbttt
  -  r[t] = r[a] + r[b]

- `SUB rT, rA, rB`
  - 0010100aaabbbttt
  -  r[t] = r[a] - r[b]

### Data Transfer

- `MOVL rT, imm`
  - 00110iiiiiiiittt
  -  r[t] = sign_extend(imm)

- `MOVH rT, imm`
  - 00111iiiiiiiittt
  -  r[t] = {imm, r[t][7:0]}

### Branching

- BR rT
  - 0100000000000ttt
  -  pc = r[t][15:1]

- `BEQ rT, rA, rB`
  - 0100100aaabbbttt
  -  pc = (r[a] == r[b]) ? r[t][15:1] : pc + 1

- `BNE rT, rA, rB`
  - 0100101aaabbbttt
  -  pc = (r[a] != r[b]) ? r[t][15:1] : pc + 1

- BEQI rT, rA, imm
  - 10iiiiiaaaiiittt
  -  pc = (r[a] == zero_extend(imm)) ? r[t][15:1] : pc + 1

### Memory Access

- `STRI rA, imm`
  - 11110iiaaaiiiiii
  -  mem[r[a]] = imm[7:0]

- `LDR rT, rA`
  - 1111100aaa000ttt
  - r[t] = {mem[r[a]], mem[r[a] + 1]}

- `STR rA, rT`
  - 1111100aaa001ttt
  - mem[r[a]] = r[t][7:0]

## Building `snakeGame.bin`

From the repo root:

```sh
make snakeGame.bin
```

That builds the C++ assembler and then assembles `snakeGame.s` into
`snakeGame.bin`.

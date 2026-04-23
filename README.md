# Snake-Game

429h final project - Snake running on an FPGA.

This README describes the current implementation in `cpu.v`, `mem.v`,
`ioregs.v`, and `tools/assemble.cpp`. It supersedes the older simplified
8-bit ISA description.

## Machine Model

- There are 8 registers: `r0` through `r7`.
- Registers are 16 bits wide.
- Instructions are 16 bits wide.
- Instruction fetch uses a word-addressed PC internally, but branch targets are
  supplied as byte addresses in registers. The CPU uses `r[t][15:1]` as the
  next PC, so branch targets should be even addresses.
- `r0` always reads as zero.
- Writing `r0` does not store a value; in simulation it prints the written
  value as a character.

## Immediate And Memory Behavior

- Most immediates are 8 bits.
- `MOVL` sign-extends its 8-bit immediate into 16 bits.
- `MOVH` replaces the upper byte of a register and preserves the lower byte.
- `STRI` and `STR` write only one byte to memory.
- `LDR` reads two consecutive bytes and returns `{mem[a], mem[a + 1]}`.

That last point is why `snakeGame.s` uses padded 2-byte slots for scalar game
state: it wants byte-sized values, but the current load path returns 16 bits at
once.

## Assembler Syntax

The current assembler is `tools/assemble.cpp`.

- Registers are written as `r0` through `r7`.
- Comments use `//`.
- Labels use `label:`.
- Immediates may be decimal, hex like `0x40`, or character literals like
  `'A'` and `'\n'`.
- Branch target helpers `lo(label)` and `hi(label)` are supported.

Example:

```asm
_loop:
    SUBI r1, 1
    MOVL r7, lo(_loop)
    MOVH r7, hi(_loop)
    BNE  r7, r1, r0
```

## Assembler-Supported ISA

### Other

- `NOP`
  - Assembler encoding: `0000000000000000`
  - This is treated as an inert squashed word by the current CPU pipeline.

- `HALT`
  - Decode pattern: `000001xxxxxxxxxx`
  - Assembler emits the canonical encoding `0000011111111111`

- `RAND rT` or `MOVR rT`
  - Encoding: `0000100000000ttt`
  - Effect: `r[t] = sign_extend(random_byte)`

### Arithmetic

- `ADDI rT, imm`
  - Encoding: `00010iiiiiiiittt`
  - Effect: `r[t] = r[t] + zero_extend(imm)`

- `SUBI rT, imm`
  - Encoding: `00011iiiiiiiittt`
  - Effect: `r[t] = r[t] - zero_extend(imm)`

- `ADD rT, rA, rB`
  - Encoding: `0010000aaabbbttt`
  - Effect: `r[t] = r[a] + r[b]`

- `SUB rT, rA, rB`
  - Encoding: `0010100aaabbbttt`
  - Effect: `r[t] = r[a] - r[b]`

### Data Transfer

- `MOVL rT, imm`
  - Encoding: `00110iiiiiiiittt`
  - Effect: `r[t] = sign_extend(imm)`

- `MOVH rT, imm`
  - Encoding: `00111iiiiiiiittt`
  - Effect: `r[t] = {imm, r[t][7:0]}`

### Branching

- `BR rT`
  - Encoding: `0100000000000ttt`
  - Effect: `pc = r[t][15:1]`

- `BEQ rT, rA, rB`
  - Encoding: `0100100aaabbbttt`
  - Effect: `pc = (r[a] == r[b]) ? r[t][15:1] : pc + 1`

- `BNE rT, rA, rB`
  - Encoding: `0100101aaabbbttt`
  - Effect: `pc = (r[a] != r[b]) ? r[t][15:1] : pc + 1`

- `BEQI rT, rA, imm`
  - Encoding: `10iiiiiaaaiiittt`
  - Effect: `pc = (r[a] == zero_extend(imm)) ? r[t][15:1] : pc + 1`

### Memory Access

- `STRI rA, imm`
  - Encoding: `11110iiaaaiiiiii`
  - Effect: `mem[r[a]] = imm[7:0]`

- `LDR rT, rA`
  - Encoding: `1111100aaa000ttt`
  - Effect: `r[t] = {mem[r[a]], mem[r[a] + 1]}`

- `STR rA, rT`
  - Encoding: `1111100aaa001ttt`
  - Effect: `mem[r[a]] = r[t][7:0]`

## Notes About The RTL

- `cpu.v` currently also contains load/store pair decode paths used internally
  by the pipeline logic, but the assembler does not expose mnemonics for them
  and `snakeGame.s` does not use them.
- The practical source of truth for instruction behavior is the RTL, especially
  `cpu.v`, `mem.v`, and `ioregs.v`.

## Building `snakeGame.bin`

From the repo root:

```sh
make snakeGame.bin
```

That builds the C++ assembler and then assembles `snakeGame.s` into
`snakeGame.bin`.

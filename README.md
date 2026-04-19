# Snake-Game
429h final project - Snake Game running on an FPGA

Instruction Set:
Assume there are eight 8-bit registers numbered 0-7. Instructions are 16 bits.
Other
    NOP
        00000xxxxxxxxxxx
        Does nothing
    Halt
        00001xxxxxxxxxxx
        Halts processing

Arithmetic
    Add immediate
        00010iiiiiiiittt
        r[t] = r[t] + imm
    Sub immediate
        00011iiiiiiiittt
        r[t] = r[t] - imm
    Add registers
        0010000aaabbbttt
        r[t] = r[a] + r[b]
    Sub registers
        0010100aaabbbttt
        r[t] = r[a] - r[b]
    Undef
        0010001xxxxxxxxx
        0010010xxxxxxxxx
        0010011xxxxxxxxx
        0010101xxxxxxxxx
        0010110xxxxxxxxx
        0010111xxxxxxxxx

Data Transfer
    Move immediate
        00110iiiiiiiittt
        r[t] = imm
    Fill random
        0011100000000ttt
        r[t] = random
    Undef
        00111xxxxxxxxxxx

Branching
    Branch unconditionally
        0100000000000ttt
        pc = r[t]
    Branch if registers equal
        0100100aaabbbttt
        pc = (r[a] == r[b]) ? r[t] : pc + 1
    Branch if registers not equal
        0100101aaabbbttt
        pc = (r[a] != r[b]) ? r[t] : pc + 1
    Branch if register equals immediate
        10iiiiiaaaiiittt
        pc = (r[a] == imm) ? r[t] : pc + 1
    Undef
        0100000xxxxxxxxx
        0100001xxxxxxxxx
        0100010xxxxxxxxx
        0100110xxxxxxxxx
        0100111xxxxxxxxx

Undef
    01x1xxxxxxxxxxxx
    011xxxxxxxxxxxxx
    1100xxxxxxxxxxxx
    1101xxxxxxxxxxxx
    1110xxxxxxxxxxxx
    
Memory Access
    Store immediate
        11110iiaaaiiiiii
        mem[r[a]] = imm
    Load to register
        1111100aaa000ttt
        r[t] = mem[r[a]]
    Store from register
        1111100aaa001ttt
        mem[r[a]] = r[t]

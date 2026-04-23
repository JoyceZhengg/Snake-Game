start:
    MOVL r0, 0x00
    MOVH r0, 0x00

loop:
    // Read button
    MOVL r5, 0x00
    MOVH r5, 0xD0
    LDR  r2, r5                // r2 = button value

    // Map button to visible color
    // No button (0x00) → Green (0x00)
    MOVL r6, lo(draw_square)
    MOVH r6, hi(draw_square)
    BEQ  r6, r2, r0            // if r2 == 0, use green (0x00)

    // UP (0x01) → Blue (0x01)
    MOVL r3, 0x01
    MOVL r6, lo(button_up)
    MOVH r6, hi(button_up)
    BEQ  r6, r2, r3

    // LEFT (0x02) → Blue (0x01) 
    MOVL r3, 0x02
    MOVL r6, lo(button_left)
    MOVH r6, hi(button_left)
    BEQ  r6, r2, r3

    // DOWN (0x04) → Yellow (0x10)
    MOVL r3, 0x04
    MOVL r6, lo(button_down)
    MOVH r6, hi(button_down)
    BEQ  r6, r2, r3

    // RIGHT (0x08) → Yellow (0x10)
    MOVL r3, 0x08
    MOVL r6, lo(button_right)
    MOVH r6, hi(button_right)
    BEQ  r6, r2, r3

    // Unknown button - use green
    MOVL r2, 0x00
    MOVL r6, lo(draw_square)
    MOVH r6, hi(draw_square)
    BR   r6

button_up:
    MOVL r2, 0x01              // Blue
    MOVL r6, lo(draw_square)
    MOVH r6, hi(draw_square)
    BR   r6

button_left:
    MOVL r2, 0x01              // Blue
    MOVL r6, lo(draw_square)
    MOVH r6, hi(draw_square)
    BR   r6

button_down:
    MOVL r2, 0x10              // Yellow
    MOVL r6, lo(draw_square)
    MOVH r6, hi(draw_square)
    BR   r6

button_right:
    MOVL r2, 0x10              // Yellow
    MOVL r6, lo(draw_square)
    MOVH r6, hi(draw_square)
    BR   r6

draw_square:
    // r2 = color to draw (0x00 green, 0x01 blue, or 0x10 yellow)
    // Draw 16×12 square at center (0xA208)
    MOVL r1, 0x08
    MOVH r1, 0xA2              // r1 = 0xA208
    MOVL r4, 12                // 12 rows

draw_rows:
    ADD  r3, r1, r0            // r3 = row start
    MOVL r6, 16                // 16 columns

draw_cols:
    STR  r3, r2                // Draw pixel with color r2
    ADDI r3, 1
    SUBI r6, 1
    MOVL r7, lo(draw_cols)
    MOVH r7, hi(draw_cols)
    BNE  r7, r6, r0

    ADDI r1, 160               // Next row
    SUBI r4, 1
    MOVL r7, lo(draw_rows)
    MOVH r7, hi(draw_rows)
    BNE  r7, r4, r0

    MOVL r7, lo(loop)
    MOVH r7, hi(loop)
    BR   r7
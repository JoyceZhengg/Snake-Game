// test buttons, vram, delay

start:
    // Guarantee r0 = 0
    MOVL r0, 0x00
    MOVH r0, 0x00

    // Clear screen to green
    MOVL r1, 0x00
    MOVH r1, 0x80              // r1 = 0x8000
    MOVL r2, 0x00
    MOVH r2, 0x4B              // r2 = 19200 (160*120)

clear_screen:
    STRI r1, 0x00              // Paint green
    ADDI r1, 1
    SUBI r2, 1
    MOVL r7, lo(clear_screen)
    MOVH r7, hi(clear_screen)
    BNE  r7, r2, r0

    // Start pixel at center: 0xA5D0
    MOVL r1, 0xD0
    MOVH r1, 0xA5              // r1 = current pixel position

main_loop:
    // Draw pixel at current position (blue)
    STRI r1, 0x01

    // Small delay
    MOVL r3, 0xFF
    MOVH r3, 0x0F              // r3 = 4095

delay_loop:
    SUBI r3, 1
    MOVL r7, lo(delay_loop)
    MOVH r7, hi(delay_loop)
    BNE  r7, r3, r0

    // Erase current pixel (green)
    STRI r1, 0x00

    // Read button input
    MOVL r5, 0x00
    MOVH r5, 0xD0              // r5 = 0xD000
    LDR  r2, r5                // r2 = button

    // Check UP (0x01)
    MOVL r7, lo(move_up)
    MOVH r7, hi(move_up)
    BEQI r7, r2, 1

    // Check LEFT (0x02)
    MOVL r7, lo(move_left)
    MOVH r7, hi(move_left)
    BEQI r7, r2, 2

    // Check DOWN (0x04)
    MOVL r7, lo(move_down)
    MOVH r7, hi(move_down)
    BEQI r7, r2, 4

    // Check RIGHT (0x08)
    MOVL r7, lo(move_right)
    MOVH r7, hi(move_right)
    BEQI r7, r2, 8

    // No button - just loop
    MOVL r7, lo(main_loop)
    MOVH r7, hi(main_loop)
    BR   r7

move_up:
    SUBI r1, 160               // Move up one row
    MOVL r7, lo(main_loop)
    MOVH r7, hi(main_loop)
    BR   r7

move_left:
    SUBI r1, 1                 // Move left one pixel
    MOVL r7, lo(main_loop)
    MOVH r7, hi(main_loop)
    BR   r7

move_down:
    ADDI r1, 160               // Move down one row
    MOVL r7, lo(main_loop)
    MOVH r7, hi(main_loop)
    BR   r7

move_right:
    ADDI r1, 1                 // Move right one pixel
    MOVL r7, lo(main_loop)
    MOVH r7, hi(main_loop)
    BR   r7
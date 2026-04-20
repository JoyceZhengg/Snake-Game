// ============================================================================
// INITIALIZATION (Equivalent to gameInit)
// ============================================================================
_start:
    // Initialize snakeHeadX (0x4000) to 20
    MOVL r5, 0x00      // Load lower byte of data memory base address [cite: 34]
    MOVH r5, 0x40      // Load upper byte of data memory base address (0x4000) [cite: 37]
    STRI r5, 20        // mem[0x4000] = 20 (WIDTH / 2) [cite: 66, 68]

    // Initialize snakeHeadY (0x4001) to 10
    MOVL r5, 0x01
    MOVH r5, 0x40
    STRI r5, 10        // mem[0x4001] = 10 (HEIGHT / 2) [cite: 66, 68]

    // Initialize Direction (0x4003) to 0 (DIR_NONE)
    MOVL r5, 0x03
    MOVH r5, 0x40
    STRI r5, 0         // mem[0x4003] = 0 [cite: 66, 68]

// ============================================================================
// MAIN GAME LOOP
// ============================================================================
_game_loop:
    
    // --- INPUT POLLING ---
    // Read the button inputs mapped to 0xD000
    MOVL r5, 0x00
    MOVH r5, 0xD0      // r5 = 0xD000 (Button MMIO Address)
    LDR  r1, r5        // r1 = mem[0xD000] (Load button states) [cite: 69, 71]

    // Compare input with Button 0 (Assume Bit 0 is UP)
    // If UP is pressed, branch to _set_dir_up
    // (Requires setting up a target address in a register for branching) [cite: 41]
    MOVL r2, 0x01      // Bitmask for UP button
    MOVL r7, <addr_of_set_dir_up_low> 
    MOVH r7, <addr_of_set_dir_up_high>
    BEQ  r7, r1, r2    // If r1 == r2, PC = r7 [cite: 44, 46]

_input_done:

    // --- GAME STEP (Move Head) ---
    // Load current direction
    MOVL r5, 0x03
    MOVH r5, 0x40
    LDR  r1, r5        // r1 = snakeDirection [cite: 69, 71]

    // Branch logic to move based on direction (omitted for brevity)
    // Example: If moving RIGHT (DIR_RIGHT = 2)
    // Load snakeHeadX, Add 1, Store snakeHeadX
    MOVL r5, 0x00
    MOVH r5, 0x40
    LDR  r2, r5        // r2 = snakeHeadX [cite: 69, 71]
    ADDI r2, 1         // r2 = r2 + 1 [cite: 14, 16]
    STR  r5, r2        // mem[0x4000] = r2 [cite: 72, 74]

    // --- VGA RENDERING ---
    // Instead of rendering the whole terminal buffer, we calculate the VRAM 
    // address for the new head: Address = 0x8000 + (Y * 160) + X
    
    // Load X
    MOVL r5, 0x00
    MOVH r5, 0x40
    LDR  r1, r5        // r1 = X [cite: 69, 71]
    
    // Load Y
    MOVL r5, 0x01
    MOVH r5, 0x40
    LDR  r2, r5        // r2 = Y [cite: 69, 71]

    // Multiply Y by 160 (Implementation of multiply using shifts/adds required here)
    // Assume result is in r3
    
    // Add X to (Y*160)
    ADD  r4, r3, r1    // r4 = (Y*160) + X [cite: 20, 22]
    
    // Add VRAM base offset (0x8000)
    MOVL r6, 0x00
    MOVH r6, 0x80      // r6 = 0x8000
    ADD  r5, r4, r6    // r5 = Target VRAM Address [cite: 20, 22]

    // Draw the Snake Head (Color Code 0x01 = BLUE)
    STRI r5, 0x01      // mem[VRAM_ADDR] = 0x01 [cite: 66, 68]

    // --- DELAY LOOP ---
    // Execute a nested subtraction loop to stall the CPU and control game speed
    MOVL r1, 0xFF
    MOVH r1, 0xFF      // Load large number into r1 [cite: 34, 37]
_delay:
    SUBI r1, 1         // Decrement counter [cite: 17, 19]
    MOVL r0, 0x00      
    MOVL r7, <addr_of_delay_low>
    MOVH r7, <addr_of_delay_high>
    BNE  r7, r1, r0    // If r1 != 0, loop back to _delay [cite: 47, 49]

    // Loop back to start of game loop
    MOVL r7, <addr_of_game_loop_low>
    MOVH r7, <addr_of_game_loop_high>
    BR   r7            // Unconditional branch to _game_loop [cite: 41, 43]
//   left = addr - 1
//   right = addr + 1
//   up = addr - 160
//   down = addr + 160

// Colors:
//   0x00 = background / green
//   0x01 = snake / wall / blue
//   0x10 = banana / yellow

// Direction encodings:
//   DIR_NONE = 0
//   DIR_LEFT = 1
//   DIR_RIGHT = 2
//   DIR_UP = 3
//   DIR_DOWN = 4

// Assumed button mapping for mem[0xD000]:
//   0x01 = UP
//   0x02 = LEFT
//   0x04 = DOWN
//   0x08 = RIGHT

// Data memory map:
//   0x4000 : snakeHeadAddr
//   0x4002 : snakeTailLen
//   0x4004 : snakeDirection
//   0x4006 : bananaAddr
//   0x4008 : snakeScore
//   0x400A : snakeGameOver
//   0x400C : tailReadPtr
//   0x400E : tailWritePtr
//   0x4010 : tmpNextHead

// Tail queue:
//   0x4100 - 0x41C9 : 101 slots, 2 bytes each
//   exclusive wrap address = 0x41CA

// VRAM:
//   160x120 logical grid
//   valid addresses 0x8000 - 0xCAFF
//   exclusive wrap address = 0xCB00
//


// gameInit

_start:
    // Clear game-state words at 0x4000 through 0x4012.
    MOVL r5, 0x00
    MOVH r5, 0x40
    MOVL r4, 10
_clear_state_words:
    STR  r5, r0
    ADDI r5, 2
    SUBI r4, 1
    MOVL r7, lo(_clear_state_words)
    MOVH r7, hi(_clear_state_words)
    BNE  r7, r4, r0

    // Clear the whole 160x120 framebuffer to background.
    MOVL r1, 0x00
    MOVH r1, 0x80
    MOVL r2, 120
_clear_vram_rows:
    ADD  r3, r1, r0
    MOVL r4, 0xA0
    MOVH r4, 0x00
_clear_vram_cols:
    STRI r3, 0x00
    ADDI r3, 1
    SUBI r4, 1
    MOVL r7, lo(_clear_vram_cols)
    MOVH r7, hi(_clear_vram_cols)
    BNE  r7, r4, r0
    ADDI r1, 160
    SUBI r2, 1
    MOVL r7, lo(_clear_vram_rows)
    MOVH r7, hi(_clear_vram_rows)
    BNE  r7, r2, r0

    // Draw blue top border.
    MOVL r1, 0x00
    MOVH r1, 0x80
    MOVL r2, 0xA0
    MOVH r2, 0x00
_draw_top_border:
    STRI r1, 0x01
    ADDI r1, 1
    SUBI r2, 1
    MOVL r7, lo(_draw_top_border)
    MOVH r7, hi(_draw_top_border)
    BNE  r7, r2, r0

    // Draw blue bottom border. 0xCA60 = 0x8000 + 119 * 160.
    MOVL r1, 0x60
    MOVH r1, 0xCA
    MOVL r2, 0xA0
    MOVH r2, 0x00
_draw_bottom_border:
    STRI r1, 0x01
    ADDI r1, 1
    SUBI r2, 1
    MOVL r7, lo(_draw_bottom_border)
    MOVH r7, hi(_draw_bottom_border)
    BNE  r7, r2, r0

    // Draw blue left and right borders.
    MOVL r1, 0x00
    MOVH r1, 0x80
    MOVL r2, 120
_draw_side_borders:
    STRI r1, 0x01
    MOVL r3, 0x9F
    MOVH r3, 0x00
    ADD  r3, r1, r3
    STRI r3, 0x01
    ADDI r1, 160
    SUBI r2, 1
    MOVL r7, lo(_draw_side_borders)
    MOVH r7, hi(_draw_side_borders)
    BNE  r7, r2, r0

    // snakeHeadAddr = 0xA5D0, the center of the 160x120 grid.
    MOVL r1, 0xD0
    MOVH r1, 0xA5
    MOVL r5, 0x00
    MOVH r5, 0x40
    STR  r5, r1
    STRI r1, 0x01

    // Initialize circular queue with the starting head address.
    MOVL r5, 0x00
    MOVH r5, 0x41
    STR  r5, r1

    // tailReadPtr = 0x4100.
    MOVL r1, 0x00
    MOVH r1, 0x41
    MOVL r5, 0x0C
    MOVH r5, 0x40
    STR  r5, r1

    // tailWritePtr = 0x4102.
    MOVL r1, 0x02
    MOVH r1, 0x41
    MOVL r5, 0x0E
    MOVH r5, 0x40
    STR  r5, r1

    // Spawn the first banana, then enter the main loop.
    MOVL r7, lo(_main_loop)
    MOVH r7, hi(_main_loop)
    MOVL r6, lo(_spawn_banana)
    MOVH r6, hi(_spawn_banana)
    BR   r6


// Main loop and input
_main_loop:
    MOVL r5, 0x00
    MOVH r5, 0xD0
    LDR  r1, r5

// switch between directions
    MOVL r6, lo(_dir_up_pressed)
    MOVH r6, hi(_dir_up_pressed)
    BEQI r6, r1, 1

    MOVL r6, lo(_dir_left_pressed)
    MOVH r6, hi(_dir_left_pressed)
    BEQI r6, r1, 2

    MOVL r6, lo(_dir_down_pressed)
    MOVH r6, hi(_dir_down_pressed)
    BEQI r6, r1, 4

    MOVL r6, lo(_dir_right_pressed)
    MOVH r6, hi(_dir_right_pressed)
    BEQI r6, r1, 8

    MOVL r7, lo(_after_input)
    MOVH r7, hi(_after_input)
    BR   r7

_dir_up_pressed:
    MOVL r2, 3
    MOVL r6, lo(_apply_direction)
    MOVH r6, hi(_apply_direction)
    BR   r6

_dir_left_pressed:
    MOVL r2, 1
    MOVL r6, lo(_apply_direction)
    MOVH r6, hi(_apply_direction)
    BR   r6

_dir_down_pressed:
    MOVL r2, 4
    MOVL r6, lo(_apply_direction)
    MOVH r6, hi(_apply_direction)
    BR   r6

_dir_right_pressed:
    MOVL r2, 2
    MOVL r6, lo(_apply_direction)
    MOVH r6, hi(_apply_direction)
    BR   r6

_apply_direction:
    // r2 = candidate direction. 
    // if no tail yet accept immediately
    MOVL r5, 0x02
    MOVH r5, 0x40
    LDR  r3, r5
    MOVL r6, lo(_store_direction)
    MOVH r6, hi(_store_direction)
    BEQ  r6, r3, r0

    // else block exact reverse turns
    MOVL r5, 0x04
    MOVH r5, 0x40
    LDR  r3, r5

    MOVL r6, lo(_candidate_is_left)
    MOVH r6, hi(_candidate_is_left)
    BEQI r6, r2, 1

    MOVL r6, lo(_candidate_is_right)
    MOVH r6, hi(_candidate_is_right)
    BEQI r6, r2, 2

    MOVL r6, lo(_candidate_is_up)
    MOVH r6, hi(_candidate_is_up)
    BEQI r6, r2, 3

    MOVL r6, lo(_candidate_is_down)
    MOVH r6, hi(_candidate_is_down)
    BEQI r6, r2, 4

    MOVL r7, lo(_after_input)
    MOVH r7, hi(_after_input)
    BR   r7

_candidate_is_left:
    MOVL r6, lo(_after_input)
    MOVH r6, hi(_after_input)
    BEQI r6, r3, 2
    MOVL r6, lo(_store_direction)
    MOVH r6, hi(_store_direction)
    BR   r6

_candidate_is_right:
    MOVL r6, lo(_after_input)
    MOVH r6, hi(_after_input)
    BEQI r6, r3, 1
    MOVL r6, lo(_store_direction)
    MOVH r6, hi(_store_direction)
    BR   r6

_candidate_is_up:
    MOVL r6, lo(_after_input)
    MOVH r6, hi(_after_input)
    BEQI r6, r3, 4
    MOVL r6, lo(_store_direction)
    MOVH r6, hi(_store_direction)
    BR   r6

_candidate_is_down:
    MOVL r6, lo(_after_input)
    MOVH r6, hi(_after_input)
    BEQI r6, r3, 3
    MOVL r6, lo(_store_direction)
    MOVH r6, hi(_store_direction)
    BR   r6

_store_direction:
    MOVL r5, 0x04
    MOVH r5, 0x40
    STR  r5, r2
    MOVL r7, lo(_after_input)
    MOVH r7, hi(_after_input)
    BR   r7



// Game step

_after_input:
    // If game over, keep delaying without changing the screen.
    MOVL r5, 0x0A
    MOVH r5, 0x40
    LDR  r1, r5
    MOVL r7, lo(_delay)
    MOVH r7, hi(_delay)
    BNE  r7, r1, r0

    // If direction is none, wait for the first button press.
    MOVL r5, 0x04
    MOVH r5, 0x40
    LDR  r2, r5
    MOVL r7, lo(_delay)
    MOVH r7, hi(_delay)
    BEQ  r7, r2, r0

    // r1 = current head address.
    MOVL r5, 0x00
    MOVH r5, 0x40
    LDR  r1, r5

    MOVL r7, lo(_move_left)
    MOVH r7, hi(_move_left)
    BEQI r7, r2, 1

    MOVL r7, lo(_move_right)
    MOVH r7, hi(_move_right)
    BEQI r7, r2, 2

    MOVL r7, lo(_move_up)
    MOVH r7, hi(_move_up)
    BEQI r7, r2, 3

    MOVL r7, lo(_move_down)
    MOVH r7, hi(_move_down)
    BEQI r7, r2, 4

    MOVL r7, lo(_delay)
    MOVH r7, hi(_delay)
    BR   r7

_move_left:
    SUBI r1, 1
    MOVL r6, lo(_after_move_math)
    MOVH r6, hi(_after_move_math)
    BR   r6

_move_right:
    ADDI r1, 1
    MOVL r6, lo(_after_move_math)
    MOVH r6, hi(_after_move_math)
    BR   r6

_move_up:
    SUBI r1, 160
    MOVL r6, lo(_after_move_math)
    MOVH r6, hi(_after_move_math)
    BR   r6

_move_down:
    ADDI r1, 160
    MOVL r6, lo(_after_move_math)
    MOVH r6, hi(_after_move_math)
    BR   r6

_after_move_math:
    // Save next head address while helper routines use registers freely.
    MOVL r5, 0x10
    MOVH r5, 0x40
    STR  r5, r1

    // Read the destination pixel.
    LDR  r2, r1
    MOVL r3, 0x10
    MOVL r7, lo(_eat_banana)
    MOVH r7, hi(_eat_banana)
    BEQ  r7, r2, r3

    // Not eating: erase the old tail/head first, then test for wall/body.
    MOVL r7, lo(_after_tail_erased_for_check)
    MOVH r7, hi(_after_tail_erased_for_check)
    MOVL r6, lo(_erase_tail)
    MOVH r6, hi(_erase_tail)
    BR   r6

_after_tail_erased_for_check:
    MOVL r5, 0x10
    MOVH r5, 0x40
    LDR  r1, r5
    LDR  r2, r1
    MOVL r3, 0x01
    MOVL r7, lo(_set_game_over)
    MOVH r7, hi(_set_game_over)
    BEQ  r7, r2, r3

    MOVL r7, lo(_delay)
    MOVH r7, hi(_delay)
    MOVL r6, lo(_commit_head)
    MOVH r6, hi(_commit_head)
    BR   r6

_eat_banana:
    // score++
    MOVL r5, 0x08
    MOVH r5, 0x40
    LDR  r2, r5
    ADDI r2, 1
    STR  r5, r2

    // If the tail is already full, erase one old segment to keep max length.
    MOVL r5, 0x02
    MOVH r5, 0x40
    LDR  r4, r5
    MOVL r7, lo(_eat_at_max_tail)
    MOVH r7, hi(_eat_at_max_tail)
    BEQI r7, r4, 100

    ADDI r4, 1
    STR  r5, r4
    MOVL r7, lo(_spawn_after_commit)
    MOVH r7, hi(_spawn_after_commit)
    MOVL r6, lo(_commit_head)
    MOVH r6, hi(_commit_head)
    BR   r6

_eat_at_max_tail:
    MOVL r7, lo(_eat_full_tail_erased)
    MOVH r7, hi(_eat_full_tail_erased)
    MOVL r6, lo(_erase_tail)
    MOVH r6, hi(_erase_tail)
    BR   r6

_eat_full_tail_erased:
    MOVL r7, lo(_spawn_after_commit)
    MOVH r7, hi(_spawn_after_commit)
    MOVL r6, lo(_commit_head)
    MOVH r6, hi(_commit_head)
    BR   r6

_spawn_after_commit:
    MOVL r7, lo(_delay)
    MOVH r7, hi(_delay)
    MOVL r6, lo(_spawn_banana)
    MOVH r6, hi(_spawn_banana)
    BR   r6



// Queue helpers

_erase_tail:
    // Load tailReadPtr, then load and erase the oldest VRAM address.
    MOVL r5, 0x0C
    MOVH r5, 0x40
    LDR  r4, r5
    LDR  r3, r4
    STRI r3, 0x00

    // Advance tailReadPtr by one queue slot, wrapping at 0x41CA.
    ADDI r4, 2
    MOVL r3, 0xCA
    MOVH r3, 0x41
    MOVL r6, lo(_erase_tail_store_ptr)
    MOVH r6, hi(_erase_tail_store_ptr)
    BNE  r6, r4, r3
    MOVL r4, 0x00
    MOVH r4, 0x41
_erase_tail_store_ptr:
    MOVL r5, 0x0C
    MOVH r5, 0x40
    STR  r5, r4
    BR   r7

_commit_head:
    // Draw new head.
    MOVL r5, 0x10
    MOVH r5, 0x40
    LDR  r1, r5
    STRI r1, 0x01

    // snakeHeadAddr = nextHead.
    MOVL r5, 0x00
    MOVH r5, 0x40
    STR  r5, r1

    // Store new head address at tailWritePtr.
    MOVL r5, 0x0E
    MOVH r5, 0x40
    LDR  r4, r5
    STR  r4, r1

    // Advance tailWritePtr by one queue slot, wrapping at 0x41CA.
    ADDI r4, 2
    MOVL r3, 0xCA
    MOVH r3, 0x41
    MOVL r6, lo(_commit_store_write_ptr)
    MOVH r6, hi(_commit_store_write_ptr)
    BNE  r6, r4, r3
    MOVL r4, 0x00
    MOVH r4, 0x41
_commit_store_write_ptr:
    MOVL r5, 0x0E
    MOVH r5, 0x40
    STR  r5, r4
    BR   r7


// Banana spawning

_spawn_banana:
    // Start scanning from the previous banana + 1. If there is no previous
    // banana, seed near the center but away from the initial head.
    MOVL r5, 0x06
    MOVH r5, 0x40
    LDR  r1, r5
    MOVL r6, lo(_spawn_seed)
    MOVH r6, hi(_spawn_seed)
    BEQ  r6, r1, r0
    ADDI r1, 1
    MOVL r6, lo(_spawn_scan)
    MOVH r6, hi(_spawn_scan)
    BR   r6

_spawn_seed:
    MOVL r1, 0x70
    MOVH r1, 0xA6

_spawn_scan:
    // Wrap 0xCB00 back to first inner playable cell, 0x80A1.
    MOVL r3, 0x00
    MOVH r3, 0xCB
    MOVL r6, lo(_spawn_check_pixel)
    MOVH r6, hi(_spawn_check_pixel)
    BNE  r6, r1, r3
    MOVL r1, 0xA1
    MOVH r1, 0x80

_spawn_check_pixel:
    LDR  r2, r1
    MOVL r6, lo(_spawn_store)
    MOVH r6, hi(_spawn_store)
    BEQ  r6, r2, r0
    ADDI r1, 1
    MOVL r6, lo(_spawn_scan)
    MOVH r6, hi(_spawn_scan)
    BR   r6

_spawn_store:
    MOVL r5, 0x06
    MOVH r5, 0x40
    STR  r5, r1
    STRI r1, 0x10
    BR   r7


// Game over and delay

_set_game_over:
    MOVL r1, 1
    MOVL r5, 0x0A
    MOVH r5, 0x40
    STR  r5, r1
    MOVL r7, lo(_delay)
    MOVH r7, hi(_delay)
    BR   r7

_delay:
    MOVL r1, 0xFF
    MOVH r1, 0xFF
_delay_loop:
    SUBI r1, 1
    MOVL r7, lo(_delay_loop)
    MOVH r7, hi(_delay_loop)
    BNE  r7, r1, r0

    MOVL r7, lo(_main_loop)
    MOVH r7, hi(_main_loop)
    BR   r7

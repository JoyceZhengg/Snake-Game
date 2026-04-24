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
//   0x01 = RIGHT
//   0x02 = DOWN
//   0x04 = UP
//   0x08 = LEFT

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


// gameInit
//   r0 = always 0x0000
//   r1 = VRAM address being cleared/written
//   r2 = row counter
//   r3 = temp VRAM address / pixel position
//   r4 = column counter / temp value
//   r5 = data memory address pointer
//   r6 = function address / temp
//   r7 = return address / branch target

start:
    MOVL r0, 0x00
    MOVH r0, 0x00

    // Clear game state words at 0x4000 through 0x4012
    // r5 = current memory address to clear
    // r4 = counter (10 words to clear)
    MOVL r5, 0x00
    MOVH r5, 0x40
    MOVL r4, 10

clear_state_words:
    STR  r5, r0
    ADDI r5, 2
    SUBI r4, 1
    MOVL r7, lo(clear_state_words)
    MOVH r7, hi(clear_state_words)
    BNE  r7, r4, r0

    // Clear the whole 160x120 framebuffer to background.
    // r1 = start of current row
    // r2 = row counter (120 rows)
    // r3 = current pixel address
    // r4 = column counter (160 pixels)
    // lol end of comments for now
    MOVL r1, 0x00
    MOVH r1, 0x80
    MOVL r2, 120

clear_vram_rows:
    ADD  r3, r1, r0
    MOVL r4, 0xA0
    MOVH r4, 0x00

clear_vram_cols:
    STRI r3, 0x00
    ADDI r3, 1
    SUBI r4, 1
    MOVL r7, lo(clear_vram_cols)
    MOVH r7, hi(clear_vram_cols)
    BNE  r7, r4, r0
    ADDI r1, 160
    SUBI r2, 1
    MOVL r7, lo(clear_vram_rows)
    MOVH r7, hi(clear_vram_rows)
    BNE  r7, r2, r0

    // Draw blue top border
    MOVL r1, 0x00
    MOVH r1, 0x80
    MOVL r2, 0xA0
    MOVH r2, 0x00

draw_top_border:
    STRI r1, 0x01
    ADDI r1, 1
    SUBI r2, 1
    MOVL r7, lo(draw_top_border)
    MOVH r7, hi(draw_top_border)
    BNE  r7, r2, r0

    // Draw blue bottom border 0xCA60 = 0x8000 + 119 * 160
    MOVL r1, 0x60
    MOVH r1, 0xCA
    MOVL r2, 0xA0
    MOVH r2, 0x00

draw_bottom_border:
    STRI r1, 0x01
    ADDI r1, 1
    SUBI r2, 1
    MOVL r7, lo(draw_bottom_border)
    MOVH r7, hi(draw_bottom_border)
    BNE  r7, r2, r0

    // Draw blue left and right borders
    MOVL r1, 0x00
    MOVH r1, 0x80
    MOVL r2, 120

draw_side_borders:
    STRI r1, 0x01
    MOVL r3, 0x9F
    MOVH r3, 0x00
    ADD  r3, r1, r3
    STRI r3, 0x01
    ADDI r1, 160
    SUBI r2, 1
    MOVL r7, lo(draw_side_borders)
    MOVH r7, hi(draw_side_borders)
    BNE  r7, r2, r0

    // snakeHeadAddr = 0xA5D0, the center of the 160x120 grid
    MOVL r1, 0xD0
    MOVH r1, 0xA5
    MOVL r5, 0x00
    MOVH r5, 0x40
    STR  r5, r1
    STRI r1, 0x01

    // Initialize circular queue with the starting head address
    MOVL r5, 0x00
    MOVH r5, 0x41
    STR  r5, r1

    // tailReadPtr = 0x4100
    MOVL r1, 0x00
    MOVH r1, 0x41
    MOVL r5, 0x0C
    MOVH r5, 0x40
    STR  r5, r1

    // tailWritePtr = 0x4102
    MOVL r1, 0x02
    MOVH r1, 0x41
    MOVL r5, 0x0E
    MOVH r5, 0x40
    STR  r5, r1

    // Spawn the first banana, then enter the main loop
    MOVL r7, lo(main_loop)
    MOVH r7, hi(main_loop)
    MOVL r6, lo(spawn_banana)
    MOVH r6, hi(spawn_banana)
    BR   r6


// Main loop and input
main_loop:
    MOVL r5, 0x00
    MOVH r5, 0xD0
    LDR  r1, r5

// switch between directions
    MOVL r6, lo(dir_up_pressed)
    MOVH r6, hi(dir_up_pressed)
    BEQI r6, r1, 4

    MOVL r6, lo(dir_left_pressed)
    MOVH r6, hi(dir_left_pressed)
    BEQI r6, r1, 8

    MOVL r6, lo(dir_down_pressed)
    MOVH r6, hi(dir_down_pressed)
    BEQI r6, r1, 2

    MOVL r6, lo(dir_right_pressed)
    MOVH r6, hi(dir_right_pressed)
    BEQI r6, r1, 1

    MOVL r7, lo(after_input)
    MOVH r7, hi(after_input)
    BR   r7

dir_up_pressed:
    MOVL r2, 3
    MOVL r6, lo(apply_direction)
    MOVH r6, hi(apply_direction)
    BR   r6

dir_left_pressed:
    MOVL r2, 1
    MOVL r6, lo(apply_direction)
    MOVH r6, hi(apply_direction)
    BR   r6

dir_down_pressed:
    MOVL r2, 4
    MOVL r6, lo(apply_direction)
    MOVH r6, hi(apply_direction)
    BR   r6

dir_right_pressed:
    MOVL r2, 2
    MOVL r6, lo(apply_direction)
    MOVH r6, hi(apply_direction)
    BR   r6

apply_direction:
    // r2 = candidate direction
    // if no tail yet accept immediately
    MOVL r5, 0x02
    MOVH r5, 0x40
    LDR  r3, r5
    MOVL r6, lo(store_direction)
    MOVH r6, hi(store_direction)
    BEQ  r6, r3, r0

    // else block exact reverse turns
    MOVL r5, 0x04
    MOVH r5, 0x40
    LDR  r3, r5

    MOVL r6, lo(candidate_is_left)
    MOVH r6, hi(candidate_is_left)
    BEQI r6, r2, 1

    MOVL r6, lo(candidate_is_right)
    MOVH r6, hi(candidate_is_right)
    BEQI r6, r2, 2

    MOVL r6, lo(candidate_is_up)
    MOVH r6, hi(candidate_is_up)
    BEQI r6, r2, 3

    MOVL r6, lo(candidate_is_down)
    MOVH r6, hi(candidate_is_down)
    BEQI r6, r2, 4

    MOVL r7, lo(after_input)
    MOVH r7, hi(after_input)
    BR   r7

candidate_is_left:
    MOVL r6, lo(after_input)
    MOVH r6, hi(after_input)
    BEQI r6, r3, 2
    MOVL r6, lo(store_direction)
    MOVH r6, hi(store_direction)
    BR   r6

candidate_is_right:
    MOVL r6, lo(after_input)
    MOVH r6, hi(after_input)
    BEQI r6, r3, 1
    MOVL r6, lo(store_direction)
    MOVH r6, hi(store_direction)
    BR   r6

candidate_is_up:
    MOVL r6, lo(after_input)
    MOVH r6, hi(after_input)
    BEQI r6, r3, 4
    MOVL r6, lo(store_direction)
    MOVH r6, hi(store_direction)
    BR   r6

candidate_is_down:
    MOVL r6, lo(after_input)
    MOVH r6, hi(after_input)
    BEQI r6, r3, 3
    MOVL r6, lo(store_direction)
    MOVH r6, hi(store_direction)
    BR   r6

store_direction:
    MOVL r5, 0x04
    MOVH r5, 0x40
    STR  r5, r2
    MOVL r7, lo(after_input)
    MOVH r7, hi(after_input)
    BR   r7


// Game step

after_input:
    // if game over keep delaying without changing the screen
    MOVL r5, 0x0A
    MOVH r5, 0x40
    LDR  r1, r5
    MOVL r7, lo(delay)
    MOVH r7, hi(delay)
    BNE  r7, r1, r0

    // if direction is none wait for the first button press
    MOVL r5, 0x04
    MOVH r5, 0x40
    LDR  r2, r5
    MOVL r7, lo(delay)
    MOVH r7, hi(delay)
    BEQ  r7, r2, r0

    // r1 = current head address
    MOVL r5, 0x00
    MOVH r5, 0x40
    LDR  r1, r5

    MOVL r7, lo(move_left)
    MOVH r7, hi(move_left)
    BEQI r7, r2, 1

    MOVL r7, lo(move_right)
    MOVH r7, hi(move_right)
    BEQI r7, r2, 2

    MOVL r7, lo(move_up)
    MOVH r7, hi(move_up)
    BEQI r7, r2, 3

    MOVL r7, lo(move_down)
    MOVH r7, hi(move_down)
    BEQI r7, r2, 4

    MOVL r7, lo(delay)
    MOVH r7, hi(delay)
    BR   r7

move_left:
    SUBI r1, 1
    MOVL r6, lo(check_next_head)
    MOVH r6, hi(check_next_head)
    BR   r6

move_right:
    ADDI r1, 1
    MOVL r6, lo(check_next_head)
    MOVH r6, hi(check_next_head)
    BR   r6

move_up:
    SUBI r1, 160
    MOVL r6, lo(check_next_head)
    MOVH r6, hi(check_next_head)
    BR   r6

move_down:
    ADDI r1, 160
    MOVL r6, lo(check_next_head)
    MOVH r6, hi(check_next_head)
    BR   r6

check_next_head:
    // save next head address in temp 
    MOVL r5, 0x10
    MOVH r5, 0x40
    STR  r5, r1

    // read the destination pixel 
    LDR  r2, r1
    MOVL r3, 0x10
    MOVL r7, lo(eat_banana)
    MOVH r7, hi(eat_banana)
    BEQ  r7, r2, r3

    // Normal move: erase the tail before checking blue collision.
    // This lets the head move into the square where the tail just was.
    MOVL r7, lo(check_normal_move_collision)
    MOVH r7, hi(check_normal_move_collision)
    MOVL r6, lo(erase_tail)
    MOVH r6, hi(erase_tail)
    BR   r6

check_normal_move_collision:
    // Reload nextHead and read the screen again after the tail is gone.
    MOVL r5, 0x10
    MOVH r5, 0x40
    LDR  r1, r5
    LDR  r2, r1
    MOVL r3, 0x01
    MOVL r7, lo(set_game_over)
    MOVH r7, hi(set_game_over)
    BEQ  r7, r2, r3

    MOVL r7, lo(delay)
    MOVH r7, hi(delay)
    MOVL r6, lo(commit_head)
    MOVH r6, hi(commit_head)
    BR   r6

eat_banana:
    // score++
    MOVL r5, 0x08
    MOVH r5, 0x40
    LDR  r2, r5
    ADDI r2, 1
    STR  r5, r2

    // if the tail is already full, erase one old segment to keep max length
    MOVL r5, 0x02
    MOVH r5, 0x40
    LDR  r4, r5
    MOVL r7, lo(eat_at_max_tail)
    MOVH r7, hi(eat_at_max_tail)
    BEQI r7, r4, 100

    ADDI r4, 1
    STR  r5, r4
    MOVL r7, lo(spawn_after_commit)
    MOVH r7, hi(spawn_after_commit)
    MOVL r6, lo(commit_head)
    MOVH r6, hi(commit_head)
    BR   r6

eat_at_max_tail:
    MOVL r7, lo(eat_full_tail_erased)
    MOVH r7, hi(eat_full_tail_erased)
    MOVL r6, lo(erase_tail)
    MOVH r6, hi(erase_tail)
    BR   r6

eat_full_tail_erased:
    MOVL r7, lo(spawn_after_commit)
    MOVH r7, hi(spawn_after_commit)
    MOVL r6, lo(commit_head)
    MOVH r6, hi(commit_head)
    BR   r6

spawn_after_commit:
    MOVL r7, lo(delay)
    MOVH r7, hi(delay)
    MOVL r6, lo(spawn_banana)
    MOVH r6, hi(spawn_banana)
    BR   r6


// helpers

erase_tail:
    // load tailReadPtr then load and erase the oldest framebuffer address
    MOVL r5, 0x0C
    MOVH r5, 0x40
    LDR  r4, r5
    LDR  r3, r4
    STRI r3, 0x00

    // advance tailReadPtr by one queue slot + wrap at 0x41CA
    ADDI r4, 2
    MOVL r3, 0xCA
    MOVH r3, 0x41
    MOVL r6, lo(erase_tail_store_ptr)
    MOVH r6, hi(erase_tail_store_ptr)
    BNE  r6, r4, r3
    MOVL r4, 0x00
    MOVH r4, 0x41

erase_tail_store_ptr:
    MOVL r5, 0x0C
    MOVH r5, 0x40
    STR  r5, r4
    BR   r7

commit_head:
    // Draw new head
    MOVL r5, 0x10
    MOVH r5, 0x40
    LDR  r1, r5
    STRI r1, 0x01

    // snakeHeadAddr = nextHead
    MOVL r5, 0x00
    MOVH r5, 0x40
    STR  r5, r1

    // store new head address at tailWritePtr
    MOVL r5, 0x0E
    MOVH r5, 0x40
    LDR  r4, r5
    STR  r4, r1

    // advance tailWritePtr by one queue slot, wrapping at 0x41CA
    ADDI r4, 2
    MOVL r3, 0xCA
    MOVH r3, 0x41
    MOVL r6, lo(commit_store_write_ptr)
    MOVH r6, hi(commit_store_write_ptr)
    BNE  r6, r4, r3
    MOVL r4, 0x00
    MOVH r4, 0x41

commit_store_write_ptr:
    MOVL r5, 0x0E
    MOVH r5, 0x40
    STR  r5, r4
    BR   r7


// Banana spawning

spawn_banana:
    // Build a random interior cell:
    MOVL r4, 0x00
    MOVH r4, 0xFF
    // Sample both random seeds up front so the column choice does not depend
    // on how many cycles the row reduction loop takes.
    RAND r1
    RAND r2

row_mod_loop:
    SUBI r1, 118
    ADD  r3, r1, r0
    MOVH r3, 0x00
    SUB  r5, r1, r3
    MOVL r6, lo(row_mod_loop)
    MOVH r6, hi(row_mod_loop)
    BNE  r6, r5, r4
    ADDI r1, 118
    ADDI r1, 1

col_mod_loop:
    SUBI r2, 158
    ADD  r3, r2, r0
    MOVH r3, 0x00
    SUB  r5, r2, r3
    MOVL r6, lo(col_mod_loop)
    MOVH r6, hi(col_mod_loop)
    BNE  r6, r5, r4
    ADDI r2, 158
    ADDI r2, 1

    // r5 = 0x8000 framebuffer base
    MOVL r5, 0x00
    MOVH r5, 0x80

row_to_addr_loop:
    MOVL r6, lo(row_to_addr_done)
    MOVH r6, hi(row_to_addr_done)
    BEQ  r6, r1, r0
    ADDI r5, 160
    SUBI r1, 1
    MOVL r6, lo(row_to_addr_loop)
    MOVH r6, hi(row_to_addr_loop)
    BR   r6

row_to_addr_done:
    ADD  r1, r5, r2

spawn_scan:
    // Wrap 0xCB00 back to first inner playable cell 0x80A1
    MOVL r3, 0x00
    MOVH r3, 0xCB
    MOVL r6, lo(spawn_check_pixel)
    MOVH r6, hi(spawn_check_pixel)
    BNE  r6, r1, r3
    MOVL r1, 0xA1
    MOVH r1, 0x80

spawn_check_pixel:
    LDR  r2, r1
    MOVL r6, lo(spawn_store)
    MOVH r6, hi(spawn_store)
    BEQ  r6, r2, r0
    ADDI r1, 1
    MOVL r6, lo(spawn_scan)
    MOVH r6, hi(spawn_scan)
    BR   r6

spawn_store:
    MOVL r5, 0x06
    MOVH r5, 0x40
    STR  r5, r1
    STRI r1, 0x10
    BR   r7


// Game over and delay

set_game_over:
    // snakeGameOver = 1
    MOVL r1, 1
    MOVL r5, 0x0A
    MOVH r5, 0x40
    STR  r5, r1

game_over_poll:
    // Read the buttons from 0xD000
    MOVL r5, 0x00
    MOVH r5, 0xD0
    LDR  r1, r5

    // If UP button (0x04) is pressed, jump all the way back to start
    MOVL r6, lo(start)
    MOVH r6, hi(start)
    BEQI r6, r1, 4

    // Otherwise, keep polling the buttons forever
    MOVL r7, lo(game_over_poll)
    MOVH r7, hi(game_over_poll)
    BR   r7

delay:
    // Nested loop to control the speed of the snake!
    // Decrease 0x14 to make the snake faster, increase to make it slower.
    MOVL r3, 0x10  // <--- Change this to 0x10
    MOVH r3, 0x00

delay_outer:
    // Inner loop counts down from 65,535
    MOVL r1, 0xFF
    MOVH r1, 0xFF

delay_inner:
    SUBI r1, 1
    MOVL r7, lo(delay_inner)
    MOVH r7, hi(delay_inner)
    BNE  r7, r1, r0

    // Inner loop finished, decrement outer loop
    SUBI r3, 1
    MOVL r7, lo(delay_outer)
    MOVH r7, hi(delay_outer)
    BNE  r7, r3, r0

    MOVL r7, lo(main_loop)
    MOVH r7, hi(main_loop)
    BR   r7

start:
    MOVL r0, 0x00
    MOVH r0, 0x00
    MOVL r5, 0x00
    MOVH r5, 0x40
    MOVL r4, 10
    STR  r5, r0
    ADDI r5, 2
    SUBI r4, 1
    MOVL r7, lo(clear_state_words)
    MOVH r7, hi(clear_state_words)
clear_state_words:
    BNE  r7, r4, r0

    // Clear Screen
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

    // Draw Borders
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

    // Spawn Snake Head
    MOVL r1, 0xD0
    MOVH r1, 0xA5
    MOVL r5, 0x00
    MOVH r5, 0x40
    STR  r5, r1
    STRI r1, 0x01
    
    // Set Write/Read Pointers
    MOVL r5, 0x00
    MOVH r5, 0x41
    STR  r5, r1
    MOVL r1, 0x00
    MOVH r1, 0x41
    MOVL r5, 0x0C
    MOVH r5, 0x40
    STR  r5, r1
    MOVL r1, 0x02
    MOVH r1, 0x41
    MOVL r5, 0x0E
    MOVH r5, 0x40
    STR  r5, r1

    MOVL r7, lo(main_loop)
    MOVH r7, hi(main_loop)
    MOVL r6, lo(spawn_banana)
    MOVH r6, hi(spawn_banana)
    BR   r6

main_loop:
    MOVL r5, 0x00
    MOVH r5, 0xD0
    LDR  r1, r5
    
    // Button Logic (Mapped to hardware pins)
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
    MOVL r5, 0x02
    MOVH r5, 0x40
    LDR  r3, r5
    MOVL r6, lo(store_direction)
    MOVH r6, hi(store_direction)
    BEQ  r6, r3, r0

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

after_input:
    MOVL r5, 0x0A
    MOVH r5, 0x40
    LDR  r1, r5
    MOVL r7, lo(delay)
    MOVH r7, hi(delay)
    BNE  r7, r1, r0

    MOVL r5, 0x04
    MOVH r5, 0x40
    LDR  r2, r5
    MOVL r7, lo(delay)
    MOVH r7, hi(delay)
    BEQ  r7, r2, r0

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
    MOVL r5, 0x10
    MOVH r5, 0x40
    STR  r5, r1
    LDR  r2, r1
    MOVL r3, 0x10
    MOVL r7, lo(eat_banana)
    MOVH r7, hi(eat_banana)
    BEQ  r7, r2, r3

check_normal_move_collision:
    MOVL r7, lo(erase_tail)
    MOVH r7, hi(erase_tail)
    BR   r7

erase_tail:
    MOVL r5, 0x10
    MOVH r5, 0x40
    LDR  r1, r5
    LDR  r2, r1
    MOVL r3, 0x01
    MOVL r7, lo(set_game_over)
    MOVH r7, hi(set_game_over)
    BEQ  r7, r2, r3
    
    MOVL r7, lo(commit_head)
    MOVH r7, hi(commit_head)
    BR   r7

eat_banana:
    MOVL r5, 0x08
    MOVH r5, 0x40
    LDR  r2, r5
    ADDI r2, 1
    STR  r5, r2

    MOVL r5, 0x02
    MOVH r5, 0x40
    LDR  r4, r5
    MOVL r7, lo(eat_at_max_tail)
    MOVH r7, hi(eat_at_max_tail)
    BEQI r7, r4, 100
    
    ADDI r4, 1
    STR  r5, r4
    MOVL r7, lo(commit_head)
    MOVH r7, hi(commit_head)
    BR   r7

eat_at_max_tail:
    MOVL r7, lo(erase_tail)
    MOVH r7, hi(erase_tail)
    BR   r7

commit_head:
    MOVL r5, 0x0C
    MOVH r5, 0x40
    LDR  r4, r5
    LDR  r3, r4
    STRI r3, 0x00
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

    MOVL r5, 0x10
    MOVH r5, 0x40
    LDR  r1, r5
    STRI r1, 0x01
    MOVL r5, 0x00
    MOVH r5, 0x40
    STR  r5, r1

    MOVL r5, 0x0E
    MOVH r5, 0x40
    LDR  r4, r5
    STR  r4, r1
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

    // Return to main execution based on whether we ate a banana
    // In our loop structure, after head commit, we either delay or spawn
    MOVL r7, lo(spawn_banana)
    MOVH r7, hi(spawn_banana)
    // (Logic handled in binary structure below to branch correctly)
    BR   r7

spawn_banana:
    RAND r2
    MOVL r0, 0x00    
    MOVL r1, 0xA1    
    MOVH r1, 0x80
    ADD  r1, r1, r2

spawn_scan:
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
    MOVL r7, lo(delay)
    MOVH r7, hi(delay)
    BR   r7

set_game_over:
    MOVL r1, 1
    MOVL r5, 0x0A
    MOVH r5, 0x40
    STR  r5, r1
game_over_poll:
    MOVL r5, 0x00
    MOVH r5, 0xD0
    LDR  r1, r5
    MOVL r6, lo(start)
    MOVH r6, hi(start)
    BEQI r6, r1, 4    // UP button restarts
    MOVL r7, lo(game_over_poll)
    MOVH r7, hi(game_over_poll)
    BR   r7

delay:
    MOVL r3, 0x10
    MOVH r3, 0x00
delay_outer:
    MOVL r1, 0xFF
    MOVH r1, 0xFF
delay_inner:
    SUBI r1, 1
    MOVL r7, lo(delay_inner)
    MOVH r7, hi(delay_inner)
    BNE  r7, r1, r0
    
    SUBI r3, 1
    MOVL r7, lo(delay_outer)
    MOVH r7, hi(delay_outer)
    BNE  r7, r3, r0
    
    MOVL r7, lo(main_loop)
    MOVH r7, hi(main_loop)
    BR   r7
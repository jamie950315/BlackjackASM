; ===========================================
; BLACKJACK - DOS 16-bit Assembly
; ===========================================

.MODEL SMALL
.STACK 100h

BASE_BET    EQU 10


.DATA
    ; --- Game Strings ---
    crlf            DB 13, 10, '$'
    
    welcome_msg     DB 'Welcome to Blackjack!$'
    
    current_money_msg DB 13, 10, 'Your current money: $', '$'
    
    bet_prompt_base DB 13, 10, 'The base bet is 10. $'
    bet_prompt_mul  DB 'Enter multiplier (1-9) or 0 to exit: $'
    bet_mul_error   DB 13, 10, 'Error: Please enter a number between 0-9!$'
    bet_error       DB 13, 10, 'Error: You do not have enough money for this bet!$'
    
    deal_player_msg DB 13, 10, 'Dealing to Player: $'
    dealer_show_msg DB 13, 10, 'Dealer shows: $'
    dealer_reveal_msg DB 13, 10, 'Dealer reveals hand: $'
    dealer_total_msg DB 13, 10, 'Dealer total: $'
    player_sum_msg  DB 13, 10, 'Your total: $'
    card_received_msg DB 13, 10, 'You received: $'
    invalid_choice_msg DB 13, 10, 'Invalid input. Please enter 0 or 1.$'
    
    hit_prompt      DB 13, 10, 'Do you want to hit? (1=Yes, 0=No): $'
    player_bust_msg DB 13, 10, 'You busted (over 21)! You lose $'
    dealer_bust_msg DB 13, 10, 'Dealer busted! You win $'
    player_win_msg  DB 13, 10, 'You win! You win $'
    player_lose_msg DB 13, 10, 'You lose! You lose $'
    push_msg        DB 13, 10, 'Push (Tie)! Your bet is returned.$'
    
    game_over_msg   DB 13, 10, 'You do not have enough money to continue!$'
    restart_prompt  DB 13, 10, 'Restart? (1=Yes, 0=No): $'
    goodbye_msg     DB 13, 10, 'Thanks for playing!$'

    ; --- Card Value Lookup Table ---
    card_values     DB 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10
    
    ; --- Game Variables ---
    player_money    DW 500
    current_bet     DW 0
    player_sum      DW 0
    dealer_sum      DW 0
    dealer_first_card DW 0
    dealer_second_card DW 0
    
    rand_seed       DW 0


.CODE
MAIN PROC
    ; --- DOS Initialization ---
    MOV AX, @data
    MOV DS, AX


    ; --- Game Entry Point ---
_start:
    CALL GAME_INIT
    JMP MAIN_GAME_LOOP

; --- 1. Game Initialization ---
GAME_INIT:
    MOV [player_money], 500
    
    CALL PRINT_NEWLINE
    MOV DX, OFFSET welcome_msg
    CALL PRINT_STRING
    
    
    
    
    ; *** random seed ***
    MOV AH, 00h
    INT 1Ah
    MOV AX, DX
    MOV [rand_seed], AX
    
    RET

; --- 2. Main Game Loop ---
MAIN_GAME_LOOP:
    MOV AX, [player_money]
    CMP AX, BASE_BET
    JAE GET_BET
    
    CALL HANDLE_GAME_OVER
    CMP AL, '1'
    JE _start
    
    JMP NEAR PTR EXIT_GAME

; --- 3. Get Player Bet ---
GET_BET:
    CALL PRINT_NEWLINE
    MOV DX, OFFSET current_money_msg
    CALL PRINT_STRING
    MOV AX, [player_money]
    CALL PRINT_NUMBER
    
    MOV DX, OFFSET bet_prompt_base
    CALL PRINT_STRING
    MOV DX, OFFSET bet_prompt_mul
    CALL PRINT_STRING
    
    CALL READ_CHAR
    CALL PRINT_NEWLINE
    
    CMP AL, '0'
    JNE NOT_EXITING_YET
    JMP NEAR PTR EXIT_GAME
NOT_EXITING_YET:
    
    CMP AL, '1'
    JL INVALID_MULTIPLIER
    CMP AL, '9'
    JG INVALID_MULTIPLIER
    
    ; --- Calculate Bet ---
    SUB AL, '0'
    XOR AH, AH
    
    MOV BL, BASE_BET
    MUL BL
    
    MOV [current_bet], AX
    
    MOV BX, [player_money]
    CMP AX, BX
    JG INVALID_BET
    
    SUB BX, AX
    MOV [player_money], BX
    JMP DEAL_INITIAL_CARDS

INVALID_MULTIPLIER:
    MOV DX, OFFSET bet_mul_error
    CALL PRINT_STRING
    JMP GET_BET

INVALID_BET:
    MOV DX, OFFSET bet_error
    CALL PRINT_STRING
    JMP GET_BET

; --- 4. Deal Initial Cards ---
DEAL_INITIAL_CARDS:
    MOV [player_sum], 0
    MOV [dealer_sum], 0
    
    MOV DX, OFFSET deal_player_msg
    CALL PRINT_STRING
    CALL GET_CARD_VALUE
    CALL DISPLAY_CARD_RECEIVED
    LEA SI, player_sum
    CALL ADD_CARD_TO_TOTAL
    CALL GET_CARD_VALUE
    CALL DISPLAY_CARD_RECEIVED
    LEA SI, player_sum
    CALL ADD_CARD_TO_TOTAL
    
    CALL GET_CARD_VALUE
    MOV [dealer_first_card], AX
    LEA SI, dealer_sum
    CALL ADD_CARD_TO_TOTAL
    CALL GET_CARD_VALUE
    MOV [dealer_second_card], AX
    LEA SI, dealer_sum
    CALL ADD_CARD_TO_TOTAL
    
    CALL PRINT_NEWLINE
    MOV DX, OFFSET player_sum_msg
    CALL PRINT_STRING
    MOV AX, [player_sum]
    CALL PRINT_NUMBER
    
    MOV DX, OFFSET dealer_show_msg
    CALL PRINT_STRING
    MOV AX, [dealer_first_card]
    CALL PRINT_NUMBER
    
    CMP [player_sum], 21
    JE PLAYER_STAND
    JMP PLAYER_TURN

; --- 5. Player's Turn (Hit/Stand) ---
PLAYER_TURN:
PLAYER_TURN_CHOICE:
    MOV DX, OFFSET hit_prompt
    CALL PRINT_STRING
    CALL READ_CHAR
    
    CMP AL, '0'
    JE PLAYER_STAND
    CMP AL, '1'
    JE PLAYER_HIT

    CALL PRINT_NEWLINE
    MOV DX, OFFSET invalid_choice_msg
    CALL PRINT_STRING
    JMP PLAYER_TURN_CHOICE

PLAYER_HIT:
    CALL GET_CARD_VALUE
    CALL DISPLAY_CARD_RECEIVED
    LEA SI, player_sum
    CALL ADD_CARD_TO_TOTAL
    
    MOV AX, [player_sum]
    CMP AX, 21
    JG PLAYER_BUST

    CALL PRINT_NEWLINE
    MOV DX, OFFSET player_sum_msg
    CALL PRINT_STRING
    MOV AX, [player_sum]
    CALL PRINT_NUMBER

    CMP AX, 21
    JE PLAYER_STAND

    JMP PLAYER_TURN

PLAYER_BUST:
    CALL PRINT_NEWLINE
    MOV DX, OFFSET player_bust_msg
    CALL PRINT_STRING
    MOV AX, [current_bet]
    CALL PRINT_NUMBER
    
    JMP NEAR PTR MAIN_GAME_LOOP

PLAYER_STAND:
    JMP DEALER_TURN

; --- 6. Dealer's Turn ---
DEALER_TURN:
    CALL PRINT_NEWLINE
    MOV DX, OFFSET dealer_reveal_msg
    CALL PRINT_STRING

    MOV AX, [dealer_first_card]
    CALL PRINT_NUMBER_SPACE

    MOV AX, [dealer_second_card]
    CALL PRINT_NUMBER_SPACE
    
DEALER_HIT_LOOP:
    CMP [dealer_sum], 17
    JGE DEALER_STAND

    CALL GET_CARD_VALUE
    CALL PRINT_NUMBER_SPACE
    LEA SI, dealer_sum
    CALL ADD_CARD_TO_TOTAL

    MOV AX, [dealer_sum]
    CMP AX, 21
    JG DEALER_BUST

    JMP DEALER_HIT_LOOP

DEALER_STAND:
    MOV DX, OFFSET dealer_total_msg
    CALL PRINT_STRING
    MOV AX, [dealer_sum]
    CALL PRINT_NUMBER
    
    JMP CHECK_WINNER

DEALER_BUST:
    MOV DX, OFFSET dealer_total_msg
    CALL PRINT_STRING
    MOV AX, [dealer_sum]
    CALL PRINT_NUMBER

    CALL PRINT_NEWLINE
    MOV DX, OFFSET dealer_bust_msg
    CALL PRINT_STRING
    MOV AX, [current_bet]
    CALL PRINT_NUMBER
    
    CALL PLAYER_WINS_MONEY
    
    JMP NEAR PTR MAIN_GAME_LOOP

; --- 7. Check Winner (No busts) ---
CHECK_WINNER:
    MOV AX, [player_sum]
    MOV BX, [dealer_sum]
    
    CMP AX, BX
    JG PLAYER_WINS_ROUND
    JL PLAYER_LOSES_ROUND
    JMP PUSH_GAME

PLAYER_WINS_ROUND:
    CALL PRINT_NEWLINE
    MOV DX, OFFSET player_win_msg
    CALL PRINT_STRING
    MOV AX, [current_bet]
    CALL PRINT_NUMBER
    CALL PLAYER_WINS_MONEY
    
    JMP NEAR PTR MAIN_GAME_LOOP

PLAYER_LOSES_ROUND:
    CALL PRINT_NEWLINE
    MOV DX, OFFSET player_lose_msg
    CALL PRINT_STRING
    MOV AX, [current_bet]
    CALL PRINT_NUMBER
    
    JMP NEAR PTR MAIN_GAME_LOOP

PUSH_GAME:
    CALL PRINT_NEWLINE
    MOV DX, OFFSET push_msg
    CALL PRINT_STRING
    MOV AX, [current_bet]
    ADD [player_money], AX
    
    JMP NEAR PTR MAIN_GAME_LOOP

; --- 8. Handle Game Over (Out of money) ---
HANDLE_GAME_OVER:
    MOV DX, OFFSET game_over_msg
    CALL PRINT_STRING
HANDLE_GAME_OVER_PROMPT:
    MOV DX, OFFSET restart_prompt
    CALL PRINT_STRING
    
    CALL READ_CHAR
    CMP AL, '0'
    JE HANDLE_GAME_OVER_DONE
    CMP AL, '1'
    JE HANDLE_GAME_OVER_DONE

    CALL PRINT_NEWLINE
    MOV DX, OFFSET invalid_choice_msg
    CALL PRINT_STRING
    JMP HANDLE_GAME_OVER_PROMPT

HANDLE_GAME_OVER_DONE:
    RET

; --- 9. Exit Game ---
EXIT_GAME:
    MOV DX, OFFSET goodbye_msg
    CALL PRINT_STRING
    
    MOV AH, 4Ch
    INT 21h

; ===========================================
; ===========================================
;       HELPER SUBROUTINES
; ===========================================
; ===========================================

; --- (A) Player Wins Money ---
PLAYER_WINS_MONEY PROC
    PUSH AX
    MOV AX, [current_bet]
    ADD AX, AX
    ADD [player_money], AX
    POP AX
    RET
PLAYER_WINS_MONEY ENDP

ADD_CARD_TO_TOTAL PROC
    PUSH BX

    MOV BX, [SI]
    ADD BX, AX
    MOV [SI], BX

    POP BX
    RET
ADD_CARD_TO_TOTAL ENDP

DISPLAY_CARD_RECEIVED PROC
    PUSH AX
    PUSH DX

    MOV DX, OFFSET card_received_msg
    CALL PRINT_STRING

    POP DX
    POP AX
    CALL PRINT_NUMBER

    RET
DISPLAY_CARD_RECEIVED ENDP


GET_CARD_VALUE PROC
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI


    MOV AX, [rand_seed]
    MOV CX, 25173
    MUL CX
    
    ADD AX, 13849
    MOV [rand_seed], AX


    XOR DX, DX
    MOV CX, 13
    DIV CX

 
    MOV SI, DX
    

    LEA BX, card_values
    
    MOV AL, [BX + SI]
    
    XOR AH, AH
    
    POP SI
    POP DX
    POP CX
    POP BX
    RET
GET_CARD_VALUE ENDP

; --- (C) Print String ---
PRINT_STRING PROC
    PUSH AX
    MOV AH, 09h
    INT 21h
    POP AX
    RET
PRINT_STRING ENDP

; --- (D) Print Newline ---
PRINT_NEWLINE PROC
    PUSH DX
    MOV DX, OFFSET crlf
    CALL PRINT_STRING
    POP DX
    RET
PRINT_NEWLINE ENDP

; --- (E) Print Character ---
PRINT_CHAR PROC
    PUSH AX
    MOV AH, 02h
    INT 21h
    POP AX
    RET
PRINT_CHAR ENDP

; --- (F) Flush Keyboard Buffer ---
FLUSH_KB_BUFFER PROC
    PUSH AX
_flush_loop:
    MOV AH, 0Bh
    INT 21h
    CMP AL, 00h
    JE _flush_done
    
    MOV AH, 07h
    INT 21h
    JMP _flush_loop
_flush_done:
    POP AX
    RET
FLUSH_KB_BUFFER ENDP

; --- (G) Read Character ---
READ_CHAR PROC
    CALL FLUSH_KB_BUFFER
    
    MOV AH, 01h
    INT 21h
    
    RET
READ_CHAR ENDP

; --- (H) 印出數字並加空格 ---
PRINT_NUMBER_SPACE PROC
    CALL PRINT_NUMBER
    PUSH DX
    MOV DL, ' '
    CALL PRINT_CHAR
    POP DX
    RET
PRINT_NUMBER_SPACE ENDP

; --- (I) Print Number ---
PRINT_NUMBER PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    
    CMP AX, 0
    JNE _print_num_loop
    
    MOV DL, '0'
    CALL PRINT_CHAR
    JMP _print_num_done

_print_num_loop:
    XOR CX, CX
    MOV BX, 10

_divide_loop:
    XOR DX, DX
    DIV BX
    ADD DX, '0'
    PUSH DX
    INC CX
    CMP AX, 0
    JNE _divide_loop

_print_stack_loop:
    POP DX
    CALL PRINT_CHAR
    LOOP _print_stack_loop

_print_num_done:
    POP DX
    POP CX
    POP BX
    POP AX
    RET
PRINT_NUMBER ENDP

; --- Exit ---
MAIN ENDP
END MAIN
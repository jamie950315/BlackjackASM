# Blackjack (16-bit DOS, MASM 6.15)

👉 [繁體中文](README_zh-TW.md)

This is a text-mode Blackjack (21) game written in 16-bit DOS assembly. The program is contained in a single file: `BLACKJACK.ASM`.
It has minimal dependencies: it uses only DOS interrupts (INT 21h) for input/output and a simple Linear Congruential Generator (LCG) for card values.

---

## Features

- Full game loop: betting, dealing, player turn (Hit/Stand), dealer turn, automatic result, and bankroll update.
- I/O via DOS interrupts only:
  - AH=09h print string, AH=02h print character, AH=01h read character, AH=0Bh check keyboard buffer, AH=07h discard key.
- Randomness: initialize seed from `INT 1Ah` (time) and use an LCG to produce an index 0..12 that maps to card values.
- Betting uses a base unit of 10 with multipliers (1–9); entering 0 exits the game.

---

## Game Flow Overview

1. Initialization (GAME_INIT)
   - Set `player_money = 500`
   - Show welcome message
   - Obtain time via `INT 1Ah` and initialize `rand_seed`
2. Main Loop (MAIN_GAME_LOOP)
   - If `player_money < BASE_BET (10)`, enter the "insufficient funds" flow and ask to restart.
   - Otherwise go to betting (GET_BET).
3. Betting (GET_BET)
   - Display current bankroll and remind base bet is 10.
   - Ask for multiplier 1–9 (or 0 to exit).
   - Compute `current_bet = BASE_BET * multiplier`; if invalid input or insufficient funds, show an error and retry.
   - Subtract `current_bet` from `player_money` (chips placed on the table).
4. Initial Deal (DEAL_INITIAL_CARDS)
   - Player gets two cards; dealer gets two cards (store dealer’s first/second card for display).
   - Show player total and dealer’s up-card (first card).
   - If the player starts with 21, immediately stand.
5. Player Turn (PLAYER_TURN)
   - Ask Hit(1) or Stand(0).
   - Hit: draw a card, update total; if > 21 then bust.
   - Stand: end player turn and proceed to dealer turn.
6. Dealer Turn (DEALER_TURN)
   - Reveal cards and draw until total ≥ 17.
   - If dealer > 21, player wins.
7. Result & Settlement (CHECK_WINNER)
   - With no busts, compare player and dealer totals.
   - Player win: return bet and pay even money (effectively double the stake back to bankroll).
   - Player loss: the pre-deducted bet is not returned.
   - Push: return the bet.
8. Return to the main loop for the next hand or exit based on user input.

---

## Card Values and Scoring

- Card value table (`card_values`): `[1,2,3,4,5,6,7,8,9,10,10,10,10]`
  - Ace = 1; 10/J/Q/K = 10.
- This implementation does not handle Ace as 1/11 (no soft hand logic).
- Each draw uses LCG to obtain an index 0..12 mapping to the table above; this is equivalent to drawing with replacement from infinite decks.

---

## Key Constants and Variables

- `BASE_BET = 10`: base betting unit.
- `player_money`: player’s bankroll, starts at 500.
- `current_bet`: bet amount for the current round.
- `player_sum`, `dealer_sum`: total points for player and dealer.
- `dealer_first_card`, `dealer_second_card`: dealer’s first two card values for reveal.
- `rand_seed`: LCG seed (set using `INT 1Ah` time).

---

## Subroutine Overview

- `MAIN`: set DS and jump to `_start`.
- `GAME_INIT`: initialize bankroll, print welcome, seed RNG.
- `MAIN_GAME_LOOP`: check funds, dispatch to betting or game-over/restart flow.
- `GET_BET`: read bet multiplier, validate funds, deduct bet.
- `DEAL_INITIAL_CARDS`: deal two cards to player and dealer, show player total and dealer up-card.
- `PLAYER_TURN` / `PLAYER_HIT` / `PLAYER_STAND`: handle player actions, bust/stand.
- `DEALER_TURN`: dealer draws until reaching at least 17.
- `CHECK_WINNER`: compare totals when no bust, route to win/lose/push.
- `PLAYER_WINS_MONEY`: double the stake back into bankroll (equivalent to returning the bet plus even-money winnings).
- `GET_CARD_VALUE`:
  - LCG: `seed = (seed * 25173 + 13849) mod 65536`
  - Use `seed mod 13` as index -> fetch `card_values[index]` into AX.
- I/O helpers:
  - `PRINT_STRING (AH=09h)`, `PRINT_CHAR (AH=02h)`, `PRINT_NUMBER`, `PRINT_NUMBER_SPACE`
  - `READ_CHAR (AH=01h)` + `FLUSH_KB_BUFFER (AH=0Bh/07h)

---

## DOS I/O and Interrupts

- Print string: AH=09h, DX=address of `$`-terminated string.
- Print character: AH=02h, DL=character.
- Read character: AH=01h, returns ASCII in AL.
- Clear keyboard buffer: AH=0Bh to check, AH=07h to consume/discard.
- RNG seed: `INT 1Ah` to read system time.

---

## How to Play

- Betting: enter a multiplier 1–9 (base 10). For example, `3` means betting 30. Enter `0` to exit.
- Player turn:
  - `1` = Hit
  - `0` = Stand
- Invalid input is rejected with a message and re-prompted.

---

## Build and Run

This project targets MASM 6.15 in a 16-bit DOS environment. On modern OSes, use DOSBox (or similar) to build and run.

### Using DOSBox + MASM 6.15 (Recommended)

1. Install DOSBox.
2. Mount MASM 6.15 tools (`ML.EXE`, `LINK.EXE`/`LINK16.EXE`) and this project directory in DOSBox.
3. Inside DOSBox, change to the project directory and run:

   ```bat
   rem Assemble 16-bit object
   ml /c /Zm /Zi BLACKJACK.ASM

   rem Link to produce a 16-bit .EXE (use LINK or LINK16 depending on your tools)
   link16 BLACKJACK.OBJ
   rem or: link BLACKJACK.OBJ
   ```

4. Run the generated executable:

   ```bat
   BLACKJACK.EXE
   ```

> Note: Options vary across MASM/Link versions. If `link16` is unavailable, use `link` and ensure the output is a 16-bit DOS MZ executable.

---

## Correctness and Payout Rules

- The bet is deducted before dealing: `player_money -= current_bet`.
- Player win or dealer bust: `PLAYER_WINS_MONEY` doubles the stake back into the bankroll (returning the bet + even-money winnings).
- Player bust or loss to dealer: the deducted bet is not returned.
- Push: the bet is returned (add `current_bet` back to `player_money`.

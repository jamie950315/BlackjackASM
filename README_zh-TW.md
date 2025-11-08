# Blackjack (16-bit DOS, MASM 6.15)

這是一個以 16-bit DOS 組合語言撰寫的文字介面的21點 (Blackjack) 小遊戲，單一檔案為 `BLACKJACK.ASM`。
它以最小依賴實作：只使用 DOS 中斷 (INT 21h) 進行輸入與輸出、不需任何額外函式庫，
並以一個簡單的線性同餘產生器 (LCG) 產生牌值。

---

## 特色

- 完整遊戲循環：下注、發牌、玩家回合 (Hit/Stand)、莊家回合、自動判定勝負與資金更新。
- 輸入/輸出完全透過 DOS 中斷：
  - AH=09h 印字串、AH=02h 印字元、AH=01h 讀字元、AH=0Bh 查鍵盤緩衝、AH=07h 吃掉按鍵。
- 亂數：使用 INT 1Ah 讀系統時間作為初始種子，之後以 LCG 產生 0..12 的索引對應牌值。
- 下注以「基底 10」為單位，支援乘數 (1–9)；0 直接離開遊戲。

---

## 遊戲流程總覽

1. 初始化 (GAME_INIT)
   - 設定 `player_money = 500`
   - 顯示歡迎訊息
   - 使用 `INT 1Ah` 取得時間，設定 `rand_seed`
2. 主循環 (MAIN_GAME_LOOP)
   - 若 `player_money < BASE_BET (10)`，進入「資金不足」流程，詢問是否重來。
   - 否則進入下注 (GET_BET)。
3. 下注 (GET_BET)
   - 顯示目前資金，提示基底押注為 10 元。
   - 要求輸入乘數 1–9（或 0 離開）。
   - 計算 `current_bet = BASE_BET * 乘數`；若資金不足或輸入非法則提示錯誤並重輸。
   - 從 `player_money` 中先行扣除 `current_bet`（視作押注金放桌上）。
4. 發初始牌 (DEAL_INITIAL_CARDS)
   - 玩家兩張、莊家兩張（儲存莊家第一、二張以便顯示）。
   - 顯示玩家總點數與莊家明牌（第一張）。
   - 若玩家一開始就 21，直接進入玩家停牌 (stand)。
5. 玩家回合 (PLAYER_TURN)
   - 詢問 Hit(1) 或 Stand(0)。
   - Hit：抽一張牌、更新點數、若 > 21 直接爆牌 (bust)。
   - Stand：結束玩家回合，進入莊家回合。
6. 莊家回合 (DEALER_TURN)
   - 翻開牌面並一張張抽到總點數 ≥ 17 為止。
   - 若莊家 > 21，玩家獲勝。
7. 判定與結算 (CHECK_WINNER)
   - 無爆牌時，比較玩家與莊家總點數。
   - 玩家勝：返還押注並等額獲利（等同把桌上押注翻倍加回資金）。
   - 玩家負：先前已扣押注，不再退回。
   - 平手 Push：退回押注金。
8. 回到主循環，繼續下一局或依使用者指示結束。

---

## 牌值與計分

- 牌值對應表 (`card_values`): `[1,2,3,4,5,6,7,8,9,10,10,10,10]`
  - A 視為 1；10、J、Q、K 皆視為 10。
- 本實作不處理 Ace 的 1/11 雙重值（無 soft hand）。
- 每次抽牌以 LCG 取得 0..12 的索引，對應上述表格，等效於「無限副牌」且「帶回放」的抽樣。

---

## 關鍵常數與變數

- `BASE_BET = 10`：基底押注。
- `player_money`：玩家資金，開局 500。
- `current_bet`：本局押注金額。
- `player_sum`、`dealer_sum`：雙方點數總和。
- `dealer_first_card`、`dealer_second_card`：莊家前兩張牌的牌值，用於翻牌顯示。
- `rand_seed`：LCG 亂數種子（以 `INT 1Ah` 時間設置）。

---

## 子程式一覽（重點）

- `MAIN`：設定 DS、進入 `_start`。
- `GAME_INIT`：初始化資金、顯示歡迎、亂數種子設定。
- `MAIN_GAME_LOOP`：檢查資金、分派至下注或遊戲結束/重來流程。
- `GET_BET`：輸入押注乘數、檢查資金、扣除押注。
- `DEAL_INITIAL_CARDS`：玩家與莊家各發兩張，顯示玩家總和與莊家明牌。
- `PLAYER_TURN` / `PLAYER_HIT` / `PLAYER_STAND`：玩家操作，處理爆牌/停牌。
- `DEALER_TURN`：莊家自動抽到 17 點（含）以上。
- `CHECK_WINNER`：無爆牌時比較點數，分派勝/負/平結果。
- `PLAYER_WINS_MONEY`：將押注翻倍加回玩家資金（等同返還押注+贏得等額獎金）。
- `GET_CARD_VALUE`：
  - LCG：`seed = (seed * 25173 + 13849) mod 65536`
  - `seed mod 13` 做為索引 -> 取 `card_values[index]` 回傳於 AX。
- 輸入輸出：
  - `PRINT_STRING (AH=09h)`, `PRINT_CHAR (AH=02h)`, `PRINT_NUMBER`, `PRINT_NUMBER_SPACE`
  - `READ_CHAR (AH=01h)` + `FLUSH_KB_BUFFER (AH=0Bh/07h)`

---

## I/O 與中斷

- 顯示字串：AH=09h, DX=字串位址，以 `$` 結尾。
- 顯示字元：AH=02h, DL=字元。
- 讀取字元：AH=01h，回傳 ASCII 於 AL。
- 清鍵盤緩衝：AH=0Bh 檢查、AH=07h 取出按鍵丟棄。
- 亂數初始種子：`INT 1Ah` 取得系統時間。

---

## 互動方式（操作說明）

- 押注：輸入 1–9 的乘數（基底為 10），例如輸入 `3` 代表押注 30。輸入 `0` 直接離開遊戲。
- 玩家回合：
  - `1` = Hit（要牌）
  - `0` = Stand（停牌）
- 非法輸入會提示錯誤並重新要求輸入。

---

## 編譯與執行

本專案以 MASM 6.15 與 16-bit DOS 環境為目標。若在現代操作系統環境，建議使用 DOSBox 或類似模擬器。

###  使用 DOSBox + MASM 6.15（建議）

1. 安裝 DOSBox。
2. 將 MASM 6.15 工具（`ML.EXE`, `LINK.EXE`/`LINK16.EXE`）與本專案資料夾一併掛載至 DOSBox。
3. 在 DOSBox 中切換至專案目錄，執行下列指令完成編譯與連結：

   ```bat
   rem 編譯為 16-bit 目標物件
   ml /c /Zm /Zi BLACKJACK.ASM

   rem 使用 16-bit 連結器產生 .EXE（依你的工具可能是 LINK 或 LINK16）
   link16 BLACKJACK.OBJ
   rem 或者：link BLACKJACK.OBJ
   ```

4. 產生 `BLACKJACK.EXE` 後，在 DOSBox 直接執行：

   ```bat
   BLACKJACK.EXE
   ```

> 注意：不同 MASM/Link 版本的選項名稱略有差異；若無 `link16`，請改用 `link` 並確保目標格式為 16-bit DOS MZ 可執行檔。

---

## 邏輯正確性與結算規則

- 押注在發牌前即自資金扣除：`player_money -= current_bet`。
- 玩家勝或莊家爆：呼叫 `PLAYER_WINS_MONEY` 進行「翻倍返還」，等效於返還押注 + 獲利等額押注。
- 玩家爆或輸給莊家：不再退回押注（已扣除）。
- 平手 Push：退回押注（將 `current_bet` 加回 `player_money`）。

---

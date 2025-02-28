# Rock Paper Scissors Lizard Spock (RPSLS) Smart Contract

เกม Rock Paper Scissors Lizard Spock (RPSLS) Blockchain ที่ทำงานบน Blockchain โดยใช้ภาษา Solidity
- ใช้ commit-reveal pattern ในการส่ง choice เพื่อซ่อน choice 
- มี ระบบกันการล็อกเมื่อมี player ที่ไม่เล่น
- Reset game ทำให้ contract ใช้งานได้ใหม่ เมื่อจ่ายรางวัลไปแล้ว 

## โครงสร้างไฟล์

*   [RPSLS.sol](RPSLS.sol): Smart Contract หลักของเกม
*   [TimeUnit.sol](TimeUnit.sol): Contract สำหรับจัดการเวลา
*   [CommitReveal.sol](CommitReveal.sol): Contract สำหรับการ commit และ reveal ข้อมูล

## การเล่นเกม
- player แต่ละคน จ่าย 1 ETH เพื่อเล่น
- เลือก (Commit) choice ซึ่งมี  Rock (0), Paper (1), Scissors (2), Lizard (3), Spock (4)
- ผู้ชนะได้รางวัลทั้งหมด 2 ETH
- ถ้าเสมอ จ่ายเหรียญคืนคนละ 1 ETH

## การทำงานของ Smart Contract

1.  **การเพิ่มผู้เล่น:**

    *   ฟังก์ชัน [`addPlayer`](RPSLS.sol#L60) ใช้สำหรับเพิ่มผู้เล่นเข้าสู่เกม
    *   ต้องเป็น address ที่ได้รับอนุญาต ([`is_allowed_player`](RPSLS.sol#L28)) เท่านั้น
    *   จำกัดจำนวนผู้เล่นไว้ที่ 2 คน
    *   ผู้เล่นแต่ละคนต้องส่ง 1 ETH เพื่อเข้าร่วมเกม ซึ่งจะถูกเก็บเป็น reward
    *   ใช้ [`time_add_player.setStartTime()`](RPSLS.sol#L69) เพื่อจับเวลาในการป้องกันการล็อก
        *   **กรณีมีผู้เล่นคนเดียว:** หากมีผู้เล่นเพียงคนเดียวและไม่มีผู้เล่นคนที่สองเข้าร่วมภายใน 1 นาที, ผู้เล่นคนแรกสามารถเรียกฟังก์ชัน [`withdraw_no_player_2`](RPSLS.sol#L68) เพื่อถอนเงินรางวัลทั้งหมดคืนได้
        *   ฟังก์ชันนี้ตรวจสอบว่ามีผู้เล่นเพียงคนเดียว (`require(numPlayer == 1)`)
        *   ตรวจสอบว่าผู้เรียกคือผู้เล่นคนแรก (`require(msg.sender == players[0])`)
        *   ตรวจสอบว่าเวลาผ่านไปอย่างน้อย 60 วินาที (`require(time_add_player.elapsedSeconds() > 60)`)
        *   จากนั้นจึงทำการโอนเงินรางวัลทั้งหมดคืนให้ผู้เล่นคนแรกและ reset เกม
2.  **การป้องกันการ Lock เงินใน Contract:**

    
    
    *   **กรณี Reveal แล้วไม่มีการ Reveal อีกคน:** หากมีผู้เล่น reveal choice แล้วแต่อีกฝ่ายไม่ reveal ภายใน 1 นาที, ผู้เล่นที่ reveal สามารถเรียกฟังก์ชัน [`withdraw_no_reveal`](RPSLS.sol#L131) เพื่อถอนเงินรางวัลคืนได้ครึ่งหนึ่ง
        *   ฟังก์ชันนี้ตรวจสอบว่ามีผู้เล่น 2 คน (`require(numPlayer == 2)`)
        *   ตรวจสอบว่ามีผู้เล่น reveal เพียง 1 คน (`require(numInput == 1)`)
        *   ตรวจสอบว่าผู้เรียกคือผู้เล่นคนแรกหรือคนที่สอง (`require(msg.sender == players[0] || msg.sender == players[1])`)
        *   ตรวจสอบว่าเวลาผ่านไปอย่างน้อย 1 นาที (`require(time_reveal.elapsedMinutes() > 1)`)
        *   จากนั้นจึงทำการแบ่งเงินรางวัลให้ผู้เล่นทั้งสองคน (แบ่งครึ่ง) และ reset เกม
2.  **การ Commit Choice:**

    *   ฟังก์ชัน [`commit_choice`](RPSLS.sol#L81) ใช้เพื่อให้ผู้เล่น commit choice ที่ต้องการจาก ซึ่งจะเป็น  ค่า random 31 byte ต่อด้วย choice ( "00" "01" "02" "03" "04") จะเรียกค่านี้ว่า `choice_data` จากนั้นนำ `choice_data` มา hash ได้ `choice_hash` แล้วส่ง `choice_hash` มากับ [`commit_choice`](RPSLS.sol#L81)
    *   ต้องมีผู้เล่น 2 คนในเกม (`require(numPlayer == 2)`) ถึงจะ commit ได้
    *   ผู้เล่นต้องยังไม่ได้ commit choice ก่อนหน้านี้ (`require(player_not_played[msg.sender])`)
    *   เก็บค่า `choice_hash` ของ player โดยใช้ [`commit_reveal.commit(choice_hash, msg.sender)`](RPSLS.sol#L87) จาก Contract [`CommitReveal`](CommitReveal.sol) 
    *   มีการใช้ [`time_commit.setStartTime()`](RPSLS.sol#L90) เพื่อจับเวลา เพื่อจับเวลาในการป้องกันการล็อก
        *   **กรณี Commit แล้ว Player อีกคนไม่ Commit :** หากมีผู้เล่น commit choice แล้วแต่อีกฝ่ายไม่ commit ภายใน 1 นาที, ผู้เล่นที่ commit สามารถเรียกฟังก์ชัน [`withdraw_no_commit`](RPSLS.sol#L93) เพื่อคืนเงินรางวัล
        *   ฟังก์ชันนี้ตรวจสอบว่ามีผู้เล่น 2 คน (`require(numPlayer == 2)`)
        *   ตรวจสอบว่ามีผู้เล่น commit เพียง 1 คน (`require(numCommit == 1)`)
        *   ตรวจสอบว่าผู้เรียกคือผู้เล่นคนแรกหรือคนที่สอง (`require(msg.sender == players[0] || msg.sender == players[1])`)
        *   ตรวจสอบว่าเวลาผ่านไปอย่างน้อย 1 นาที (`require(time_commit.elapsedMinutes() > 1)`)
        *   จากนั้นจึงทำการคืนเงินรางวัลโดยแบ่งครึ่งเงินรางวัลให้ผู้เล่นทั้งสองคน reset เกม
3.  **การ Reveal Choice และตัดสินผู้ชนะ:**

    *   ฟังก์ชัน [`reveal_choice`](RPSLS.sol#L106) ใช้เพื่อให้ผู้เล่น reveal choice ที่ commit ไว้ โดย player ส่งค่า `choice_data` มา
    *   ต้องมีผู้เล่น 2 คนและต้อง commit choice แล้วทั้งคู่ (`require(numPlayer == 2)` และ `require(numCommit == 2)`)
    *   ผู้เล่นต้องยังไม่ได้ reveal choice มาก่อน (`require(player_not_revealed[msg.sender])`)
    *   ตรวจสอบความถูกต้องของ reveal โดยการเทียบ ค่า hash ของ `choice_data` และ `choice_hash` ที่ส่งมาก่อนหน้าว่าตรงกันหรือไม่โดยใช้ [`commit_reveal.reveal(choice_data, msg.sender)`](RPSLS.sol#L114) จาก Contract [`CommitReveal`](CommitReveal.sol)
    *   ถ้าตรงกันจะดึง choice ของผู้เล่นจาก byte สุดท้ายของ `choice_data` (`player_choice[msg.sender] = uint8(choice_data[31])`)
    *   เมื่อมีผู้เล่น reveal ครบ 2 คน, จะเรียกฟังก์ชัน [`_checkWinnerAndPay`](RPSLS.sol#L158) เพื่อตรวจสอบผู้ชนะและจ่ายรางวัล
    *   ฟังก์ชัน [`_checkWinnerAndPay`](RPSLS.sol#L155) ทำการเปรียบเทียบ choice ของผู้เล่นแต่ละคนตามกติกาของ RPSLS และทำการโอน reward ให้กับผู้ชนะ หรือแบ่ง reward หากเสมอ
5.  **การ Reset เกม:**

    *   ฟังก์ชัน [`_resetGame`](RPSLS.sol#L188) ใช้สำหรับ reset สถานะของเกม
    *   ลบข้อมูล choice ของผู้เล่น, สถานะการเล่น, และข้อมูล commit/reveal
    *   ลบข้อมูลผู้เล่นออกจาก array `players`
    *   Reset จำนวนผู้เล่น, จำนวน input, จำนวน commit, และ reward
;;; collect
; an incredibly simple game made after barely
; making it through 5 Nerdy Nights posts
; (http://nintendoage.com/forum/messageview.cfm?catid=22&threadid=7155)

; iNES header
  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring

; internal RAM from [$0000-$0800)
; PPU/APU/etc access from [$0800-$8000)
; program code from [$8000-$FFFA)

;;;;;;;;;;;;;;;
; global variables, starting from $0000
  .org $0000
player1_up_vel:
  .org $0001
player1_down_vel:
  .org $0002
player1_left_vel:
  .org $0003
player1_right_vel:

  .org $0004
player1_max_vel:

  .org $0005
player2_up_vel:
  .org $0006
player2_down_vel:
  .org $0007
player2_left_vel:
  .org $0008
player2_right_vel:

  .org $0009
player2_max_vel:

  .org $000A
player1_score:
  .org $000B
player2_score:

;;;;;;;;;;;;;;;
; program code, starting from $8000

  .bank 0      ; will be from [$8000-$A000)
  .org $8000   ; the program instructions will start at $8000 (not in RAM)
RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now x = 0
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait1

clrmem:        ; clears all 2KB of RAM, except $0200-$02FF, which is mysteriously set to FEFEFEFEFE... (why?)
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x ; $0200-$02FF will be used to store a sprite table to be transferred to the PPU
  INX          ; x will increment from 0 to F, then when it increments again to 0, the BNE will fail, and execution will continue past the loop
  BNE clrmem

vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2

LoadPalettes:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006             ; write the high byte of $3F00 address ($3F00 is the address where the palettes are on the PPU)
  LDA #$00
  STA $2006             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        ; load data from address (palette + the value in x)
  STA $2007             ; write to PPU
  INX                   ; increment x, x = x + 1
  CPX #$20              ; compare x to hex $20, decimal 32 - copying 32 bytes = 8 palettes...
  BNE LoadPalettesLoop  ; branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down

LoadSprites:
  LDX #$00              ; start at 0
LoadSpritesLoop:
  LDA sprites, x        ; load data from address (sprites +  x)
  STA $0200, x          ; store into RAM address ($0200 + x)
  INX                   ; increment x = x + 1
  CPX #$60              ; load $60 bytes worth of data (enough for 24 sprites)
  BNE LoadSpritesLoop   ; branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to $60, continue execution

  LDA #%10000000   ; enable NMI, sprites from Pattern Table 1
  STA $2000

  LDA #%00010000   ; enable sprites
  STA $2001

Forever:
  JMP Forever     ;jump back to Forever, infinite loop

NMI:
  ; here we will transfer sprite data (stored at $0200) to the PPU
  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer

;;; player velocity modification begin
  LDA player1_up_vel
  CMP player1_down_vel
  BNE Player1YVelModDone
  LDA #$00
  STA player1_up_vel
  STA player1_down_vel
Player1YVelModDone:

  LDA player1_left_vel
  CMP player1_right_vel
  BNE Player1XVelModDone
  LDA #$00
  STA player1_left_vel
  STA player1_right_vel
Player1XVelModDone:

  LDA player2_up_vel
  CMP player2_down_vel
  BNE Player2YVelModDone
  LDA #$00
  STA player2_up_vel
  STA player2_down_vel
Player2YVelModDone:

  LDA player2_left_vel
  CMP player2_right_vel
  BNE Player2XVelModDone
  LDA #$00
  STA player2_left_vel
  STA player2_right_vel
Player2XVelModDone:
;;; player velocity modification end

;;; collision begin

  ; player 1's collision logic
  ; will check for collision with the coin, and if there was one:
    ; update the player's score
    ; move the coin to a semi-random place
  LDA $0204  ; load the y position of player 1
  CLC
  ADC #$04   ; add 4, to get the center y position of player 1

  CMP $0200  ; compare to the y position of the coin
  BCC Player1CollisionDetectionDone       ; NOT player1 y center > coin y

  SEC
  SBC #$08  ; subtract 8 more from the y position of player 1 so that we can do: player1 y center < coin y + 8

  CMP $0200 ; compare to the y position of the coin
  BCS Player1CollisionDetectionDone      ; NOT player1 y center - 8 < coin y => player1 y center < coin y + 8

  LDA $0207 ; load the x position of player 1
  CLC
  ADC #$04  ; add 4, to get the center x position of player 1

  CMP $0203 ; compare to the x position of the coin
  BCC Player1CollisionDetectionDone       ; NOT player1 x center > coin x

  SEC
  SBC #$08  ; subtract 8 more from the x position of player 1 so that we can do: player1 x center < coin x + 8

  CMP $0203 ; compare to the x position of the coin
  BCS Player1CollisionDetectionDone      ; NOT player1 x center - 8 < coin x => player1 x center < coin x + 8

  ; move the sprite showing player 1's current score offscreen
  LDA player1_score
  ; multiply by 4, since there are 4 bytes per sprite which can represent the player's score
  ASL A
  ASL A
  TAX
  LDA #$FF     ; move the current score's sprite's y position offscreen
  STA $020C, x ; start from the first digit sprite, and offset it according to the player score
  LDA #$FF     ; move the current score's sprite's x position offscreen
  STA $020F, x

  ; increase player 1's score
  LDA player1_score
  CLC
  ADC #$01 ; add 1 to the player's score
  CMP #$0A ; if the player's score is 10, make it 0 instead (wrap)
  BNE Player1ScoreModDone
  LDA #$00
Player1ScoreModDone:
  STA player1_score

  ; move the sprite showing player 1's updated score onscreen
  LDA player1_score
  ; multiply by 4
  ASL A
  ASL A
  TAX
  LDA #$0F
  STA $020C, x ; start from the first digit sprite, and offset it according to the player score
  LDA #$0F
  STA $020F, x

  ; change the coin position somewhat randomly
  LDA $020B ; player 2's x position
  ASL A     ; multiply by 2
  ADC #$CC  ; add some number
  STA $0200 ; store result in the coin's y position

  LDA $0208 ; player 2's y position
  ASL A     ; multiply by 2
  ADC #$CC  ; add some number
  STA $0203 ; store result in the coin's x position

Player1CollisionDetectionDone:

  ; repeat collision logic for player 2
  LDA $0208
  CLC
  ADC #$04

  CMP $0200
  BCC Player2CollisionDetectionDone       ; NOT player2 y center > coin y

  SEC
  SBC #$08

  CMP $0200
  BCS Player2CollisionDetectionDone      ; NOT player2 y center - 8 < coin y => player2 y center < coin y + 8

  LDA $020B
  CLC
  ADC #$04

  CMP $0203
  BCC Player2CollisionDetectionDone       ; NOT player2 x center > coin x

  SEC
  SBC #$08
  CMP $0203
  BCS Player2CollisionDetectionDone      ; NOT player2 x center - 8 < coin x => player2 x center < coin x + 8

  ; move the sprite showing player 2's current score offscreen
  LDA player2_score
  ; multiply by 4
  ASL A
  ASL A
  TAX
  LDA #$FF
  STA $0234, x ; start from the first digit sprite, and offset it according to the player score
  LDA #$FF
  STA $0237, x

  ; increase player 2's score
  LDA player2_score
  CLC
  ADC #$01
  CMP #$0A
  BNE Player2ScoreModDone
  LDA #$00
Player2ScoreModDone:
  STA player2_score

  ; move the sprite showing player 2's updated score onscreen
  LDA player2_score
  ; multiply by 4
  ASL A
  ASL A
  TAX
  LDA #$0F
  STA $0234, x ; start from the first digit sprite, and offset it according to the player score
  LDA #$F0
  STA $0237, x

  ; change the coin position somewhat randomly
  LDA $0207
  ASL A
  ADC #$CC
  STA $0200

  LDA $0204
  ASL A
  ADC #$CC
  STA $0203

Player2CollisionDetectionDone:

; make sure the coin, if it's respawned, is not at the edges

  LDA $0200
  CMP #$0F   ; make sure coin's y position > 0F
  BCS CoinYGreaterThan0F
  CLC
  ADC #$0F  ; if coin's y position < 0F, add 0F to it
CoinYGreaterThan0F:
  CMP #$F0   ; make sure coin's y position < F0
  BCC CoinYLessThanF0
  SEC
  SBC #$0F  ; if coin's y position > F0, subtract 0F from it
CoinYLessThanF0:
  STA $0200

  LDA $0203
  CMP #$0F   ; make sure coin's x position > 0F
  BCS CoinXGreaterThan0F
  CLC
  ADC #$0F  ; if coin's x position < 0F, add 0F to it
CoinXGreaterThan0F:
  CMP #$F0   ; make sure coin's x position < F0
  BCC CoinXLessThanF0
  SEC
  SBC #$0F  ; if coin's x position > F0, subtract 0F from it
CoinXLessThanF0:
  STA $0203

;;; collision end

;;; update player positions begin
  ; move player 1 up/down
  LDA $0204       ; load sprite Y position
  SEC
  SBC player1_up_vel
  CLC
  ADC player1_down_vel
  STA $0204

  ; move player 1 left/right
  LDA $0207       ; load sprite X position
  SEC
  SBC player1_left_vel
  CLC
  ADC player1_right_vel
  STA $0207

  ; move player 2 up/down
  LDA $0208       ; load sprite Y position
  SEC
  SBC player2_up_vel
  CLC
  ADC player2_down_vel
  STA $0208

  ; move player 2 left/right
  LDA $020B       ; load sprite X position
  SEC
  SBC player2_left_vel
  CLC
  ADC player2_right_vel
  STA $020B
;;; update player positions end

;;; controller logic begin
LatchController:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016       ; tell both the controllers to latch buttons

; set the max velocity (might want to be able to modify this with button presses or something later)
  LDA #$04
  STA player1_max_vel
  LDA #$04
  STA player2_max_vel

  LDA $4016     ; player 1 - A
  LDA $4016     ; player 1 - B
  LDA $4016     ; player 1 - Select
  LDA $4016     ; player 1 - Start

ReadPlayer1Up:
  LDA $4016                 ; player 1 - Up
  AND #%00000001            ; only look at bit 0
  BEQ ReadPlayer1UpDone     ; branch to ReadPlayer1UpDone if button is NOT pressed (0)
                            ; add instructions here to do something when button IS pressed (1)
  LDA player1_up_vel
  CMP player1_max_vel
  BPL ReadPlayer1UpDone
  CLC
  ADC #$01
  STA player1_up_vel
ReadPlayer1UpDone:

ReadPlayer1Down:
  LDA $4016                  ; player 1 - Down
  AND #%00000001             ; only look at bit 0
  BEQ ReadPlayer1DownDone    ; branch to ReadPlayer1DownDone if button is NOT pressed (0)
                             ; add instructions here to do something when button IS pressed (1)
  LDA player1_down_vel
  CMP player1_max_vel
  BPL ReadPlayer1DownDone
  CLC
  ADC #$01
  STA player1_down_vel
ReadPlayer1DownDone:     ; handling this button is done

ReadPlayer1Left:
  LDA $4016                 ; player 1 - Left
  AND #%00000001            ; only look at bit 0
  BEQ ReadPlayer1LeftDone   ; branch to ReadPlayer1LeftDone if button is NOT pressed (0)
                            ; add instructions here to do something when button IS pressed (1)
  LDA player1_left_vel
  CMP player1_max_vel
  BPL ReadPlayer1LeftDone
  CLC
  ADC #$01
  STA player1_left_vel
ReadPlayer1LeftDone:         ; handling this button is done

ReadPlayer1Right:
  LDA $4016                  ; player 1 - Right
  AND #%00000001             ; only look at bit 0
  BEQ ReadPlayer1RightDone   ; branch to ReadPlayer1RightDone if button is NOT pressed (0)
                             ; add instructions here to do something when button IS pressed (1)
  LDA player1_right_vel
  CMP player1_max_vel
  BPL ReadPlayer1RightDone
  CLC
  ADC #$01
  STA player1_right_vel
ReadPlayer1RightDone:    ; handling this button is done

  LDA $4017     ; player 2 - A
  LDA $4017     ; player 2 - B
  LDA $4017     ; player 2 - Select
  LDA $4017     ; player 2 - Start

ReadPlayer2Up:
  LDA $4017                 ; player 2 - Up
  AND #%00000001            ; only look at bit 0
  BEQ ReadPlayer2UpDone     ; branch to ReadPlayer2UpDone if button is NOT pressed (0)
                            ; add instructions here to do something when button IS pressed (1)
  LDA player2_up_vel
  CMP player2_max_vel
  BPL ReadPlayer2UpDone
  CLC
  ADC #$01
  STA player2_up_vel
ReadPlayer2UpDone:

ReadPlayer2Down:
  LDA $4017                  ; player 2 - Down
  AND #%00000001             ; only look at bit 0
  BEQ ReadPlayer2DownDone    ; branch to ReadPlayer2DownDone if button is NOT pressed (0)
                             ; add instructions here to do something when button IS pressed (1)
  LDA player2_down_vel
  CMP player2_max_vel
  BPL ReadPlayer2DownDone
  CLC
  ADC #$01
  STA player2_down_vel
ReadPlayer2DownDone:     ; handling this button is done

ReadPlayer2Left:
  LDA $4017                 ; player 2 - Left
  AND #%00000001            ; only look at bit 0
  BEQ ReadPlayer2LeftDone   ; branch to ReadPlayer2LeftDone if button is NOT pressed (0)
                            ; add instructions here to do something when button IS pressed (1)
  LDA player2_left_vel
  CMP player2_max_vel
  BPL ReadPlayer2LeftDone
  CLC
  ADC #$01
  STA player2_left_vel
ReadPlayer2LeftDone:     ; handling this button is done

ReadPlayer2Right:
  LDA $4017                  ; player 2 - Right
  AND #%00000001             ; only look at bit 0
  BEQ ReadPlayer2RightDone   ; branch to ReadPlayer2RightDone if button is NOT pressed (0)
                             ; add instructions here to do something when button IS pressed (1)
  LDA player2_right_vel
  CMP player2_max_vel
  BPL ReadPlayer2RightDone
  CLC
  ADC #$01
  STA player2_right_vel
ReadPlayer2RightDone:    ; handling this button is done
;;; controller logic end

  RTI             ; return from interrupt

;;;;;;;;;;;;;;

  .bank 1    ; will be from [$A000-$C000)
  .org $A000
palette:
  .db $0F,$21,$26,$2b,$0F,$21,$26,$2b,$0F,$21,$26,$2b,$0F,$21,$26,$2b
  .db $0F,$21,$26,$2b,$0F,$21,$26,$2b,$0F,$21,$26,$2b,$0F,$21,$26,$2b

sprites:
     ;vert tile attr horiz
  .db $80, $00, $00, $80   ;0200
  .db $80, $01, $00, $88   ;0204
  .db $88, $02, $00, $80   ;0208

  .db $0F, $03, $00, $0F   ;020C
  .db $FF, $04, $00, $FF   ;0210
  .db $FF, $05, $00, $FF   ;0214
  .db $FF, $06, $00, $FF   ;0218
  .db $FF, $07, $00, $FF   ;021C
  .db $FF, $08, $00, $FF   ;0220
  .db $FF, $09, $00, $FF   ;0224
  .db $FF, $0A, $00, $FF   ;0228
  .db $FF, $0B, $00, $FF   ;022C
  .db $FF, $0C, $00, $FF   ;0230

  .db $0F, $0D, $00, $F0   ;0234
  .db $FF, $0E, $00, $FF   ;0238
  .db $FF, $0F, $00, $FF   ;023C
  .db $FF, $10, $00, $FF   ;
  .db $FF, $11, $00, $FF   ;
  .db $FF, $12, $00, $FF   ;
  .db $FF, $13, $00, $FF   ;
  .db $FF, $14, $00, $FF   ;
  .db $FF, $15, $00, $FF   ;
  .db $FF, $16, $00, $FF   ;

  .org $FFFA     ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial

;;;;;;;;;;;;;;

  ; this is in the chr ROM (8KB) ???
  ; what is going on here, don't I have my global variable at $0000?
  ; what exactly do these bank directives do?
  .bank 2
  .org $0000
  .incbin "collect.chr"   ; graphics, from $0000-$01FF

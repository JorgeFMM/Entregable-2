PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMADDR   = $2003
OAMDMA    = $4014

CONTROLLER1 = $4016
CONTROLLER2 = $4017

BTN_RIGHT   = %00000001
BTN_LEFT    = %00000010
BTN_DOWN    = %00000100
BTN_UP      = %00001000
BTN_START   = %00010000
BTN_SELECT  = %00100000
BTN_B       = %01000000
BTN_A       = %10000000

.segment "ZEROPAGE"
block_h: .res 1
block_l: .res 1
block_tile: .res 1
stage: .res 1
scroll: .res 1
ppuctrl_settings: .res 1
pad1: .res 1
.exportzp block_h, block_l, block_tile, stage, scroll, ppuctrl_settings, pad1

.segment "HEADER"
.byte $4e, $45, $53, $1a ; Magic string that always begins an iNES header
.byte $02        ; Number of 16KB PRG-ROM banks
.byte $01        ; Number of 8KB CHR-ROM banks
.byte %00001000  ; Horizontal mirroring, no save RAM, no mapper
.byte %00000000  ; No special-case flags set, no mapper
.byte $00        ; No PRG-RAM present
.byte $00        ; NTSC format

.segment "CODE"
.proc irq_handler
  RTI
.endproc

.proc nmi_handler
  LDA #$00
  STA OAMADDR
  LDA #$02
  STA OAMDMA

  JSR read_controller1

  LDA pad1        ; Load button presses
  AND #BTN_A   ; Filter out all but A
  BEQ not_pressed ; If result is zero, A not pressed
  LDA stage
  EOR #%00000001 ; flip bit #0 to its opposite
  STA stage
  JSR reset_stage
  not_pressed:
	LDA scroll
  CMP #255 ; did we scroll to the end of a nametable?
  BNE set_scroll_positions
  JMP stop

set_scroll_positions:
  INC scroll
  LDA scroll ; X scroll first
  STA PPUSCROLL
  LDA #$00 ; then Y scroll
  STA PPUSCROLL

  stop:
  RTI
.endproc

.proc reset_handler
  SEI
  CLD
  LDX #$40
  STX $4017
  LDX #$FF
  TXS
  INX
  STX $2000
  STX $2001
  STX $4010
  BIT $2002
vblankwait:
  BIT $2002
  BPL vblankwait

	LDX #$00
	LDA #$FF
clear_oam:
	STA $0200,X ; set sprite y-positions off the screen
	INX
	INX
	INX
	INX
	BNE clear_oam

LDA #$00
STA stage
vblankwait2:
  BIT $2002
  BPL vblankwait2
  JMP main
.endproc

.proc reset_stage
  SEI
  CLD
  LDX #$40
  STX $4017
  LDX #$FF
  TXS
  INX
  STX $2000
  STX $2001
  STX $4010
  BIT $2002
vblankwait:
  BIT $2002
  BPL vblankwait

	LDX #$00
	LDA #$FF
clear_oam:
	STA $0200,X ; set sprite y-positions off the screen
	INX
	INX
	INX
	INX
	BNE clear_oam

vblankwait2:
  BIT $2002
  BPL vblankwait2
  JMP main
.endproc

.proc main
  LDA #$00	 ; Y is only 240 lines tall!
	STA scroll
  ; write a palette
  LDX PPUSTATUS
  LDX #$3f
  STX PPUADDR
  LDX #$00
  STX PPUADDR
  LDA stage
  CMP #$00
  BNE stage2
  JMP load_palettes
  stage2:
  LDX #$04
  loop1:
  LDA palettes, X
  STA PPUDATA
  INX
  CPX #$08
  BNE loop1

  LDX #$00
  loop2:
  LDA palettes, X
  STA PPUDATA
  INX
  CPX #$04
  BNE loop2
  LDX #$08
load_palettes:
  LDA palettes,X
  STA PPUDATA
  INX
  CPX #$20
  BNE load_palettes

  JSR change_stage
  
vblankwait:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10010000  ; turn on NMIs, sprites use first pattern table
	STA ppuctrl_settings
  STA PPUCTRL
  LDA #%00011110  ; turn on screen
  STA PPUMASK

forever:
  JMP forever
.endproc


.proc change_stage
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA 

  LDA stage
  CMP #$00
  BNE stage2
  JSR load_stage1
  JMP end

  stage2:
  JSR load_stage2

  end:
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc load_stage1
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA
  
  LDA #$20
  STA block_h
  LDA #$00
  STA block_l
  STA block_tile
  LDX #$00
  LDY #$00
load_nam1:
  LDA nam_1,X
  AND #%11000000
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$04
  STA block_tile
  JSR draw_blocks
  LDA block_l
  CLC
  ADC #$02
  STA block_l

  LDA nam_1,X
  AND #%00110000
  LSR A
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$04
  STA block_tile
  JSR draw_blocks
  LDA block_l
  CLC
  ADC #$02
  STA block_l

  LDA nam_1,X
  AND #%00001100
  LSR A
  LSR A
  CLC
  ADC #$04
  STA block_tile
  JSR draw_blocks
  LDA block_l
  CLC
  ADC #$02
  STA block_l

  LDA nam_1,X
  AND #%00000011
  CLC
  ADC #$04
  STA block_tile
  JSR draw_blocks
  LDA block_l
  CLC
  ADC #$02
  STA block_l

  INY
  CPY #$04
  BNE no_sum1
  LDY #$00
  LDA block_l
  CMP #$E0
  BNE sum1
  LDA block_h
  CLC
  ADC #$01
  STA block_h
  LDA #$00
  STA block_l
  JMP no_sum1

  sum1:
  CLC
  ADC #$20
  STA block_l

  no_sum1:
  INX
  CPX #$3c
  BEQ continue1
  JMP load_nam1

continue1:
  LDA #$24
  STA block_h
  LDA #$00
  STA block_l
  LDX #$00
  LDY #$00
load_nam2:
  LDA nam_2,X
  AND #%11000000
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$04
  STA block_tile
  JSR draw_blocks
  LDA block_l
  CLC
  ADC #$02
  STA block_l

  LDA nam_2,X
  AND #%00110000
  LSR A
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$04
  STA block_tile
  JSR draw_blocks
  LDA block_l
  CLC
  ADC #$02
  STA block_l

  LDA nam_2,X
  AND #%00001100
  LSR A
  LSR A
  CLC
  ADC #$04
  STA block_tile
  JSR draw_blocks
  LDA block_l
  CLC
  ADC #$02
  STA block_l

  LDA nam_2,X
  AND #%00000011
  CLC
  ADC #$04
  STA block_tile
  JSR draw_blocks
  LDA block_l
  CLC
  ADC #$02
  STA block_l

  INY
  CPY #$04
  BNE no_sum2
  LDY #$00
  LDA block_l
  CMP #$E0
  BNE sum2
  LDA block_h
  CLC
  ADC #$01
  STA block_h
  LDA #$00
  STA block_l
  JMP no_sum2

  sum2:
  CLC
  ADC #$20
  STA block_l

  no_sum2:
  INX
  CPX #$3c
  BEQ end
  JMP load_nam2

  end:
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc load_stage2
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA #$20
  STA block_h
  LDA #$00
  STA block_l
  STA block_tile
  LDX #$00
  LDY #$00
load_nam3:
  LDA nam_3,X
  AND #%11000000
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$08
  STA block_tile
  JSR draw_blocks
  LDA block_l
  CLC
  ADC #$02
  STA block_l

  LDA nam_3,X
  AND #%00110000
  LSR A
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$08
  STA block_tile
  JSR draw_blocks
  LDA block_l
  CLC
  ADC #$02
  STA block_l

  LDA nam_3,X
  AND #%00001100
  LSR A
  LSR A
  CLC
  ADC #$08
  STA block_tile
  JSR draw_blocks
  LDA block_l
  CLC
  ADC #$02
  STA block_l

  LDA nam_3,X
  AND #%00000011
  CLC
  ADC #$08
  STA block_tile
  JSR draw_blocks
  LDA block_l
  CLC
  ADC #$02
  STA block_l

  INY
  CPY #$04
  BNE no_sum3
  LDY #$00
  LDA block_l
  CMP #$E0
  BNE sum3
  LDA block_h
  CLC
  ADC #$01
  STA block_h
  LDA #$00
  STA block_l
  JMP no_sum3

  sum3:
  CLC
  ADC #$20
  STA block_l

  no_sum3:
  INX
  CPX #$3c
  BEQ continue3
  JMP load_nam3

continue3:
  LDA #$24
  STA block_h
  LDA #$00
  STA block_l
  LDX #$00
  LDY #$00
load_nam4:
  LDA nam_4,X
  AND #%11000000
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$08
  STA block_tile
  JSR draw_blocks
  LDA block_l
  CLC
  ADC #$02
  STA block_l

  LDA nam_4,X
  AND #%00110000
  LSR A
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$08
  STA block_tile
  JSR draw_blocks
  LDA block_l
  CLC
  ADC #$02
  STA block_l

  LDA nam_4,X
  AND #%00001100
  LSR A
  LSR A
  CLC
  ADC #$08
  STA block_tile
  JSR draw_blocks
  LDA block_l
  CLC
  ADC #$02
  STA block_l

  LDA nam_4,X
  AND #%00000011
  CLC
  ADC #$08
  STA block_tile
  JSR draw_blocks
  LDA block_l
  CLC
  ADC #$02
  STA block_l

  INY
  CPY #$04
  BNE no_sum4
  LDY #$00
  LDA block_l
  CMP #$E0
  BNE sum4
  LDA block_h
  CLC
  ADC #$01
  STA block_h
  LDA #$00
  STA block_l
  JMP no_sum4

  sum4:
  CLC
  ADC #$20
  STA block_l

  no_sum4:
  INX
  CPX #$3c
  BEQ continue4
  JMP load_nam4

continue4:

  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc
.proc draw_blocks
  ; save registers
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA PPUSTATUS
  LDA block_h
  STA PPUADDR
  LDA block_l
  STA PPUADDR
  LDX block_tile
  STX PPUDATA

  LDA PPUSTATUS
  LDA block_h
  STA PPUADDR
  LDA block_l
  CLC
  ADC #$01
  STA PPUADDR
  LDX block_tile
  STX PPUDATA

  LDA PPUSTATUS
  LDA block_h
  STA PPUADDR
  LDA block_l
  CLC
  ADC #$20
  STA PPUADDR
  LDX block_tile
  STX PPUDATA

  LDA PPUSTATUS
  LDA block_h
  STA PPUADDR
  LDA block_l
  CLC
  ADC #$21
  STA PPUADDR
  LDX block_tile
  STX PPUDATA

  ; restore registers and return
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc read_controller1
  PHA
  TXA
  PHA
  PHP

  ; write a 1, then a 0, to CONTROLLER1
  ; to latch button states
  LDA #$01
  STA CONTROLLER1
  LDA #$00
  STA CONTROLLER1

  LDA #%00000001
  STA pad1

get_buttons:
  LDA CONTROLLER1 ; Read next button's state
  LSR A           ; Shift button state right, into carry flag
  ROL pad1        ; Rotate button state from carry flag
                  ; onto right side of pad1
                  ; and leftmost 0 of pad1 into carry flag
  BCC get_buttons ; Continue until original "1" is in carry flag

  PLP
  PLA
  TAX
  PLA
  RTS
.endproc

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "RODATA"
palettes:
.byte $0f, $12, $23, $27
.byte $0f, $00, $10, $30
.byte $0f, $12, $23, $27
.byte $0f, $12, $23, $27

.byte $0f, $0c, $21, $32
.byte $0f, $00, $00, $00
.byte $0f, $00, $00, $00
.byte $0f, $00, $00, $00

nam_1:
.byte %00000000, %00000000, %00000000, %00000000
.byte %10101010, %10101010, %10101010, %10101010
.byte %10000000, %00000000, %01000011, %11110000
.byte %10000101, %01010100, %01000101, %11010101
.byte %10000100, %11110111, %01000001, %00011101
.byte %10000100, %01110101, %01010101, %00011101
.byte %10000100, %01000000, %11111111, %00011101
.byte %10000101, %01000001, %01010101, %01010001
.byte %10001111, %11000001, %00000011, %11110001
.byte %10000111, %11010001, %00010101, %11010001
.byte %10000100, %01010001, %00010001, %00010001
.byte %10000100, %01000001, %00011101, %00010001
.byte %10010100, %01010101, %00011101, %00010001
.byte %00000000, %00000000, %00011111, %00010000
.byte %10101010, %10101010, %10101010, %10101010

nam_2:
.byte %00000000, %00000000, %00000000, %00000000
.byte %10101010, %10101010, %10101010, %10101010
.byte %11111100, %00000000, %11111111, %00000010
.byte %11011101, %01010101, %01010101, %01010010
.byte %11010000, %00111111, %00000000, %00010010
.byte %00010101, %01011101, %00010101, %00010010
.byte %00000001, %11010001, %11010001, %00010010
.byte %01010001, %11010001, %11010001, %00010010
.byte %00010001, %00010001, %11010001, %00011110
.byte %00010001, %00010001, %11010001, %00011110
.byte %00010001, %00010101, %00010001, %00011110
.byte %00010001, %00000000, %00000001, %00011110
.byte %00010001, %01010101, %01011101, %01010110
.byte %00010000, %00111111, %00011111, %11000000
.byte %10101010, %10101010, %10101010, %10101010

nam_3:
.byte %00000000, %00000000, %00000000, %00000000
.byte %10101010, %10101010, %10101010, %10101010
.byte %10000000, %11110101, %01010101, %01001111
.byte %10000101, %01110100, %00000000, %01000111
.byte %10000111, %01110111, %01010111, %01000111
.byte %10000111, %11111111, %11000111, %01000111
.byte %10000101, %01010101, %01000111, %01000111
.byte %10000100, %00000111, %11110101, %01010111
.byte %10110100, %01110111, %01110000, %11110111
.byte %10111100, %01110111, %01110101, %01110111
.byte %10110100, %01110111, %11110111, %01000111
.byte %10000111, %01110101, %01010111, %01000111
.byte %10000111, %11000000, %00111111, %01000111
.byte %00000101, %01010101, %01010101, %01001111
.byte %10101010, %10101010, %10101010, %10101010

nam_4:
.byte %00000000, %00000000, %00000000, %00000000
.byte %10101010, %10101010, %10101010, %10101010
.byte %11000000, %00000000, %00011111, %11111110
.byte %01010101, %01010101, %00011101, %11011110
.byte %01000000, %11111111, %11011101, %00011110
.byte %01010101, %01011101, %11011101, %00011110
.byte %01111111, %11011111, %11010001, %11010010
.byte %01110101, %11010101, %01010001, %11010010
.byte %01110101, %11000000, %00000001, %11010010
.byte %01110101, %01010101, %01010001, %11010010
.byte %01110101, %01011111, %11010001, %11010110
.byte %01000000, %00000001, %11011101, %11110010
.byte %01010101, %01010101, %11011101, %01010010
.byte %11000000, %00000000, %00011111, %11010000
.byte %10101010, %10101010, %10101010, %10101010

.segment "CHARS"
.incbin "sprites.chr"
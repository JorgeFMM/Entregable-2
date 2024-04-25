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
player_x: .res 1
player_y: .res 1
player_dir: .res 1
player_walk: .res 1
is_moving: .res 1
delay_counter: .res 1
block_h: .res 1
block_l: .res 1
block_tile: .res 1
stage: .res 1
scroll: .res 1
ppuctrl_settings: .res 1
pad1: .res 1
is_wall: .res 1
wall_x: .res 1
wall_y: .res 1
walking: .res 1
walk_counter: .res 1
.exportzp player_x, player_y, player_dir, player_walk, is_moving, delay_counter, block_h, block_l, block_tile, stage, scroll, ppuctrl_settings, pad1, is_wall, wall_x, wall_y, walking, walk_counter

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

  LDA scroll ; X scroll first
  STA PPUSCROLL
  LDA #$00 ; then Y scroll
  STA PPUSCROLL

  JSR read_controller1
  JSR update_player
  JSR draw_player
  LDX delay_counter
  CPX #$00
  BNE continue
  LDX #$00
  CPX player_walk
  BNE negate
  LDX #$01
  STX player_walk
  LDX #$00
  JMP continue
negate:
  LDX #$00
  STX player_walk
continue:
  INX
  STX delay_counter
  LDX delay_counter
  CPX #$10
  BNE keep_counting
  LDX #$00
  STX delay_counter
keep_counting:
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
	STA $0200,X ; _yset sprite y-positions off the screen
	INX
	INX
	INX
	INX
	BNE clear_oam

LDA #$00
STA is_wall
STA stage
STA player_x
LDA #208
STA player_y
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

.proc update_player
  PHP  ; Start by saving registers,
  PHA  ; as usual.
  TXA
  PHA
  TYA
  PHA

  LDA #$00
  STA is_moving
  LDX player_x
  LDY player_y

  LDA walking
  CMP #1
  BEQ walk_left
  CMP #2
  BNE next0
  JMP walk_right
  next0:
  CMP #3
  BNE next1 
  JMP walk_up
  next1:
  CMP #4
  BNE next2
  JMP walk_down
  next2:

  check_left:
  LDA pad1        ; Load button presses
  AND #BTN_LEFT   ; Filter out all but Left
  BEQ check_right ; If result is zero, left not pressed
  LDA player_x
  SEC
  SBC #16
  CLC
  ADC scroll
  STA wall_x
  LDA player_y
  STA wall_y
  BCS second
  first:
  JSR check_wall
  JMP go
  second:
  LDA player_x
  CMP #$08
  BEQ first
  JSR check_wall2
  go:
  LDA is_wall
  CMP #$00
  BNE check_right
  LDA #1
  STA walking
  LDA #$00
  STA walk_counter
  walk_left:
  DEC scroll
  DEC player_x  ; If the branch is not taken, move player left
  LDA #$01
  STA player_dir
  INC walk_counter
  LDA walk_counter
  CMP #8
  BNE jump1
  LDA #$00
  STA walking
  LDA #$00
  STA walk_counter
  jump1:
  JMP check_movedx
check_right:
  LDA pad1
  AND #BTN_RIGHT
  BEQ check_up
  LDA player_x
  CMP #240
  BNE check
  LDA player_y
  CMP #208
  BEQ check
  JMP check_movedx
  check:
  LDA player_x
  CLC
  ADC #16
  ADC scroll
  STA wall_x
  LDA player_y
  STA wall_y
  BCS second2
  JSR check_wall
  JMP go2
  second2:
  JSR check_wall2
  go2:
  LDA is_wall
  CMP #$00
  BNE check_up
  LDA #2
  STA walking
  LDA #$00
  STA walk_counter
  walk_right:
  INC scroll
  INC player_x
  LDA #$03
  STA player_dir
  INC walk_counter
  LDA walk_counter
  CMP #8
  BNE jump2
  LDA #$00
  STA walking
  LDA #$00
  STA walk_counter
  jump2:
  JMP check_movedx
check_up:
  LDA pad1
  AND #BTN_UP
  BEQ check_down
  LDA player_y
  SEC
  SBC #16
  STA wall_y
  LDA player_x
  CLC
  ADC scroll
  STA wall_x
  BCS second3
  JSR check_wall
  JMP go3
  second3:
  JSR check_wall2
  go3:
  LDA is_wall
  CMP #$00
  BNE check_down
  LDA #3
  STA walking
  LDA #$00
  STA walk_counter
  walk_up:
  DEC player_y
  DEC player_y
  LDA #$02
  STA player_dir
  INC walk_counter
  LDA walk_counter
  CMP #8
  BNE jump3
  LDA #$00
  STA walking
  LDA #$00
  STA walk_counter
  jump3:
  JMP check_movedx
check_down:
  LDA pad1
  AND #BTN_DOWN
  BEQ check_movedx
  LDA player_y
  CLC
  ADC #16
  STA wall_y
  LDA player_x
  CLC
  ADC scroll
  STA wall_x
  BCS second4
  JSR check_wall
  JMP go4
  second4:
  JSR check_wall2
  go4:
  LDA is_wall
  CMP #$00
  BNE check_movedx
  LDA #4
  STA walking
  LDA #$00
  STA walk_counter
  walk_down:
  INC player_y
  INC player_y
  LDA #$00
  STA player_dir
  INC walk_counter
  LDA walk_counter
  CMP #8
  BNE jump4
  LDA #$00
  STA walking
  LDA #$00
  STA walk_counter
  jump4:
check_movedx:
  LDA #$00
  CPX player_x
  BEQ check_movedy
  LDA #$01
  STA is_moving
check_movedy:
  CPY player_y
  BEQ done_checking
  CLC
  ADC #$01
  STA is_moving
done_checking:
  PLA ; Done with updates, restore registers
  TAY ; and return to where we called this
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc check_wall
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDX #$00
  STX is_wall
loop:
  LDA solids, X
  INX
  CMP wall_x
  BNE continue
  LDA solids, X
  CMP wall_y
  BNE continue
  LDY #$01
  STY is_wall
  JMP end

  continue:
  INX
  CPX #246
  BNE loop

  end:
  PLA ; Done with updates, restore registers
  TAY ; and return to where we called this
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc check_wall2
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDX #$00
  STX is_wall
loop:
  LDA solids2, X
  INX
  CMP wall_x
  BNE continue
  LDA solids2, X
  CMP wall_y
  BNE continue
  LDY #$01
  STY is_wall
  JMP end

  continue:
  INX
  CPX #246
  BNE loop

  end:
  PLA ; Done with updates, restore registers
  TAY ; and return to where we called this
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc draw_player
  ; save registers
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; store tile locations
  ; top left tile:
  DEC player_y

  LDA player_y
  STA $0200
  LDA player_x
  STA $0203

  ; top right tile (x + 8):
  LDA player_y
  STA $0204
  LDA player_x
  CLC
  ADC #$08
  STA $0207

  ; bottom left tile (y + 8):
  LDA player_y
  CLC
  ADC #$08
  STA $0208
  LDA player_x
  STA $020b

  ; bottom right tile (x + 8, y + 8)
  LDA player_y
  CLC
  ADC #$08
  STA $020c
  LDA player_x
  CLC
  ADC #$08
  STA $020f

  INC player_y

  ; store tiles and sprite flags
  LDX #$00
  CPX is_moving
  BEQ standing
  JMP moving_down
standing:
  CPX player_dir
  BNE standing_left
  ; tiles
  LDA #$04
  STA $0201
  LDA #$05
  STA $0205
  LDA #$06
  STA $0209
  LDA #$07
  STA $020d
  ; flags
  LDA #%00100000
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP done

standing_left:
  INX
  CPX player_dir
  BNE standing_up
  ; tiles
  LDA #$14
  STA $0201
  LDA #$15
  STA $0205
  LDA #$16
  STA $0209
  LDA #$17
  STA $020d
  ; flags
  LDA #%00100000
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP done

standing_up:
  INX
  CPX player_dir
  BNE standing_right
  ; tiles
  LDA #$0C
  STA $0201
  LDA #$0D
  STA $0205
  LDA #$0E
  STA $0209
  LDA #$0F
  STA $020d
  ; flags
  LDA #%00100000
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP done
  
standing_right:
  INX
  CPX player_dir
  BNE standing_left
  ; tiles
  LDA #$15
  STA $0201
  LDA #$14
  STA $0205
  LDA #$17
  STA $0209
  LDA #$16
  STA $020d
  ; flags
  LDA #%01100000
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP done

moving_down:
  CPX player_dir
  BNE moving_left
  LDA #$08
  STA $0201
  LDA #$09
  STA $0205
  LDA #%00100000
  STA $0202
  STA $0206

  LDY #$00
  CPY player_walk
  BNE switch_down
  LDA #$0a
  STA $0209
  LDA #$0b
  STA $020d
  LDA #%00100000
  STA $020a
  STA $020e
  JMP done
switch_down:
  LDA #$0b
  STA $0209
  LDA #$0a
  STA $020d
  LDA #%01100000
  STA $020a
  STA $020e
  JMP done

moving_left:
  INX
  CPX player_dir
  BNE moving_up
  LDA #%00100000
  STA $0202
  STA $0206
  STA $020a
  STA $020e

  LDY #$00
  CPY player_walk
  BNE switch_left
  LDA #$18
  STA $0201
  LDA #$19
  STA $0205
  LDA #$1a
  STA $0209
  LDA #$1b
  STA $020d
  JMP done
switch_left:
  LDA #$1c
  STA $0201
  LDA #$1d
  STA $0205
  LDA #$1e
  STA $0209
  LDA #$1f
  STA $020d
  JMP done

moving_up:
  INX
  CPX player_dir
  BNE moving_right
  LDA #$10
  STA $0201
  LDA #$11
  STA $0205
  LDA #%00100000
  STA $0202
  STA $0206

  LDY #$00
  CPY player_walk
  BNE switch_up
  LDA #$12
  STA $0209
  LDA #$13
  STA $020d
  LDA #%00100000
  STA $020a
  STA $020e
  JMP done
switch_up:
  LDA #$13
  STA $0209
  LDA #$12
  STA $020d
  LDA #%01100000
  STA $020a
  STA $020e
  JMP done
moving_right:
  LDA #%01100000
  STA $0202
  STA $0206
  STA $020a
  STA $020e

  LDY #$00
  CPY player_walk
  BNE switch_right
  LDA #$19
  STA $0201
  LDA #$18
  STA $0205
  LDA #$1b
  STA $0209
  LDA #$1a
  STA $020d
  JMP done
switch_right:
  LDA #$1d
  STA $0201
  LDA #$1c
  STA $0205
  LDA #$1f
  STA $0209
  LDA #$1e
  STA $020d
done:
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
.byte $0f, $12, $23, $27
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

solids:
.byte 0, 16
.byte 16, 16
.byte 32, 16
.byte 48, 16
.byte 64, 16
.byte 80, 16
.byte 96, 16
.byte 112, 16
.byte 128, 16
.byte 144, 16
.byte 160, 16
.byte 176, 16
.byte 192, 16
.byte 208, 16
.byte 224, 16
.byte 240, 16
.byte 0, 32
.byte 128, 32
.byte 0, 48
.byte 32, 48
.byte 48, 48
.byte 64, 48
.byte 80, 48
.byte 96, 48
.byte 128, 48
.byte 160, 48
.byte 176, 48
.byte 208, 48
.byte 224, 48
.byte 240, 48
.byte 0, 64
.byte 32, 64
.byte 96, 64
.byte 128, 64
.byte 176, 64
.byte 208, 64
.byte 240, 64
.byte 0, 80
.byte 32, 80
.byte 64, 80
.byte 96, 80
.byte 112, 80
.byte 128, 80
.byte 144, 80
.byte 160, 80
.byte 176, 80
.byte 208, 80
.byte 240, 80
.byte 0, 96
.byte 32, 96
.byte 64, 96
.byte 208, 96
.byte 240, 96
.byte 0, 112
.byte 32, 112
.byte 48, 112
.byte 64, 112
.byte 112, 112
.byte 128, 112
.byte 144, 112
.byte 160, 112
.byte 176, 112
.byte 192, 112
.byte 208, 112
.byte 240, 112
.byte 0, 128
.byte 112, 128
.byte 240, 128
.byte 0, 144
.byte 32, 144
.byte 80, 144
.byte 112, 144
.byte 144, 144
.byte 160, 144
.byte 176, 144
.byte 208, 144
.byte 240, 144
.byte 0, 160
.byte 32, 160
.byte 64, 160
.byte 80, 160
.byte 112, 160
.byte 144, 160
.byte 176, 160
.byte 208, 160
.byte 240, 160
.byte 0, 176
.byte 32, 176
.byte 64, 176
.byte 112, 176
.byte 144, 176
.byte 176, 176
.byte 208, 176
.byte 240, 176
.byte 0, 192
.byte 16, 192
.byte 32, 192
.byte 64, 192
.byte 80, 192
.byte 96, 192
.byte 112, 192
.byte 144, 192
.byte 176, 192
.byte 208, 192
.byte 240, 192
.byte 144, 208
.byte 208, 208
.byte 0, 224
.byte 16, 224
.byte 32, 224
.byte 48, 224
.byte 64, 224
.byte 80, 224
.byte 96, 224
.byte 112, 224
.byte 128, 224
.byte 144, 224
.byte 160, 224
.byte 176, 224
.byte 192, 224
.byte 208, 224
.byte 224, 224
.byte 240, 224

solids2:
.byte 0, 16
.byte 16, 16
.byte 32, 16
.byte 48, 16
.byte 64, 16
.byte 80, 16
.byte 96, 16
.byte 112, 16
.byte 128, 16
.byte 144, 16
.byte 160, 16
.byte 176, 16
.byte 192, 16
.byte 208, 16
.byte 224, 16
.byte 240, 16
.byte 240, 32
.byte 16, 48
.byte 48, 48
.byte 64, 48
.byte 80, 48
.byte 96, 48
.byte 112, 48
.byte 128, 48
.byte 144, 48
.byte 160, 48
.byte 176, 48
.byte 192, 48
.byte 208, 48
.byte 240, 48
.byte 16, 64
.byte 208, 64
.byte 240, 64
.byte 16, 80
.byte 32, 80
.byte 48, 80
.byte 64, 80
.byte 80, 80
.byte 112, 80
.byte 144, 80
.byte 160, 80
.byte 176, 80
.byte 208, 80
.byte 240, 80
.byte 48, 96
.byte 80, 96
.byte 112, 96
.byte 144, 96
.byte 176, 96
.byte 208, 96
.byte 240, 96
.byte 0, 112
.byte 16, 112
.byte 48, 112
.byte 80, 112
.byte 112, 112
.byte 144, 112
.byte 176, 112
.byte 208, 112
.byte 240, 112
.byte 16, 128
.byte 48, 128
.byte 80, 128
.byte 112, 128
.byte 144, 128
.byte 176, 128
.byte 208, 128
.byte 240, 128
.byte 16, 144
.byte 48, 144
.byte 80, 144
.byte 112, 144
.byte 144, 144
.byte 176, 144
.byte 208, 144
.byte 240, 144
.byte 16, 160
.byte 48, 160
.byte 80, 160
.byte 96, 160
.byte 112, 160
.byte 144, 160
.byte 176, 160
.byte 208, 160
.byte 240, 160
.byte 16, 176
.byte 48, 176
.byte 176, 176
.byte 208, 176
.byte 240, 176
.byte 16, 192
.byte 48, 192
.byte 64, 192
.byte 80, 192
.byte 96, 192
.byte 112, 192
.byte 128, 192
.byte 144, 192
.byte 176, 192
.byte 192, 192
.byte 208, 192
.byte 224, 192
.byte 240, 192
.byte 16, 208
.byte 144, 208
.byte 0, 224
.byte 16, 224
.byte 32, 224
.byte 48, 224
.byte 64, 224
.byte 80, 224
.byte 96, 224
.byte 112, 224
.byte 128, 224
.byte 144, 224
.byte 160, 224
.byte 176, 224
.byte 192, 224
.byte 208, 224
.byte 224, 224
.byte 240, 224

.segment "CHARS"
.incbin "sprites.chr"
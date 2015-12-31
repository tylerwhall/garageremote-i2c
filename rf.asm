	processor 12f529t39a
	include "p12f529t39a.inc"
        __CONFIG _WDT_OFF & _OSC_INTRC & _IOSCFS_8MHz & _MCLRE_OFF & _CP_DISABLE & _CPDF_OFF

; Figure 9-7 303.825MHz target *16384 / 24MHz xtal = 207411
; Default is 400.777Mhz measured = 273436
;RF_DF       equ     D'273436' ;400.777
;RF_DF       equ     D'272906' ;399.777
;RF_DF       equ     D'215040' ;315
;RF_DF       equ     D'212672' ;311.544
;RF_DF       equ     D'210944' ;
;RF_DF       equ     D'208213' ;305
RF_DF       equ     D'207411'

KHZ3_DELAY  equ     D'158' ; 476MHz/3

; RF commands (first byte of 3)
RF_WAPP     equ     0x0
RF_RAPP     equ     0x33
RF_WFREQ    equ     0x18
RF_RFREQ    equ     0x44
RF_RSTAT    equ     0x55

; RF app register
RF_APP_MAN      equ     D'15'
RF_APP_OOK      equ     D'14'
RF_APP_BAND8    equ     D'13'
RF_APP_POWER10  equ     D'4'
RF_APP_RESERV   equ     b'100'

RF_APP_MAN_VAL  equ     (1 << RF_APP_MAN) | (1 << RF_APP_OOK) | RF_APP_RESERV | (1 << RF_APP_POWER10)
RF_APP_AUT_VAL  equ                         (1 << RF_APP_OOK) | RF_APP_RESERV | (1 << RF_APP_POWER10)

RED_LED     equ     4
GREEN_LED   equ     1
RF_CTRL     equ     5
RF_DATA     equ     2
I2C_SDA     equ     0 ; Pin 13 / ICSP DAT
I2C_SCL     equ     3 ; Pin 4 / VPP

TRIS_NORMAL     equ     0xff & ~(1 << RED_LED | 1 << GREEN_LED | 1 << RF_CTRL | 1 << RF_DATA)
TRIS_I2C_ACK    equ     TRIS_NORMAL & ~(1 << I2C_SDA)

; RF Ceiling Fan Protocol
; 3KHz, 1 = 0b110, 0 = 0b010
; 11.5 ms between packets

FAN_LIGHT_CMD   equ     b'110010000001'
FAN21_CMD       equ     b'1110111110001101'

; Common Bank Variables
TEMP        equ     0x7
FAN_OUTB    equ     0x8
FAN_OUT0    equ     0x9
FAN_OUT1    equ     0xa
I2C_PREV    equ     0xb
I2C_CHANGED equ     0xc
LOOP_COUNT  equ     0xd
I2C_DATA    equ     0xe

pin_off macro   pin
        bcf     PORTB, pin
        endm
pin_on macro    pin
        bsf     PORTB, pin
        endm
red_on  macro
        pin_off RED_LED
        endm
red_off macro
        pin_on  RED_LED
        endm
green_on  macro
        pin_off GREEN_LED
        endm
green_off macro
        pin_on  GREEN_LED
        endm

delayp  macro
        movlw   KHZ3_DELAY
        call    delayw
        endm

delayms macro
        call    _delayms
        endm

fan_bit macro   reg, bit
        btfsc   reg, bit
        pin_on  RF_DATA
        btfss   reg, bit
        pin_off RF_DATA
        call    _fan_bit
        endm

fan_start   macro
        pin_off RF_DATA
        call    _fan_bit
        endm

start:
        ; set prescaler to (/2). 4MHz/4/2 = 500KHz
        ; measured CPU frequency is 3.8095 MHz, so 476Khz
        movlw   (1 << NOT_RBPU) | (1 << NOT_RBWU) | b'000'
        option

        ; outputs
        movlw   0xff & ~(1 << RF_CTRL | 1 << RF_DATA)
        movwf   PORTB
        movlw   TRIS_NORMAL
        tris    PORTB

        ; Overly long delay to wait for RF to be ready
        delayms
        delayms
        delayms

        ; Program freq
        movlw   RF_WFREQ | (RF_DF >> D'16')
        call    rf_outw
        movlw   (RF_DF >> 8) & 0xff
        call    rf_outw
        movlw   (RF_DF >> 0) & 0xff
        call    rf_outw

        delayms
        delayms
        delayms

        goto do_i2c

        ; Manual mode
        movlw   RF_WAPP
        call    rf_outw
        movlw   (RF_APP_MAN_VAL >> 8) & 0xff
        call    rf_outw
        movlw   (RF_APP_MAN_VAL >> 0) & 0xff
        call    rf_outw

        delayms
        delayms
        delayms

        red_off

        green_on
        movlw   FAN_LIGHT_CMD >> 8
        movwf   FAN_OUT0
        movlw   FAN_LIGHT_CMD & 0xff
        movwf   FAN_OUT1

        movlw   FAN21_CMD >> d'8'
        movwf   FAN_OUT0
        movlw   FAN21_CMD & 0xff
        movwf   FAN_OUT1
loop:
        ;call    fan_cmd12bit
        call    fan_cmd21bit
        ; 11 ms delay between commands
        delayms
        delayms
        delayms
        delayms
        delayms
        delayms
        delayms
        delayms
        delayms
        delayms
        delayms
        goto loop

; Sends a 12-bit command. Bits 3-0 in FAN_OUT0 followed by 7-0 in FAN_OUT1
; Uses 4 stack
fan_cmd12bit:
        red_on
        fan_start
        movf    FAN_OUT0, w
        movwf   FAN_OUTB
        call fan_send4
        movf    FAN_OUT1, w
        movwf   FAN_OUTB
        call fan_send8
        red_off
        retlw   0x0

; Sends a 21-bit command. 16 bits in FAN_OUT0,1, a constant 1, then calculated 4-bit checksum
; Uses 4 stack
fan_cmd21bit:
        red_on
        fan_start
        ; 8 bits
        movf    FAN_OUT0, w
        movwf   FAN_OUTB
        call fan_send8
        ; 8 bits
        movf    FAN_OUT1, w
        movwf   FAN_OUTB
        call fan_send8
        ; Constant 1 bit
        pin_on  RF_DATA
        call    _fan_bit
        ; Calculate checksum into FAN_OUTB
        swapf   FAN_OUT0, w
        andlw   0xf
        movwf   FAN_OUTB

        movf    FAN_OUT0, w
        andlw   0xf
        addwf   FAN_OUTB, f

        swapf   FAN_OUT1, w
        andlw   0xf
        addwf   FAN_OUTB, f

        movf    FAN_OUT1, w
        andlw   0xf
        addwf   FAN_OUTB, f

        ; Add 3 to the checksum
        movlw   0x3
        addwf   FAN_OUTB, f

        call    fan_send4
        red_off
        retlw   0x0

; Uses 3 stack
fan_send8:
        fan_bit FAN_OUTB, 7
        fan_bit FAN_OUTB, 6
        fan_bit FAN_OUTB, 5
        fan_bit FAN_OUTB, 4
fan_send4:
        fan_bit FAN_OUTB, 3
        fan_bit FAN_OUTB, 2
        fan_bit FAN_OUTB, 1
        fan_bit FAN_OUTB, 0
        retlw   0x0

; Uses 1 stack
delayw:
        movwf   TEMP
        movlw   0x0
        movwf   TMR0
delayw_loop:
        movf    TMR0, w
        subwf   TEMP, w
        btfsc   STATUS, C
        goto    delayw_loop
        retlw   0x0

; Uses 2 stack
_delayms:
        delayp
        delayp
        delayp
        retlw   0x0

; Uses 2 stack
_fan_bit:
        delayp
        pin_on  RF_DATA
        delayp
        pin_off RF_DATA
        delayp
        retlw   0x0
        
rf_bit  macro   reg, bit
        pin_on  RF_DATA
        btfss   reg, bit
        pin_off RF_DATA
        pin_on  RF_CTRL
        pin_off RF_CTRL
        endm

; Could be made into a function with a shift
;  quite inefficient as-is
rf_out  macro   reg
        rf_bit  reg, 7
        rf_bit  reg, 6
        rf_bit  reg, 5
        rf_bit  reg, 4
        rf_bit  reg, 3
        rf_bit  reg, 2
        rf_bit  reg, 1
        rf_bit  reg, 0
        endm

rf_outw:
        movwf   TEMP
        rf_out  TEMP
        retlw   0x0

; i2c slave bitbang

I2C_SDA_MASK    equ     (1 << I2C_SDA)
I2C_SCL_MASK    equ     (1 << I2C_SCL)
I2C_PIN_MASK    equ     (I2C_SDA_MASK | I2C_SCL_MASK)

gotoz   macro label
        btfsc   STATUS, Z
        goto    label
        endm

gotonz  macro label
        btfss   STATUS, Z
        goto    label
        endm

goto_if_i2cstart    macro   label
        local   out
        btfss   I2C_CHANGED, I2C_SDA
        goto    out
        movlw   I2C_SCL_MASK
        subwf   I2C_PREV, w
        gotoz   label
out:
        endm

goto_if_i2cstop     macro   label
        local   out
        btfss   I2C_CHANGED, I2C_SDA
        goto    out
        movlw   I2C_PIN_MASK
        subwf   I2C_PREV, w
        gotoz   label
out:
        endm

goto_if_i2cdata     macro   label
        local   out
        btfss   I2C_CHANGED, I2C_SCL
        goto    out
        btfsc   I2C_PREV, I2C_SCL
        goto    label
out:
        endm

; Wait for i2c lines to change from previous saved state. Return the pin number
; that changed in W. Update previous saved state.
i2c_wait_for_change:
        ; Read current state
        movf    PORTB, w
        andlw   I2C_PIN_MASK

        ; Stash current state
        movwf   TEMP
        ; Compare with previous
        xorwf   I2C_PREV, w
        gotoz   i2c_wait_for_change
        movwf   I2C_CHANGED
        ; Update prev state with new value
        movf    TEMP, w
        movwf   I2C_PREV
        retlw   0x0

i2c_read_byte   macro   reg
        local   loop
        local   got_bit
        local   submit_bit
        movlw   8
        movwf   LOOP_COUNT
loop:
        call i2c_wait_for_change
        goto_if_i2cdata     got_bit
        goto_if_i2cstop     do_i2c
        goto_if_i2cstart    do_i2c
        goto    loop
got_bit:
        btfsc  I2C_PREV, I2C_SDA
        bsf     STATUS, C
        btfss  I2C_PREV, I2C_SDA
        bcf     STATUS, C
        rlf     reg, f
        decfsz  LOOP_COUNT, f
        goto    loop
        endm

i2c_ack         macro
        ; Drive ack bit
        bcf     PORTB, I2C_SDA
        movlw   TRIS_I2C_ACK
        tris    PORTB
        ; Wait for clock high
wait_ack_clock_high:
        call    i2c_wait_for_change
        btfss   I2C_CHANGED, I2C_SCL    ; Clock changed
        goto    wait_ack_clock_high
        btfss   I2C_PREV, I2C_SCL       ; Clock went high
        goto    wait_ack_clock_high
        ; Wait for clock low
wait_ack_clock_low:
        call    i2c_wait_for_change
        btfss   I2C_CHANGED, I2C_SCL    ; Clock changed
        goto    wait_ack_clock_low
        btfsc   I2C_PREV, I2C_SCL       ; Clock went low
        goto    wait_ack_clock_low
        ; Release data line
        movlw   TRIS_NORMAL
        tris    PORTB
        endm

do_i2c:
        red_off
        green_off

        ; Initialize previous value
        movf    PORTB, w
        andlw   I2C_PIN_MASK
        movwf   I2C_PREV

i2c_loop:
        call i2c_wait_for_change

        goto_if_i2cstart    i2c_addr; Ready for address phase
        goto_if_i2cstop     do_i2c  ; Reset on stop
        goto                do_i2c  ; Reset on data when idle

i2c_addr:
        green_on
        i2c_read_byte       I2C_DATA; May jump back to do_i2c
        movlw   (0x46 << 1 | 0)     ; Address 0x46, write
        subwf   I2C_DATA, w
        gotonz  do_i2c              ; Reset if no address match
        i2c_ack
        green_off
        goto    red_halt

halt:
        green_on
        red_on
        goto halt

green_halt:
        red_off
        green_on
        goto green_halt

red_halt:
        red_on
        green_off
        goto red_halt

        ; Wait for start (sda x low, scl high)

        goto    do_i2c
        end

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

KHZ_DELAY   equ     D'250'
KHZ3_DELAY  equ     D'166'

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

RF_APP_MAN_VAL  equ     (1 << RF_APP_MAN) | (1 << RF_APP_OOK) | RF_APP_RESERV; | (1 << RF_APP_POWER10)
RF_APP_AUT_VAL  equ                         (1 << RF_APP_OOK) | RF_APP_RESERV; | (1 << RF_APP_POWER10)

RED_LED     equ     4
GREEN_LED   equ     1
RF_CTRL     equ     5
RF_DATA     equ     2

; RF Ceiling Fan Protocol
; 3KHz, 1 = 0b110, 0 = 0b010
; 11.5 ms between packets

; Common Bank Variables (0-3)
TEMP        equ     0x7
FAN_OUT     equ     0x8

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
        movlw   KHZ_DELAY
        call    delayw
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
        ; set prescaler to (/4). 8MHz/4/4 = 500KHz, though I seem to be getting 250 somehow
        movlw   (1 << NOT_RBPU) | (1 << NOT_RBWU) | b'000'
        option

        ; outputs
        movlw   0xff & ~(1 << RF_CTRL | 1 << RF_DATA)
        movwf   PORTB
        movlw   0xff & ~(1 << RED_LED | 1 << GREEN_LED | 1 << RF_CTRL | 1 << RF_DATA)
        tris    PORTB
        red_on

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

#if 1
        ; Manual mode
        movlw   RF_WAPP
        call    rf_outw
        movlw   (RF_APP_MAN >> 8) & 0xff
        call    rf_outw
        movlw   (RF_APP_MAN >> 0) & 0xff
        call    rf_outw
#endif

        delayms
        delayms
        delayms

FAN_LIGHT_CMD   equ     b'110010000001'

        green_on
fan_send:
#if 1
        movlw   FAN_LIGHT_CMD >> 4
        movwf   FAN_OUT
        fan_start
        fan_bit FAN_OUT, 7
        fan_bit FAN_OUT, 6
        fan_bit FAN_OUT, 5
        fan_bit FAN_OUT, 4
        fan_bit FAN_OUT, 3
        fan_bit FAN_OUT, 2
        fan_bit FAN_OUT, 1
        fan_bit FAN_OUT, 0
        movlw   FAN_LIGHT_CMD & 0xf
        movwf   FAN_OUT
        fan_bit FAN_OUT, 3
        fan_bit FAN_OUT, 2
        fan_bit FAN_OUT, 1
        fan_bit FAN_OUT, 0
#endif
#if 0
        pin_on  RF_DATA
        red_on
        delayp
        red_off
        pin_off RF_DATA
        delayp
        goto fan_send
#endif
        red_off

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
        delayms
        delayms
        delayms
        goto fan_send

flash_leds:
        ; test top bit of timer
        red_on
        pin_on  RF_DATA
        delayp
        red_off
        pin_off  RF_DATA
        delayp
        goto    flash_leds

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

        end

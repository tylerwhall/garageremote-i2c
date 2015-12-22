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

; RF commands (first byte of 3)
RF_WAPP     equ     0x0
RF_RAPP     equ     0x33
RF_WFREQ    equ     0x18
RF_RFREQ    equ     0x44
RF_RSTAT    equ     0x55

RED_LED     equ     4
GREEN_LED   equ     1
RF_CTRL     equ     5
RF_DATA     equ     2

; Common Bank Variables (0-3)
TEMP        equ     0x7

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

start:
        ; set prescaler to max (/8)
        movlw   NOT_RBPU & NOT_RBWU & b'111'
        option

        ; outputs
        movlw   0xff & ~(1 << RF_CTRL | 1 << RF_DATA)
        movwf   PORTB
        movlw   0xff & ~(1 << RED_LED | 1 << GREEN_LED | 1 << RF_CTRL | 1 << RF_DATA)
        tris    PORTB
        red_on

        ; Overly long delay to wait for RF to be ready
        call    delay_ms
        red_off

        ; Program freq
        movlw   RF_WFREQ | (RF_DF >> D'16')
        call    rf_outw
        movlw   (RF_DF >> 8) & 0xff
        call    rf_outw
        movlw   (RF_DF >> 0) & 0xff
        call    rf_outw

        call    delay_ms

flash_leds:
        ; test top bit of timer
        red_on
        pin_on  RF_DATA
        call    delay_ms
        red_off
        pin_off  RF_DATA
        call    delay_ms
        goto    flash_leds

delay_ms:
        movlw   D'7'
        movwf   TEMP
        movlw   0x0
        movwf   TMR0
delay_ms_loop:
        movf    TMR0, w
        subwf   TEMP, w
        btfsc   STATUS, C
        goto    delay_ms_loop
        retlw   0x0

rf_bit  macro   reg, bit
        pin_on  RF_DATA
        btfss   reg, bit
        pin_off RF_DATA
        pin_on  RF_CTRL
        pin_off RF_CTRL
        endm

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

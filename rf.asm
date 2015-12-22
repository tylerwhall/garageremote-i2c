	processor 12f529t39a
	include "p12f529t39a.inc"
        __CONFIG _WDT_OFF & _OSC_INTRC & _IOSCFS_8MHz & _MCLRE_OFF & _CP_DISABLE & _CPDF_OFF

RED_LED     equ     4
GREEN_LED   equ     4

TRIS_MIRROR equ     0x10

red_on  macro
        bcf     PORTB, RED_LED
        endm

red_off macro
        bsf     PORTB, RED_LED
        endm

start:
        ; set prescaler to max
        movlw   NOT_RBPU & NOT_RBWU & b'111'
        option

        ; LED outputs
        movlw   0xff
        movwf   PORTB
        movlw   0xff & ~(1 << RED_LED) & ~(1 << GREEN_LED)
        tris    PORTB

delay:
        ; test top bit of timer
        btfss   TMR0, 7
        goto    timer_low
        red_off
        goto    delay

timer_low:
        red_on
        goto    delay
        end

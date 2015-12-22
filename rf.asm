	processor 12f529t39a
	include "p12f529t39a.inc"
        __CONFIG _WDT_OFF & _OSC_INTRC & _IOSCFS_8MHz & _MCLRE_OFF & _CP_DISABLE & _CPDF_OFF

RED_LED EQU 4
        ; set prescaler to max
        movlw   NOT_RBPU & NOT_RBWU & b'111'
        option
        bcf     PORTB, RED_LED
        ; all pins to input except 0

        movlw   0xff
        tris    PORTB

delay:
        ; test top bit of timer
        btfss   TMR0, 7
        goto    timer_low
        andlw   0xff & ~(1 << RED_LED)
        tris    PORTB
        goto    delay

timer_low:
        iorlw   (1 << RED_LED)
        tris    PORTB
        goto    delay
        end

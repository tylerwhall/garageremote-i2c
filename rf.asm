	processor 12f529t39a
	include "p12f529t39a.inc"
        __CONFIG _WDT_OFF & _OSC_INTRC & _IOSCFS_8MHz & _MCLRE_OFF

        ; set prescaler to max
        movlw   NOT_RBPU & NOT_RBWU & b'111'
        option
        ; all pins to input except 0
        movlw   0xfe
        tris    w

delay:
        ; test top bit of timer
        btfss   TMR0, 7
        goto    timer_low
        bcf     PORTB, 1
        goto    delay

timer_low:
        bsf     PORTB, 0
        goto    delay
        end

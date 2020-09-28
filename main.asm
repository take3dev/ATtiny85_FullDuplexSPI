;
; ATtiny85_FullDuplexSPI.asm
;
; Created: 9/26/2020 11:22:03
; Author : paul@take3dev.com
;
; Code for Part 1 of the "Full-Duplex SPI on the ATtiny85 using AVR
; Assembly" series on take3dev.com
;
; ===== REFERENCE DOCUMENTS =====
; ATtiny85 datasheet:
;     Atmel document 2586Q-AVR-08/2013
; AVR instruction set manual:
;     Atmel-0856L-AVR-Instruction-Set-Manual_Other-11/2016
; AVR assembler manual:
;     DS40001917A

.cseg
; ===== VECTOR TABLE =====
; This vector table is taken directly from the ATtiny85 datasheet
; See datasheet section 9.1 for context
.org 0x0000 ; Set address of next statement
rjmp RESET  ; Address 0x0000
reti ;rjmp INT0_ISR       ; Address 0x0001
reti ;rjmp PCINT0_ISR     ; Address 0x0002
reti ;rjmp TIM1_COMPA_ISR ; Address 0x0003
reti ;rjmp TIM1_OVF_ISR   ; Address 0x0004
reti ;rjmp TIM0_OVF_ISR   ; Address 0x0005
reti ;rjmp EE_RDY_ISR     ; Address 0x0006
reti ;rjmp ANA_COMP_ISR   ; Address 0x0007
reti ;rjmp ADC_ISR        ; Address 0x0008
reti ;rjmp TIM1_COMPB_ISR ; Address 0x0009
reti ;rjmp TIM0_COMPA_ISR ; Address 0x000A
reti ;rjmp TIM0_COMPB_ISR ; Address 0x000B
reti ;rjmp WDT_ISR        ; Address 0x000C
reti ;rjmp USI_START_ISR  ; Address 0x000D
reti ;rjmp USI_OVF_ISR    ; Address 0x000E

; ===== ISR PROCEDURES =====
RESET:
    ; Initialize stack pointer
    ldi r16, low(RAMEND)
    out SPL, r16
    ldi r16, high(RAMEND)
    out SPH, r16

; ===== INITIALIZATION =====
io_init:
    ; PB1 (DO):  output
    ; PB2 (SCK): output
    ldi r16, (1<<PORTB1) | (1<<PORTB2)
    out DDRB, r16

; ===== APPLICATION CODE =====
main_loop:
    ldi r16, 0b10100101
    rcall spi_transfer
    rjmp main_loop

spi_transfer:
    out USIDR, r16
    ldi r16, (1<<USIOIF)
    out USISR, r16
    ldi r17, (1<<USIWM0) | (1<<USICS1) | (1<<USICLK) | (1<<USITC)

spi_transfer_loop:
    out USICR, r17
    in r16, USISR
    sbrs r16, USIOIF
    rjmp spi_transfer_loop
    in r16, USIBR
    ret

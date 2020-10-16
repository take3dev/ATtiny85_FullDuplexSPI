;
; ATtiny85_FullDuplexSPI.asm
;
; Created: 9/26/2020 11:22:03
; Author : paul@take3dev.com
;
; Code for Full-Duplex SPI on the ATtiny85 using AVR Assembly series on
; https://www.take3dev.com
;
; Register use and calling convention are covered in detail at:
; https://take3dev.com/attiny85-register-introduction/
;
; ===== REGISTER LAYOUT =====
; R0: Scratch register, need not be saved or restored surrounding use.
; R1: Fixed register, always assumed to contain a value of 0.
; R2 - R11: General purpose registers. These are call-saved, meaning the
;   application can expect the data in these registers to be stored and
;   restored by a subroutine before returning.
; R12 - R15: Extended argument/return registers for called procedures.
;   These are call-used, meaning the application should not expect data
;   in these registers to remain persistent through a procedure call and
;   return. The caller is responsible for storing and restoring data in
;   these registers surrounding procedure calls.
; R16, R17: Scratch registers, data need not be stored or restored
;   surrounding use.
; R18 - R21: General purpose immediate registers. Call-used.
; R22 - R25: Primary argument/return registers for called functions.
;   Call-used.
; R26 - R31: X, Y, Z registers for indirect addressing. Call-saved.

; ===== PROCEDURE CALL CONVENTION =====
; Procedure calls are made in accordance with the avr-gcc ABI.
; To summarize:
; - Arguments are passed on even-number register boundaries starting at
;   R24 and counting down with increased size requirements.
; - If there is insufficient register space to handle arguments,
;   arguments are passed in memory.
; - Return values are passed back to the caller using the same register
;   alignment as before
; - If there will be insufficient register space to handle return values
;   it is the responsibility of the caller to allocate stack space and
;   provide the called procedure with a base address at which to begin
;   writing.
;
; ===== REFERENCE DOCUMENTS =====
; ATtiny85 datasheet:
;     Atmel document 2586Q-AVR-08/2013
; AVR instruction set manual:
;     Atmel-0856L-AVR-Instruction-Set-Manual_Other-11/2016
; AVR assembler manual:
;     DS40001917A
; AVR-GCC Application Binary Interface:
;     https://gcc.gnu.org/wiki/avr-gcc

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

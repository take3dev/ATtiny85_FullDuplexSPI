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
; ===== DOCUMENTATION DETAILS =====
; Callable procedures will contain a doc header formatted as follows:
; - Label
; - Brief of purpose
; - C-like abstraction of implementation
; - Parameter register descriptions
; - Returns register descriptions
; - Memory/stack use if applicable
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

.dseg
; ===== GLOBAL DATA INSTANTIATION =====
tbuf: .byte 16 ; Transmit buffer, 16 bytes
rbuf: .byte 16 ; Receive buffer, 16 bytes

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
    ; PB0 (DI):  INPUT (implicit)
    ; PB1 (DO):  output
    ; PB2 (SCK): output
    ldi r16, (1<<PORTB1) | (1<<PORTB2)
    out DDRB, r16

spi_init:
    ; Wire mode 01: three wire mode for SPI protocol
    ; Clock source 10: external, positive edge
    ; Clock strobe 1: select USITC as clock source
    ldi r16, (1<<USIWM0) | (1<<USICS1) | (1<<USICLK)
    out USICR, r16

; ===== APPLICATION CODE =====
main_loop:
    ; Move const string from Flash to transmit buffer in RAM
    ldi r16, 0x0d ; Length of "Hello World!" + '\0'
    ldi XL, low(tbuf)
    ldi XH, high(tbuf)
    ldi ZL, low(hello * 2) ; Flash is 16b wide so multiply address by 2
    ldi ZH, high(hello * 2)
    lpm r0, Z+
    st X+, r0
    dec r16
    brne PC-0x03
    ; Prepare registers for SPI transfer call
    ldi r20, low(tbuf)
    ldi r21, high(tbuf) ; pdataTx
    ldi r22, low(rbuf)
    ldi r23, high(rbuf) ; pdataRx
    ldi r24, 0x0d ; nbytes
    rcall spi_transfer
    mov r16, r24
    rjmp main_loop

; ===== SPI MASTER =====
; spi_transfer
; Transmit and receive N bytes as a SPI master
; void spi_transfer(uint16 *pdataTx, uint16 *pdataRx, uint8 nbytes)
; Param R21,20: pdataTx; SRAM address of transmit buffer
; Param R23,22: pdataRx; SRAM address of receive buffer
; Param R24: nbytes; Number of bytes to transmit and receive
; Return none
spi_transfer:
    nop
    ret
; spi_byte_transfer
; Transmit and receive one byte over three-wire USI
; uint8 spi_byte_transfer(uint8 payload)
; Param R24: payload; Byte value to transmit
; Return R24: Received byte
spi_byte_transfer:
    out USIDR, r24 ; Transfer payload from r24 to USI data register
    ldi r16, (1<<USIOIF) ; Clear counter overflow interrupt flag
    out USISR, r16
spi_byte_transfer_loop:
    sbi USICR, USITC ; Toggle clock
    in r16, USISR    ; Record USI peripheral status
    sbrs r16, USIOIF ; Exit loop if counter overflow flag is set
    rjmp spi_byte_transfer_loop
    in r24, USIBR
    ret

; ===== CONSTANT DATA INITIALIZATION =====
hello: .db "Hello World!", 0x00, 0x00 ; Extra padding 0 for alignment

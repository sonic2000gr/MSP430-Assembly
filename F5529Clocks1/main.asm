;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
;
;
;-------------------------------------------------------------------------------
            .cdecls C,LIST,"msp430.h"       ; Include device header file

;-------------------------------------------------------------------------------
            .text                           ; Assemble into program memory
            .retain                         ; Override ELF conditional linking
                                            ; and retain current section
            .retainrefs                     ; Additionally retain any sections
                                            ; that have references to current
                                            ; section
            .global RESET
;-------------------------------------------------------------------------------
RESET       mov.w   #__STACK_END,SP         ; Initialize stackpointer
StopWDT     mov.w   #WDTPW|WDTHOLD,&WDTCTL  ; Stop watchdog timer

;-------------------------------------------------------------------------------
                                            ; Main loop here
;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
;											Output SMCLK, MCLK, ACLK to pins
;-------------------------------------------------------------------------------

			bis.b #BIT2,&P2DIR				; Set P2.2 as output
			bis.b #BIT2,&P2SEL				; Set P2.2 as peripheral output
											; P2.2 is multiplexed with SMCLK
											; This will output SMCLK to P2.2

			bis.b #BIT7,&P7DIR				; Set P7.7 as output
			bis.b #BIT7,&P7SEL				; Set P7.7 as peripheral output
											; P7.7 is multiplexed with MCLK
											; This will output MCLK to P7.7
											; P7.7 is not present in the headers
											; of the launchpad. It is output pin 60
											; on F5529. Top right corner ;)

			bis.b #BIT7,&P4DIR				; Set P4.7 as output (Green LED)
			bis.b #BIT0,&P1DIR				; Set P1.0 as output (Red LED)

			mov.w #3787, R15				; Delay parameters
			mov.w #22, R14

blink		xor.b #BIT0,&P1OUT
			call #delay
			jmp blink

;-------------------------------------------------------------------------------
;                                             Delay subroutine
;-------------------------------------------------------------------------------
; 											Inner Loop: R13 (Via R15)
;											Outer Loop: R14
;											Total delay: Setting up / return: 20 cycles
;											Inner Loop: R15x3xR14 cycles
;											Outer Loop : R14x4 cycles

delay		pushm.a #2, R14					; 2+2*2 = 6 cycles
outer		mov.w R15, R13			    	; 1 cycle
inner		sub.w #1, R13					; 1 cycles (uses CGR2)
			jne inner						; 2 cycles
			sub.w #1, R14					; 1 cycles (uses CGR2)
			jne outer						; 2 cycles
			popm.a #2,R14					; 2+2*2=6 cycles
            ret								; 4 cycles


;-------------------------------------------------------------------------------
;           Stack Pointer definition
;-------------------------------------------------------------------------------
            .global __STACK_END
            .sect 	.stack

;-------------------------------------------------------------------------------
;           Interrupt Vectors
;-------------------------------------------------------------------------------
            .sect   ".reset"                ; MSP430 RESET Vector
            .short  RESET

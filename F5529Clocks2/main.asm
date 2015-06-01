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

;-------------------------------------------------------------------------------
;											Connect and start the LFXT1
;                                           (Low frequency crystal 1)
;											32KHz and XT2 (4MHz)
;-------------------------------------------------------------------------------
			bis.b #BIT4+BIT5,&P5SEL			; Connect XT1 to P5.5, P5.4
											; by configuring the ports for
											; peripheral function

			bis.b #BIT2+BIT3,&P5SEL			; Connect XT2 to P5.3, P5.2
											; by configuring the ports for
											; peripheral function

			bic.w #XT1OFF, &UCSCTL6			; Turn on XT1
			bic.w #XT2OFF, &UCSCTL6			; Turn on XT2

			bis.w #XCAP_3, &UCSCTL6          ; Internal load capacitor for XT1

waitclear   bic.w   #XT2OFFG | XT1LFOFFG | DCOFFG, &UCSCTL7
	                                        ; Clear XT2,XT1,DCO fault flags  (XT1 and XT2 only here)
            bic.w   #OFIFG,&SFRIFG1         ; Clear fault flags
            bit.w   #OFIFG,&SFRIFG1         ; Test oscillator fault flag
            jc      waitclear

            bic.w   #XT1DRIVE_3,&UCSCTL6    ; XT1 is now stable, reduce drive
                                            ; strength. Low frequency crystals take some time
                                            ; to start and stabilize
            bic.w   #XT2DRIVE_0,&UCSCTL6    ; XT2 Drive strength reduced to level 0
            								; for 4-8MHz operation

;-------------------------------------------------------------------------------
;                                         Connect crystals to ACLK, SMCLK, MCLK
;-------------------------------------------------------------------------------
;                                         Uncomment here to use crystals directly
;											or skip to next section to use DCO
;-------------------------------------------------------------------------------
            mov.w #SELA_0|SELS_5|SELM_5,&UCSCTL4 ; UCSCTL4 selects the source for every clock
;
;			MCLK=SMCLK=XT2CLK (4MHz), ACLK=XT1 (32768Hz)

;			SELA_X sets ACLK according to table:
;
;			SELA_0 - XT1CLK
;           SELA_1 - VLOCLK
;			SELA_2 - REFOCLK
;			SELA_3 - DCOCLK
;			SELA_4 - DCOCLKDIV
;			SELA_5 - XT2CLK
;			SELA_6 - Reserved (XT2CLK or DCOCLKDIV if XT2 not available)
;			SELA_7 - Reserved (same as above)
;
;           SELS_X sets SMCLK (see table above)
;           SELM_X sets MCLK (see table above)
;
;-----------------------------------------------------------------------------

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

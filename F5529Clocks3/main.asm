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
SVSMXCTLD	.set 0x4400

;-------------------------------------------------------------------------------
RESET       mov.w   #__STACK_END,SP         ; Initialize stackpointer
StopWDT     mov.w   #WDTPW|WDTHOLD,&WDTCTL  ; Stop watchdog timer

;-------------------------------------------------------------------------------
                                            ; Main loop here
;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
;											Increase Vcore to max
;											step by step
;-------------------------------------------------------------------------------
           	mov.w #PMMCOREV_1,R12
			call #setvcore
			mov.w #PMMCOREV_2,R12
			call #setvcore
			mov.w #PMMCOREV_3,R12
			call #setvcore
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

waitclear   bic.w   #XT2OFFG + XT1LFOFFG + DCOFFG , &UCSCTL7
	                                        ; Clear XT2,XT1,DCO fault flags
            bic.w   #OFIFG,&SFRIFG1         ; Clear fault flags
            bit.w   #OFIFG,&SFRIFG1         ; Test oscillator fault flag
            jc      waitclear

            bic.w   #XT1DRIVE_3,&UCSCTL6    ; XT1 is now stable, reduce drive
                                            ; strength. Low frequency crystals take some time
                                            ; to start and stabilize
            bic.w   #XT2DRIVE_0,&UCSCTL6    ; XT2 Drive strength reduced to level 0
            								; for 4-8MHz operation
;-------------------------------------------------------------------------------------------------
;												Prepare DCO
;-------------------------------------------------------------------------------------------------
;			Default settings in UCSCTL3: SELREF = 000b -> FLLREF = XT1CLK
;										 FLLREFDIV = 000b -> FLLREFCLK / 1

			bis.w   #SCG0,SR                  ; Disable the FLL control loop
            clr.w   &UCSCTL0                  ; Set lowest possible DCOx, MODx
            mov.w   #DCORSEL_7,&UCSCTL1       ; Select range for 20MHz operation
            mov.w   #FLLD_2 + 639,&UCSCTL2    ; Set DCO multiplier for DCOCLKDIV
                                              ; (FLLN + 1) * (FLLRef/n) * FLLD = DCOCLK
                                              ; FLLD_2 = 4
                                              ; FLLRef=32768 and n=1
                                              ; (n=FLLREFDIV)
                                              ; DCOCLKDIV = DCOCLK/FLLD = (FLLN+1)*(FLLRef/n)
                                              ; Default settings are DCOCLKDIV for MCLK/SMCLK
            bic.w   #SCG0,SR                  ; Enable the FLL control loop

; Worst-case settling time for the DCO when the DCO range bits have been
; changed is n x 32 x 32 x F_fLLREFCLK cycles.
; 32 x 32 x 20.97152 MHz / 32.768 KHz = 655360 = MCLK cycles for DCO to settle

			mov.w #9930,R15
			mov.w #22,R14
			call #delay

; Total cycles: setup 6+6+2=14
; Internal Loop: 9930*3*22=655380
; Outer loop: 22*5 = 110
; Total: 110+655380+14 = 655504

; Loop until DCO fault flag is cleared

delay_DCO   bic.w   #DCOFFG,&UCSCTL7        ; Clear DCO fault flags
            bic.w   #OFIFG,&SFRIFG1         ; Clear fault flags
            bit.w   #OFIFG,&SFRIFG1         ; Test oscillator fault flag
            jc      delay_DCO

 			mov.w #SELA_0|SELS_4|SELM_4,&UCSCTL4

;-----------------------------------------------------------------------------

			mov.w #16384, R15				; Delay parameters
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
setvcore   ; SetVCore function
           ; In order to support high speed MCLK , The voltage level of Vcore  must be sufficiently high
           ; The voltage level of Vcore must be increased by one step one time
           ; This is taken from TI's own example code
;-------------------------------------------------------------------------------
            mov.b   #PMMPW_H, &PMMCTL0_H     ; Open PMM registers for write
   											 ; Set SVS/SVM high side new level
            mov.w   R12,R15                  ; R12--->R15
			and.w   #0xff,R15				 ; Make sure high byte is cleared
            swpb    R15                      ; exchange the high and low byte of R15
            add.w   R12,R15                  ; add src to dst src+dst--->dst
            								 ; The above sets both SVSHRVL and SVSMHRRL fields to the same
            								 ; value (same bits as desired PMMVCORE_x)
            add.w   #SVSMXCTLD,R15           ; SVM high-side enable ,SVS high-side enable
            mov.w   R15,&SVSMHCTL            ;
   									         ;  Set SVM low side to new level
			mov.w   R12,R15
			add.w   #SVSMXCTLD,R15
			mov.w   R15,&SVSMLCTL
   											 ; Wait till SVM is settled
do_waitsvm  bit.w   #SVSMLDLYIFG,&PMMIFG     ; Test SVSMLDLYIFG
			jz      do_waitsvm
   											 ; Clear already set flags
            bic.w   #SVMLIFG,&PMMIFG         ; Clear SVM low-side interrupt flag
            bic.w   #SVMLVLRIFG,&PMMIFG      ; Clear  SVM low-side voltage level reached interrupt flag

            mov.b   R12,&PMMCTL0_L			 ; Set VCore to new level
   											 ; Wait till new level reached
            bit.w   #SVMLIFG,&PMMIFG
            jz      low_set
do_waitifg  bit.w   #SVMLVLRIFG,&PMMIFG      ; Test SVMLvLrIFG
			jz      do_waitifg
    										 ; Set SVS/SVM low side to new level
low_set     mov.w   R12,R15
            and.w   #0xff,R15				 ; Make sure high byte is cleared
            swpb    R15
            add.w   R15,R12
            add.w   #SVSMXCTLD,R12
            mov.w   R12,&SVSMLCTL
			clr.b   &PMMCTL0_H				 ; Lock PMM registers for write access
            ret
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

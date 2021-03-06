;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; DATE:  2018-12-05
; AUTHOR: Jacques Deschenes, Copyright 2018
; DESCRIPTION:    
;   musix box built using a PIC12F1572
; VERSION: 2    
; LICENCE: GPLv3    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;    
    
;*******************************************************************************
;   This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <https://www.gnu.org/licenses/>
;*******************************************************************************
    
    include p12f1572.inc
    
	__config _CONFIG1, _FOSC_INTOSC&_WDTE_OFF&_PWRTE_OFF&_BOREN_OFF&_MCLRE_ON
	
	__config _CONFIG2, _PLLEN_ON&_STVREN_OFF&_LPBOREN_OFF&_LVP_OFF
	
	radix dec
	
;;;;;;;;;;;;;	
; constants	
;;;;;;;;;;;;;
VERSION EQU 2	
ENV_CLK EQU 15500 ; clock after prescale for ENV pwm
FOSC EQU 32000000  ; CPU oscillator frequency, PLLON
FCYCLE EQU 8000000  ; instruction cycle frequency
CPER EQU 125 ; intruction cycle in nanoseconds

; offset pwm registers
PWMPHL EQU 0
PWMPHH EQU 1 
PWMDCL EQU 2 
PWMDCH EQU 3
PWMPRL EQU 4
PWMPRH EQU 5
PWMOFL EQU 6
PWMOFH EQU 7
PWMTMRL EQU 8
PWMTMRH EQU 9
PWMCON EQU 10
PWMINTE EQU 11
PWMINTF EQU 12
PWMCLKCON EQU 13 
PWMLDCON EQU 14
PWMOFCON EQU 15
; PWMCLKCON register 
PWMPS EQU 4 ; prescale select
PWMCS EQU 0 ; clock source select
 
; tone pwm
TONE EQU PWM1PH
TONE_RA EQU RA0
 
; enveloppe pwm 
ENV EQU  PWM3PH
ENV_PIR EQU PIR3
ENV_INTF EQU PWM3IF
ENV_PIE EQU PIE3
ENV_INTE EQU PWM3IE 
ENV_RA EQU RA2
 
; CWG output pins, red/green LED control 
GRNLED_RA EQU RA5
REDLED_RA EQU RA4

; heart beat LED
HBLED EQU PWM2PH
HBEAT_LED EQU RA0
HBLED_IF EQU PWM2IF 
HBLED_IE equ PWM2IF
HBLED_PIE EQU PIE3
HBLED_PIR EQU PIR3
 
; tempered scale 2th octave
C2 EQU 0
C2s EQU 1
D2f EQU 1
D2 EQU 2
D2s EQU 3
E2f EQU 3 
E2 EQU 4
F2 EQU 5
F2s EQU 6
G2f EQU 6
G2 EQU 7
G2s EQU 8
A2f EQU 8 
A2 EQU 9
A2s EQU 10
B2f EQU 10 
B2  EQU 11
C3  EQU 12
C3s EQU 13
D3f EQU 13
D3  EQU 14
; code 15 reserved for pause
  
; notes names in french
DO2 EQU 0
DO2D EQU 1
RE2B EQU 1
RE2 EQU 2
RE2D EQU 3
MI2B EQU 3 
MI2 EQU 4
FA2 EQU 5
FA2D EQU 6
SOL2B EQU 6
SOL2 EQU 7
SOL2D EQU 8
LA2B EQU 8 
LA2 EQU 9
LA2D EQU 10
SI2B EQU 10 
SI2  EQU 11
DO3 EQU 12
DO3D EQU 13
RE3B EQU 13 
RE3 EQU 14
 
 
; duration
WHOLE EQU 0
WHOLE_DOT EQU 1
HALF EQU 2
HALF_DOT EQU 3
QUARTER EQU 4
QUARTER_DOT EQU 5
HEIGTH EQU 6
HEIGTH_DOT EQU 7
SIXTEENTH EQU 8
SIXTEENTH_DOT EQU 9
; code 0xC to 0xF are commands
; repeat start bar in staff
REPT_BAR EQU 0xC0 
; repeat section end here
REPT_END EQU 0xD0 
; stroke switch
STROKE_SWITCH EQU 0xE0
; octave switch
OCT_SWITCH EQU 0xF0   ; octave {O2,O3}
; commands mask
CMD_MASK EQU 0xC0
; end of staff
STAFF_END EQU 0xFF

; stroke type
NORMAL EQU 0
STACCATO EQU 1
LEGATO EQU 2
 
; octaves
O2 EQU 0
O3 EQU 1
O4 EQU 2
O5 EQU 3
 
; boolean flags
; bit position 
F_DONE EQU 0
F_REPT EQU 2 ; repeat flag
 
;;;;;;;;;;;;;;;;;;;;;;;;
;   assembler macros 
;;;;;;;;;;;;;;;;;;;;;;;;

; and enable ENV pwm
env_enable macro
    banksel ENV
    clrf (ENV+PWMINTF)
    movlw 0xC0
    movwf (ENV+PWMCON)
    bcf flags,F_DONE
    endm
    
env_disable macro
    banksel ENV
    bcf (ENV+PWMCON),EN
    endm
 
;enable TONE pwm
tone_enable macro
    banksel TONE
    movlw 0xC0
    movwf (TONE+PWMCON)
    endm
    
;disable TONE pwm
tone_disable macro
    banksel TONE
    bcf (TONE+PWMCON),EN
    endm
    
;switch based on W register value
case macro n, target
    xorlw n
    skpnz
    goto target
    xorlw n
    endm
 
; create an entry in scale table
; 'n' is given pwm period count    
PR_CNT macro n
    dt low n, high n
    endm
   
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   macros to assist melody table creation 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; insert melody table multiplexer code (begin a table)
MELODY macro name
idx SET 0
name 
    movlw high (name+7)
    movwf PCLATH
    movlw low (name+7)
    addwf note_idx,W
    skpnc
    incf PCLATH
    movwf PCL
    endm

; compute duration value from tempo 
; This macro must be the first entry in melody table after MELODY
; Insert 16 bits data in low, high order
; arguments:    
;   'tempo' is  QUARTER/minute
TEMPO macro tempo    
    dt  low (ENV_CLK*60*4/tempo-1), high (ENV_CLK*60*4/tempo-1)
idx SET idx+2
    endm
    
; insert end of table code (mark end of table)
MELODY_END macro
    retlw STAFF_END
    endm

    
; add staff note entry to melody table, one entry by staff note.
; arguments:
;   'name', note name {C2,C2s,D2f,....} 
;   'time', duration {WHOLE, WHOLE_DOT, HALF,...} 
NOTE macro name, time
    retlw ((time<<4)|name)
idx SET idx+1
    endm

; add a pause entry
;  arguments:
;	'time', duration 
PAUSE macro time
    retlw ((time<<4)|0xf)
idx SET idx+1
    endm
    
; set note stroke,  added as required by staff
; s, stroke type {NORMAL,STACCATO,LEGATO} 
STROKE macro s
    retlw STROKE_SWITCH|(s&0x3)
idx SET idx+1
    endm
    
; switching octave
;  o, {O2, O3}
OCTAVE macro o    
    retlw OCT_SWITCH|(o&3)
idx SET idx+1
    endm
 
; return repeat start position    
REPT_START macro
    bsf flags, F_REPT
    retlw (REPT_BAR)
idx SET idx+2
    retlw idx
idx SET idx+1    
    endm
    
; repeat from mark to here    
REPT_LOOP macro
    retlw REPT_END
idx SET idx+1
    endm
    
 
;;;;;;;;;;;;;;;
;  variables
;;;;;;;;;;;;;;;
stack_seg    udata 0x20 
stack res 16 ; arguments stack
 
var_seg  udata_shr 0x70
flags res 1 ; boolean flags  
note_idx res 1 ; current position staff
repeat_mark res 1; index of repeat start section
octave res 1 ; 
play res 1 ; current position in play_list table
stroke res 1 ; staff note stroke {NORMAL,STACCATO,LEGATO} 
; 16 bits working storgage
tempL res 1 ; low byte
tempH res 1; high byte
; working storage 3
temp3 res 1  
; 16 bits arithmetic accumulator
accL res 1 ; low byte
accH res 1 ; high byte
; note duration counter 16 bits value
; extracted from TEMPO entry in melody table 
durationL res 1 ; low byte
durationH res 1 ; high byte
led_dc_inc res 1 ; 
 
;;;;;;;;;;;;;;;;
;   code
;;;;;;;;;;;;;;;;	
	org 0
	goto init

	org 4
isr
hbled_ctrl_isr ;heartbeat interrupt service
	banksel HBLED
	btfss (HBLED+PWMINTF),PRIF
	goto env_isr
	bcf (HBLED+PWMINTF),PRIF
	btfss led_dc_inc,7
	goto positive_slope
negative_slope	
	movlw 2
	subwf (HBLED+PWMDCL),W
	skpnc
	goto change_dc
	goto invert_slope
positive_slope
	movfw (HBLED+PWMPRL)
	addlw 254
	subwf (HBLED+PWMDCL),W
	skpc
	goto change_dc
invert_slope ; two's complement
	comf led_dc_inc,F
	incf led_dc_inc,F
change_dc
	movfw led_dc_inc
	addwf (HBLED+PWMDCL),F
	bsf (HBLED+PWMLDCON),LDA
	banksel HBLED_PIR
	bcf HBLED_PIR,HBLED_IF
env_isr	; envelope interrupt service
	btfsc flags,F_DONE
	goto isr_exit
	banksel ENV
	btfss (ENV+PWMINTF),PRIF
	goto isr_exit
	clrf (ENV+PWMINTF)
	bsf flags,F_DONE
isr_exit	
	banksel ENV_PIR
	bcf ENV_PIR,ENV_INTF
	retfie

	
; PWM period count
; This 16 bits resolution values
; values computed for 8Mhz PWM_clk	
; REF: https://www.deleze.name/marcel/physique/musique/GammeTemperee.html
scale
	clrf PCLATH
	addwf PCL,F
	; O2
	PR_CNT 61161
	PR_CNT 57719
	PR_CNT 54495
	PR_CNT 51413
	PR_CNT 48543
	PR_CNT 45818
	PR_CNT 43242
	PR_CNT 40815
	PR_CNT 38516
	PR_CNT 36363
	PR_CNT 34319
	PR_CNT 32401
	; O3
	PR_CNT 30580
	PR_CNT 28859
	PR_CNT 27238
	PR_CNT 25714
	PR_CNT 24271
	PR_CNT 22909
	PR_CNT 21621
	PR_CNT 20407
	PR_CNT 19262
	PR_CNT 18181
	PR_CNT 17159
	PR_CNT 16197
	; O4
	PR_CNT 15287  
	PR_CNT 14429  
	PR_CNT 13621  
	PR_CNT 12855  
	PR_CNT 12133  
	PR_CNT 11452  
	PR_CNT 10810  
	PR_CNT 10203  
	PR_CNT 9631   
	PR_CNT 9090   
	PR_CNT 8580   
	PR_CNT 8098   
	; O5
	PR_CNT 7644   
	PR_CNT 7215   
	PR_CNT 6809   
	PR_CNT 6427
	PR_CNT 6067
	PR_CNT 5726
	PR_CNT 5404
	PR_CNT 5101
	PR_CNT 4815
	PR_CNT 4544
	PR_CNT 4289
	PR_CNT 4049

; melodies play list
play_list
	clrf PCLATH
	addwf PCL,F
	goto greensleeves
	goto korobeiniki
	goto claire_fontaine
	goto ode_joy
	goto jingle_bell
	goto douce_nuit
	goto beau_sapin
	goto l_hiver
	goto melodia
	goto go_down_moses
	goto amazing_grace
	goto frere_jacques
	goto bon_tabac
	goto roi_dagobert
	goto morning_has_broken
	goto a_bytown
	goto joyeux_anniv
	goto o_canada
	goto god_save_the_queen
	goto deutschlandlied
	goto fur_elise
	goto reset_list


; configure CWG to control
; 4 red, 4 green leds
; 180 degres out of phase	
cwg_config
	; map CWGA -> RA5 and CWGB on RA2
	banksel APFCON
	movlw (1<<CWGASEL)|(1<<CWGBSEL)
	movwf APFCON
	; configure CWG
	banksel CWG1DBR
	bsf CWG1CON1,2 ; source is ENV PWM
	clrf CWG1DBR
	clrf CWG1DBF
	movlw (1<<G1EN)|(1<<G1OEA)|(1<<G1OEB)
	movwf CWG1CON0
	return
	
; heart beat led control
config_hbled_control
	movlw 1
	movwf led_dc_inc
	; configure HBLED PWM
	banksel HBLED
	clrf (HBLED+PWMPHL)
	clrf (HBLED+PWMPHH)
	clrf (HBLED+PWMOFL)
	clrf (HBLED+PWMOFH)
	bsf (HBLED+PWMCLKCON),1 ; use LFINTOSC as source clock
	movlw 120
	movwf (HBLED+PWMPRL)
	clrf (HBLED+PWMPRH)
	movlw 60
	movwf (HBLED+PWMDCL)
	clrf (HBLED+PWMDCH)
	bsf (HBLED+PWMLDCON),LDA
	; set interrupt on PR to modify DC
	bcf (HBLED+PWMINTF),PRIF
	bsf (HBLED+PWMINTE),PRIE
	bsf (HBLED+PWMCON),EN
	bsf (HBLED+PWMCON),OE
	; enable interrupt in HBLED_PIE
	banksel HBLED_PIE
	bsf HBLED_PIE,HBLED_IE
	return
	
init
	banksel OSCCON
	movlw (0xE<<IRCF0)
	movwf OSCCON
	banksel ANSELA
	clrf ANSELA
	; limit slew rate
	banksel SLRCONA
	movlw 0xff
	movwf SLRCONA
	; ensure ENV_RA==0 and TONE_RA=0
	banksel LATA
	bcf LATA,ENV_RA
	bcf LATA,TONE_RA
	; output pins: RA0,RA1,R2,RA2,RA5
	banksel TRISA
	clrf TRISA
	; red/green leds cwg configuration
	call cwg_config
	; heartbeat led config
	call config_hbled_control
	; clear TONE PH, DC, PR, OF
	banksel TONE
	movlw high TONE
	movwf FSR1H
	movlw low TONE
	movwf FSR1L
	movlw 8
	clrf INDF1
	incf FSR1L
	addlw 255
	skpz
	goto $-4
	bsf (TONE+PWMLDCON),LDA
	; clear ENV PH, DC, PR, OF
	movlw high ENV
	movwf FSR1H
	movlw low ENV
	movwf FSR1L
	movlw 8
	clrf INDF1
	incf FSR1L
	addlw 255
	skpz
	goto $-4
	bsf (ENV+PWMLDCON),LDA
	; configure TONE pwm
	movlw 2<<PWMPS
	movwf (TONE+PWMCLKCON)
	movlw 0xC0
	movwf (TONE+PWMCON)
	; configure ENV pwm
	movwf (ENV+PWMCON)
	movlw (2<<PWMCS)|(1<<PWMPS)
	movwf (ENV+PWMCLKCON)
	; enable_interrupt for ENV DC and PR
	clrf (ENV+PWMINTF)
	bsf (ENV+PWMINTE),PRIE
	banksel ENV_PIE
	bsf ENV_PIE,ENV_INTE
	banksel INTCON
	movlw (1<<GIE)|(1<<PEIE)
	movwf INTCON
	btfss STATUS,NOT_PD
	goto main
reset_list
	clrf play
main
	clrf note_idx
	clrf stroke
	clrf flags
	movfw play
	call play_list
	movwf durationL
	incf note_idx,F
	movfw play
	call play_list
	movwf durationH
	movfw durationL
	movwf tempL
	movfw durationH
	movwf tempH
	movlw 8
	movwf temp3
div256
	movfw temp3
	skpnz
	goto set_biled_per
	clrc
	rrf tempH,F
	rrf tempL,F
	decf temp3,F
	goto div256
set_biled_per
	banksel HBLED
	movfw tempL
	movwf (HBLED+PWMPRL)
	bsf (HBLED+PWMLDCON),LDA
staff_loop
	incf note_idx
	movfw play
	call play_list
	movwf tempL
	xorlw STAFF_END
	skpnz
	goto melody_done
	movfw tempL
	andlw 0xF0
	case OCT_SWITCH, cmd_octave
	case STROKE_SWITCH, cmd_stroke
	case REPT_BAR, cmd_repeat_bar
	case REPT_END, cmd_repeat_loop
	movlw 0xF
	andwf tempL,W
	xorlw 0xF
	skpz
	goto tone
	swapf tempL,W
	andlw 0xF
	call pause
	goto staff_loop
tone
	movfw tempL
	call play_note
	goto staff_loop
cmd_octave
	movlw 3
	andwf tempL,W
	movwf octave
	goto staff_loop
cmd_stroke
	movlw 3
	andwf tempL,W
	movwf stroke
	goto staff_loop
cmd_repeat_bar
	incf note_idx,F
	incf note_idx,F
	movfw play
	call play_list
	movwf repeat_mark
	goto staff_loop
cmd_repeat_loop
	btfss flags, F_REPT
	goto staff_loop
	movfw repeat_mark
	movwf note_idx
	bcf flags, F_REPT
	goto staff_loop
melody_done
	incf play,F
	call low_power
	sleep
	goto init

; configure �C for lowest current draw
; during sleep	
low_power
	banksel INTCON
	bcf INTCON, GIE
	banksel HBLED
	bcf (HBLED+PWMCON),EN
	bcf (HBLED+PWMCON),OE
	bcf (HBLED+PWMINTE),PRIF
	bcf (HBLED+PWMINTF),PRIF
	banksel CWG1CON0
	bcf CWG1CON0,G1OEA
	bcf CWG1CON0,G1OEB
	banksel LATA
	bcf LATA,GRNLED_RA
	bcf LATA,REDLED_RA
	bsf LATA,HBEAT_LED
	return

; disable any tone
; wait duration	
; arguemnents:
;   W  duration value extracted from melody table
;	value in low nibble	
pause
	call set_envelope
	env_enable
	btfss flags, F_DONE
	goto $-1
	env_disable
	return
	
; play staff note
; arguments:
;   W  note data extracted from melody table
;	low nibble note_idx
;	high nibble duration
play_note
	movwf temp3
	andlw 0xF
	call set_tone_freq
	swapf temp3,W
	andlw 0xF
	call set_envelope
	tone_enable
	env_enable
	btfss flags, F_DONE
	goto $-1
	tone_disable
	env_disable
	return
	
; set tone duration
; argument W duration value {WHOLE,DOTTED_WHOLE,...}	
set_envelope 
	movwf tempL
	banksel ENV
	; duration variable contain value for WHOLE
	movfw durationL
	movwf accL
	movfw durationH
	movwf accH
	clrc
	rrf tempL,W
	movwf tempH
; repeat devision by 2 until tempH==0
div2_loop	
	movfw tempH
	skpnz
	goto div_done
	clrc
	rrf accH,F
	rrf accL,F
	decf tempH,F
	goto div2_loop
div_done
; if it is dotted increase duration by 50%
	btfss tempL,0
	goto set_duration
	clrc
	rrf accH,W
	movwf tempH
	rrf accL,W
	addwf accL,F
	skpnc
	incf tempH,F
	movfw tempH
	addwf accH,F
set_duration	
	movfw accL
	movwf (ENV+PWMPRL)
	movfw accH
	movwf (ENV+PWMPRH)
	movlw LEGATO
	xorwf stroke,W
	skpnz
	goto legato_mode
	movlw STACCATO
	xorwf stroke,W
	skpnz
	goto staccato_mode
normal_mode ; 3/4 duration
	clrc
	rrf accH,F
	rrf accL,F
	clrc
	rrf accH,F
	rrf accL,W
	subwf (ENV+PWMPRL),W
	movwf accL
	skpc
	incf accH,F
	movfw accH
	subwf (ENV+PWMPRH),W
	movwf accH
	goto update_dc
staccato_mode ; 1/2 duration
	clrc
	rrf accH,F
	rrf accL,F 
	goto update_dc
legato_mode ; 7/8 duration
	movlw 3
	movwf tempL
div8
	movfw tempL
	skpnz
	goto div8_done
	clrc
	rrf accH,F
	rrf accL,F
	decf tempL,F
	goto div8
div8_done	
	movfw accL
	subwf (ENV+PWMPRL),W
	movwf accL
	skpc
	incf accH,F
	movfw accH
	subwf (ENV+PWMPRH),W
	movwf accH
update_dc
	movfw accL
	movwf (ENV+PWMDCL)
	movfw accH
	movwf (ENV+PWMDCH)
update_env
	bsf (ENV+PWMLDCON), LDA
	return
	
;configure PWM channel to generate tone 50% duty cycle
; argument W tone index for 'scale' table
set_tone_freq
	movwf tempL
	; adjust note_idx for octave
	movfw octave
	skpnz
	goto oct_adj_done
	movwf tempH
	movlw 12
oct_adj_loop	
	addwf tempL,F
	decfsz tempH,F
	goto oct_adj_loop
oct_adj_done	
	banksel TONE
	; set pwm period
	clrc
	rlf tempL,F
	movfw tempL
	call scale
	movwf (TONE+PWMPRL)
	incf tempL,W
	call scale
	movwf (TONE+PWMPRH)
	; set duty cycle
	clrc
	rrf (TONE+PWMPRH),W
	movwf (TONE+PWMDCH)
	rrf (TONE+PWMPRL),W
	movwf (TONE+PWMDCL)
	bsf (TONE+PWMLDCON),LDA
	return

	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   melodies tables to end of memory	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  l'hiver
;REF: https://www.partitionsdechansons.com/pdf/14429/Traditionnel-L-hiver.html	
	    MELODY l_hiver
	    TEMPO 60
	    OCTAVE O3
	    STROKE NORMAL
	    ;1
	    NOTE DO2, HEIGTH
	    NOTE DO2, HEIGTH
	    NOTE SOL2, HEIGTH
	    NOTE SOL2, HEIGTH
	    NOTE LA2, HEIGTH
	    NOTE LA2, HEIGTH
	    NOTE SOL2, HEIGTH
	    OCTAVE O2
	    NOTE SI2, SIXTEENTH
	    OCTAVE O3
	    NOTE DO2, SIXTEENTH
	    ;2
	    NOTE RE2, HEIGTH
	    NOTE RE2, HEIGTH
	    NOTE DO2, HEIGTH
	    OCTAVE O2
	    NOTE SI2, HEIGTH
	    OCTAVE O3
	    NOTE DO2, HALF
	    ;3
	    NOTE DO2, HEIGTH
	    NOTE DO2, HEIGTH
	    NOTE SOL2,HEIGTH
	    NOTE SOL2, HEIGTH
	    NOTE LA2, HEIGTH
	    NOTE LA2, HEIGTH
	    NOTE SOL2, HEIGTH
	    OCTAVE O2
	    NOTE SI2, SIXTEENTH
	    OCTAVE O3
	    NOTE DO2, SIXTEENTH
	    ;4
	    NOTE RE2, HEIGTH
	    NOTE RE2, HEIGTH
	    NOTE DO2, HEIGTH
	    OCTAVE O2
	    NOTE SI2, HEIGTH
	    OCTAVE O3
	    NOTE DO2, HALF
	    ;5
	    REPT_START
	    NOTE RE2, HEIGTH
	    NOTE RE2, HEIGTH
	    NOTE RE2, HEIGTH
	    NOTE RE2, HEIGTH
	    NOTE RE2, HEIGTH
	    NOTE MI2, HEIGTH
	    NOTE FA2, QUARTER
	    ;6
	    NOTE MI2, HEIGTH
	    NOTE MI2, HEIGTH
	    NOTE MI2, HEIGTH
	    NOTE MI2, HEIGTH
	    NOTE MI2, HEIGTH
	    NOTE FA2, HEIGTH
	    NOTE SOL2, QUARTER
	    ;7
	    NOTE SOL2, HEIGTH
	    NOTE SOL2, HEIGTH
	    NOTE DO3, HEIGTH
	    NOTE SOL2, HEIGTH
	    NOTE SOL2, HEIGTH
	    NOTE MI2, HEIGTH
	    NOTE RE2, QUARTER
	    ;8
	    NOTE RE2, HEIGTH
	    NOTE RE2, HEIGTH
	    OCTAVE O2
	    STROKE LEGATO
	    NOTE SI2, QUARTER
	    STROKE NORMAL
	    NOTE SI2, SIXTEENTH
	    OCTAVE O3
	    NOTE DO2, HEIGTH
	    NOTE DO2, QUARTER
	    REPT_LOOP
	    MELODY_END
	
; o douce nuit
; REF: https://www.apprendrelaflute.com/o-douce-nuit-a-la-flute-a-bec	
	MELODY douce_nuit
	TEMPO 60
	OCTAVE O3
	;1
	NOTE SOL2, QUARTER_DOT
	NOTE LA2, HEIGTH
	NOTE SOL2, QUARTER
	;2
	NOTE MI2, HALF_DOT
	;3
	NOTE SOL2, QUARTER_DOT
	NOTE LA2, HEIGTH
	NOTE SOL2, QUARTER
	;4
	NOTE MI2, HALF_DOT
	;5
	NOTE RE3, HALF
	NOTE RE3, QUARTER
	;6
	NOTE SI2, HALF_DOT
	;7
	NOTE DO3, HALF
	NOTE DO3, QUARTER
	;8
	NOTE SOL2, HALF_DOT
	;9
	REPT_START
	NOTE LA2, HALF
	NOTE LA2, QUARTER
	;10
	NOTE DO3, QUARTER_DOT
	NOTE SI2, HEIGTH
	NOTE LA2, QUARTER
	;11
	NOTE SOL2, QUARTER_DOT
	NOTE LA2, HEIGTH
	NOTE SOL2, QUARTER
	;12
	NOTE MI2,HALF_DOT
	;13
	NOTE RE3, HALF
	NOTE RE3, QUARTER
	;14
	OCTAVE O4
	NOTE FA2, QUARTER_DOT
	NOTE RE2, HEIGTH
	OCTAVE O3
	NOTE SI2, QUARTER
	;15
	NOTE DO3, HALF_DOT
	;16
	OCTAVE O4
	NOTE MI2, HALF_DOT
	;17
	OCTAVE O3
	NOTE DO3, QUARTER_DOT
	NOTE SOL2, HEIGTH
	NOTE MI2, QUARTER
	;18
	NOTE SOL2, QUARTER_DOT
	NOTE FA2, HEIGTH
	NOTE RE2, QUARTER
	;19
	NOTE DO2, HALF_DOT
	REPT_LOOP
	MELODY_END

	
; Canada national anthem
; REF: 	https://commons.wikimedia.org/wiki/File:O_Canada.pdf?uselang=fr
	MELODY o_canada
	TEMPO 100
	OCTAVE O2
;1
	NOTE LA2,HALF
	NOTE DO3, QUARTER_DOT
	NOTE DO3, HEIGTH
	;2
	NOTE FA2, HALF_DOT
	NOTE SOL2, QUARTER
	;3
	NOTE LA2, QUARTER
	NOTE SI2B, QUARTER
	NOTE DO3, QUARTER
	NOTE RE3, QUARTER
	;4
	NOTE SOL2, HALF_DOT
	PAUSE QUARTER
	;5
	NOTE LA2, HALF
	NOTE SI2, QUARTER_DOT
	NOTE SI2, HEIGTH
	;6
	NOTE DO3, HALF_DOT
	NOTE RE3, QUARTER
	;7
	OCTAVE O3
	NOTE MI2, QUARTER
	NOTE MI2, QUARTER
	OCTAVE O2
	NOTE RE3, QUARTER
	NOTE RE3, QUARTER
	;8
	NOTE DO3, HALF_DOT
	NOTE SOL2, HEIGTH_DOT
	NOTE LA2, SIXTEENTH
	;9
	NOTE SI2B, QUARTER_DOT
	NOTE LA2, HEIGTH
	NOTE SOL2,QUARTER
	NOTE LA2, HEIGTH_DOT
	NOTE SI2B, SIXTEENTH
	;10
	NOTE DO3,QUARTER_DOT
	NOTE SI2B,HEIGTH
	NOTE LA2,QUARTER
	NOTE SI2B,HEIGTH_DOT
	NOTE DO3, SIXTEENTH
	;11
	NOTE RE3, QUARTER
	NOTE DO3, QUARTER
	NOTE SI2B,QUARTER
	NOTE LA2, QUARTER
	;12
	NOTE SOL2, HALF_DOT
	NOTE SOL2, HEIGTH_DOT
	NOTE LA2, SIXTEENTH
	;13
	NOTE SI2B, QUARTER_DOT
	NOTE LA2, HEIGTH
	NOTE SOL2, QUARTER
	NOTE LA2, HEIGTH_DOT
	NOTE SI2B, SIXTEENTH
	;14
	NOTE DO3, QUARTER_DOT
	NOTE SI2B, HEIGTH
	NOTE LA2, QUARTER
	NOTE LA2, QUARTER
	;15
	NOTE SOL2, QUARTER
	NOTE DO3, QUARTER
	NOTE DO3, HEIGTH
	NOTE SI2, HEIGTH
	NOTE LA2, HEIGTH
	NOTE SI2, HEIGTH
	;16
	NOTE DO3, HALF_DOT
	PAUSE QUARTER
	;17
	NOTE LA2, HALF
	NOTE DO3, QUARTER_DOT
	NOTE DO3, HEIGTH
	;18
	NOTE FA2, HALF_DOT
	PAUSE QUARTER
	;19
	NOTE SI2B, HALF
	NOTE RE3, QUARTER_DOT
	NOTE RE3, HEIGTH
	;20
	NOTE SOL2, HALF_DOT
	PAUSE QUARTER
	;21
	NOTE DO3, HALF
	NOTE DO3D, QUARTER_DOT
	NOTE DO3, HEIGTH
	;22
	NOTE RE3, QUARTER
	NOTE SI2B, QUARTER
	NOTE LA2, QUARTER
	NOTE SOL2, QUARTER
	;23
	NOTE FA2, HALF
	NOTE SOL2, HALF
	;24
	NOTE LA2, HALF_DOT
	PAUSE QUARTER
	;25
	NOTE DO3, HALF
	OCTAVE O3
	NOTE FA2, QUARTER_DOT
	NOTE FA2, HEIGTH
	;26
	OCTAVE O2
	NOTE RE3, QUARTER
	NOTE SI2B, QUARTER
	NOTE LA2, QUARTER
	NOTE SOL2, QUARTER
	;27
	NOTE DO3, HALF
	NOTE MI2, HALF
	;28
	NOTE FA2, HALF_DOT
	PAUSE QUARTER
	MELODY_END
	
; Germany national anthem
; REF: https://www.apprendrelaflute.com/hymne-national-allemand-a-la-flute-a-bec	
	MELODY deutschlandlied
	TEMPO 80
	;1
	REPT_START
	OCTAVE O3
	NOTE SOL2, QUARTER_DOT
	NOTE LA2, HEIGTH
	;2
	NOTE SI2, QUARTER
	NOTE LA2, QUARTER
	NOTE DO3, QUARTER
	NOTE SI2, QUARTER
	;3
	STROKE LEGATO
	NOTE LA2, HEIGTH
	STROKE NORMAL
	NOTE FA2D, HEIGTH
	NOTE SOL2, QUARTER
	OCTAVE O4
	NOTE MI2, QUARTER
	NOTE RE2, QUARTER
	OCTAVE O3
	;4
	NOTE DO3, QUARTER
	NOTE SI2, QUARTER
	NOTE LA2, QUARTER
	NOTE SI2, HEIGTH
	NOTE SOL2, HEIGTH
	;5
	NOTE RE3, HALF
	REPT_LOOP
	;6
	NOTE LA2, QUARTER
	NOTE SI2, QUARTER
	;7
	STROKE LEGATO
	NOTE LA2, HEIGTH
	STROKE NORMAL
	NOTE FA2D, HEIGTH
	NOTE RE2, QUARTER
	NOTE DO3, QUARTER
	NOTE SI2, QUARTER
	;8
	STROKE LEGATO
	NOTE LA2, HEIGTH
	STROKE NORMAL
	NOTE FA2D, HEIGTH
	NOTE RE2, QUARTER
	NOTE RE3, QUARTER
	NOTE DO3, QUARTER
	;9
	NOTE SI2, QUARTER_DOT
	NOTE SI2, HEIGTH
	NOTE DO3D,QUARTER
	STROKE LEGATO
	NOTE DO3D,HEIGTH
	STROKE NORMAL
	NOTE RE3, HEIGTH
	;10
	NOTE RE3, HALF
	;11
	REPT_START
	OCTAVE O4
	NOTE SOL2, QUARTER_DOT
	NOTE FA2D,HEIGTH
	;12
	STROKE LEGATO
	NOTE FA2D,HEIGTH
	STROKE NORMAL
	NOTE MI2, HEIGTH
	NOTE RE2, QUARTER
	NOTE MI2, QUARTER_DOT
	NOTE RE2, HEIGTH
	;13
	STROKE LEGATO
	NOTE RE2,HEIGTH
	STROKE NORMAL
	NOTE DO2,HEIGTH
	OCTAVE O3
	NOTE SI2, QUARTER
	NOTE LA2, QUARTER_DOT
	NOTE SI2,SIXTEENTH
	NOTE DO3, SIXTEENTH
	;14
	STROKE LEGATO
	NOTE RE3, HEIGTH
	STROKE NORMAL
	OCTAVE O4
	NOTE MI2,HEIGTH
	STROKE LEGATO
	NOTE DO2,HEIGTH
	STROKE NORMAL
	OCTAVE O3
	NOTE LA2,HEIGTH
	NOTE SOL2, QUARTER
	STROKE LEGATO
	NOTE SI2, HEIGTH
	STROKE NORMAL
	NOTE LA2, HEIGTH
	;15
	NOTE SOL2, HALF
	REPT_LOOP
	MELODY_END
	
; A Bytown, c'est une Jolie Place
; REF: https://www.partitionsdechansons.com/pdf/12987/Traditionnel-A-Bytown-c-est-une-jolie-Place.html	
	MELODY a_bytown
	TEMPO 120
	OCTAVE O2
	;1
	NOTE RE2, QUARTER
	NOTE SOL2, QUARTER
	;2
	STROKE LEGATO
	NOTE SOL2, QUARTER
	NOTE SOL2, HEIGTH
	STROKE NORMAL
	NOTE SI2, SIXTEENTH
	NOTE SI2, SIXTEENTH
	;3
	NOTE LA2, QUARTER
	NOTE SOL2, QUARTER
	;4
	NOTE MI2, HALF
	;5
	NOTE RE2, QUARTER
	NOTE FA2D, QUARTER
	;6
	NOTE LA2, QUARTER
	NOTE SOL2, QUARTER
	;7
	NOTE SI2, QUARTER
	NOTE RE3, QUARTER
	;8
	NOTE SOL2, HALF
	;9
	PAUSE QUARTER
	NOTE DO3, QUARTER
	;10
	NOTE SI2, QUARTER_DOT
	NOTE LA2, HEIGTH
	;11
	NOTE SI2, QUARTER
	NOTE RE3, QUARTER
	;12
	STROKE LEGATO
	NOTE SOL2, HALF
	;13
	NOTE SOL2, QUARTER
	STROKE NORMAL
	PAUSE QUARTER
	;14
	NOTE RE2, QUARTER
	NOTE SOL2, QUARTER
	;15
	NOTE SOL2, QUARTER
	NOTE FA2D, HEIGTH
	NOTE MI2, HEIGTH
	;16
	NOTE FA2D, QUARTER_DOT
	NOTE SOL2, HEIGTH
	;17
	NOTE LA2, QUARTER_DOT
	NOTE FA2D, HEIGTH
	;18
	NOTE SOL2, QUARTER
	NOTE RE3, QUARTER
	;19
	STROKE LEGATO
	NOTE RE3, QUARTER
	NOTE RE3, HEIGTH
	STROKE NORMAL
	NOTE DO3, HEIGTH
	NOTE DO3, HEIGTH
	;20
	NOTE SI2, QUARTER_DOT
	NOTE LA2, HEIGTH
	;21
	NOTE SOL2, QUARTER
	PAUSE QUARTER
	MELODY_END
	
; go down moses
; REF: https://www.apprendrelaflute.com/go-down-moses-a-la-flute-a-bec 	
	MELODY go_down_moses
	TEMPO 120
	OCTAVE O2
	;1
	NOTE MI2, QUARTER
	;2
	NOTE DO3, QUARTER
	NOTE DO3, QUARTER
	NOTE SI2, QUARTER
	NOTE SI2, QUARTER
	;3
	NOTE DO3, HEIGTH
	NOTE DO3, QUARTER
	STROKE LEGATO
	NOTE LA2, HEIGTH
	STROKE NORMAL
	NOTE LA2, QUARTER_DOT
	PAUSE HEIGTH
	;4
	NOTE MI2, QUARTER
	NOTE MI2, QUARTER
	NOTE SOL2D, HEIGTH
	NOTE SOL2D, QUARTER_DOT
	;5
	NOTE LA2, HALF
	PAUSE QUARTER
	NOTE MI2, QUARTER
	;6
	NOTE DO3, QUARTER
	NOTE DO3, QUARTER
	NOTE SI2, QUARTER
	NOTE SI2, QUARTER
	;7
	NOTE DO3, HEIGTH
	NOTE DO3, QUARTER
	STROKE LEGATO
	NOTE LA2, HEIGTH
	STROKE NORMAL
	NOTE LA2, QUARTER_DOT
	PAUSE HEIGTH
	;8
	NOTE MI2, QUARTER
	NOTE MI2, QUARTER
	NOTE SOL2D, HEIGTH
	NOTE SOL2D, QUARTER_DOT
	;9
	NOTE LA2, WHOLE
	;10
	NOTE LA2, HEIGTH
	STROKE LEGATO
	NOTE LA2, QUARTER_DOT
	STROKE NORMAL
	NOTE LA2, HALF
	;11
	NOTE RE3, HEIGTH
	STROKE LEGATO
	NOTE RE3, QUARTER_DOT
	STROKE NORMAL
	NOTE RE3, HALF
	;12
	OCTAVE O3
	NOTE MI2, HALF
	NOTE MI2, QUARTER_DOT
	NOTE RE2, HEIGTH
	;13
	NOTE MI2, HEIGTH
	NOTE MI2, QUARTER
	OCTAVE O2
	NOTE RE3, HEIGTH
	NOTE DO3, HEIGTH
	NOTE LA2, QUARTER_DOT
	;14
	NOTE DO3, HEIGTH
	STROKE LEGATO
	NOTE LA2, QUARTER_DOT
	STROKE NORMAL
	NOTE LA2, QUARTER
	PAUSE QUARTER
	;15
	NOTE DO3, HEIGTH
	STROKE LEGATO
	NOTE LA2, QUARTER_DOT
	STROKE NORMAL
	NOTE LA2, QUARTER_DOT
	NOTE MI2, HEIGTH
	;16
	NOTE MI2, QUARTER
	NOTE MI2, QUARTER
	NOTE SOL2D, HEIGTH
	NOTE SOL2D, QUARTER_DOT
	;17
	NOTE LA2, HALF_DOT
	PAUSE QUARTER
	MELODY_END
	
; amazing grace
; REF: https://www.apprendrelaflute.com/amazing-grace-a-la-flute-a-bec	
	MELODY amazing_grace
	TEMPO 120
	OCTAVE O2
	;1
	NOTE SOL2, QUARTER
	;2
	NOTE DO3, HALF
	OCTAVE O3
	NOTE MI2, HEIGTH
	NOTE DO2, HEIGTH
	;3
	NOTE MI2, HALF
	NOTE RE2, QUARTER
	;4
	NOTE DO2, HALF
	OCTAVE O2
	NOTE LA2, QUARTER
	;5
	NOTE SOL2, HALF
	NOTE SOL2, QUARTER
	;6
	NOTE DO3, HALF
	OCTAVE O3
	NOTE MI2, HEIGTH
	NOTE DO2, HEIGTH
	;7
	NOTE MI2, HALF
	NOTE RE2, QUARTER
	;8
	STROKE LEGATO
	NOTE SOL2, HALF_DOT
	;9
	STROKE NORMAL
	NOTE SOL2, HALF
	NOTE MI2, QUARTER
	;10
	NOTE SOL2, QUARTER_DOT
	NOTE MI2, HEIGTH
	NOTE SOL2, HEIGTH
	NOTE MI2, HEIGTH
	;11
	OCTAVE O2
	NOTE DO3, HALF
	NOTE SOL2, QUARTER
	;12
	NOTE LA2, QUARTER_DOT
	NOTE DO3, HEIGTH
	NOTE DO3, HEIGTH
	NOTE LA2, HEIGTH
	;13
	NOTE SOL2, HALF
	NOTE SOL2, QUARTER
	;14
	NOTE DO3, HALF
	OCTAVE O3
	NOTE MI2, HEIGTH
	NOTE DO2, HEIGTH
	;15
	NOTE MI2, HALF
	NOTE RE2, QUARTER
	STROKE LEGATO
	OCTAVE O2
	NOTE DO3, HALF_DOT
	;16
	STROKE NORMAL
	NOTE DO3, HALF_DOT
	MELODY_END
	
; greensleeves
; REF: https://www.apprendrelaflute.com/greensleeves-a-la-flute-a-bec
	MELODY greensleeves
	TEMPO 120
	OCTAVE O2
	;1
	PAUSE QUARTER
	PAUSE QUARTER
	NOTE LA2, QUARTER
	;2
	STROKE LEGATO
	NOTE DO3, HALF
	STROKE NORMAL
	NOTE RE3, QUARTER
	;3
	OCTAVE O3
	NOTE MI2, QUARTER_DOT
	NOTE FA2, HEIGTH
	NOTE MI2, QUARTER
	;4
	STROKE LEGATO
	NOTE RE2, HALF
	STROKE NORMAL
	OCTAVE O2
	NOTE SI2, QUARTER
	;5
	NOTE SOL2, QUARTER_DOT
	NOTE LA2, HEIGTH
	NOTE SI2, QUARTER
	;6
	STROKE LEGATO
	NOTE DO3, HALF
	STROKE NORMAL
	NOTE LA2, QUARTER
	;7
	NOTE LA2, QUARTER_DOT
	NOTE SOL2D, HEIGTH
	NOTE LA2, QUARTER
	;8
	NOTE SI2, HALF
	NOTE SOL2D, QUARTER
	;9
	NOTE MI2, HALF
	NOTE LA2, QUARTER
	;10
	NOTE DO3, HALF
	NOTE RE3, QUARTER
	;11
	OCTAVE O3
	NOTE MI2, QUARTER_DOT
	NOTE FA2, HEIGTH
	NOTE MI2, QUARTER
	;12
	OCTAVE O2
	NOTE RE3, HALF
	NOTE SI2, QUARTER
	;13
	NOTE SOL2, QUARTER_DOT
	NOTE LA2, HEIGTH
	NOTE SI2, QUARTER
	;14
	NOTE DO3, QUARTER_DOT
	NOTE SI2, HEIGTH
	NOTE LA2, QUARTER
	;15
	NOTE SOL2D, QUARTER_DOT
	NOTE FA2D, HEIGTH
	NOTE SOL2D, HEIGTH
	;16
	NOTE LA2, HALF
	NOTE LA2, QUARTER
	;17
	NOTE LA2, HALF_DOT
	;18
	OCTAVE O3
	NOTE SOL2, HALF_DOT
	;19
	NOTE SOL2, QUARTER_DOT
	NOTE FA2D, HEIGTH
	NOTE MI2, QUARTER
	;20
	OCTAVE O2
	NOTE RE3, HALF
	NOTE SI2, QUARTER
	;21
	NOTE SOL2, QUARTER_DOT
	NOTE LA2, HEIGTH
	NOTE SI2, QUARTER
	;22
	NOTE DO3, HALF
	NOTE LA2, QUARTER
	;23
	NOTE LA2, QUARTER_DOT
	NOTE SOL2D, HEIGTH
	NOTE LA2, QUARTER
	;24
	NOTE SI2, HALF
	NOTE SOL2D, QUARTER
	;25
	NOTE MI2, HALF_DOT
	;26
	OCTAVE O3
	NOTE SOL2, HALF_DOT
	;27
	NOTE SOL2, QUARTER_DOT
	NOTE FA2D, HEIGTH
	NOTE MI2, QUARTER
	;28
	OCTAVE O2
	NOTE RE3, HALF
	NOTE SI2, QUARTER
	;29
	NOTE SOL2, QUARTER_DOT
	NOTE LA2, HEIGTH
	NOTE SI2, QUARTER
	;30
	NOTE DO3, QUARTER_DOT
	NOTE SI2, HEIGTH
	NOTE LA2, QUARTER
	;31
	NOTE SOL2D, QUARTER_DOT
	NOTE FA2D, HEIGTH
	NOTE SOL2D, QUARTER
	;32
	STROKE LEGATO
	NOTE LA2, HALF_DOT
	;33
	NOTE LA2, HALF
	STROKE NORMAL
	PAUSE QUARTER
	MELODY_END
	
	
; Great Britain national anthem
; REF: https://www.apprendrelaflute.com/god-save-the-queen-a-la-flute-a-bec	
	MELODY god_save_the_queen
	TEMPO 120
	OCTAVE O3
	;1
	NOTE DO2, QUARTER
	NOTE DO2, QUARTER
	NOTE RE2, QUARTER
	;2
	OCTAVE O2
	NOTE SI2, QUARTER_DOT
	NOTE DO3, HEIGTH
	NOTE RE3, QUARTER
	;3
	OCTAVE O3
	NOTE MI2, QUARTER
	NOTE MI2, QUARTER
	NOTE FA2, QUARTER
	;4
	NOTE MI2, QUARTER_DOT
	NOTE RE2, HEIGTH
	NOTE DO2, QUARTER
	;5
	OCTAVE O2
	NOTE RE3, QUARTER
	NOTE DO3, QUARTER
	NOTE SI2, QUARTER
	;6
	NOTE DO3, HALF_DOT
	;7
	OCTAVE O3
	NOTE SOL2, QUARTER
	NOTE SOL2, QUARTER
	NOTE SOL2, QUARTER
	;8
	NOTE SOL2, QUARTER_DOT
	NOTE FA2, HEIGTH
	NOTE MI2, QUARTER
	;9
	NOTE FA2, QUARTER
	NOTE FA2, QUARTER
	NOTE FA2, QUARTER
	;10
	NOTE FA2, QUARTER_DOT
	NOTE MI2, HEIGTH
	NOTE RE2, QUARTER
	;11
	NOTE MI2, QUARTER
	NOTE FA2, HEIGTH
	NOTE MI2, HEIGTH
	NOTE RE2, HEIGTH
	NOTE DO2, HEIGTH
	;12
	NOTE MI2, QUARTER_DOT
	NOTE FA2, HEIGTH
	NOTE SOL2, QUARTER
	;13
	NOTE LA2, HEIGTH
	NOTE FA2, HEIGTH
	NOTE MI2, QUARTER
	NOTE RE2, QUARTER
	;13
	NOTE DO2, HALF_DOT
	
	MELODY_END
	
; melodia
; REF: https://www.apprendrelaflute.com/melodia-musique-du-film-jeux-interdits-flute-a-bec
	MELODY melodia
	TEMPO 120
	OCTAVE O2
	;1
	NOTE LA2, QUARTER
	NOTE LA2, QUARTER
	NOTE LA2, QUARTER
	;2
	NOTE LA2, QUARTER
	NOTE SOL2, QUARTER
	NOTE FA2, QUARTER
	;3
	NOTE FA2, QUARTER
	NOTE MI2, QUARTER
	NOTE RE2, QUARTER
	;4
	NOTE RE2, QUARTER
	NOTE FA2, QUARTER
	NOTE LA2, QUARTER
	;5
	NOTE RE3, QUARTER
	NOTE RE3, QUARTER
	NOTE RE3, QUARTER
	;6
	NOTE RE3, QUARTER
	NOTE DO3, QUARTER
	NOTE SI2B, QUARTER
	;7
	NOTE SI2B, QUARTER
	NOTE LA2, QUARTER
	NOTE SOL2, QUARTER
	;8
	NOTE SOL2, QUARTER
	NOTE LA2, QUARTER
	NOTE SI2B, QUARTER
	;9
	NOTE LA2, QUARTER
	NOTE SI2B, QUARTER
	NOTE LA2, QUARTER
	;10
	NOTE DO3D, QUARTER
	NOTE SI2B, QUARTER
	NOTE LA2, QUARTER
	;11
	NOTE LA2, QUARTER
	NOTE SOL2, QUARTER
	NOTE FA2, QUARTER
	;12
	NOTE FA2, QUARTER
	NOTE MI2, QUARTER
	NOTE RE2, QUARTER
	;13
	NOTE MI2, QUARTER
	NOTE MI2, QUARTER
	NOTE MI2, QUARTER
	;14
	NOTE MI2, QUARTER
	NOTE FA2, QUARTER
	NOTE MI2, QUARTER
	;15
	NOTE RE2, HALF_DOT
	MELODY_END
	
	
; Le bon roi Dagobert
; REF: https://www.apprendrelaflute.com/le-bon-roi-dagobert-a-la-flute-a-bec
	MELODY roi_dagobert
	TEMPO 140
	OCTAVE O2
	;1
	PAUSE QUARTER
	PAUSE QUARTER
	NOTE SI2, QUARTER
	;2
	NOTE SI2, HALF
	NOTE LA2, QUARTER
	;3
	NOTE LA2, HALF
	NOTE SOL2, QUARTER
	;4
	NOTE SOL2, QUARTER_DOT
	;5
	NOTE LA2, QUARTER_DOT
	;6
	NOTE SI2, QUARTER
	NOTE DO3, QUARTER
	NOTE SI2, QUARTER
	;7
	NOTE LA2, QUARTER
	NOTE SOL2, QUARTER
	NOTE LA2, QUARTER
	;8
	NOTE SOL2, QUARTER_DOT
	;9
	PAUSE QUARTER
	NOTE SOL2, QUARTER
	NOTE LA2, QUARTER
	;10
	NOTE SI2, HALF
	NOTE SI2, QUARTER
	;11
	NOTE SI2, QUARTER
	NOTE DO3, QUARTER
	NOTE RE3, QUARTER
	;12
	NOTE LA2, HALF
	NOTE LA2, QUARTER
	;13
	NOTE LA2, QUARTER
	NOTE SOL2, QUARTER
	NOTE LA2, QUARTER
	;14
	NOTE SI2, HALF
	NOTE SI2, QUARTER
	;15
	NOTE SI2, QUARTER
	NOTE DO3, QUARTER
	NOTE RE3, QUARTER
	;16
	NOTE LA2, HALF
	NOTE LA2, QUARTER
	;17
	NOTE LA2, HALF
	NOTE LA2, QUARTER
	;18
	NOTE SI2, HALF
	NOTE LA2, QUARTER
	;19
	NOTE LA2, HALF
	NOTE SOL2, QUARTER
	;20
	NOTE SOL2, QUARTER_DOT
	;21
	NOTE LA2, QUARTER_DOT
	;22
	NOTE SI2, QUARTER
	NOTE DO3, QUARTER
	NOTE SI2, QUARTER
	;23
	NOTE LA2, QUARTER
	NOTE SOL2, QUARTER
	NOTE LA2, QUARTER
	;24
	NOTE SOL2, HALF_DOT
	MELODY_END
	
; fr�re Jacques
; ref: https://www.apprendrelaflute.com/lecon-5-frere-jacques
	MELODY frere_jacques
	TEMPO 120
	OCTAVE O2
	;1
	NOTE FA2, QUARTER
	NOTE SOL2, QUARTER
	NOTE LA2, QUARTER
	NOTE FA2, QUARTER
	;2
	NOTE FA2, QUARTER
	NOTE SOL2, QUARTER
	NOTE LA2, QUARTER
	NOTE FA2, QUARTER
	;3
	NOTE LA2, QUARTER
	NOTE SI2B, QUARTER
	NOTE DO3, HALF
	;4
	NOTE LA2, QUARTER
	NOTE SI2B, QUARTER
	NOTE DO3, HALF
	;5
	NOTE DO3,HEIGTH_DOT
	NOTE RE3,SIXTEENTH
	NOTE DO3, HEIGTH
	NOTE SI2B, HEIGTH
	NOTE LA2, QUARTER
	NOTE FA2, QUARTER
	;6
	NOTE DO3,HEIGTH_DOT
	NOTE RE3,SIXTEENTH
	NOTE DO3, HEIGTH
	NOTE SI2B, HEIGTH
	NOTE LA2, QUARTER
	NOTE FA2, QUARTER
	;7
	NOTE FA2, QUARTER
	NOTE DO2, QUARTER
	NOTE FA2, HALF
	;8
	NOTE FA2, QUARTER
	NOTE DO2, QUARTER
	NOTE FA2, HALF
	MELODY_END
	
; ode to joy , Beethoven
; REF: https://www.apprendrelaflute.com/lecon-6-ode-a-la-joie	
    MELODY ode_joy
    TEMPO 140
    OCTAVE O2
    ;1
    NOTE A2,QUARTER
    NOTE A2,QUARTER
    NOTE B2f,QUARTER
    OCTAVE O3
    NOTE C2, QUARTER
    ;2
    NOTE C2, QUARTER
    OCTAVE O2
    NOTE B2f, QUARTER
    NOTE A2, QUARTER
    NOTE G2, QUARTER
    ;3
    NOTE F2, QUARTER
    NOTE F2, QUARTER
    NOTE G2, QUARTER
    NOTE A2, QUARTER
    ;4
    NOTE A2, QUARTER_DOT
    NOTE G2, HEIGTH
    NOTE G2, HALF
    ;5
    NOTE A2, QUARTER
    NOTE A2, QUARTER
    NOTE B2f, QUARTER
    OCTAVE O3
    NOTE C2, QUARTER
    ;6
    NOTE C2, QUARTER
    OCTAVE O2
    NOTE B2f, QUARTER
    NOTE A2, QUARTER
    NOTE G2, QUARTER
    ;7
    NOTE F2, QUARTER
    NOTE F2,QUARTER
    NOTE G2,QUARTER
    NOTE A2,QUARTER
    ;8
    NOTE G2,QUARTER_DOT
    NOTE F2,HEIGTH
    NOTE F2,HALF
    ;9
    NOTE G2,QUARTER
    NOTE G2,QUARTER
    NOTE A2,QUARTER
    NOTE F2,QUARTER
    ;10
    NOTE G2,QUARTER
    STROKE LEGATO
    NOTE A2,HEIGTH
    NOTE B2f,HEIGTH
    STROKE NORMAL
    NOTE A2,QUARTER
    NOTE F2,QUARTER
    ;11
    NOTE G2,QUARTER
    STROKE LEGATO
    NOTE A2,HEIGTH
    NOTE B2f,HEIGTH
    STROKE NORMAL
    NOTE A2,QUARTER
    NOTE G2,QUARTER
    ;12
    NOTE F2,QUARTER
    NOTE G2,QUARTER
    NOTE C2,HALF
    ;13
    NOTE A2, QUARTER
    NOTE A2, QUARTER
    NOTE B2f, QUARTER
    OCTAVE O3
    NOTE C2, QUARTER
    ;14
    NOTE C2, QUARTER
    OCTAVE O2
    NOTE B2f, QUARTER
    NOTE A2, QUARTER
    NOTE G2, QUARTER
    ;15
    NOTE F2, QUARTER
    NOTE F2, QUARTER
    NOTE G2, QUARTER
    NOTE A2, QUARTER
    ;16
    NOTE G2, QUARTER_DOT
    NOTE F2,HEIGTH
    NOTE F2, HALF
    MELODY_END

    ; tetris game theme
    ;REF: https://en.wikipedia.org/wiki/Korobeiniki
    MELODY korobeiniki
    TEMPO 80
    ;1
    OCTAVE O4
    NOTE MI2, QUARTER_DOT
    NOTE SOL2D, HEIGTH
    NOTE SI2, QUARTER
    NOTE SOL2, HEIGTH
    NOTE MI2, HEIGTH
    ;2
    NOTE LA2, QUARTER_DOT
    NOTE DO3, HEIGTH
    OCTAVE O5
    NOTE MI2, QUARTER
    OCTAVE O4
    NOTE RE3, HEIGTH
    NOTE DO3, HEIGTH
    ;3
    NOTE SI2, QUARTER_DOT
    NOTE DO3, HEIGTH
    NOTE RE3, QUARTER
    OCTAVE O5
    NOTE MI2, QUARTER
    OCTAVE O4
    ;4
    NOTE DO3, QUARTER
    NOTE LA2, QUARTER
    NOTE LA2, HALF
    ;5
    REPT_START
    OCTAVE O5
    NOTE FA2, QUARTER_DOT
    NOTE SOL2, HEIGTH
    NOTE LA2, QUARTER
    NOTE SOL2, HEIGTH
    NOTE FA2, HEIGTH
    ;6
    NOTE MI2, QUARTER_DOT
    NOTE FA2, HEIGTH
    NOTE MI2, QUARTER
    NOTE RE2, HEIGTH
    NOTE DO2, HEIGTH
    ;7
    OCTAVE O4
    NOTE SI2, QUARTER_DOT
    NOTE DO3, HEIGTH
    NOTE RE3, QUARTER
    OCTAVE O5
    NOTE MI2, QUARTER
    ;8
    OCTAVE O4
    NOTE DO3, QUARTER
    NOTE LA2, QUARTER
    NOTE LA2, HALF
    REPT_LOOP
    
    MELODY_END

; J'ai du bon tabac dans ma tabati�re
; REF: https://www.apprendrelaflute.com/j-ai-du-bon-tabac-dans-ma-tabatiere    
    MELODY bon_tabac
    TEMPO 120
    NOTE SOL2,QUARTER
    NOTE LA2,QUARTER
    NOTE SI2,QUARTER
    NOTE SOL2,QUARTER
    NOTE LA2, HALF
    NOTE LA2, QUARTER
    NOTE SI2, QUARTER
    NOTE DO3, HALF
    NOTE DO3, HALF
    NOTE SI2, HALF
    NOTE SI2, HALF
    NOTE SOL2, QUARTER
    NOTE LA2, QUARTER
    NOTE SI2, QUARTER
    NOTE SOL2, QUARTER
    NOTE LA2, HALF
    NOTE LA2, QUARTER
    NOTE SI2, QUARTER
    NOTE DO3, HALF
    NOTE RE3, HALF
    NOTE SOL2, WHOLE
    NOTE RE3, HALF
    NOTE RE3, QUARTER
    NOTE DO3, QUARTER
    NOTE SI2,HALF
    NOTE LA2,QUARTER
    NOTE SI2,QUARTER
    NOTE DO3, HALF
    NOTE RE3, HALF
    NOTE LA2, WHOLE
    MELODY_END
    
; joyeux aniversaire  
; REF: https://www.apprendrelaflute.com/lecon-7-joyeux-anniversaire    
    MELODY joyeux_anniv
    TEMPO 120
    NOTE DO2,HEIGTH_DOT
    NOTE DO2,SIXTEENTH
    NOTE RE2,QUARTER
    NOTE DO2,QUARTER
    NOTE FA2,QUARTER
    NOTE MI2,HALF
    NOTE DO2,HEIGTH_DOT
    NOTE DO2,SIXTEENTH
    NOTE RE2,QUARTER
    NOTE DO2,QUARTER
    NOTE SOL2,QUARTER
    NOTE FA2,HALF
    NOTE DO2,HEIGTH_DOT
    NOTE DO2,SIXTEENTH
    NOTE DO3,QUARTER
    NOTE LA2,QUARTER
    NOTE FA2,QUARTER
    NOTE MI2,QUARTER
    NOTE RE2,QUARTER
    NOTE SI2B,HEIGTH_DOT
    NOTE SI2B,SIXTEENTH
    NOTE LA2,QUARTER
    NOTE FA2,QUARTER
    NOTE SOL2,QUARTER
    NOTE FA2,HALF
    MELODY_END
 
; mon beau sapin
; REF: https://www.apprendrelaflute.com/mon-beau-sapin-a-la-flute-a-bec    
    MELODY beau_sapin
    TEMPO 80
    NOTE DO2,QUARTER
    NOTE FA2,HEIGTH_DOT
    NOTE FA2, SIXTEENTH
    NOTE FA2, QUARTER
    NOTE SOL2, QUARTER
    NOTE LA2, HEIGTH_DOT
    NOTE LA2,SIXTEENTH
    NOTE LA2,QUARTER_DOT
    NOTE LA2,HEIGTH
    NOTE SOL2,HEIGTH
    NOTE LA2,HEIGTH
    NOTE SI2B,QUARTER
    NOTE MI2,QUARTER
    NOTE SOL2,QUARTER
    NOTE FA2,QUARTER
    PAUSE HEIGTH
    NOTE DO3,HEIGTH
    NOTE DO3,HEIGTH
    NOTE LA2,HEIGTH
    NOTE RE3,QUARTER_DOT
    NOTE DO3,QUARTER
    NOTE DO3,QUARTER
    NOTE SI2B,HEIGTH
    NOTE SI2B,QUARTER_DOT
    NOTE SI2B,HEIGTH
    NOTE SI2B,HEIGTH
    NOTE SOL2,HEIGTH
    NOTE DO3,QUARTER_DOT
    NOTE SI2B,HEIGTH
    NOTE SI2B,HEIGTH
    NOTE LA2, HEIGTH
    NOTE LA2, QUARTER
    NOTE DO2, QUARTER
    NOTE FA2,HEIGTH_DOT
    NOTE FA2,SIXTEENTH
    NOTE FA2,QUARTER
    NOTE SOL2,QUARTER
    NOTE LA2,HEIGTH_DOT
    NOTE LA2,SIXTEENTH
    NOTE LA2,QUARTER_DOT
    NOTE LA2,HEIGTH
    NOTE SOL2,HEIGTH
    NOTE LA2,HEIGTH
    NOTE SI2B,QUARTER
    NOTE MI2,QUARTER
    NOTE SOL2,QUARTER
    NOTE FA2,HALF
    MELODY_END

; gingle bell
; REF: https://www.apprendrelaflute.com/jingle-bells-a-la-flute-a-bec
    MELODY jingle_bell
    TEMPO 150
    OCTAVE O4
    STROKE NORMAL
    ;1
    NOTE SOL2, QUARTER
    OCTAVE O5
    NOTE MI2, QUARTER
    NOTE RE2, QUARTER
    NOTE DO2, QUARTER
    ;2
    OCTAVE O4
    NOTE SOL2, HALF_DOT
    NOTE SOL2, HEIGTH
    NOTE SOL2, HEIGTH
    ;3
    NOTE SOL2, QUARTER
    OCTAVE O5
    NOTE MI2, QUARTER
    NOTE RE2, QUARTER
    NOTE DO2, QUARTER
    ;4
    OCTAVE O4
    NOTE LA2, HALF_DOT
    PAUSE QUARTER
    ;5
    NOTE LA2, QUARTER
    OCTAVE O5
    NOTE FA2, QUARTER
    NOTE MI2, QUARTER
    NOTE RE2, QUARTER
    ;6
    OCTAVE O4
    NOTE SI2, HALF_DOT
    PAUSE QUARTER
    ;7
    OCTAVE O5
    NOTE SOL2, QUARTER
    NOTE SOL2, QUARTER
    NOTE FA2, QUARTER
    NOTE RE2, QUARTER
    ;8
    NOTE MI2, HALF_DOT
    PAUSE QUARTER
    ;9
    OCTAVE O4
    NOTE SOL2, QUARTER
    OCTAVE O5
    NOTE MI2, QUARTER
    NOTE RE2, QUARTER
    NOTE DO2, QUARTER
    ;10
    OCTAVE O4
    NOTE SOL2, HALF_DOT
    PAUSE QUARTER
    ;11
    NOTE SOL2, QUARTER
    OCTAVE O5
    NOTE MI2, QUARTER
    NOTE RE2, QUARTER
    NOTE DO2, QUARTER
    ;12
    OCTAVE O4
    NOTE LA2, HALF_DOT
    NOTE LA2, QUARTER
    ;13
    NOTE LA2, QUARTER
    OCTAVE O5
    NOTE FA2, QUARTER
    NOTE MI2, QUARTER
    NOTE RE2, QUARTER
    ;14
    NOTE SOL2, QUARTER
    NOTE SOL2, QUARTER
    NOTE SOL2, QUARTER
    NOTE SOL2, QUARTER
    ;15
    NOTE LA2, QUARTER
    NOTE SOL2, QUARTER
    NOTE FA2, QUARTER
    NOTE RE2, QUARTER
    ;16
    NOTE DO2, HALF
    NOTE SOL2, HALF
    ;17
    NOTE MI2, QUARTER
    NOTE MI2, QUARTER
    NOTE MI2, HALF
    ;18
    NOTE MI2, QUARTER
    NOTE MI2, QUARTER
    NOTE MI2, HALF
    ;19
    NOTE MI2, QUARTER
    NOTE SOL2, QUARTER
    NOTE DO2, QUARTER_DOT
    NOTE RE2, HEIGTH
    ;20
    NOTE MI2, HALF_DOT
    PAUSE QUARTER
    ;21
    NOTE FA2, QUARTER
    NOTE FA2, QUARTER
    NOTE FA2, QUARTER_DOT
    NOTE FA2, HEIGTH
    ;22
    NOTE FA2, QUARTER
    NOTE MI2, QUARTER
    NOTE MI2, QUARTER
    NOTE MI2, HEIGTH
    NOTE MI2, HEIGTH
    ;23
    NOTE MI2, QUARTER
    NOTE RE2, QUARTER
    NOTE RE2, QUARTER
    NOTE MI2, QUARTER
    ;24
    NOTE RE2, HALF
    NOTE SOL2, HALF
    ;25
    NOTE MI2, QUARTER
    NOTE MI2, QUARTER
    NOTE MI2, HALF
    ;26
    NOTE MI2, QUARTER
    NOTE MI2, QUARTER
    NOTE MI2, HALF
    ;27
    NOTE MI2, QUARTER
    NOTE SOL2, QUARTER
    NOTE DO2, QUARTER_DOT
    NOTE RE2, HEIGTH
    ;28
    NOTE MI2, HALF_DOT
    PAUSE QUARTER
    ;29
    NOTE FA2, QUARTER
    NOTE FA2, QUARTER
    NOTE FA2, QUARTER_DOT
    NOTE FA2, HEIGTH
    ;30
    NOTE FA2, QUARTER
    NOTE MI2, QUARTER
    NOTE MI2, QUARTER
    NOTE MI2, HEIGTH
    NOTE MI2, HEIGTH
    ;31
    NOTE SOL2, QUARTER
    NOTE SOL2, QUARTER
    NOTE FA2, QUARTER
    NOTE RE2, QUARTER
    ;32
    NOTE DO2, WHOLE
    MELODY_END
    
; � la claire fontaine
; REF: https://www.apprendrelaflute.com/a-la-claire-fontaine-a-la-flute-a-bec    
    MELODY claire_fontaine
    TEMPO 100
    NOTE SOL2,HALF
    NOTE SOL2,QUARTER
    NOTE SI2,QUARTER
    NOTE SI2,QUARTER
    NOTE LA2,QUARTER
    NOTE SI2,QUARTER
    NOTE SOL2,QUARTER
    NOTE SOL2,HALF
    NOTE SOL2,QUARTER
    NOTE SI2,QUARTER
    NOTE SI2,QUARTER
    NOTE LA2,QUARTER
    NOTE SI2,HALF
    NOTE SI2,HALF
    NOTE SI2,QUARTER
    NOTE LA2,QUARTER
    NOTE SOL2,QUARTER
    NOTE SI2,QUARTER
    NOTE RE3,QUARTER
    NOTE SI2,QUARTER
    NOTE RE3,HALF
    NOTE RE3,QUARTER
    NOTE SI2,QUARTER
    NOTE SOL2,QUARTER
    NOTE SI2,QUARTER
    NOTE LA2,HALF
    NOTE SOL2,HALF
    NOTE SOL2,QUARTER
    NOTE SI2,QUARTER
    NOTE SI2,QUARTER
    NOTE LA2,HEIGTH
    NOTE SOL2,HEIGTH
    NOTE SI2,QUARTER
    NOTE SOL2,QUARTER
    NOTE SI2, HALF
    NOTE SI2,QUARTER
    NOTE LA2,HEIGTH
    NOTE SOL2,HEIGTH
    NOTE SI2,QUARTER
    NOTE LA2,QUARTER
    NOTE SOL2,HALF
    MELODY_END 
    
; morning as broken
; REF: https://www.8notes.com    
	MELODY morning_has_broken
	TEMPO 100
	OCTAVE O2
	STROKE LEGATO
	;0
	NOTE FA2, QUARTER
	NOTE LA2, QUARTER
	NOTE DO3, QUARTER
	;1
	OCTAVE O3
	NOTE F2, HALF_DOT
	;2
	NOTE SOL2, HALF_DOT
	;3
	NOTE MI2, QUARTER
	NOTE RE2, QUARTER
	NOTE DO2, QUARTER
	;4
	NOTE RE2, QUARTER_DOT
	NOTE MI2, HEIGTH
	NOTE RE2, QUARTER
	;5
	NOTE DO2, HALF_DOT
	;6
	OCTAVE O2
	NOTE FA2, QUARTER
	NOTE SOL2, QUARTER
	NOTE LA2, QUARTER
	;7
	NOTE DO3, HALF_DOT
	;8
	NOTE RE3, HALF_DOT
	;9
	NOTE DO3, QUARTER
	NOTE LA2, QUARTER
	NOTE FA2, QUARTER
	;10
	NOTE SOL2, HALF_DOT
	;11
	NOTE SOL2, HALF_DOT
	;12
	NOTE DO3, QUARTER
	NOTE LA2, QUARTER
	NOTE DO3, QUARTER
	;13
	OCTAVE O3
	NOTE FA2, HALF_DOT
	;14
	NOTE RE2, HALF_DOT
	;15
	OCTAVE O2
	NOTE DO3, QUARTER
	NOTE LA2, QUARTER
	NOTE FA2, QUARTER
	;16
	NOTE FA2, HALF_DOT
	;17
	NOTE SOL2, HALF_DOT
	;18
	NOTE LA2, QUARTER
	NOTE SOL2, QUARTER
	NOTE LA2, QUARTER
	;19
	NOTE DO3, HALF_DOT
	;20
	NOTE RE3, HALF_DOT
	;21
	NOTE SOL2, QUARTER
	NOTE LA2, QUARTER
	NOTE SOL2, QUARTER
	;22
	NOTE FA2, HALF_DOT
	;23
	NOTE FA2, HALF_DOT
	;24
	NOTE FA2, HALF_DOT
	
	MELODY_END

; fur elise
; REF: 	https://www.8notes.com/scores/571.asp
	MELODY fur_elise
	TEMPO 100
	OCTAVE O3
	STROKE LEGATO
	;1
	NOTE MI2, HEIGTH
	NOTE RE2D, HEIGTH
	;2
	NOTE MI2, HEIGTH
	NOTE RE2D, HEIGTH
	NOTE MI2, HEIGTH
	OCTAVE O2
	NOTE SI2, HEIGTH
	NOTE RE3, HEIGTH
	NOTE DO3, HEIGTH
	;3
	NOTE LA2, QUARTER
	PAUSE HEIGTH
	NOTE DO2, HEIGTH
	NOTE MI2, HEIGTH
	NOTE LA2, HEIGTH
	;4
	NOTE SI2, QUARTER
	PAUSE HEIGTH
	NOTE MI2, HEIGTH
	NOTE SOL2D, HEIGTH
	NOTE SI2, HEIGTH
	;5
	NOTE DO3, QUARTER
	PAUSE HEIGTH
	NOTE MI2, HEIGTH
	OCTAVE O3
	NOTE MI2, HEIGTH
	NOTE RE2D, HEIGTH
	;6
	NOTE MI2, HEIGTH
	NOTE RE2D, HEIGTH
	NOTE MI2, HEIGTH
	OCTAVE O2
	NOTE SI2, HEIGTH
	OCTAVE O3
	NOTE RE2, HEIGTH
	NOTE DO2, HEIGTH
	;7
	OCTAVE O2
	NOTE LA2, QUARTER
	PAUSE HEIGTH
	NOTE DO2, HEIGTH
	NOTE MI2, HEIGTH
	NOTE LA2, HEIGTH
	;8
	NOTE SI2, QUARTER
	PAUSE HEIGTH
	NOTE MI2, HEIGTH
	NOTE DO3, HEIGTH
	NOTE SI2, HEIGTH
	;9
	NOTE LA2, HALF
	OCTAVE O3
	NOTE MI2, HEIGTH
	NOTE RE2D, HEIGTH
	;10
	NOTE MI2, HEIGTH
	NOTE RE2D, HEIGTH
	NOTE MI2, HEIGTH
	OCTAVE O2
	NOTE SI2, HEIGTH
	NOTE RE3, HEIGTH
	NOTE DO3, HEIGTH
	;11
	NOTE LA2, QUARTER
	PAUSE HEIGTH
	NOTE DO2, HEIGTH
	NOTE MI2, HEIGTH
	NOTE LA2, HEIGTH
	;12
	NOTE SI2, QUARTER
	PAUSE HEIGTH
	NOTE MI2, HEIGTH
	NOTE SOL2D, HEIGTH
	NOTE SI2, HEIGTH
	;13
	NOTE DO3, QUARTER
	PAUSE HEIGTH
	NOTE MI2, HEIGTH
	OCTAVE O3
	NOTE MI2, HEIGTH
	NOTE RE2D, HEIGTH
	;14
	NOTE MI2, HEIGTH
	NOTE RE2D,HEIGTH
	NOTE MI2, HEIGTH
	OCTAVE O2
	NOTE SI2, HEIGTH
	NOTE RE3, HEIGTH
	NOTE DO3, HEIGTH
	;15
	NOTE LA2, QUARTER
	PAUSE HEIGTH
	NOTE DO2, HEIGTH
	NOTE MI2, HEIGTH
	NOTE LA2, HEIGTH
	;16
	NOTE SI2, QUARTER
	PAUSE HEIGTH
	NOTE MI2, HEIGTH
	NOTE DO3, HEIGTH
	NOTE SI2, HEIGTH
	;17
	NOTE LA2, QUARTER
	PAUSE HEIGTH
	NOTE SI2, HEIGTH
	NOTE DO3, HEIGTH
	NOTE RE3, HEIGTH
	;18
	;REPT_START
	OCTAVE O3
	NOTE MI2, QUARTER_DOT
	OCTAVE O2
	NOTE SOL2, HEIGTH
	OCTAVE O3
	NOTE FA2, HEIGTH
	NOTE MI2, HEIGTH
	;19
	NOTE RE2, QUARTER_DOT
	OCTAVE O2
	NOTE FA2, HEIGTH
	OCTAVE O3
	NOTE MI2, HEIGTH
	NOTE RE2, HEIGTH
	;20
	NOTE DO2, QUARTER_DOT
	OCTAVE O2
	NOTE MI2, HEIGTH
	NOTE RE3, HEIGTH
	NOTE DO3, HEIGTH
	;21
	NOTE SI2, QUARTER
	PAUSE HEIGTH
	NOTE MI2, HEIGTH
	OCTAVE O3
	NOTE MI2, HEIGTH
	PAUSE HEIGTH
	;22
	PAUSE QUARTER
	PAUSE HEIGTH
	NOTE RE2D, HEIGTH
	NOTE MI2, HEIGTH
	NOTE RE2D, HEIGTH
	;23
	NOTE MI2, HEIGTH
	NOTE RE2D,HEIGTH
	NOTE MI2, HEIGTH
	NOTE RE2D, HEIGTH
	NOTE MI2, HEIGTH
	NOTE RE2D, HEIGTH
	NOTE MI2, HEIGTH
	NOTE RE2D, HEIGTH
	;24
	NOTE MI2, HEIGTH
	NOTE RE2D, HEIGTH
	NOTE MI2, HEIGTH
	OCTAVE O2
	NOTE SI2, HEIGTH
	NOTE RE3, HEIGTH
	NOTE DO3, HEIGTH
	;25
	NOTE LA2, QUARTER
	PAUSE HEIGTH
	NOTE DO2, HEIGTH
	NOTE MI2, HEIGTH
	NOTE LA2, HEIGTH
	;26
	NOTE SI2, QUARTER
	PAUSE HEIGTH
	NOTE MI2, HEIGTH
	NOTE SOL2D, HEIGTH
	NOTE SI2, HEIGTH
	;27
	NOTE DO3, QUARTER
	PAUSE HEIGTH
	NOTE MI2, HEIGTH
	OCTAVE O3
	NOTE MI2, HEIGTH
	NOTE RE2D, HEIGTH
	;28
	NOTE MI2, HEIGTH
	NOTE RE2D, HEIGTH
	NOTE MI2, HEIGTH
	OCTAVE O2
	NOTE SI2, HEIGTH
	NOTE RE3, HEIGTH
	NOTE DO3, HEIGTH
	;29
	NOTE LA2, QUARTER
	PAUSE HEIGTH
	NOTE DO2, HEIGTH
	NOTE MI2, HEIGTH
	NOTE LA2, HEIGTH
	;30
	NOTE SI2, QUARTER
	PAUSE HEIGTH
	NOTE MI2, HEIGTH
	NOTE DO3, HEIGTH
	NOTE SI2, HEIGTH
	;31
;	NOTE LA2, QUARTER
;	PAUSE HEIGTH
;	NOTE SI2, HEIGTH
;	NOTE DO3, HEIGTH
;	NOTE RE3, HEIGTH
	;REPT_LOOP
	;32
	NOTE LA2, HALF
	MELODY_END

	
	end 
    
    
    



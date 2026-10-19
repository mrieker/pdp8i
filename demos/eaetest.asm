
; test PDP-8/I EAE instructions
; prints char on tty every ~18 sec (@ 1.50uS clkratm1=9)
;                           14 sec (@ 1.05uS clkratm1=6)
; prints all instructions tested when SR<MSB> turned on

	tsf = 06041
	tls = 06046

	. = 1

count:	.word	0,0,0	; number of eae instructions tested

_0006:	.word	00006
_0007:	.word	00007
_0020:	.word	00020
_0024:	.word	00024
_0034:	.word	00034
_0037:	.word	00037
_0040:	.word	00040
_0060:	.word	00060
_0100:	.word	00100
_0200:	.word	00200
_0376:	.word	00376
_4000:	.word	04000
_7740:	.word	07740
_7750:	.word	07750
_7764:	.word	07764

_getrand: .word	getrand
_verify:  .word verify

_printchr:  .word printchr
_printmsg:  .word printmsg
_printoct2: .word printoct2
_printoct4: .word printoct4
_printregs: .word printregs
_printstr:  .word printstr

mqin:	.word	.-.
acin:	.word	.-.
linkin:	.word	.-.	; <11:01> = 0; <00> = link

mqout:	.word	.-.
acout:	.word	.-.
linkout:.word	.-.	; <11:01> = 0; <00> = link
scout:	.word	.-.

mqwork:	.word	.-.
acwork:	.word	.-.
linkwork: .word	.-.	; <11:01> = 0; <00> = link
scwork:	.word	.-.

temp1:	.word	.-.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; start of test
testloop:
	jmsi	_getrand	; get 12 random bits
	dca	mqin		; use those for MQ
	jmsi	_getrand	; get 12 random bits
	dca	acin		; use those for AC
	ral			; also save LINK bit
	dca	linkin
	jmsi	_getrand	; get 12 random bits
	dca	_scin		; ... low 5 bits into SC
	tad	_scin		; ... high 7 bits for opcode
	rtr
	rtr
	and	_0376		; 'or' in 7401
	cma			; ... who cares we flip random bits
	dca	eaeop

	tad	eaeop		; see if EAE opcode has memory operand
	and	_0006
	sza
	jmsi	_getrand	; if so, get 12 random bits (+ NOP is still 12 random bits)
	tad	nopcod		; if not, put a NOP after the EAE opcode
	dca	memop

	tad	mqin
	mql			; load MQ then clear AC
	tad	linkin
	cll rar			; load LINK then clear AC
	tad	acin		; load AC

	scl			; load ~_scin<4:0> into SC
_scin:	.word	.-.

eaeop:	.word	.-.		; perform EAE instruction
memop:	.word	.-.		; possible memory operand (or NOP)

	dca	acout		; save resulting AC
	ral			; save resulting LINK
	dca	linkout
	cla mqa			; save resulting MQ
	dca	mqout
	cla sca			; save resulting SC
	dca	scout

	jmsi	_verify		; verify it worked

	isz	count+0		; try another test
	jmp	testloop
	tad	_0060		; '0'+SC = '0'..'O'
	tad	scout
	jmsi	_printchr
	isz	count+1
	jmp	testloop
	isz	count+2
	jmp	testloop
	jmp	testloop

nopcod:	nop

	.align	0200

	.global	__boot
__boot:
	jmp	testloop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; get 12-bit random number
; returns with random number in AC
; LINK is also randomised
;
;  632 cyc @ 1.50uS = 948uS (clkratm1 = 9)
;          @ 1.05uS = 664uS (clkratm1 = 6)
;
getrand: .word .-.
	cla
	tad	_7764	; repeat the loop 12 times
	dca	randcnt	; ... so we get 12 new bits
randloop:
	; https://www.xilinx.com/support/documentation/application_notes/xapp052.pdf
	; 48,47,21,20 - 1 => 47,46,20,19
	tad	lfsr+3	; get lfsr<47>
	rtl
	dca	lfsrxor	; ... into lfsrxor<00>
	tad	lfsr+3	; get lfsr<46>
	rtl
	ral
	tad	lfsrxor	; ... xor into lfsrxor<00>
	dca	lfsrxor
	tad	lfsr+1	; get lfsr<20>
	bsw
	rtr
	tad	lfsrxor	; ... xor into lfsrxor<00>
	dca	lfsrxor
	tad	lfsr+1	; get lfsr<19>
	bsw
	rar
	tad	lfsrxor	; ... xor into lfsrxor<00>
	rar		; complement into link
	cla cml
	tad	lfsr+0	; shift left into bottom of lfsr
	ral
	dca	lfsr+0
	tad	lfsr+1
	ral
	dca	lfsr+1
	tad	lfsr+2
	ral
	dca	lfsr+2
	tad	lfsr+3
	ral
	dca	lfsr+3
	isz	randcnt
	jmp	randloop
	tad	lfsr+0	; get 12 new bits from lfsr<11:00>
	jmpi	getrand

randcnt: .word	.-.
lfsrxor: .word	.-.
lfsr:	.word	01234
	.word	05670
	.word	00765
	.word	04321

	.align	0200

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; veriy eae result
;  input:
;   acin,linkin,_scin,eaeop,memop,mqin
;   acout,linkout,scout,mqout
verify:	.word	.-.

	; step 1
	tad	eaeop		; CLA
	and	_0200
	sna cla
	tad	acin
	dca	acwork

	tad	mqin
	dca	mqwork
	tad	_scin
	cma
	and	_0037
	dca	scwork
	tad	linkin
	dca	linkwork

	; step 2
	tad	eaeop		; MQL - load MQ from AC then clear AC
	and	_0020
	sna cla
	jmp	vfy_nomql
	tad	acwork
	dca	mqwork
	dca	acwork
vfy_nomql:
	tad	eaeop		; SCA - or SC into AC
	and	_0040
	sna cla
	jmp	vfy_nosca
	tad	scwork
	cma
	dca	temp1
	tad	acwork
	cma
	and	temp1
	cma
	dca	acwork
vfy_nosca:
	tad	eaeop		; MQA - or MQ into AC
	and	_0100
	sna cla
	jmp	vfy_nomqa
	tad	mqin		; (MQ before munched by MQL)
	cma
	dca	temp1
	tad	acwork
	cma
	and	temp1
	cma
	dca	acwork
vfy_nomqa:

	; step 3
	tad	eaeop
	rar
	and	_0007
	tad	_step3tbl
	dca	temp1
	tadi	temp1
	dca	temp1
	jmsi	temp1

	; clean up scwork
	cla
	tad	scwork
	and	_0037
	dca	scwork

	; maybe always dump
	cla osr
	spa
	jmsi	_dumpit

	; compare results
	cla
	tad	mqwork
	cma iac
	tad	mqout
	sza
	jmsi	_error

	tad	acwork
	cma iac
	tad	acout
	sza
	jmsi	_error

	tad	scwork
	cma iac
	tad	scout
	sza
	jmsi	_error

	tad	linkwork
	cma iac
	tad	linkout
	sza
	jmsi	_error

	jmpi	verify

_dumpit: .word	dumpit
_error:	 .word	error
_step3tbl: .word step3tbl
step3tbl:
	.word	step3_nop
	.word	step3_scl
	.word	step3_muy
	.word	step3_dvi
	.word	step3_nmi
	.word	step3_shl
	.word	step3_asr
	.word	step3_lsr

	.align	0200

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; print error message then halt
error:	.word	.-.
	jms	dumpit
	jmsi	_printmsg
		.asciz	"\r\n\r"
	hlt
	jmp	.-1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; print all about eae instruction just tested
dumpit:	.word	.-.
	cla
	jmsi	_printmsg
		.asciz	"\r\nY="
	tad	memop
	jmsi	_printoct4
	jmsi	_printmsg
		.asciz	" OP="
	tad	eaeop
	jmsi	_printoct4
	tad	eaeop
	and	_0200
	sna cla
	jmp	dmp_nocla
	jmsi	_printmsg
		.asciz	" CLA"
dmp_nocla:
	tad	eaeop
	and	_0020
	sna cla
	jmp	dmp_nomql
	jmsi	_printmsg
		.asciz	" MQL"
dmp_nomql:
	tad	eaeop
	and	_0040
	sna cla
	jmp	dmp_nosca
	jmsi	_printmsg
		.asciz	" SCA"
dmp_nosca:
	tad	eaeop
	and	_0100
	sna cla
	jmp	dmp_nomqa
	jmsi	_printmsg
		.asciz	" MQA"
dmp_nomqa:
	jmsi	_dumpit2
	jmpi	dumpit

_dumpit2: .word	dumpit2

	.align	0200

dumpit2: .word	.-.
	tad	_0040
	jmsi	_printchr
	tad	eaeop
	ral
	and	_0034
	tad	_mnetbl
	jmsi	_printstr
	jmsi	_printmsg
		.asciz	"\r\n in:"
	tad	_scin
	cma
	and	_0037
	dca	dmp_temp1
	jmsi	_printregs
		.word	linkin
		.word	acin
		.word	mqin
		.word	dmp_temp1
	jmsi	_printmsg
		.asciz	"\r\nout:"
	jmsi	_printregs
		.word	linkout
		.word	acout
		.word	mqout
		.word	scout
	jmsi	_printmsg
		.asciz	"\r\n sb:"
	jmsi	_printregs
		.word	linkwork
		.word	acwork
		.word	mqwork
		.word	scwork
	jmsi	_printmsg
		.asciz	"\r\ncount="
	tad	count+2
	jmsi	_printoct4
	tad	count+1
	jmsi	_printoct4
	tad	count+0
	jmsi	_printoct4
	jmsi	_printmsg
		.asciz	"\r\n"
	jmpi	dumpit2

dmp_temp1: .word .-.

_mnetbl: .word	mnetbl
mnetbl:	.asciz	"NOP"
	.asciz	"SCL"
	.asciz	"MUY"
	.asciz	"DVI"
	.asciz	"NMI"
	.asciz	"SHL"
	.asciz	"ASR"
	.asciz	"LSR"

	.align	0200

; print register set
printregs: .word .-.
	jms	printmsg
		.asciz	" LINK="
	tadi	printregs
	isz	printregs
	dca	pr_temp1
	tadi	pr_temp1
	tad	_0060
	jms	printchr
	jms	printmsg
		.asciz	" AC="
	tadi	printregs
	isz	printregs
	dca	pr_temp1
	tadi	pr_temp1
	jms	printoct4
	jms	printmsg
		.asciz	" MQ="
	tadi	printregs
	isz	printregs
	dca	pr_temp1
	tadi	pr_temp1
	jms	printoct4
	jms	printmsg
		.asciz	" SC="
	tadi	printregs
	isz	printregs
	dca	pr_temp1
	tadi	pr_temp1
	jms	printoct2
	jmpi	printregs
pr_temp1: .word	.-.

; print inline null-terminated message
printmsg: .word	.-.
	tad	printmsg
	jms	printstr
	jmpi	pstr_temp1

; print null-terminated message pointed to by AC
printstr: .word	.-.
	dca	pstr_temp1
pstr_loop:
	tadi	pstr_temp1
	isz	pstr_temp1
	sna
	jmpi	printstr
	jms	printchr
	jmp	pstr_loop
pstr_temp1: .word .-.

; print 4-digit octal number in AC
printoct4: .word .-.
	dca	po4_temp
	tad	po4_temp
	bsw
	jms	printoct2
	tad	po4_temp
	jms	printoct2
	jmpi	printoct4
po4_temp: .word	.-.

; print 2-digit octal number in AC
printoct2: .word .-.
	dca	po2_temp
	tad	po2_temp
	rtr
	rar
	and	_0007
	tad	_0060
	jms	printchr
	tad	po2_temp
	and	_0007
	tad	_0060
	jms	printchr
	jmpi	printoct2
po2_temp: .word	.-.

; print single char in AC
printchr: .word	.-.
	tls
	cla
	tsf
	jmp	.-1
	jmpi	printchr

	.align	0200

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 7401 NOP
step3_nop: .word .-.
	jmpi	step3_nop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 7403 SCL - step counter load from memory
step3_scl: .word .-.
	tad	memop
	cma
	and	_0037
	dca	scwork
	jmpi	step3_scl

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 7411 NMI - normalize
step3_nmi: .word .-.
	tad	_7740
	dca	scwork		; start with SC = 7740
nmi_loop:
	tad	acwork		; done if top 2 bits of AC different
	cll ral
	tad	_4000
	szl
	jmp	nmi_done
	ral			; top 2 bits same, check for rest of AC zero
	sza cla
	jmp	nmi_shift
	tad	mqwork		; ...and all of MQ zero
	sna cla
	jmp	nmi_done	; ...done if so
nmi_shift:
	tad	mqwork		; shift LINK.AC.MQ left one bit
	cll ral
	dca	mqwork
	tad	acwork
	ral
	dca	acwork
	ral
	dca	linkwork
	isz	scwork		; increment SC
	jmp	nmi_loop	; repeat only if <4:0> non-zero
nmi_done:
	jmpi	step3_nmi

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 7413 SHL - shift left
step3_shl: .word .-.
	tad	memop
	and	_0037
	cma
	dca	scwork		; set SC = negative shift ocunt
shl_loop:
	tad	mqwork		; shift LINK.AC.MQ left one bit
	cll ral
	dca	mqwork
	tad	acwork
	ral
	dca	acwork
	ral
	dca	linkwork
	isz	scwork		; see if more to shift
	jmp	shl_loop
	jmpi	step3_shl

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 7415 ASR - arithmetic shift right
step3_asr: .word .-.

.if 000
	jmsi	_printmsg
		.asciz	"\r\nASR ACMQ="
	tad	acwork
	jmsi	_printoct4
	tad	mqwork
	jmsi	_printoct4
	jmsi	_printmsg
		.asciz	" >> Y="
	tad	memop
	and	_0037
	jmsi	_printoct2
.endif

	tad	memop
	and	_0037
	cma
	dca	scwork		; set SC = negative shift ocunt
	tad	acwork		; set LINK = AC<11>
	ral
	cla ral
	dca	linkwork
asr_loop:
	tad	linkwork	; shift LINK.AC.MQ right one bit
	cll rar
	tad	acwork
	rar
	dca	acwork
	tad	mqwork
	rar
	dca	mqwork
	isz	scwork		; see if more to shift
	jmp	asr_loop

.if 000
	jmsi	_printmsg
		.asciz	"+1 => ACMQ="
	tad	acwork
	jmsi	_printoct4
	tad	mqwork
	jmsi	_printoct4
	jmsi	_printmsg
		.asciz	"\r\n"
.endif

	jmpi	step3_asr

	.align	0200

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 7417 LSR - logical shift right
step3_lsr: .word .-.
	tad	memop
	and	_0037
	cma
	dca	scwork		; set SC = negative shift ocunt
	dca	linkwork	; clear LINK
lsr_loop:
	tad	acwork		; shift AC.MQ right one bit
	cll rar
	dca	acwork
	tad	mqwork
	rar
	dca	mqwork
	isz	scwork		; see if more to shift
	jmp	lsr_loop
	jmpi	step3_lsr

	.align	0200

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 7405 MUY - multiply: Y * MQ + AC => AC,MQ; 0 => LINK; 0 => SC
step3_muy: .word .-.

.if 000
	jmsi	_printmsg
		.asciz	"\r\nMUY Y="
	tad	memop
	jmsi	_printoct4
	jmsi	_printmsg
		.asciz	" * MQ="
	tad	mqwork
	jmsi	_printoct4
	jmsi	_printmsg
		.asciz	" + AC="
	tad	acwork
	jmsi	_printoct4
.endif

	tad	acwork
	dca	umul_prod+0
	dca	umul_prod+1
	tad	mqwork
	dca	umul_mcand+0
	dca	umul_mcand+1
	tad	memop
	jms	umul24
	tad	umul_prod+0
	dca	mqwork
	tad	umul_prod+1
	dca	acwork
	dca	linkwork
	dca	scwork

.if 000
	jmsi	_printmsg
		.asciz	" => AC="
	tad	acwork
	jmsi	_printoct4
		.asciz	" MQ="
	tad	mqwork
	jmsi	_printoct4
	jmsi	_printmsg
		.asciz	"\r\n"
.endif

	jmpi	step3_muy

umul_mcand: .word 0,0
umul_prod:  .word 0,0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; unsigned multiply
;  input:
;   ac = 12-bit multiplier
;   umul_mcand = 24-bit multiplicand (little endian)
;  output:
;   ac = 0
;   umul_prod += 24-bit product (little endian)
;  scratch:
;   umul_multr, umul_mcand
umul24:	.word	.-.

umul24_loop:
	cll rar			; check low multiplier bit
	dca	umul_multr	; and shift multiplier right
	snl
	jmp	umul24_skip
	cll			; set, add multiplicand to product
	tad	umul_prod+0
	tad	umul_mcand+0
	dca	umul_prod+0
	ral
	tad	umul_prod+1
	tad	umul_mcand+1
	dca	umul_prod+1
umul24_skip:
	cla cll			; shift multiplicand left
	tad	umul_mcand+0
	ral
	dca	umul_mcand+0
	tad	umul_mcand+1
	ral
	dca	umul_mcand+1
	tad	umul_multr
	sza
	jmp	umul24_loop
	jmpi	umul24

umul_multr: .blkw 1

	.align	0200

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 7407 DVI - divide: AC,MQ / Y => MQ r AC
step3_dvi: .word .-.
	tad	memop		; see if AC >= Y
	cll cma iac
	tad	acwork
	szl cla
	jmp	dvi_ovrflo
	tad	mqwork		; AC < Y, divide can be performed
	dca	udiv_dvquo+0
	tad	acwork
	dca	udiv_dvquo+1
	tad	memop
	jms	udiv24
	tad	udiv_remdr	; AC = remainder
	dca	acwork
	tad	udiv_dvquo+0	; MQ = quotient
	dca	mqwork
	dca	scwork		; set SC = 0, divide complete
	dca	linkwork	; set LINK = 0, no overflow
	jmpi	step3_dvi

	; AC >= Y, divide overlow
	; the real 8/I EAE leaves AC = Y + ~ AC
	; ...and leaves MQ alone and sets SC = 0
	; but our board leaves both AC and MQ alone
	; ...and sets SC = 0024 (didn't do any steps, 12. to go)
dvi_ovrflo:
	tad	_0024		; set SC = 0024
	dca	scwork
	iac			; set LINK = 1 for overflow
	dca	linkwork
	jmpi	step3_dvi

udiv_dvquo: .word 0,0
udiv_remdr: .word 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; unsigned divide
;  input:
;   ac = divisor
;   udiv_dvquo = 24-bit dividend (little endian)
;  output:
;   ac = 0
;   udiv_remdr = remainder
;   udiv_dvquo = 24-bit quotient (little endian)
;  scratch:
;   udiv_count, udiv_ndvsr
udiv24:	.word	.-.

	cma iac
	dca	udiv_ndvsr	; negative of divisor
	tad	_7750
	dca	udiv_count
	dca	udiv_remdr
udiv24_loop:
	; [link] [remdr] [dvquo+1] [dvquo+0] < quotient bits
	;        [ndvsr]
	tad	udiv_dvquo+0	; shift link-remdr-dvquo left one bit
	cll ral			; zero goes in bottom for quotient bit
	dca	udiv_dvquo+0
	tad	udiv_dvquo+1
	ral
	dca	udiv_dvquo+1
	tad	udiv_remdr
	ral
	dca	udiv_remdr
	tad	udiv_remdr	; get top 12 bits of 36-bit dividend (link = 13th bit)
	tad	udiv_ndvsr	; add negative divisor
	snl
	jmp	udiv24_skip
	dca	udiv_remdr	; boosted negated divisor from neg to pos, it fits
	isz	udiv_dvquo+0	; change bottom quotient bit to a one
udiv24_skip:
	cla
	isz	udiv_count
	jmp	udiv24_loop
	jmpi	udiv24

udiv_ndvsr: .blkw 2		; negative of divisor
udiv_count: .blkw 1		; iteration counter


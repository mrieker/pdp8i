
; test eae instructions
; relies on pdp8ishad.v to verify results
; prints char on tty every ~15 sec (@ 1.50uS clkratm1=9)
;                           10 sec (@ 1.05uS clkratm1=6)

	tls = 06046

	. = 020

count:	.word	0,0

_0006:	.word	00006
_0060:	.word	00060
_0376:	.word	00376
_7764:	.word	07764

_getrand: .word	getrand

	. = 0200
	.global	__boot
__boot:

testloop:
	jmsi	_getrand	; get 12 random bits
	mql			; ... into MQ then clear AC
	jmsi	_getrand	; get 12 random bits
	dca	scdat		; ... low 5 bits into SC
	tad	scdat		; ... high 7 bits for opcode
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

	scl			; load ~scdat<4:0> into SC
scdat:	.word	.-.
	jmsi	_getrand	; get 12 random bits into AC and one in LINK
eaeop:	.word	.-.		; perform EAE instruction, let pdp8ishad.v check it
memop:	.word	.-.		; possible memory operand (or NOP)
				; pdp8ishad.v will check AC and LINK on its own
	cla mqa			; let pdp8ishad.v check MQ contents by putting it in AC
	cla sca			; let pdp8ishad.v check SC contents by putting it in AC

	isz	count+0
	jmp	testloop
	tad	_0060		; '0'+SC = '0'..'O'
	tls
	isz	count+1
	jmp	testloop
	jmp	testloop

nopcod:	nop

	.align	0200
;
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


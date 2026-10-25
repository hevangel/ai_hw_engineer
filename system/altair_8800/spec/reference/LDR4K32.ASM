	org	0
;
; SIO Loader for 4K BASIC Version 3.2
; 
;   ** Set all sense switches OFF **
;
; H = msb of load address
; L = lsb of load address = length of loader = leader byte
;
	org	0

;	lxi	h,1F7Dh		;8K BASIC V3.0
;	lxi	h,0F7Dh		;4K BASIC V3.1
	lxi	h,0FAEh		;4K BASIC V3.2
;	lxi	h,1FAEh		;8K BASIC V3.2
;	lxi	h,0FC2h		;4K BASIC V4.0
;	lxi	h,1FC2h		;8K BASIC v4.0
;	lxi	h,3FC2h		;Extended BASIC V4.0
;	lxi	h,7EC2h		;Extended Disk BASIC v5.0

loop	lxi	sp,stack	;init SP so a RET jumps to loop
	in	00h		;get sio status
	rrc			;new byte available?
	rc			;no (jumps back to loop)

	in	01h		;get the byte
	cmp	l		;new byte = leader byte?
	rz			;yes (jumps back to loop)

	dcr	l		;not leader, decrement address
	mov	m,a		;store the byte (reverse order)
	rnz			;loop until L = 0

	pchl			;jump to code just downloaded

stack	dw	loop
	end


	.file	"arm-tas-v8.S"
/*
 * ulong _tas(ulong*);
 */
	.align	2
	.global	_tas
	.type	_tas, %function
_tas:
	mov	w3, #1
	mov	x1, x0
loop:
	ldaxr	x0, [x1]
	stlxr	w2, w3, [x1]
	cbnz	w2, loop
	ret	
	.size	_tas, .-_tas

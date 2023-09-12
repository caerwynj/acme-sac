#define	FN(x)	.type x,%function; .global x; x
#define	ENT
#define	RET	ret

	.file	"setfcr-Linux-arm64.S"
FN(setfcr):
	ENT
	msr fpcr, x0
	RET

FN(getfcr):
	ENT
	mrs x0, fpcr	
	RET

FN(getfsr):
	ENT
	mrs x0, fpsr
	RET

FN(setfsr):
	ENT
	msr fpsr, x0
	RET

/*
 * system- and machine-specific declarations for emu:
 * floating-point save and restore, signal handling primitive, and
 * implementation of the current-process variable `up'.
 */

/*
 * This structure must agree with FPsave and FPrestore asm routines
 */
typedef struct FPU FPU;
struct FPU
{
	uchar	env[28];
};


#ifndef USE_PTHREADS
#define KSTACK (16 * 1024)	/* must be power of two */
static __inline Proc *getup(void) {
	Proc *p;
	__asm__(	"mov	%0, %%sp;" 
			: "=r" (p) 
 	); 
	return *(Proc **)((uintptr)p & ~(KSTACK - 1));
}
#else
#define KSTACK (32 * 1024)	/* need not be power of two */
extern	Proc*	getup(void);
#endif

#define	up	(getup())

typedef sigjmp_buf osjmpbuf;
#define	ossetjmp(buf)	sigsetjmp(buf, 1)

#include <fenv.h>
#include "lib9.h"
#include "mathi.h"

void
FPinit(void)
{
	feclearexcept(FE_ALL_EXCEPT);
	fesetround(FE_TONEAREST);
	feenableexcept(FE_OVERFLOW|FE_UNDERFLOW|FE_DIVBYZERO|FE_INVALID);
}

ulong
getFPstatus(void)
{
	fexcept_t fsr9;
	fsr9 = fetestexcept(FE_ALL_EXCEPT);
	
	ulong fsr = 0;
	/* on specific machines, could be table lookup */
	if(fsr9&FE_INEXACT) fsr |= INEX;
	if(fsr9&FE_OVERFLOW) fsr |= OVFL;
	if(fsr9&FE_UNDERFLOW) fsr |= UNFL;
	if(fsr9&FE_DIVBYZERO) fsr |= ZDIV;
	if(fsr9&FE_INVALID) fsr |= INVAL;
	return fsr;
}

ulong
FPstatus(ulong fsr, ulong mask)
{
	fexcept_t fsr9 = 0;
	ulong old = getFPstatus();
	fsr = (fsr&mask) | (old&~mask);
	if(fsr&INEX) fsr9 |= FE_INEXACT;
	if(fsr&OVFL) fsr9 |= FE_OVERFLOW;
	if(fsr&UNFL) fsr9 |= FE_UNDERFLOW;
	if(fsr&ZDIV) fsr9 |= FE_DIVBYZERO;
	if(fsr&INVAL) fsr9 |= FE_INVALID;
	feclearexcept(FE_ALL_EXCEPT);
	fesetexcept(fsr9);
	return(old&mask);
}

ulong
getFPcontrol(void)
{
	ulong fcr = 0;
	fexcept_t fcr9 = fegetexcept();
	ulong round = fegetround();
	
	switch(round){
		case FE_TONEAREST:	fcr = RND_NR; break;
		case FE_DOWNWARD:	fcr = RND_NINF; break;
		case FE_UPWARD:	fcr = RND_PINF; break;
		case FE_TOWARDZERO:	fcr = RND_Z; break;
	}
	if(fcr9&FE_INEXACT) fcr |= INEX;
	if(fcr9&FE_OVERFLOW) fcr |= OVFL;
	if(fcr9&FE_UNDERFLOW) fcr |= UNFL;
	if(fcr9&FE_DIVBYZERO) fcr |= ZDIV;
	if(fcr9&FE_INVALID) fcr |= INVAL;
	return fcr;
}

ulong
FPcontrol(ulong fcr, ulong mask)
{
	ulong fcr9 = 0;
	ulong round = 0;
	ulong old = getFPcontrol();
	fcr = (fcr&mask) | (old&~mask);
	if(fcr&INEX) fcr9 |= FE_INEXACT;
	if(fcr&OVFL) fcr9 |= FE_OVERFLOW;
	if(fcr&UNFL) fcr9 |= FE_UNDERFLOW;
	if(fcr&ZDIV) fcr9 |= FE_DIVBYZERO;
	if(fcr&INVAL) fcr9 |= FE_INVALID;
	switch(fcr&RND_MASK){
		case RND_NR:	round |= FE_TONEAREST; break;
		case RND_NINF:	round |= FE_DOWNWARD; break;
		case RND_PINF:	round |= FE_UPWARD; break;
		case RND_Z:	round |= FE_TOWARDZERO; break;
	}
	fesetround(round);
	fedisableexcept(FE_ALL_EXCEPT);
	feenableexcept(fcr9);
	return(old&mask);
}

FPsave(void* envp)
{
	fegetenv((fenv_t*) envp);
}

FPrestore(void* envp)
{
	fesetenv((fenv_t*) envp);
}


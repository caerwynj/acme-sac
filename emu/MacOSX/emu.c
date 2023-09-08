#include "dat.h"
#include "fns.h"
#include "error.h"
#include "interp.h"
#include "emu.root.h"

ulong ndevs = 29;

extern Dev  rootdevtab;
extern Dev  consdevtab;
extern Dev  envdevtab;
extern Dev  mntdevtab;
extern Dev  pipedevtab;
extern Dev  progdevtab;
extern Dev  profdevtab;
extern Dev  srvdevtab;
extern Dev  dupdevtab;
extern Dev  ssldevtab;
extern Dev  capdevtab;
extern Dev  fsdevtab;
extern Dev  cmddevtab;
extern Dev  indirdevtab;
extern Dev  drawdevtab;
extern Dev  pointerdevtab;
extern Dev  snarfdevtab;
extern Dev  wmszdevtab;
extern Dev  ipdevtab;
extern Dev  eiadevtab;
extern Dev  memdevtab;

Dev* devtab[]={
	&rootdevtab,
	&consdevtab,
	&envdevtab,
	&mntdevtab,
	&pipedevtab,
	&progdevtab,
	&profdevtab,
	&srvdevtab,
	&dupdevtab,
	&ssldevtab,
	&capdevtab,
	&fsdevtab,
	&cmddevtab,
	&indirdevtab,
	&drawdevtab,
	&pointerdevtab,
	&snarfdevtab,
	&wmszdevtab,
	&ipdevtab,
	&eiadevtab,
	&memdevtab,
	nil,
	nil,
	nil,
	nil,
	nil,
	nil,
	nil,
	nil,
	nil,
};


void links(void){
}


extern void  sysmodinit(void);
extern void  drawmodinit(void);
extern void  mathmodinit(void);
extern void  srvmodinit(void);
extern void  keyringmodinit(void);
void modinit(void){
	sysmodinit();
	drawmodinit();
	mathmodinit();
	srvmodinit();
	keyringmodinit();
}


	int	dontcompile = 1;
	int macjit = 1;
char* conffile="emu";
ulong kerndate = KERNDATE;

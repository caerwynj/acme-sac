#include "dat.h"
#include "fns.h"
#include "error.h"
#include "interp.h"
#include "emu.root.h"

ulong ndevs = 26;

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
extern Dev  fsdevtab;
extern Dev  cmddevtab;
extern Dev  drawdevtab;
extern Dev  ipdevtab;
extern Dev  audiodevtab;
extern Dev  pointerdevtab;
extern Dev  snarfdevtab;
extern Dev  wmszdevtab;

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
	&fsdevtab,
	&cmddevtab,
	&drawdevtab,
	&ipdevtab,
	&audiodevtab,
	&pointerdevtab,
	&snarfdevtab,
	&wmszdevtab,
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


char* conffile="emu";
ulong kerndate = KERNDATE;

#include "dat.h"
#include "fns.h"
#include "error.h"
#include "interp.h"
#include "acme.root.h"

ulong ndevs = 28;

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
extern Dev  memdevtab;
extern Dev  archdevtab;
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
	&memdevtab,
	&archdevtab,
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
extern void  cryptmodinit(void);
extern void  ipintsmodinit(void);
void modinit(void){
	sysmodinit();
	drawmodinit();
	mathmodinit();
	srvmodinit();
	keyringmodinit();
	cryptmodinit();
	ipintsmodinit();
}


char* conffile="acme";
ulong kerndate = KERNDATE;

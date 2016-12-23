#include "dat.h"
#include "fns.h"
#include "error.h"
#include "interp.h"
#include "cell.root.h"

ulong ndevs = 19;

extern Dev  rootdevtab;
extern Dev  consdevtab;
extern Dev  envdevtab;
extern Dev  mntdevtab;
extern Dev  pipedevtab;
extern Dev  progdevtab;
extern Dev  srvdevtab;
extern Dev  dupdevtab;
extern Dev  fsdevtab;
extern Dev  cmddevtab;
extern Dev  ipdevtab;

Dev* devtab[]={
	&rootdevtab,
	&consdevtab,
	&envdevtab,
	&mntdevtab,
	&pipedevtab,
	&progdevtab,
	&srvdevtab,
	&dupdevtab,
	&fsdevtab,
	&cmddevtab,
	&ipdevtab,
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
extern void  mathmodinit(void);
extern void  srvmodinit(void);
extern void  keyringmodinit(void);
void modinit(void){
	sysmodinit();
	mathmodinit();
	srvmodinit();
	keyringmodinit();
}


	int	dontcompile = 1;
	int macjit = 1;
	void setpointer(int x, int y){USED(x); USED(y);}
	ulong strtochan(char *s){USED(s); return ~0;}
char* conffile="cell";
ulong kerndate = KERNDATE;

/*
 * host wm size
 */

#include	"dat.h"
#include	"fns.h"
#include	"../port/error.h"

#include <draw.h>
#include <memdraw.h>
#include <cursor.h>

#define	cursorenable()
#define	cursordisable()

enum{
	Qdir,
	Qwmsize
};

typedef struct Wmsize Wmsize;

struct Wmsize {
	int	x;
	int	y;
	int	b;
	ulong	msec;
};

static struct
{
	Wmsize	v;
	int	modify;
	int	lastb;
	Rendez	r;
	Ref	ref;
	QLock	q;
} mouse;

static
Dirtab wmsizetab[]={
	".",			{Qdir, 0, QTDIR},	0,	0555,
	"wmsize",		{Qwmsize},	0,	0666,
};

enum {
	Nevent = 16	/* enough for some */
};

static struct {
	int	rd;
	int	wr;
	Wmsize	clicks[Nevent];
	Rendez r;
	int	full;
	int	put;
	int	get;
} ptrq;

/*
 * called by any source of wmsize data
 */
void
wmtrack(int b, int x, int y, int isdelta)
{
	int lastb;
	ulong msec;
	Wmsize e;

	if(isdelta){
		x += mouse.v.x;
		y += mouse.v.y;
	}
	msec = osmillisec();
	if(0 && b && (mouse.v.b ^ b)&0x1f){
		if(msec - mouse.v.msec < 300 && mouse.lastb == b
		   && abs(mouse.v.x - x) < 12 && abs(mouse.v.y - y) < 12)
			b |= 1<<8;
		mouse.lastb = b & 0x1f;
		mouse.v.msec = msec;
	}
	if((b&(1<<8))==0 && x == mouse.v.x && y == mouse.v.y && mouse.v.b == b)
		return;
	lastb = mouse.v.b;
	mouse.v.x = x;
	mouse.v.y = y;
	mouse.v.b = b;
	mouse.v.msec = msec;
	if(!ptrq.full && lastb != b){
		e = mouse.v;
		ptrq.clicks[ptrq.wr] = e;
		if(++ptrq.wr >= Nevent)
			ptrq.wr = 0;
		if(ptrq.wr == ptrq.rd)
			ptrq.full = 1;
	}
	mouse.modify = 1;
	ptrq.put++;
	Wakeup(&ptrq.r);
/*	drawactive(1);	*/
/*	setwmsize(x, y); */
}

static int
ptrqnotempty(void *x)
{
	USED(x);
	return ptrq.full || ptrq.put != ptrq.get;
}

static Wmsize
wmsizeconsume(void)
{
	Wmsize e;

	Sleep(&ptrq.r, ptrqnotempty, 0);
	ptrq.full = 0;
	ptrq.get = ptrq.put;
	if(ptrq.rd != ptrq.wr){
		e = ptrq.clicks[ptrq.rd];
		if(++ptrq.rd >= Nevent)
			ptrq.rd = 0;
	}else
		e = mouse.v;
	return e;
}

static Chan*
wmsizeattach(char* spec)
{
	return devattach('w', spec);
}

static Walkqid*
wmsizewalk(Chan *c, Chan *nc, char **name, int nname)
{
	Walkqid *wq;

	wq = devwalk(c, nc, name, nname, wmsizetab, nelem(wmsizetab), devgen);
	if(wq != nil && wq->clone != c && wq->clone != nil && (ulong)c->qid.path == Qwmsize)
		incref(&mouse.ref);	/* can this happen? */
	return wq;
}

static int
wmsizestat(Chan* c, uchar *db, int n)
{
	return devstat(c, db, n, wmsizetab, nelem(wmsizetab), devgen);
}

static Chan*
wmsizeopen(Chan* c, int omode)
{
	c = devopen(c, omode, wmsizetab, nelem(wmsizetab), devgen);
	if((ulong)c->qid.path == Qwmsize){
		if(waserror()){
			c->flag &= ~COPEN;
			nexterror();
		}
		if(!canqlock(&mouse.q))
			error(Einuse);
		if(incref(&mouse.ref) != 1){
			qunlock(&mouse.q);
			error(Einuse);
		}
		cursorenable();
		qunlock(&mouse.q);
		poperror();
	}
	return c;
}

static void
wmsizeclose(Chan* c)
{
	if((c->flag & COPEN) == 0)
		return;
	switch((ulong)c->qid.path){
	case Qwmsize:
		qlock(&mouse.q);
		if(decref(&mouse.ref) == 0){
			cursordisable();
		}
		qunlock(&mouse.q);
		break;
	}
}

static long
wmsizeread(Chan* c, void* a, long n, vlong off)
{
	Wmsize mt;
	char buf[1+4*12+1];
	int l;

	USED(&off);
	switch((ulong)c->qid.path){
	case Qdir:
		return devdirread(c, a, n, wmsizetab, nelem(wmsizetab), devgen);
	case Qwmsize:
		qlock(&mouse.q);
		if(waserror()) {
			qunlock(&mouse.q);
			nexterror();
		}
		mt = wmsizeconsume();
		poperror();
		qunlock(&mouse.q);
		l = snprint(buf, sizeof(buf), "m%11d %11d %11d %11lud ", mt.x, mt.y, mt.b, mt.msec);
		if(l < n)
			n = l;
		memmove(a, buf, n);
		break;
	default:
		n=0;
		break;
	}
	return n;
}

static long
wmsizewrite(Chan* c, void* va, long n, vlong off)
{
	char *a = va;
	char buf[128];
	int b, x, y;

	USED(&off);
	switch((ulong)c->qid.path){
	case Qwmsize:
		if(n > sizeof buf-1)
			n = sizeof buf -1;
		memmove(buf, va, n);
		buf[n] = 0;
		x = strtoul(buf+1, &a, 0);
		if(*a == 0)
			error(Eshort);
		y = strtoul(a, &a, 0);
		if(*a != 0)
			b = strtoul(a, 0, 0);
		else
			b = mouse.v.b;
		/*mousetrack(b, x, y, msec);*/
		/* setwmsize(x, y); */
		USED(b);
		break;
	default:
		error(Ebadusefd);
	}
	return n;
}

Dev wmszdevtab = {
	'w',
	"wmsz",

	devinit,
	wmsizeattach,
	wmsizewalk,
	wmsizestat,
	wmsizeopen,
	devcreate,
	wmsizeclose,
	wmsizeread,
	devbread,
	wmsizewrite,
	devbwrite,
	devremove,
	devwstat,
};

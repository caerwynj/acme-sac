implement Acmewin;

include "sys.m";
include "draw.m";
include "bufio.m";
include "acmewin.m";

sys : Sys;
bufio : Bufio;

OREAD, OWRITE, ORDWR, FORKENV, NEWFD, FORKFD, NEWPGRP, UTFmax : import Sys;
FD, Dir : import sys;
fprint, sprint, sleep, create, open, read, write, remove, stat, fstat, fwstat, fildes, pctl, pipe, dup, byte2char : import sys;
Context : import Draw;
EOF : import Bufio;
Iobuf : import bufio;
DIRLEN : con 116;
PNPROC, PNGROUP : con iota;
False : con 0;
True : con 1;
Runeself : con 16r80;
OCEXEC : con 0;
CHEXCL : con 0; # 16r20000000;
CHAPPEND : con 0; # 16r40000000;

killing : int = 0;
stderr : ref FD;


init()
{
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
}

Win.wnew() : ref Win
{
	w := ref Win;
	buf := array[12] of byte;
	w.ctl = open("/chan/new/ctl", ORDWR);
	if(w.ctl==nil || read(w.ctl, buf, 12)!=12)
		error("can't open window ctl file: %r");
	w.ctlwrite("noscroll\n");
	w.winid = int string buf;
	w.event = w.openfile("event");
	w.addr = nil;	# will be opened when needed
	w.body = nil;
	w.data = nil;
	w.bufp = w.nbuf = 0;
	w.buf = array[512] of byte;
	return w;
}

Win.openfile(w : self ref Win, f : string) : ref FD
{
	buf := sprint("/chan/%d/%s", w.winid, f);
	fd := open(buf, ORDWR|OCEXEC);
	if(fd == nil)
		error(sprint("can't open window %s file: %r", f));
	return fd;
}

Win.openbody(w : self ref Win, mode : int)
{
	buf := sprint("/chan/%d/body", w.winid);
	w.body = bufio->open(buf, mode|OCEXEC);
	if(w.body == nil)
		error("can't open window body file: %r");
}

Win.wwritebody(w : self ref Win, s : string)
{
	n := len s;
	if(w.body == nil)
		w.openbody(OWRITE);
	if(w.body.puts(s) != n)
		error("write error to window: %r");
	w.body.flush();
}

Win.wreplace(w : self ref Win, addr : string, repl : string)
{
	if(w.addr == nil)
		w.addr = w.openfile("addr");
	if(w.data == nil)
		w.data = w.openfile("data");
	if(swrite(w.addr, addr) < 0){
		fprint(stderr, "acmewin: warning: bad address %s:%r\n", addr);
		return;
	}
	if(swrite(w.data, repl) != len repl)
		error("writing data: %r");
}

nrunes(s : array of byte, nb : int) : int
{
	i, n : int;

	n = 0;
	for(i=0; i<nb; n++) {
		(nil, b, ok) := byte2char(s, i);
		if (!ok)
			error("help needed in nrunes()");
		i += b;
	}
	return n;
}

Win.wread(w : self ref Win, q0 : int, q1 : int) : string
{
	m, n, nr : int;
	s, buf : string;
	b : array of byte;

	b = array[256] of byte;
	if(w.addr == nil)
		w.addr = w.openfile("addr");
	if(w.data == nil)
		w.data = w.openfile("data");
	s = nil;
	m = q0;
	while(m < q1){
		buf = sprint("#%d", m);
		if(swrite(w.addr, buf) != len buf)
			error("writing addr: %r");
		n = read(w.data, b, len b);
		if(n <= 0)
			error("reading data: %r");
		nr = nrunes(b, n);
		while(m+nr >q1){
			do; while(n>0 && (int b[--n]&16rC0)==16r80);
			--nr;
		}
		if(n == 0)
			break;
		s += string b[0:n];
		m += nr;
	}
	return s;
}

Win.wshow(w : self ref Win)
{
	w.ctlwrite("show\n");
}

Win.wsetdump(w : self ref Win, dir : string, cmd : string)
{
	t : string;

	if(dir != nil){
		t = "dumpdir " + dir + "\n";
		w.ctlwrite(t);
		t = nil;
	}
	if(cmd != nil){
		t = "dump " + cmd + "\n";
		w.ctlwrite(t);
		t = nil;
	}
}

Win.wsetaddr(w : self ref Win, addr : string,  errok: int): int
{
	if(w.addr == nil)
		w.addr = w.openfile("addr");
	if(swrite(w.addr, addr) < 0){
		if(!errok)
			error("writing addr");
		return 0;
	}
	return 1;
}

Win.wselect(w : self ref Win, addr : string)
{
	if(w.addr == nil)
		w.addr = w.openfile("addr");
	if(swrite(w.addr, addr) < 0)
		error("writing addr");
	w.ctlwrite("dot=addr\n");
}

Win.wtagwrite(w : self ref Win, s : string)
{
	fd : ref FD;

	fd = w.openfile("tag");
	if(swrite(fd, s) != len s)
		error("tag write: %r");
	fd = nil;
}

Win.ctlwrite(w : self ref Win, s : string)
{
	if(swrite(w.ctl, s) != len s)
		error("write error to ctl file: %r");
}

Win.wdel(w : self ref Win, sure : int) : int
{
	if (w == nil)
		return False;
	if(sure)
		swrite(w.ctl, "delete\n");
	else if(swrite(w.ctl, "del\n") != 4)
		return False;
	w.wdormant();
	w.ctl = nil;
	w.event = nil;
	return True;
}

Win.wname(w : self ref Win, s : string)
{
	w.ctlwrite("name " + s + "\n");
}

Win.wclean(w : self ref Win)
{
	if(w.body != nil)
		w.body.flush();
	w.ctlwrite("clean\n");
}

Win.wdormant(w : self ref Win)
{
	w.addr = nil;
	if(w.body != nil){
		w.body.close();
		w.body = nil;
	}
	w.data = nil;
}

Win.getec(w : self ref Win) : int
{
	if(w.nbuf == 0){
		w.nbuf = read(w.event, w.buf, len w.buf);
		if(w.nbuf <= 0 && !killing) {
			error("event read error: %r");
		}
		w.bufp = 0;
	}
	w.nbuf--;
	return int w.buf[w.bufp++];
}

Win.geten(w : self ref Win) : int
{
	n, c : int;

	n = 0;
	while('0'<=(c=w.getec()) && c<='9')
		n = n*10+(c-'0');
	if(c != ' ')
		error("event number syntax");
	return n;
}

Win.geter(w : self ref Win, buf : array of byte) : (int, int)
{
	r, m, n, ok : int;

	r = w.getec();
	buf[0] = byte r;
	n = 1;
	if(r >= Runeself) {
		for (;;) {
			(r, m, ok) = byte2char(buf[0:n], 0);
			if (m > 0)
				return (r, n);
			buf[n++] = byte w.getec();
		}
	}
	return (r, n);
}

Win.wevent(w : self ref Win, e : ref Event)
{
	i, nb : int;

	e.c1 = w.getec();
	e.c2 = w.getec();
	e.q0 = w.geten();
	e.q1 = w.geten();
	e.flag = w.geten();
	e.nr = w.geten();
	if(e.nr > EVENTSIZE)
		error("event string too long");
	e.nb = 0;
	for(i=0; i<e.nr; i++){
		(e.r[i], nb) = w.geter(e.b[e.nb:]);
		e.nb += nb;
	}
	e.r[e.nr] = 0;
	e.b[e.nb] = byte 0;
	c := w.getec();
	if(c != '\n')
		error("event syntax 2");
}

Win.wslave(w : self ref Win, ce : chan of Event)
{
	e : ref Event;
	for(;;){
		e = newevent();
		w.wevent(e);
		ce <-= *e;
	}
}

Win.wwriteevent(w : self ref Win, e : ref Event)
{
	fprint(w.event, "%c%c%d %d\n", e.c1, e.c2, e.q0, e.q1);
}

Win.wreadall(w : self ref Win) : string
{
	s, t : string;

	if(w.body != nil)
		w.body.close();
	w.openbody(OREAD);
	s = nil;
	while ((t = w.body.gets('\n')) != nil)
		s += t;
	w.body.close();
	w.body = nil;
	return s;
}

error(s : string)
{
	if(s != nil)
		fprint(stderr, "Wiki: %s\n", s);
	sys->fprint(stderr, "okay, i'm not exiting\n");
#	postnote(PNGROUP, pctl(0, nil), "kill");
#	killing = 1;
#	exit;
}

postnote(t : int, pid : int, note : string) : int
{
	fd := open("#p/" + string pid + "/ctl", OWRITE);
	if (fd == nil)
		return -1;
	if (t == PNGROUP)
		note += "grp";
	fprint(fd, "%s", note);
	fd = nil;
	return 0;
}

swrite(fd : ref FD, s : string) : int
{
	ab := array of byte s;
	m := len ab;
	p := write(fd, ab, m);
	if (p == m)
		return len s;
	if (p <= 0)
		return p;
	return 0;
}

newevent() : ref Event
{
	e := ref Event;
	e.b = array[EVENTSIZE*UTFmax+1] of byte;
	e.r = array[EVENTSIZE+1] of int;
	return e;
}	

implement Wikim;

include "sys.m";
	sys : Sys;
	open, write, seek, read, pread, stat, sprint, print, 
	fprint, werrstr, fildes, chdir, pctl, dup, 
	FORKFD, NEWFD, Dir, UTFmax, NEWPGRP,
	DMDIR, OREAD, ORDWR, OWRITE: import sys;
include "draw.m";
include "bufio.m";
	bufio : Bufio;
	Iobuf: import bufio;
include "acmewin.m";
	winm: Acmewin;
	Win, Event: import winm;
include "string.m";
	str: String;
include "names.m";
	names: Names;
	cleanname: import names;
include "arg.m";
	arg: Arg;
include "sh.m";
	sh: Sh;

debug := 0;
PNPROC, PNGROUP : con iota;

Wikim: module {
	init: fn(ctxt: ref Draw->Context, args: list of string);
};

Wiki: adt {
	isnew: int;
	special: int;
	arg: string;
	addr: string;
	n: int;
	dead: int;
	win: ref Win;
	time: int;
	cevent: chan of Event;
	dirtied: int;

	put: fn(w: self ref Wiki): int;
	get: fn(w: self ref Wiki);
	diff: fn(w: self ref Wiki): int;
};

wlist: list of ref Wiki;
dir: string;
stderr: ref Sys->FD;
email: string;

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
	winm = load Acmewin Acmewin->PATH;
	winm->init();
	str = load String String->PATH;
	names = load Names Names->PATH;
	arg = load Arg Arg->PATH;
	sh = load Sh Sh->PATH;

	stderr = fildes(2);
	arg->init(args);
	while((c := arg->opt()) != 0)
		case c {
		'D' =>
			debug++;
		'e' =>
			email = arg->earg();
		}
	args = arg->argv();
	if(len args == 1)
		dir = hd args;
	else
		dir = "/mnt/wiki";

	if(chdir(dir) < 0) {
		fprint(stderr, "chdir(%s) fails: %r\n", dir);
		exit;
	}
	(n, d) := stat("1");
	if(n < 0){
		fprint(stderr, "stat(%s/1) failes: %r\n", dir);
		exit;
	}
	s := d.name + "/";
	wikiopen(s, nil);
}

wikiname(w: ref Win, name: string)
{
	p := dir + "/" + name;
	for(i:=0;i<len p;i++)
		if(p[i]==' ')
			p[i]='_';
	w.wname(p);
}

Wiki.put(w: self ref Wiki): int
{
	fd: ref Sys->FD;
	n: int;
	buf : string;
	p: string;
	b: ref Iobuf;

	if((fd = open("new", ORDWR)) == nil){
		fprint(stderr, "Wiki: cannot open raw: %r\n");
		return -1;
	}

	w.win.openbody(OREAD);
	b = w.win.body;
	if((p = b.gets('\n')) == nil){
		fprint(stderr, "Wiki: no data\n");
		return -1;
	}
	fprint(fd, "%s", p);

	buf = sprint("D%ud\n", w.time);
	if(email != nil)
		buf += sprint("A%s\n", email);
	if(b.getc() == '#'){
		p = b.gets('\n');
		if(p == nil){
			fprint(stderr, "Wiki: no data\n");
			return -1;
		}
		buf += "C" + p + "\n";
	}
	fprint(fd, "%s\n\n", buf);

	bb := array[1024] of byte;
	while((n = b.read(bb, len bb)) > 0)
		write(fd, bb, n);

	werrstr("");
	if((n = write(fd, array[1] of byte, 0)) < 0){
		fprint(stderr, "Wiki commit %ud %d %d: %r\n", w.time, 0, n);
		return -1;
	}
	seek(fd, big 0, Sys->SEEKSTART);
	if((n = read(fd, bb, 300)) < 0){
		fprint(stderr, "Wiki readback: %r\n");
		return -1;
	}
	buf=string bb[0:n] + "/";
	w.arg = buf;
	w.isnew = 0;
	w.get();
	wikiname(w.win, w.arg);
	return n;
}

Wiki.get(w: self ref Wiki)
{
	fprint(w.win.ctl, "dirty\n");

	p := w.arg;
	normal := 1;
	if(p[len p - 1] == '/'){
		normal = 0;
		p += "current";
	}else if(len p > 8 && p[len p - 8:] == "/current") {
		normal = 0;
		w.arg = w.arg[:len w.arg - 7];
	}

	bin := bufio->open(p, Sys->OREAD);
	if(bin == nil){
		fprint(stderr, "Wiki: cannot read \"%s\": %r\n", p);
		w.win.wclean();
		return;
	}

	w.win.openbody(OWRITE);
	
	title := "";
	if(!normal){
		if((title = bin.gets('\n')) == nil){
			fprint(stderr, "Wiki: cannot read title for \"%s\": %r\n", p);
			w.win.wclean();
			return;
		}
		title = title[:len title -1];
	}
	if(w.win.data == nil)
		w.win.data = w.win.openfile("data");
	w.win.wsetaddr(",", 0);
	write(w.win.data, array[1] of byte, 0);

	if(!normal)
		w.win.body.puts(title + "\n\n");
	while((p = bin.gets('\n')) != nil){
		p = p[:len p - 1];
		if(normal)
			w.win.body.puts(p + "\n");
		else{
			if(len p > 0 && p[0] == 'D')
				(w.time, nil) = str->toint(p[1:], 10);
			else if(len p > 0 && p[0] == '#')
				w.win.body.puts(p[1:] + "\n");
		}
	}
	w.win.wclean();
}

Wiki.diff(w: self ref Wiki): int
{
	(p, nil) := str->splitl(w.arg, "/");

	nw := ref blankwiki;
	nw.arg = p + "/+Diff";
	nw.win = Win.wnew();
	nw.special = 1;
	nw.cevent = chan of Event;

	wikiname(nw.win, nw.arg);
	spawn diffproc(nw, p);
	return 1;
}

diffproc(w: ref Wiki, arg: string)
{
	pctl(NEWPGRP, nil);
	spawn w.win.wslave(w.cevent);
	spawn execdiff(w, arg);
	spawn wikithread(w);
}

execdiff(w: ref Wiki, s: string)
{
	pctl(FORKFD, nil);
	fd := open("/dev/null", OREAD);
	dup(fd.fd, 0);
	fd = open(sprint("/mnt/acme/%d/body", w.win.winid), OWRITE);
	dup(fd.fd, 1);
	dup(fd.fd, 2);
	fd = nil;
	pctl(NEWFD, 0 :: 1 :: 2 :: nil);
	sh->system(nil, "/acme/wiki/wiki.diff '" + s + "'");
}

staticn := 0;
wikinew(arg: string)
{
	w := ref blankwiki;
	w.arg = arg;
	w.win = Win.wnew();
	w.isnew = ++staticn;
	w.cevent = chan of Event;
	w.time = 0;
	spawn windowproc(w);
}

wikithread(w: ref Wiki)
{
	if(w.isnew){
		t := sprint("+new+%d", w.isnew);
		wikiname(w.win, t);
		if(w.arg != nil){
			w.win.openbody(OWRITE);
			w.win.body.puts(w.arg + "\n\n");
		}
		w.win.wclean();
	}else if(!w.special){
		w.get();
		wikiname(w.win, w.arg);
		if(w.addr != nil)
			w.win.wselect(w.addr);
	}
	w.win.wtagwrite("Get Put History Diff New");

	while(!w.dead){
		e :=<-w.cevent;
		acmeevent(w,  ref e);
	}

	w.win.wdormant();
	postnote(PNGROUP, pctl(0, nil), "kill");
	exit;
}

link(w: ref Wiki)
{
	for(l := wlist; l != nil; l = tl l)
		if((hd l).arg == w.arg)
			return;
	wlist = w :: wlist;
}

unlink(w: ref Wiki)
{
	nl: list of ref Wiki;
	for(l := wlist; l != nil; l = tl l)
		if((hd l).arg != w.arg)
			nl = hd l :: nl;
	wlist = nl;
}

iscmd(s, cmd: string): int
{
#	sys->print("iscmd: %s == %s %d\n", s, cmd, str->prefix(cmd, s));
	return  str->prefix(cmd, s);
}

skip(s, cmd: string): string
{
	s = s[len cmd:];
	while(s != nil && (s[0] == ' ' || s[0] == '\t' || s[0] == '\n'))
		s = s[1:];
	return s;
}

wikiload(w: ref Wiki, arg: string): int
{
	path, addr: string;
	rv: int;

	if(arg == nil)
		return 0;
	if(arg[0] == '/')
		path = arg;
	else{
		(p, nil) := str->splitr(w.arg, "/");
		if(p != nil && p[len p - 1] == '/')
			p += arg;
		else
			p = arg;
		path = names->cleanname(p);
	}
	(nil, addr) = str->splitl(path, ":");
	if(addr != nil)
		addr = addr[1:];
	rv = wikiopen(path, addr)==0;
	if(rv)
		return 1;
	return wikiopen(arg, nil)==0;
}

wikicmd(w: ref Wiki, s: string): int
{
	s = skip(s, "");

	if(iscmd(s, "Del")){
# if the del succedes then we may not get any further 
# because the event proc may error out and kill the process group.
# so we must unlink here.
		unlink(w);
		if(w.win.wdel(0))  
			w.dead = 1;
		return 1;
	}
	if(iscmd(s, "New")){
		wikinew(skip(s, "New"));
		return 1;
	}
	if(iscmd(s, "History"))
		return wikiload(w, "history.txt");
	if(iscmd(s, "Diff"))
		return w.diff();
	if(iscmd(s, "Get")){
		if(w.dirtied){
			w.dirtied = 0;
			fprint(stderr, "%s/%s modified\n", dir, w.arg);
		}else
			w.get();
		return 1;
	}
	if(iscmd(s, "Put")){
		(nil, q) := str->splitl(w.arg, "/");
		if(q != nil && len q > 1)
			fprint(stderr, "%s/%s is read-only\n", dir, w.arg);
		else
			w.put();
		return 1;
	}
	return 0;
}

acmeevent(wiki: ref Wiki, e: ref Event)
{
	e2, ea, etoss, eq : ref Event;
	na: int;
	s: string;
	e2 = newevent();
	ea = newevent();
	etoss = newevent();
	w := wiki.win;
	case(e.c1) {
	* =>
		fprint(stderr, "unknown message %c%c\n", e.c1, e.c2);
	'F' =>
		;
	'E' or 'K' =>
		if(e.c2 == 'I' || e.c2 == 'D')
			wiki.dirtied = 1;
	'M' =>
		case e.c2 {
		'x' or 'X' =>
			eq = e;
			if(e.flag & 2){
				*e2 =<- wiki.cevent;
				eq = e2;
			}
			if(e.flag & 8){
				*ea =<- wiki.cevent; 
				na = ea.nb;
				*etoss =<- wiki.cevent; 
			}else
				na = 0;

			if(eq.q1>eq.q0 && eq.nb==0)
				s = w.wread(eq.q0, eq.q1);
			else
				s = string eq.b[0:eq.nb];
			if(na)
				s +=  " " + string ea.b[0:ea.nb];
			#sys->print("exec: %s\n", s);
			if(!wikicmd(wiki, s))
				w.wwriteevent(e);
			s = nil;
			break;
		'l' or 'L' =>	# mouse only 			XXX cf wiki.c
			eq = e;
			if(e.flag & 2){
				*e2 =<- wiki.cevent;
				eq = expand(w, e, e2);
			}
			s = string eq.b[:eq.nb];
			if(eq.q1>eq.q0 && eq.nb == 0)
				s = w.wread(eq.q0, eq.q1);

			if(!wikiload(wiki, s))
				w.wwriteevent(e);
			break;
		'I' or 'D' =>
			wiki.dirtied = 1;
			break;
		'd' or 'i' =>
			break;
		* =>
			fprint(stderr, "unknown message %c%c\n", e.c1, e.c2);
			break;
		}
	}
}

blankwiki : Wiki;

wikiopen(arg, addr: string): int
{
	w: ref Wiki;

	for(i:=0;i<len arg; i++)
		if(arg[i]=='\n')
			arg[i]=' ';
	
	if(names->isprefix(dir, arg))
		arg = arg[len dir+1:];
	else if(arg[0] == '/')
		return -1;

	(n, d) := stat(arg);
	if(n < 0)
		return -1;

	if((d.mode & DMDIR) && arg[len arg-1] != '/'){
		arg += "/";
	}else if(!(d.mode & DMDIR) && arg[len arg-1]=='/'){
		arg=arg[:len arg-1];
	}

	if(len arg > 8 && arg[len arg - 8:] == "/current")
		arg = arg[0:len arg - 8 + 1];

	for(l:=wlist; l != nil; l=tl l){
		if((hd l).arg == arg){
			(hd l).win.ctlwrite("show\n");
			return 0;
		}
	}

	w = ref blankwiki;
	w.arg = arg;
	w.addr = addr;
	w.win = Win.wnew();
	link(w);
	w.cevent = chan of Event;
	spawn windowproc(w);
	return 0;
}

windowproc(w: ref Wiki)
{
	pctl(NEWPGRP, nil);
	spawn w.win.wslave(w.cevent);
	spawn wikithread(w);

}

eval(w: ref Win,  s: string): int
{
	buf := array[64] of byte;
	if(w.wsetaddr(s, 1) == 0)
		return -1;
	if(pread(w.addr, buf, 24, big 0) != 24)
		return -1;
	(n, nil) := str->toint(string buf[:24], 10);
	return n;
}

getdot(w: ref Win): (int, int, int)
{
	buf := array[24] of byte;

	w.ctlwrite("addr=dot\n");
	if(pread(w.addr, buf, 24, big 0) != 24)
		return (-1, 0, 0);
	(n, nil) := str->toint(string buf[:12], 10);
	(m, nil) := str->toint(string buf[12:], 10);
	if(debug)
		sys->print("getdot: %d %d from %s \n", n, m, string buf);
	return (0, n, m);
}

expand(w: ref Win, e: ref Event, eacme: ref Event): ref Event
{
	(n, q0, q1) := getdot(w);
	if(n == 0 && q0 <= e.q0 && e.q0 <= q1){
		e.q0 = q0;
		e.q1 = q1;
		return e;
	}

	q0 = eval(w, sprint("#%ud-/\\[/", e.q0));
	if(q0 < 0)
		return eacme;
	if(eval(w, sprint("#%ud+/\\]/", q0)) < e.q0)
		return eacme;
	q1 = eval(w, sprint("#%ud+/\\]/", e.q1));
	if(q1 < 0)
		return eacme;
	if((x := eval(w, sprint("#%ud-/\\[/", q1))) == -1 || x > e.q1)
		return eacme;
	e.q0 = q0+1;
	e.q1 = q1;
	return e;
}

newevent() : ref Event
{
	e := ref Event;
	e.b = array[Acmewin->EVENTSIZE*UTFmax+1] of byte;
	e.r = array[Acmewin->EVENTSIZE+1] of int;
	return e;
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

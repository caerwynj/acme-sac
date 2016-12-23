implement Chat;

include "sys.m";
	sys: Sys;
	open, print, sprint, fprint, dup, fildes, pread, pctl,
	OREAD, OWRITE: import sys;
include "draw.m";
include "arg.m";
	arg: Arg;
include "bufio.m";
include "acmewin.m";
	win: Acmewin;
	Win, Event: import win;
include "string.m";
	str: String;

Chat: module {
	init: fn(ctxt: ref Draw->Context, args: list of string);
};

chattyacme: int;
debug := 0;
servicedir: string;
ircwin: ref Win;
stderr: ref Sys->FD;
msgsfd : ref Sys->FD;
usage()
{
	fprint(fildes(2), "usage: Chat  file\n");
	exit;
}

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	pctl(Sys->NEWPGRP, nil);
	stderr = fildes(2);
	win = load Acmewin Acmewin->PATH;
	win->init();

	str = load String String->PATH;
	arg = load Arg Arg->PATH;
	arg->init(args);
	while((c := arg->opt()) != 0)
	case c {
	'A'  => chattyacme = 1;
	'D' => debug = 1;
	}
	args = arg->argv();
	if(len args != 1)
		usage();
	servicedir = hd args;
	ircwin = w := Win.wnew();
	w.wname("/Chat" );
	w.openbody(Sys->OWRITE);

	mainwin(w);
}

postnote(t : int, pid : int, note : string) : int
{
	fd := open("#p/" + string pid + "/ctl", OWRITE);
	if (fd == nil)
		return -1;
	if (t == 1)
		note += "grp";
	fprint(fd, "%s", note);
	fd = nil;
	return 0;
}


doexec(w: ref Win, cmd: string): int
{
	cmd = skip(cmd, "");
	arg: string;
	(cmd, arg) = str->splitl(cmd, " \t\r\n");
	if(arg != nil)
		arg = skip(arg, "");
	(arg, nil) = str->splitl(arg, " \t\r\n");
	case cmd {
	"Del" or "Delete" =>
		return -1;
	"Scroll" =>
		w.ctlwrite("scroll");
	"Noscroll" =>
		w.ctlwrite("noscroll");
	* =>
		return 0;
	}
	return 1;
}

skip(s, cmd: string): string
{
	s = s[len cmd:];
	while(s != nil && (s[0] == ' ' || s[0] == '\t' || s[0] == '\n'))
		s = s[1:];
	return s;
}

mainwin(w: ref Win)
{
	c := chan of Event;
	na: int;
	ea: Event;
	lastc2: int;
	hostpt := 2;

	msgs := chan of string;
	conn := chan of (string, ref Sys->FD);
	spawn connect(servicedir, msgs, conn);

	w.wwritebody("\n\n");
	w.ctlwrite("clean");
	spawn w.wslave(c);
	loop: for(;;) alt {
	(e, fd) := <-conn =>
		if (msgsfd == nil) {
			if (e == nil)
				msgsfd = fd;
			else
				fprint(stderr, "*** %s\n",  e);
		} else
			msgsfd = nil;

	txt := <-msgs =>
		hostpt = fixhostpt(w, hostpt);
		addr := sprint("#%ud", hostpt -2);
		if(!w.wsetaddr(addr, 1)){
			fprint(stderr, "bad address from fixhostpt %s\n", addr);
			addr = "$";
		}
		if(txt[len txt - 1] != '\n')
			txt[len txt] = '\n';
		w.wreplace(addr, sprint("%s", txt));
		w.wsetaddr("$", 1);
		(nil, nil, hostpt) = readaddr(w);
		if(debug)
			fprint(stderr, "new hostpt %d\n", hostpt);
		w.wselect("$");
	e := <-c =>
		if(chattyacme )
			fprint(stderr, "event %c hostpt %ud\n", e.c1, hostpt);
		case e.c1 {
		'M' or 'K'  =>
			case e.c2 {
			'I' =>
				if(e.q0 < hostpt)
					hostpt += e.q1-e.q0;
				else
					hostpt = domsg(w, hostpt);
			'D' =>
				if(e.q0 < hostpt){
					if(hostpt < e.q1)
						hostpt = e.q0;
					else
						hostpt -= e.q1 - e.q0;
				}
			'x' or 'X' =>
				s: string;
				eq := e;
				if(e.flag & 2)
					eq =<- c;
				if(e.flag & 8){
					ea =<- c; 
					na = ea.nb;
					<- c; #toss
				}else
					na = 0;
	
				if(eq.q1>eq.q0 && eq.nb==0)
					s = w.wread(eq.q0, eq.q1);
				else
					s = string eq.b[0:eq.nb];
				if(na)
					s +=  " " + string ea.b[0:ea.nb];
				#sys->print("chatwinexec: %s\n", s);
				n := doexec(w, s);
				if(n == 0)
					w.wwriteevent(ref e);
				else if (n < 0)
					break loop;
			'l' or 'L' =>
				w.wwriteevent(ref e);
			}
		}
		lastc2 = e.c2;
	}
	postnote(1, pctl(0, nil), "kill");
	w.wdel(1);
	exit;
}

fixhostpt(w: ref Win, hostpt: int): int
{
	dofix := 0;
	buf := "?";
	if(hostpt == 0){
		dofix = 1;
	}else if(hostpt == 1){
		buf = w.wread(0,1);
		if(len buf == 0 || buf[0] != '\n')
			dofix = 1;
	}else if (hostpt > 1){
		buf = w.wread(hostpt - 2, hostpt);
		if(len buf != 2 
		|| buf[0] != '\n'
		|| buf[1] != '\n')
			dofix = 1;
	}
	if(!dofix)
		return hostpt;

	w.wreplace(sprint("#%ud,#%ud", hostpt, hostpt), "\n");
	hostpt++;
	return hostpt;
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
	

doline(w: ref Win, line: string, q0, q1:int): int
{
#	if(line != nil && line[len line - 1] == '\n')
#		line=line[:len line - 1];
	if(len line > 0){
		d := array of byte line;
		sys->write(msgsfd, d, len d);
		w.wreplace(sprint("#%ud,#%ud", q0, q1), "");
		w.wsetaddr("$", 1);
		(nil, q0, q1) = readaddr(w);
	}
	return q1;
}

domsg(w: ref Win, hostpt: int): int
{
	if(debug)
		fprint(stderr, "domsg: hostpt  %d\n", hostpt);
	hostpt = fixhostpt(w, hostpt);
	if(w.wsetaddr(sprint("#%ud", hostpt), 1) == 0){
		w.wsetaddr("$+#0", 1);
		(nil, q0, nil) := readaddr(w);
		return q0;
	}
	if(w.wsetaddr(sprint("#%ud", hostpt), 1) && w.wsetaddr("/\\n/", 1)){
		(nil, nil, q) := readaddr(w);
		if(q <= hostpt) { #wrapped
		#	fprint(stderr, "wrapped\n");
			return hostpt;
		}
		line := w.wread(hostpt, q);
		if(debug)
			fprint(stderr, "domsg: %s\n", line);
		hostpt = doline(w, line, hostpt, q);
	}else
		fprint(stderr, "bad hostpt in domsg\n");
	return hostpt;
}

readaddr(w: ref Win): (int, int, int)
{
	buf := array[24] of byte;
	if(pread(w.addr, buf, 24, big 0) <=0)
		return (-1, 0, 0);
	(n, nil) := str->toint(string buf[:12], 10);
	(m, nil) := str->toint(string buf[12:], 10);
	return (0, n, m);
}

connect(dir: string, msgs: chan of string, conn: chan of (string, ref Sys->FD))
{
	srvpath := dir+"/msgs";
	fd := sys->open(srvpath, Sys->ORDWR);
	if(fd == nil) {
		conn <-= (sys->sprint("internal error: can't open %s: %r", srvpath), nil);
		return;
	}
	conn <-= (nil, fd);
	buf := array[Sys->ATOMICIO] of byte;
	while((n := sys->read(fd, buf, len buf)) > 0)
		msgs <-= string buf[0:n];
	conn <-= (nil, nil);
}

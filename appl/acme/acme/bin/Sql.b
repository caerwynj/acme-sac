implement Sql;

include "sys.m";
	sys: Sys;
	open, print, sprint, fprint, dup, fildes, pread, pctl, read, write,
	OREAD, OWRITE: import sys;
include "draw.m";
include "arg.m";
	arg: Arg;
include "bufio.m";
	bufio: Bufio;
include "acmewin.m";
	win: Acmewin;
	Win, Event: import win;
include "string.m";
	str: String;

Sql: module {
	init: fn(ctxt: ref Draw->Context, args: list of string);
};

debug := 0;
servername: string;
passwd: string;
fullname: string;
stderr: ref Sys->FD;

ctlfd, datafd: ref Sys->FD;
conn: string;				# connection number
sql: chan of string;

sqlwin, resultwin: ref Win;

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	win = load Acmewin Acmewin->PATH;
	win->init();
	str = load String String->PATH;
	stderr = fildes(2);
	bufio = load Bufio Bufio->PATH;
	arg = load Arg Arg->PATH;
	arg->init(args);
	while((c := arg->opt()) != 0)
	case c {
	'D' => debug = 1;
	'u' => fullname = arg->earg();
	's' => servername = arg->earg();
	'p' => passwd = arg->earg();
	}
	args = arg->argv();
	
	if(logon(servername, fullname, passwd) < 0){
		sys->fprint(stderr, "couldn't logon\n");
		exit;
	}
	sql = chan of string;
	sqlwin = w := Win.wnew();
	w.wname("/usr/" + getuser() + "/sql/" + fullname + "/" + servername + "/guide");
	w.wtagwrite("Run");
	w.ctlwrite("get\n");
	w.openbody(OWRITE);
	spawn mainwin(w);
}

newoutwin()
{
	sys->pctl(Sys->NEWPGRP, nil);
	w := resultwin = Win.wnew();
	w.wname("/usr/" + getuser() + "/sql/" + fullname + "/" + servername + "/+Errors");
	w.wtagwrite("More");
	w.openbody(OWRITE);
	spawn outwin(w);
}


logon(server, user, passwd: string): int
{
	ctlfd = open("/n/odbc/db/new", Sys->ORDWR);
	if(ctlfd == nil)
		return -1;
	buf := array[128] of byte;
	n := read(ctlfd, buf, len buf);
	conn = string buf[:n];
	ctlwrite("float ,<");
	ctlwrite("headings");
	n = ctlwrite("connect " + server + " " + user + "!" + passwd);
	if(n < 0){
		sys->fprint(stderr, "error connecting\n");
		return -1;
	}
	return 0;
}

ctlwrite(s: string): int
{
	if(ctlfd == nil)
		return -1;
	n := write(ctlfd, array of byte s, len array of byte s);
	if(n < 0){
		sys->fprint(stderr, "error writing to ctl: %r\n");
	}
	return n;
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
	case cmd {
	"Run" =>
		if(resultwin == nil)
			spawn newoutwin();
		s := readdot(w);
		sql <-= s;
	"More" =>
		more(w);
	"Del" or "Delete" =>
		return -1;
	"Scroll" =>
		w.ctlwrite("scroll\n");
	"Noscroll" =>
		w.ctlwrite("noscroll\n");
	"Heading" =>
		ctlwrite("headings");
	"Noheading" =>
		ctlwrite("noheadings");
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
	s: string;

	spawn w.wslave(c);
	loop: for(;;){
		e := <- c;
		if(e.c1 != 'M')
			continue;
		case e.c2 {
		'x' or 'X' =>
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
			#sys->print("exec: %s\n", s);
			n := doexec(w, s);
			if(n == 0)
				w.wwriteevent(ref e);
			else if(n < 0)
				break loop;
		'l' or 'L' =>
			w.wwriteevent(ref e);
		}
	}
	postnote(1, pctl(0, nil), "kill");
	w.wdel(1);
	# XXX kill all
	exit;
}

outwin(w: ref Win)
{
	c := chan of Event;
	na: int;
	ea: Event;
	s: string;

	spawn w.wslave(c);
	loop: for(;;) alt {
	sq := <- sql =>
		runsql(w, sq);
	e := <- c =>
		if(e.c1 != 'M')
			continue;
		case e.c2 {
		'x' or 'X' =>
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
			#sys->print("exec: %s\n", s);
			n := doexec(w, s);
			if(n == 0)
				w.wwriteevent(ref e);
			else if(n < 0)
				break loop;
		'l' or 'L' =>
			w.wwriteevent(ref e);
		}
	}
	resultwin = nil;
	postnote(1, pctl(0, nil), "kill");
	w.wdel(1);
	exit;
}
 
# open in own window use  Next to add data to end of file and scroll to make visible

runsql(w: ref Win, arg: string)
{
	if(datafd == nil)
		datafd= open("/n/odbc/db/" + conn + "/data", OREAD);
	fd := open("/n/odbc/db/" + conn + "/cmd", OWRITE);
	if(fd == nil){
		sys->fprint(stderr, "error opening cmd\n");
		return;
	}
	if(arg == nil)
		return;
#	sys->fprint(stderr, "sql: %s\n", arg);
	err := write(fd, array of byte arg, len array of byte arg);
	if(err <= 0){
		sys->fprint(stderr, "error writing cmd: %r\n");
		return;
	}
	if(datafd != nil)
		sys->seek(datafd, big 0, 0);
	w.wreplace(",", "");
	more(w);
}

more(w: ref Win)
{
	if(datafd == nil)
		datafd= open("/n/odbc/db/" + conn + "/data", OREAD);
	if(datafd == nil){
		sys->fprint(stderr, "error opening data\n");
		return;
	}
	buf := array[8192] of byte;
	for (i := 0; i < 1024; i++){
		n := read(datafd, buf, len buf);
		if(n <= 0)
			return;
		w.wwritebody(string buf[0:n]);
	}
}

readdot(w: ref Win): string
{
	(e, m, n) := getdot(w);
	if(e == -1)
		return nil;
	return w.wread(m, n);
}

getdot(w: ref Win): (int, int, int)
{
	buf := array[24] of byte;

	w.ctlwrite("addr=dot\n");
	if(w.addr == nil)
		w.addr = w.openfile("addr");
	if(pread(w.addr, buf, 24, big 0) != 24)
		return (-1, 0, 0);
	(n, nil) := str->toint(string buf[:12], 10);
	(m, nil) := str->toint(string buf[12:], 10);
	if(debug)
		sys->print("getdot: %d %d from %s \n", n, m, string buf);
	return (0, n, m);
}
	
getuser(): string
{
	fd := sys->open("/dev/user", sys->OREAD);
	if(fd == nil){
		sys->fprint(stderr, "Sql: cannot open /dev/user: %r\n");
		raise "fail:no user id";
	}

	buf := array[50] of byte;
	n := sys->read(fd, buf, len buf);
	if(n < 0){
		sys->fprint(stderr, "Sql: cannot read /dev/user: %r\n");
		raise "fail:no user id";
	}

	return string buf[0:n];	
}

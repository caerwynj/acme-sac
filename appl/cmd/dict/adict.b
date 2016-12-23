implement Adict;

include "sys.m";
	sys: Sys;
	open, print, sprint, fprint, dup, fildes, pread, pctl, read, write,
	OREAD, OWRITE: import sys;
include "draw.m";
include "arg.m";
	arg: Arg;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "acmewin.m";
	win: Acmewin;
	Win, Event: import win;
include "string.m";
	str: String;
include "sh.m";
	sh: Sh;

Adict: module {
	init: fn(ctxt: ref Draw->Context, args: list of string);
};

Matchwin, Entrywin, Dictwin: con iota;
MAXTAG: con 20;
MAXMATCH: con 100;
BUFSIZE: con  4096;

True : con 1;
stderr: ref Sys->FD;
debug := 0;
prog: con "adict";
lprog: con "adict";
xprog: con "dict";
dict, pattern, curone, buffer: string;
curaddr:= array[MAXMATCH] of string;
Mwin, Ewin, Dwin: ref Win;
Mopen, Eopen, curindex, count: int;

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	win = load Acmewin Acmewin->PATH;
	win->init();
	str = load String String->PATH;
	sh = load Sh Sh->PATH;
	
	stderr = fildes(2);
	bufio = load Bufio Bufio->PATH;
	arg = load Arg Arg->PATH;
	arg->init(args);
	while((c := arg->opt()) != 0)
		case c {
		'D' => debug = 1;
		'd' => dict = arg->arg();
		}
	args = arg->argv();
	if(len args == 1){
		pattern = hd args;
		if(dict == nil)
			dict = "pgw";
	}
	if((dict == nil) && (pattern == nil))
		openwin(prog, "", Dictwin);
	if(pattern == nil)
		openwin(prog, "", Entrywin);
	if((count = getaddr(pattern)) <= 1)
		openwin(prog, "Prev Next", Entrywin);
	else
		openwin(prog, "", Matchwin);
}

procrexec(xprog: list of string): ref Sys->FD
{
	p := array[2] of ref Sys->FD;

	if(sys->pipe(p) < 0)
		return nil;
	sync := chan of int;
#	xprog  = "/dis/sh" :: "-n" :: "-c" :: l2s(xprog) :: nil;
	spawn exec(sync, hd xprog, xprog, (array[2] of ref Sys->FD)[0:] = p);
	<-sync;
	p[1] = nil;
	return p[0];
}

procpexec(argl: list of string)
{
	file := hd argl;
	if(len file<4 || file[len file-4:]!=".dis")
		file += ".dis";

	c := load Command file;
	if(c == nil) {
		err := sprint("%r");
		if(file[0]!='/' && file[0:2]!="./"){
			c = load Command "/dis/"+file;
			if(c == nil)
				err = sprint("%r");
		}
		if(c == nil){
			sys->fprint(stderr, "%s: %s\n", file, err);
			return;
		}
	}
	c->init(nil, argl);
}

l2s(l: list of string): string
{
	s := "";
	for(; l != nil; l = tl l)
		s += " " + hd l;
#	print("%s\n", s);
	return  s;
}

getaddr(pattern: string): int
{
	if(pattern == nil || pattern == ""){
		curone = nil;
		curindex = 0;
		curaddr[curindex] = nil;
		return 0;
	}
	
	buffer = sprint("/%s/A", pattern);
	fd := procrexec(xprog :: "-d" :: dict :: "-c" :: buffer :: nil);
	inbuf := bufio->fopen(fd, Bufio->OREAD);
	i := 0;
	curindex = 0;
	while((bufptr := inbuf.gets('\n')) != nil && (i < (MAXMATCH-1))) {
		(bufptr, nil) = str->splitl(bufptr, "\n");
		obuf := bufptr;
		(nil, bufptr) = str->splitl(bufptr, "#");
		if(len bufptr == 0)
			print("whoops buf «%s»\n", obuf);
		curaddr[i] = bufptr;
		i++;
	}
	curaddr[i] = nil;
	if(i == MAXMATCH)
		fprint(stderr, "Too many matches!\n");
	
	curone = curaddr[curindex];
	return i;
}

getpattern(addr: string): string
{
	res := "";
	pbuffer := array[80] of byte;
	buffer = sprint("%sh", addr);
	fd := procrexec(xprog :: "-d" :: dict :: "-c" :: buffer :: nil);
	if((n := read(fd, pbuffer, 80)) > 80)
		fprint(stderr, "Error in getting address from dict.\n");
	else {
		res = str->take(string pbuffer[:n], "^ \t\n");
	}
	return res;	
}

chgaddr(dir: int): string
{
	# Increment or decrement the current address (curone). 

	res := "";
	abuffer := array[80] of byte;
	if(dir < 0)
		buffer = sprint("%s-a", curone);
	else
		buffer = sprint("%s+a", curone);
	fd := procrexec(xprog :: "-d" :: dict :: "-c" :: buffer :: nil);
	if (read(fd, abuffer, 80) > 80)
		fprint(stderr, "Error in getting address from dict.\n");
	else {
		res = string abuffer;
		(nil, res) = str->splitl(res, "#");
		(res, nil) = str->splitl(res, "\n");
	}
	return res;
}

dispdicts(cwin: ref Win)
{
	buf := array[1024] of byte;
	t : array of byte;
	i: int;
	fd := procrexec(xprog :: "-d" :: "?" :: nil);
	cwin.wreplace("0,$", "");
	while((nb := read(fd, buf, 1024)) > 0){
		t = buf;
		i = 0;
		if("Usage" == string buf[:5]) {
			while(int t[0] != '\n') {
				t = t[1:]; 
				i++;
			}
			t = t[1:];
			i++;
		}
		cwin.body.write(t, nb-i);
	}
	cwin.wclean();
}

dispentry(cwin: ref Win)
{
	buf := array[BUFSIZE] of byte;
	if(curone == nil){
		if(pattern != nil){
			cwin.wwritebody("Pattern not found.\n");
			cwin.wclean();
		}
		return;
	}
	buffer = sprint("%sp", curone);
	fd := procrexec(xprog :: "-d" :: dict :: "-c" :: buffer :: nil);
	cwin.wreplace("0,$", "");
	while((nb := read(fd, buf, BUFSIZE)) > 0) {
		cwin.body.write(buf, nb);
	}
	cwin.wclean();
}

dispmatches(cwin: ref Win)
{
	buf := array[BUFSIZE] of byte;
	buffer = sprint("/%s/H", pattern);
	fd := procrexec(xprog :: "-d" :: dict :: "-c" :: buffer :: nil);
	cwin.wreplace("0,$", "");
	while((nb := read(fd, buf, BUFSIZE)) > 0) {
		cwin.body.write(buf, nb);
	}
	cwin.wclean();
}

format(s: string): string
{
	for(i := 0; i < len s; i++)
		if(!(((s[i] >= 'a') && (s[i] <= 'z')) ||
			((s[i] >= 'A') && (s[i] <= 'Z')) ||
			((s[i] >= '0') && (s[i] <= '9'))))
				s[i] = '_';
	return s;
}

openwin(name, buttons:string, wintype: int)
{
	buf: string;
	
	pctl(Sys->NEWPGRP, nil);
	w := Win.wnew();
	if(wintype == Dictwin)
		buf = sprint("%s", name);
	else if((wintype == Entrywin) && (count > 1))
		buf = sprint("%s/%s/%s/%d", name, dict, format(pattern), curindex+1);	
	else
		buf = sprint("%s/%s/%s", name, dict, format(pattern));
	w.wname(buf);
	w.wtagwrite(buttons);
	w.wclean();
	w.openbody(Bufio->OWRITE);
	if(wintype == Dictwin)
		dispdicts(w);
	if(wintype == Matchwin){
		Mopen = True;
		dispmatches(w);
	}
	if(wintype == Entrywin){
		Eopen = True;
		dispentry(w);
		Ewin = w;
	}
	handle(w, wintype);
}

exec(sync: chan of int, cmd : string, argl : list of string, out: array of ref Sys->FD)
{
	file := cmd;
	if(len file<4 || file[len file-4:]!=".dis")
		file += ".dis";

	sys->pctl(Sys->FORKFD, nil);
	sys->dup(out[1].fd, 1);
	out[0] = nil;
	out[1] = nil;
	sync <-= sys->pctl(Sys->NEWFD, 0 :: 1 :: 2 :: nil);
	c := load Command file;
	if(c == nil) {
		err := sprint("%r");
		if(file[0]!='/' && file[0:2]!="./"){
			c = load Command "/dis/"+file;
			if(c == nil)
				err = sprint("%r");
		}
		if(c == nil){
			# debug(sprint("file %s not found\n", file));
			sys->fprint(sys->fildes(2), "%s: %s\n", cmd, err);
			return;
		}
	}
	c->init(nil, argl);
}

command(w: ref Win, cmd: string, nil: int): int
{
	cmd = skip(cmd, "");
	arg: string;
	(cmd, arg) = str->splitl(cmd, " \t\r\n");
	if(arg != nil)
		arg = skip(arg, "");
	case cmd {
	"Del" or "Delete" =>
		return -1;
	"Next" =>
		if(curone != nil){
			curone = chgaddr(1);
			buf := getpattern(curone);
			buffer = sprint("%s/%s/%s", prog, dict, format(buf));
			w.wname(buffer);
			dispentry(w);
		}
	"Prev" =>
		if(curone != nil){
			curone = chgaddr(-1);
			buf := getpattern(curone);
			buffer = sprint("%s/%s/%s", prog, dict, format(buf));
			w.wname(buffer);
			dispentry(w);
		}
	"Nmatch" =>
		if(curaddr[++curindex] == nil)
			curindex = 0;
		curone = curaddr[curindex];
		if(curone != nil){
			buffer = sprint("%s/%s/%s/%d", prog, dict, format(pattern), curindex+1);
			w.wname(buffer);
			dispentry(w);
		}
	* =>
		return 0;
	}
	return 1;
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

skip(s, cmd: string): string
{
	s = s[len cmd:];
	while(s != nil && (s[0] == ' ' || s[0] == '\t' || s[0] == '\n'))
		s = s[1:];
	return s;
}

handle(w: ref Win, wintype: int)
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
			n := command(w, s, wintype);
			if(n == 0)
				w.wwriteevent(ref e);
			else if(n < 0)
				break loop;
		'l' or 'L' =>
			if(e.flag & 2)
				e =<- c;
			w.wclean();
			if(wintype == Dictwin)
				spawn procpexec(lprog :: "-d" :: string e.b[:e.nb] :: nil);
			if(wintype == Entrywin)
				spawn procpexec(lprog :: "-d" :: dict :: string e.b[:e.nb] :: nil);
			if(wintype == Matchwin){
				tmp := str->toint(string e.b[:e.nb], 10).t0;
				if((tmp >= 0) && (tmp < MAXMATCH) && (curaddr[tmp] != nil)){
					curindex = tmp;
					curone = curaddr[curindex];
					if(Eopen){
						buf := sprint("%s/%s/%s/%d", prog, dict, format(pattern), curindex+1);
						Ewin.wname(buf);
						dispentry(Ewin);
					}else
						spawn openwin(prog, "Nmatch Prev Next", Entrywin);
				}
			}
		}
	}
	postnote(1, pctl(0, nil), "kill");
	w.wdel(1);
	# XXX kill all
	exit;
}

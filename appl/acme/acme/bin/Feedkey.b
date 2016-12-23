implement Feedkey;

include "sys.m";
	sys: Sys;
	open, print, sprint, fprint, dup, fildes, pread, pctl, read, write,
	OREAD, OWRITE: import sys;
include "draw.m";
include "bufio.m";
include "acmewin.m";
	win: Acmewin;
	Win, Event: import win;
include "string.m";
	str: String;

Feedkey: module {
	init: fn(ctxt: ref Draw->Context, args: list of string);
};

stderr: ref Sys->FD;
keyfd: ref Sys->FD;
pwd: string;
Debug := 0;

needs: chan of list of ref Attr;
acks: chan of int;

init(nil: ref Draw->Context, nil: list of string)
{
	sys = load Sys Sys->PATH;
	win = load Acmewin Acmewin->PATH;
	win->init();
	str = load String String->PATH;
	stderr = fildes(2);
	
	needfile := "/mnt/factotum/needkey";
	if(Debug)
		needfile = "/dev/null";

	needs = chan of list of ref Attr;
	acks = chan of int;

	sys->pctl(Sys->NEWPGRP|Sys->NEWFD, list of {0, 1, 2});

	fd := sys->open(needfile, Sys->ORDWR);
	if(fd == nil)
		err(sys->sprint("can't open %s: %r", needfile));
	spawn needy(fd, needs, acks);
	fd = nil;

	ctlfile := "/mnt/factotum/ctl";
	keyfd = sys->open(ctlfile, Sys->ORDWR);
	if(keyfd == nil)
		err(sys->sprint("can't open %s: %r", ctlfile));

	
#	w := Win.wnew();
#	w.wname("Needkey");
#	spawn mainwin(w);
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

doexec(nil: ref Win, cmd: string): int
{
	cmd = skip(cmd, "");
	arg: string;
	(cmd, arg) = str->splitl(cmd, " \t\r\n");
	if(arg != nil)
		arg = skip(arg, "");
	case cmd {
	"Del" or "Delete" =>
		return -1;
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

newmainwin(title: string)
{
	sys->pctl(Sys->NEWPGRP, nil);
	w := Win.wnew();
	w.wname("Needkey");
	w.wtagwrite(title);
	spawn mainwin(w);
}

mainwin(w: ref Win)
{
	c := chan of Event;
	na: int;
	ea: Event;
	s: string;
	attrs: list of ref Attr;
	prompt: string;

	spawn w.wslave(c);
	loop: for(;;){
#		sys->sleep(1000);
		s = w.wreadall();
		lens := len s;
		lenp := len prompt;
		if (lens >= (lenp + 1) && s[0:lenp] == prompt && s[lens-1] == '\n') {
			pwd = s[lenp:lens-1];
			if(pwd == "" && len prompt > 4 && prompt[:4] == "user")
				pwd = getuser();
#			w.wreplace(",", "");
			for (i := 0; i < lens; i++)
				s[i] = '\b';
			w.wwritebody(s);
			acks <-= 0;
#			break;
		}
		alt {
		attrs = <-needs =>
			if(attrs == nil)
				break loop;
			a := hd attrs;
			if(a.name == "user")
				prompt = a.name + " [" + getuser() + "]:";
			else
				prompt = a.name + ":";
			w.ctlwrite("echo\n");
			w.wwritebody(prompt);
			w.wclean();
			w.wselect("$");
			if(prompt[0] == '!')
				w.ctlwrite("noecho\n");
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
	}
	postnote(1, pctl(0, nil), "kill");
	w.wdel(1);
	exit;
}

reverse[T](l: list of T): list of T
{
	rl: list of T;
	for(; l != nil; l = tl l)
		rl = hd l :: rl;
	return rl;
}

needy(fd: ref Sys->FD, needs: chan of list of ref Attr, acks: chan of int)
{
	if(Debug){
		for(;;){
			sys->sleep(1000);
			attrs := parseline("proto=pass user? server=fred.com service=ftp confirm !password?");
			spawn newmainwin(attrtext(attrs));
			for(al := attrs; al != nil; al = tl al){
				a := hd al;
				case a.tag {
				Aquery =>
					needs <-= a :: nil;
					<-acks;
					a.val = pwd;
					a.tag = Aval;
				}
			}
			needs <-= nil;
			sys->print("%s\n", attrtext(attrs));
		}
	}

	buf := array[512] of byte;
	while((n := sys->read(fd, buf, len buf)) > 0){
		s := string buf[0:n];
		for(i := 0; i < len s; i++)
			if(s[i] == ' ')
				break;
		if(i >= len s)
			continue;
		attrs := parseline(s[i+1:]);
		nl: list of ref Attr;
		tag: ref Attr;
		for(; attrs != nil; attrs = tl attrs){
			a := hd attrs;
			if(a.name == "tag")
				tag = a;
			else
				nl = a :: nl;
		}
		if(nl == nil)
			continue;
		attrs = nl;
		if(attrs != nil && tag != nil && tag.val != nil){
			spawn newmainwin(attrtext(attrs));
			for(al := attrs; al != nil; al = tl al){
				a := hd al;
				case a.tag {
				Aquery =>
					if(a.name != nil){
						needs <-= a :: nil;
						<-acks;
						a.val = pwd;
						a.tag = Aval;
					}
				}
			}
			needs <-= nil;
			if(sys->fprint(keyfd, "key %s", attrtext(attrs)) < 0)
				sys->fprint(sys->fildes(2), "feedkey: can't install key %q: %r\n", attrtext(attrs));
			sys->fprint(fd, "tag=%d", int tag.val);
		}
	}
	if(n < 0)
		sys->fprint(sys->fildes(2), "feedkey: error reading needkey: %r\n");
	needs <-= nil;
}

# need a library module

Aattr, Aval, Aquery: con iota;

Attr: adt {
	tag:	int;
	name:	string;
	val:	string;

	text:	fn(a: self ref Attr): string;
};

parseline(s: string): list of ref Attr
{
	fld := str->unquoted(s);
	rfld := fld;
	for(fld = nil; rfld != nil; rfld = tl rfld)
		fld = (hd rfld) :: fld;
	attrs: list of ref Attr;
	for(; fld != nil; fld = tl fld){
		n := hd fld;
		a := "";
		tag := Aattr;
		for(i:=0; i<len n; i++)
			if(n[i] == '='){
				a = n[i+1:];
				n = n[0:i];
				tag = Aval;
			}
		if(len n == 0)
			continue;
		if(tag == Aattr && len n > 1 && n[len n-1] == '?'){
			tag = Aquery;
			n = n[0:len n-1];
		}
		attrs = ref Attr(tag, n, a) :: attrs;
	}
	return attrs;
}

Attr.text(a: self ref Attr): string
{
	case a.tag {
	Aattr =>
		return a.name;
	Aval =>
		return sys->sprint("%q=%q", a.name, a.val);
	Aquery =>
		return a.name+"?";
	* =>
		return "??";
	}
}

attrtext(attrs: list of ref Attr): string
{
	s := "";
	sp := 0;
	for(; attrs != nil; attrs = tl attrs){
		if(sp)
			s[len s] = ' ';
		sp = 1;
		s += (hd attrs).text();
	}
	return s;
}

err(s: string)
{
	sys->fprint(sys->fildes(2), "feedkey: %s\n", s);
	raise "fail:error";
}

getuser(): string
{
	fd := sys->open("/dev/user", sys->OREAD);
	if(fd == nil){
		sys->fprint(stderr, "Feedkey: cannot open /dev/user: %r\n");
		return nil;
	}

	buf := array[50] of byte;
	n := sys->read(fd, buf, len buf);
	if(n < 0){
		sys->fprint(stderr, "Feedkey: cannot read /dev/user: %r\n");
		return nil;
	}
	return string buf[0:n];	
}

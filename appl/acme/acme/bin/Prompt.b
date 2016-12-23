implement Prompt;

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

Prompt: module {
	init: fn(ctxt: ref Draw->Context, args: list of string);
};

stderr: ref Sys->FD;
pwd: string;

init(nil: ref Draw->Context, nil: list of string)
{
	sys = load Sys Sys->PATH;
	win = load Acmewin Acmewin->PATH;
	win->init();
	str = load String String->PATH;
	stderr = fildes(2);
	
	w := Win.wnew();
	w.wname("Prompt");
	w.wwritebody("Password:");
	w.wclean();
	w.wselect("$");
	w.ctlwrite("noecho\n");
	spawn mainwin(w);
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

mainwin(w: ref Win)
{
	c := chan of Event;
	na: int;
	ea: Event;
	s: string;

	spawn w.wslave(c);
	loop: for(;;){
		sys->sleep(1000);
		s = w.wreadall();
		lens := len s;
		if (lens >= 10 && s[0:9] == "Password:" && s[lens-1] == '\n') {
			pwd = s[9:lens-1];
			for (i := 0; i < lens; i++)
				s[i] = '\b';
			w.wwritebody(s);
			break;
		}
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
	sys->print("%s", pwd);
	postnote(1, pctl(0, nil), "kill");
	w.wdel(1);
	exit;
}

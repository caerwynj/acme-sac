implement Navigator;

include "sys.m";
	sys: Sys;
	open, print, sprint, fprint, dup, fildes, pread, pctl, read, write,
	OREAD, OWRITE: import sys;
include "draw.m";
	draw: Draw;
	Font: import draw;
include "bufio.m";
include "acmewin.m";
	win: Acmewin;
	Win, Event: import win;
include "string.m";
	str: String;
include "readdir.m";
	readdir: Readdir;
include "names.m";
	names: Names;
include	"plumbmsg.m";
	plumbmsg: Plumbmsg;
	Msg: import plumbmsg;

Navigator: module {
	init: fn(ctxt: ref Draw->Context, args: list of string);
};

stderr: ref Sys->FD;
cwd: string;
plumbed := 0;
ctxt: ref Draw->Context;

font: ref Font;
width := 65;
tabwid := 8;
mintab := 1;

Dirlist : adt {
	r : string;
	wid : int;
};

init(ct: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	draw = load Draw Draw->PATH;
	win = load Acmewin Acmewin->PATH;
	win->init();
	str = load String String->PATH;
	stderr = fildes(2);
	readdir = load Readdir Readdir->PATH;
	names = load Names Names->PATH;
	plumbmsg = load Plumbmsg Plumbmsg->PATH;
	if(plumbmsg->init(1, nil, 0) >= 0){
		plumbed = 1;
	}
	ctxt = ct;
	args = tl args;
	if (len args != 0)
		cwd = names->cleanname(hd args);
	else
		cwd = "/";
	w := Win.wnew();
	w.wname("/+Navigator");
	w.wtagwrite("Get Pin");
	w.wclean();
	getwidth(w);
	dolook(w, cwd);
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

doexec(w: ref Win, cmd: string): int
{
	cmd = skip(cmd, "");
	arg: string;
	(cmd, arg) = str->splitl(cmd, " \t\r\n");
	if(arg != nil)
		arg = skip(arg, "");
	case cmd {
	"Del" or "Delete" =>
		return -1;
	"Pin" =>
		if(plumbed){
			msg := ref Msg("Navigator", "", 
			cwd, "text", "click=1",
			array of byte sprint("%s", cwd));
			if(msg.send() < 0)
				fprint(sys->fildes(2), "Navigator: plumbing write error: %r\n");
		}
		return 1;
	"Get" =>
		return dolook(w, ".");
	* =>
		return 0;
	}
	return 1;
}

dolook(w: ref Win, file: string): int
{
	file = names->cleanname(names->rooted(cwd, file));
	fd := sys->open(file, Sys->OREAD);
	if(fd == nil){
		sys->fprint(stderr, "can't open %s: %r\n", file);
		return 1;
	}
	(nil, d) := sys->fstat(fd);
	if(d.qid.qtype & Sys->QTDIR){
		cwd = file;
		(a, n) := readdir->readall(fd, Readdir->NAME);
		if(file == "/")
			w.wname(file + "+Navigator");
		else
			w.wname(file + "/+Navigator");
		w.wreplace(",", "");
		
		dlp := array[16] of ref Dirlist;
		ndl := 0;
		dl := ref Dirlist;
		dl.r = "..";
		dl.wid = font.width(dl.r);
		dlp[ndl++] = dl;
		for(i := 0; i < n; i++){
			s := "";
			if(a[i].qid.qtype & Sys->QTDIR)
				s = "/";
			dl = ref Dirlist;
			dl.r = sprint("%s%s", a[i].name, s);
			dl.wid = font.width(dl.r);
			if(ndl >= len dlp)
				dlp = (array[len dlp * 2] of ref Dirlist)[0:] = dlp[:];
			dlp[ndl++] = dl;
		}
		columnate(w, dlp, ndl);
		w.ctlwrite("dump Navigator " + cwd + "\n");
		w.wclean();
	}else{
		return 0;
	}
	return 1;
}

getwidth(w: ref Win)
{
	if(ctxt == nil || draw == nil)
		return;
	if((fd := open(sprint("/mnt/acme/%d/ctl", w.winid), Sys->ORDWR)) == nil){
		sys->fprint(sys->fildes(2), "Navigator: couldn't open /dev/acme/ctl %r\n");
		return;
	}
	buf := array[256] of byte;
	if((n := read(fd, buf, len buf)) <= 0){
		sys->fprint(sys->fildes(2), "Navigator: couldn't read /dev/acme/ctl %r\n");
		return;
	}
	(nf, f) := sys->tokenize(string buf[:n], " ");
	if(nf != 8){
		sys->fprint(sys->fildes(2), "Navigator: bad fields \n");
		return;
	}
	f0 := tl tl tl tl tl f;
	if((font = Font.open(ctxt.display, hd tl f0)) == nil){
		sys->fprint(sys->fildes(2), "Navigator: bad font \n");
		return;
	}
	tabwid = int hd tl tl f0;
	mintab = font.width("0");	
	width = int hd f0;
	# sys->print("width %d tabwid %d mintab %d\n", width, tabwid, mintab);
	return;
}

max(x : int, y : int) : int
{
	if (x > y)
		return x;
	return y;
}

min(x : int, y : int) : int
{
	if (x < y)
		return x;
	return y;
}

columnate(win: ref Win, dlp : array of ref Dirlist, ndl : int)
{
	i, j, w, colw, mint, maxt, ncol, nrow: int;
	dl : ref Dirlist;

	getwidth(win);
	(maxt, mint) = (tabwid, mintab);
	# mint = charwidth(t.frame.font, '0');
	# go for narrower tabs if set more than 3 wide
	# t.frame.maxtab = min(dat->maxtab, TABDIR)*mint;
	# maxt = t.frame.maxtab;
	# maxt = min(tabwid, 3)*mint;
	colw = 0;
	for(i=0; i<ndl; i++){
		dl = dlp[i];
		w = dl.wid;
		if(maxt-w%maxt<mint || w%maxt==0)
			w += mint;
		if(w % maxt)
			w += maxt-(w%maxt);
		if(w > colw)
			colw = w;
	}
	if(colw == 0)
		ncol = 1;
	else
		ncol = max(1, width/colw);
	nrow = (ndl+ncol-1)/ncol;

	for(i=0; i<nrow; i++){
		for(j=i; j<ndl; j+=nrow){
			dl = dlp[j];
			win.wwritebody(dl.r);
			if(j+nrow >= ndl)
				break;
			w = dl.wid;
			if(maxt-w%maxt < mint){
				win.wwritebody("\t");
				w += mint;
			}
			do{
				win.wwritebody("\t");
				w += maxt-(w%maxt);
			}while(w < colw);
		}
		win.wwritebody("\n");
	}
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
			eq := e;
			if(e.flag & 2)
				eq =<-c;
			s = string eq.b[0:eq.nb];
			if(eq.q1>eq.q0 && eq.nb==0)
				s = w.wread(eq.q0, eq.q1);
			n := dolook(w, s);
			if(n == 0)
				w.wwriteevent(ref e);
		}
	}
	postnote(1, pctl(0, nil), "kill");
	w.wdel(1);
	exit;
}

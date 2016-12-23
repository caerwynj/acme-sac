implement Ctag;

include "sys.m";
	sys: Sys;
	open, print, sprint, fprint, dup, fildes, pread, pctl, read, write,
	OREAD, OWRITE: import sys;
include "draw.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
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
include "regex.m";
	regex: Regex;
	Re: import regex;

Ctag: module {
	init: fn(ctxt: ref Draw->Context, args: list of string);
};

Symbol: adt {
	name: string;
	file: string;
	addr: string;
	kind: string;
};

Obj: adt {
	name: string;
	syms: list of ref Symbol;
};

Srcfile: adt {
	name: string;
	objs: list of ref Obj;
};

classes: list of ref Obj;
srcfiles: list of ref Srcfile;
allsyms: array of ref  Symbol;
nsyms := 0;

curfiles: list of ref Srcfile;
cursyms: list of ref Symbol;

tagsfile: string;

stderr: ref Sys->FD;
cwd: string;
plumbed := 0;

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
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
	regex = load Regex Regex->PATH;
	
	args = tl args;
	if(len args != 0)
		tagsfile = hd args;
	
	in: ref Iobuf;
	allsyms = array[1024] of ref Symbol;
	if(tagsfile != nil)
		in = bufio->open(tagsfile, Bufio->OREAD);
	else
		in = bufio->fopen(sys->fildes(0), Bufio->OREAD);
	cwd = names->dirname(tagsfile);
	while ((s := in.gets('\n')) != nil){
		if(s[len s - 1] == '\n')
			s = s[:len s - 1];
		if(s[len s - 1] == '\r')
			s = s[:len s - 1];
		parseline(s);
	}
	w := Win.wnew();
	w.wname(names->cleanname(cwd + "/+Ctag"));
	w.wtagwrite("Get File Tag ");
	w.wclean();
	spawn mainwin(w);
}

writesrcfile(w: ref Win, sf: ref Srcfile)
{
	for(l := sf.objs; l != nil; l = tl l){
		w.wwritebody(sprint("%s\n", (hd l).name));
		for(k := reverse((hd l).syms); k != nil; k = tl k){
			sym := hd k;
			suffix := "";
			if(sym.kind == "m")
				suffix = "()";
			w.wwritebody(sprint("\t%s%s\n", sym.name, suffix));
		}
		w.wwritebody("\n");
	}
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
	"File" =>
		w.wreplace(",", "");
		(re, err) := regex->compile(arg,0);
		if(re == nil) {
			sys->fprint(stderr, "Ctag: %s\n", err);
			return 1;
		}
		curfiles = nil;
		cursyms = nil;
		for(l := srcfiles; l != nil; l = tl l){
			sf := hd l;
			# sys->print("%s\n", sf.name);
			if(regex->executese(re, sf.name, (0, len sf.name-1), 1, 1) != nil){
				writesrcfile(w, sf);
				curfiles = sf :: curfiles;
			}
		}
	"Tag" =>
		n := bsearch(arg);
		if(cursyms == nil)
			w.wreplace(",", "");
		curfiles = nil;
		while(n < nsyms){
			nn := acomp(arg, allsyms[n].name);
			case nn {
			-1 or 0 =>
				w.wwritebody(sprint("%s\n", allsyms[n].file));				
				w.wwritebody(sys->sprint("\t%s   %s\n\n", allsyms[n].name, allsyms[n].kind));
				cursyms = allsyms[n] :: cursyms;
			-2 or 1 or 2 =>
				break;
			}
			n++;
		}
		return 1;
	* =>
		return 0;
	}
	return 1;
}

dolook(w: ref Win, pat: string): int
{
	buf := array[128] of byte;
	obj := "";
	if(w.data == nil)
		w.data = w.openfile("data");
	#sys->print("pat: %s\n", pat);
	if(pat[0] == '/')
		return 0;
	ok := w.wsetaddr("-/^[a-zA-Z0-9]/", 0);
	if(ok == 1) {
		nb := sys->read(w.data, buf, len buf);
		s := string buf[:nb];
		for(i := 0; i < len s; i++)
			if(s[i] == '\n')
				break;
		obj = s[:i];
		#sys->print("obj: %s\n", obj);
	}
	if(cursyms != nil){
		for(l := cursyms; l != nil; l = tl l){
			o := hd l;
			if(o.file == obj && o.name == pat){
				highlight(names->cleanname(names->rooted(cwd, o.file)), o.addr);
				return 1;
			}
		}
	}
	for(l := curfiles; l != nil; l = tl l){
		for(m := (hd l).objs; m != nil; m = tl m){
			if(obj != "" && (hd m).name != obj)
				continue;
			for (n := (hd m).syms; n != nil; n = tl n){
				o := hd n;
				if(o.name == pat){
					highlight(names->cleanname(names->rooted(cwd, o.file)), o.addr);
					return 1;
				}
			}
		}
	}
	return 0;
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
			w.wsetaddr("#" + string eq.q0, 0);
			n := dolook(w, s);
			if(n == 0)
				w.wwriteevent(ref e);
		}
	}
	postnote(1, pctl(0, nil), "kill");
	w.wdel(1);
	exit;
}

parseline(s: string)
{
	sym, file, re, cmd, typ, rest: string;
	(sym, rest) = nextok(s);
	(file, rest) = nextok(rest);
	(re, rest) = nextok(rest);
	(cmd, rest) = nextok(rest);
	(typ, rest) = nextok(rest);
	
	file = fixfilename(file);
	symbol := ref Symbol(sym, file, fixpattern(re), cmd);
	if(typ != nil){
		f := looksrc(file);
		o := look(f, typ);
		o.syms = symbol :: o.syms;
	}else{
		f := looksrc(file);
		o := look(f, file);
		o.syms = symbol :: o.syms;
	}
	if(nsyms > (len allsyms - 1))
		allsyms = (array[len allsyms * 2] of ref Symbol)[0:] = allsyms[:];
	allsyms[nsyms++] = symbol;
#	sys->print("%s, %s\n", sym, typ);
}

look(sf: ref Srcfile, name: string): ref Obj
{
	for(l := sf.objs; l != nil; l = tl l){
		if((hd l).name == name)
			return hd l;
	}
	o := ref Obj(name, nil);
	sf.objs = o :: sf.objs;
	return o;
}

looksrc(name: string): ref Srcfile
{
	for(l := srcfiles; l != nil; l = tl l){
		if((hd l).name == name)
			return hd l;
	}
	o := ref Srcfile(name, nil);
	srcfiles = o :: srcfiles;
	return o;
}

reverse(l: list of ref Symbol): list of ref Symbol
{
	nl : list of ref Symbol;
	for(; l != nil; l = tl l)
		nl = hd l :: nl;
	return nl;
}

nextok(s: string): (string, string)
{
	inregexp := 0;
	if(len s == 0)
		return (nil, "");
	if(s[0] == '/')
		inregexp = 1;
		
	for(i := 1; i < len s; i++){
		if(s[i] == '/' && s[i-1] != '\\')
			inregexp = 0;
		if(s[i] == '\t' && !inregexp)
			break;
	}
	if( i == len s)
		return (s[:i], nil);
	else
		return (s[:i], s[i+1:]);
}

fixfilename(s: string): string
{
	for(i:=0;i< len s; i++)
		if(s[i] == '\\')
			s[i] = '/';
	return names->cleanname(s);
}

fixpattern(s: string): string
{
	if(len s == 0)
		return "";
	r := "";
	k := 0;
	for(i:=0;i< len s; i++){
		if(s[i] == '(' || s[i] == '.' || s[i] == '*' || s[i] == ')' || s[i] == '[' 
			|| s[i] == ']')
			r[k++] = '\\';
		r[k++] = s[i];
	}
	if(len r > 2)
		r = r[:len r - 2];  # remove ;"
	return r;
}

findwin(f: string): int
{
	io := bufio->open("/mnt/acme/index", Sys->OREAD);
	if(io == nil){
		fprint(sys->fildes(2), "couldn't open acme/index\n");
		return 0;
	}
	while((s := io.gets('\n')) != nil){
		fwin := int s[0:11];
		(p, q) := str->splitl(s[60:], " ");
		if(len p >= len f && f == p[0:len f])
			return fwin;
		(p, q) = str->splitr(p, "/");
		if(len q >= len f && f == q[0:len f])
			return fwin;
	}
	return 0;
}

highlight(f: string, addr: string): int
{
	if(f == "")
		return 0;
	fwin := findwin(f);
	if(fwin == 0){
		if(plumbed){
			msg := ref Msg("Ctag", "", 
			cwd, "text", "click=1",
			array of byte sprint("%s", f));
			if(msg.send() < 0)
				fprint(sys->fildes(2), "deb: plumbing write error: %r\n");
		}
		sys->sleep(1000);
		fwin = findwin(f);
		if(fwin == 0)
			return 0;
	}
	afd := open(sprint("/mnt/acme/%d/addr", fwin), Sys->OWRITE);
	cfd := open(sprint("/mnt/acme/%d/ctl", fwin), Sys->OWRITE);
	if(afd == nil || cfd == nil)
		return 0;
	fprint(afd, "%s", addr);
	fprint(cfd, "dot=addr");
	fprint(cfd, "show");
	return 1;
}

bsearch(name: string): int
{
	bot := 0;
	mid := 0;
	n := 0;
	top := nsyms;
	for(;;){
		mid = (top+bot)/2;
		n = acomp(name, allsyms[mid].name);
		if(n < 0)
			top = mid - 1;
		else if (n > 0)
			bot = mid + 1;
		if(n == 0){  # duplicate keys, step backwards.
			while(n == 0 && mid >= 0)
				n = acomp(name, allsyms[mid--].name);
			mid++;
			break;
		}
		if(bot > top)
			break;
	}
	return mid;
}

#
#	acomp(s, t) returns:
#		-2 if s strictly precedes t
#		-1 if s is a prefix of t
#		0 if s is the same as t
#		1 if t is a prefix of s
#		2 if t strictly precedes s
#  fix fax 	= 2
#  fix fi 	= 1
#  fix fix 	= 0
#  fix fixx = -1
#  fix fox 	= -2

acomp(s, t: string): int
{
	if(s == t)
		return 0;
	l := len s;
	if(l > len t)
		l = len t;
	cs, ct: int;
	for(i := 0; i < l; i++) {
		cs = s[i];
		ct = t[i];
		if(cs != ct)
			break;
	}
	if(i == len s)
		return -1;
	if(i == len t)
		return 1;
	if(cs < ct)
		return -2;
	return 2;
}

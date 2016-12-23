implement Adeb;

include "sys.m";
	sys: Sys;
	open, read, write, stat, fildes, print, sprint, fprint, pctl, OWRITE: import sys;
include "draw.m";

include "string.m";
	str: String;
include "arg.m";
	arg: Arg;
include "readdir.m";
	readdir: Readdir;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "acmewin.m";
	acmewin: Acmewin;
	Win, Event: import acmewin;
include "debug.m";
	debug: Debug;
	Prog, Exp, Module, Src, Sym: import debug;
include "dis.m";
	dism: Dis;
include	"plumbmsg.m";
	plumbmsg: Plumbmsg;
	Msg: import plumbmsg;
include "workdir.m";
	workdir: Workdir;

Diss: module {};

Adeb: module {
	init: fn(ctxt: ref Draw->Context, args: list of string);
};

Bpt: adt
{
	id:	int;
	m:	ref Mod;
	pc:	int;
};

Recv, Send, Alt, Running, Stopped, Exited, Broken, Killing, Killed: con iota;
status := array[] of
{
	Running =>	"Running",
	Recv =>		"Receive",
	Send =>		"Send",
	Alt =>		"Alt",
	Stopped =>	"Stopped",
	Exited =>	"Exited",
	Broken =>	"Broken",
	Killing =>	"Killed",
	Killed =>	"Killed",
};

KidGrab, KidStep, KidStmt, KidOver, KidOut, KidKill, KidRun: con iota;
WinGet: con iota;
Kid: adt
{
	state:	int;
	prog:	ref Prog;
	watch:	int;		# pid of watching prog
	run:	int;		# pid of stepping prog
	pickup:	int;		# picking up this kid?
	cmd:	chan of int;
#	stack:	ref Vars;
	w:		ref Win;
	wcmd: chan of int;
};

Options: adt
{
	dis:	string;		# .dis path
	args:	list of string;	# cmd + argument for starting a kid
	dir:	string;		# . for kid
	nrun:	int;		# run new kids?
	xkill:	int;		# kill kids on exit?
};

Mod: adt
{
	src:	string;		# .b path
	dis:	string;		# .dis path
	sym:	ref Sym;	# debugger symbol table
};

kids:		list of ref Kid;
kid:		ref Kid;
kidctxt:	ref Draw->Context;
kidack:		chan of (ref Kid, string);
kidevent:	chan of (ref Kid, string);
bpts:		list of ref Bpt;
bptid:=		1;
opts:		ref Options;
dbpid:		int;
stderr: ref Sys->FD;
plumbed := 0;

badmodule(p: string)
{
	sys->fprint(sys->fildes(2), "deb: cannot load %s: %r\n", p);
	raise "fail:bad module";
}

init(ctxt: ref Draw->Context, nil: list of string)
{
	sys = load Sys Sys->PATH;
	str = load String String->PATH;
	arg = load Arg Arg->PATH;
	bufio = load Bufio Bufio->PATH;
	readdir = load Readdir Readdir->PATH;
	debug = load Debug Debug->PATH;
	debug->init();
	dism = load Dis Dis->PATH;
	dism->init();
	kidctxt = ctxt;
	sys->pctl(Sys->NEWPGRP, nil);
	plumbmsg = load Plumbmsg Plumbmsg->PATH;
	if(plumbmsg->init(1, nil, 0) >= 0){
		plumbed = 1;
		workdir = load Workdir Workdir->PATH;
	}
	acmewin = load Acmewin Acmewin->PATH;
	acmewin->init();
	opts = ref Options;
	opts.nrun = 0;
	opts.xkill = 1;
	opts.dir = ".";
	kids = nil;
	kid = nil;
	kidack = chan of (ref Kid, string);
	kidevent = chan of (ref Kid, string);
	stderr = fildes(2);
	w := Win.wnew();
	w.wname("/task/manager");
	w.openbody(Sys->OWRITE);
	w.wtagwrite("Get Debug ");
	spawn debugevent();
	addpickprogs(w);
	mainwin(w);
}

attach(pid: int)
{
	k := pickup(pid);
	if(k == nil)
		return;
	if(k.w == nil)
		newwin(k);
}

newwin(k: ref Kid)
{
	sys->pctl(Sys->NEWPGRP, nil);
	w := Win.wnew();
	w.openbody(Sys->OWRITE);
	w.wtagwrite("Get Stmt Over Out Stop Cont Detach Break ");
	w.ctlwrite("scroll");
	k.w = w;
	kidstate(k);
	spawn debugwin(w, k);
}

doexec(w: ref Win, k: ref Kid, cmd: string): int
{
	cmd = skip(cmd, "");
	arg: string;
	(cmd, arg) = str->splitl(cmd, " ");
	if(arg != nil)
		arg = arg[1:];
	case cmd {
	"Break" =>
		if(arg == nil){
			seebpt(w);
			return 1;
		}
		setbpt(arg);
	"Debug" =>
		if(arg == nil)
			return 1;
		q := str->unquoted(arg);
		spawn spawnkid(q);
	"Step" =>
		step(k, KidStep);
	"Stmt" =>
		step(k, KidStmt);
	"Over" =>
		step(k, KidOver);
	"Out" =>
		step(k, KidOut);
	"Cont" =>
		step(k, KidRun);
	"Stop" =>
		if(k != nil)
			k.prog.stop();
	"Killall" =>
		killkids();
	"Detach" =>
		detachkid(k);
		return -1;
	"Get" =>
		if(k == nil)
			addpickprogs(w);
		else {
			w.wreplace(",", "");
			refresh(k, 1);
		}
		return 1;
	"Del" or "Delete" =>
		if(k != nil)
			killkid(k);
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

	w.ctlwrite("clean");
	spawn w.wslave(c);
	loop: for(;;){
		alt {
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
				n := doexec(w, nil, s);
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
				nopen := 0;
				do{
					(n, t) := strtoi(s);
					if(n>0 && (t == len s || s[t]==' ' || s[t]=='\t' || s[t]=='\n')){
						spawn attach(n);
						nopen++;
						s = s[t:];
					}
					while(s != nil && s[0]!='\n')
						s = s[1:];
				}while(s != nil);
				if(nopen == 0)	# send it back 
					w.wwriteevent(ref e);
			}
		}
	}
	w.wdel(1);
	postnote(1, pctl(0, nil), "kill");
	# XXX kill all
	# exit;
}

debugwin(w: ref Win, k: ref Kid)
{
	c := chan of Event;
	na: int;
	ea: Event;
	s: string;

	w.ctlwrite("clean");
	spawn w.wslave(c);
#	doexec(w, k, "Get");
	loop: for(;;){
		alt {
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
				n := doexec(w, k, s);
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
				# try and find sourcefile in current stack
				# if there highlight the line
				(p, q) := str->splitl(s, ":");
				if(q != nil)
					(q, nil) = str->splitl(q[1:], "^0-9");
				if(highlight(p, q))	# send it back 
					w.wwriteevent(ref e);
			}
		cmd := <- k.wcmd =>
			case cmd {
			WinGet =>
				refresh(k, 0);
			}
				
		}
	}
	w.wdel(1);
	postnote(1, pctl(0, nil), "kill");
	# XXX kill all
	# exit;
}

strtoi(s : string) : (int, int)
{
	m := 0;
	neg := 0;
	t := 0;
	ls := len s;
	while (t < ls && (s[t] == ' ' || s[t] == '\t'))
		t++;
	if (t < ls && s[t] == '+')
		t++;
	else if (t < ls && s[t] == '-') {
		neg = 1;
		t++;
	}
	while (t < ls && (s[t] >= '0' && s[t] <= '9')) {
		m = 10*m + s[t]-'0';
		t++;
	}
	if (neg)
		m = -m;
	return (m, t);	
}

debugevent()
{
	for(;;){
		alt {
		(k, s) := <-kidevent =>
			case s{
			"recv" =>
				if(k.state == Running)
					k.state = Recv;
			"send" =>
				if(k.state == Running)
					k.state = Send;
			"alt" =>
				if(k.state == Running)
					k.state = Alt;
			"run" =>
				if(k.state == Recv || k.state == Send || k.state == Alt)
					k.state = Running;
			"exited" =>
				k.state = Exited;
			"interrupted" or
			"killed" =>
				alert("Thread "+string k.prog.id+" "+s);
				k.state = Exited;
			* =>
				if(str->prefix("new ", s)){
					nk := newkid(int s[len "new ":]);
					if(opts.nrun)
						step(nk, KidRun);
					break;
				}
				if(str->prefix("load ", s)){
					s = s[len "load ":];
					if(s != nil && s[0] != '$')
						loaded(s);
					break;
				}
				if(str->prefix("child: ", s))
					s = s[len "child: ":];

				if(str->prefix("broken: ", s))
					k.state = Broken;
				alert("Thread "+string k.prog.id+" "+s);
			}
#			if(k.state != Running)
				k.wcmd <-= WinGet;
			k = nil;
		(k, s) := <-kidack =>
			if(k.state == Killing){
				k.state = Killed;
				k.cmd <-= KidKill;
				k = nil;
				break;
			}
			if(k.state == Killed){
				delkid(k);
				k = nil;
				break;
			}
			case s{
			"" or "child: breakpoint" or "child: stopped" =>
				k.state = Stopped;
				k.prog.unstop();
			"prog broken" =>
				k.state = Broken;
			* =>
				if(!str->prefix("child: ", s))
					alert("Debugger error "+status[k.state]+" "+string k.prog.id+" '"+s+"'");
			}
			k.wcmd <-= WinGet;
			if(k.pickup && opts.nrun){
				k.pickup = 0;
				if(k.state == Stopped)
					step(k, KidRun);
			}
			k = nil;
		}
	}
}


loaded(nil: string)
{

}

PNPROC, PNGROUP : con iota;

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

addpickprogs(w: ref Win): array of (int, int)
{
	s: string;
	(d, n) := readdir->init("/prog", Readdir->NONE);
	if(n <= 0)
		return nil;
	a := array[n] of { * => (-1, -1) };
	for(i := 0; i < n; i++){
		(p, nil) := debug->prog(int d[i].name);
		if(p == nil)
			continue;
		(grp, nil, st, code) := debug->p.status();
		if(grp < 0)
			continue;
		a[i] = (p.id, grp);
		s += sys->sprint("%4d\t%4d\t%8s\t%s\n", p.id, grp, st, code);
	}
#	print("%s\n", s);
	w.wreplace(",", s);
	w.wclean();
	return a;
}

step(k: ref Kid, cmd: int)
{
	if(k == nil){
		if(kids != nil){
			alert("No current thread");
			return;
		}
		return;
	}
	case k.state{
	Stopped =>
		k.cmd <-= cmd;
		k.state = Running;
		kidstate(k);
	Running or Send or Recv or Alt or Exited or Broken =>
		;
	* =>
		sys->print("bad debug step state %d\n", k.state);
	}
}

repsuff(name, old, new: string): string
{
	no := len old;
	nn := len name;
	if(nn >= no && name[nn-no:] == old)
		return name[:nn-no] + new;
	return name;
}

attachsym(m: ref Mod)
{
	if(m.sym != nil)
		return;
	sbl := repsuff(m.src, ".b", ".sbl");
	err : string;
	(m.sym, err) = debug->sym(sbl);
	if(m.sym != nil)
		return;
	alert(err);
}

getsel(s: string): (ref Mod, int)
{
	s = skip(s, "");
	(src, index) := str->splitl(s, ":");
	if(len index > 1)
		index = index[1:];
	m := ref Mod(src, nil, nil);
	attachsym(m);
	if(m.sym == nil){
		alert("No symbol file for "+m.src);
		return (nil, 0);
	}
	(sline, spos) := str->splitl(index, ".");
	line := int sline;
	pos := 0;
	if(len spos > 1)
		pos = int spos[1:];
	pc := m.sym.srctopc(ref Src((m.src, line, pos), (m.src, line, pos)));
	s1 := m.sym.pctosrc(pc);
	if(s1 == nil){
		alert("No pc is appropriate");
		return (nil, 0);
	}
	return (m, pc);
}

attachdis(m: ref Mod): int
{
	c := load Diss m.dis;
	if(c == nil){
		m.dis = repsuff(m.src, ".b", ".dis");
		c = load Diss m.dis;
	}
	if(c == nil && m.sym != nil){
		m.dis = repsuff(m.sym.path, ".sbl", ".dis");
		c = load Diss m.dis;
	}
	return c != nil;
}

setbpt(bs: string)
{
	(m, pc) := getsel(bs);
	if(m == nil)
		return;
	s := m.sym.pctosrc(pc);
	if(s == nil){
		alert("No pc is appropriate");
		return;
	}

	# if the breakpoint is already there, delete it
	for(bl := bpts; bl != nil; bl = tl bl){
		b := hd bl;
		if(b.m == m && b.pc == pc){
			bpts = delbpt(b, bpts);
			return;
		}
	}

	b := ref Bpt(bptid++, m, pc);
	bpts = b :: bpts;
	attachdis(m);
	for(kl := kids; kl != nil; kl = tl kl){
		k := hd kl;
		e := k.prog.setbpt(m.dis, pc);
		if(e != nil){
			alert(e);
		}
	}
}

seebpt(w: ref Win)
{
	for(bl := bpts; bl != nil; bl = tl bl){
		b := hd bl;
		s := b.m.sym.pctosrc(b.pc);
		w.wwritebody(sprint("%s:%d.%d\n", s.start.file, s.start.line, s.start.pos));
	}
}

delbpt(b: ref Bpt, bpts: list of ref Bpt): list of ref Bpt
{
	if(bpts == nil)
		return nil;
	hb := hd bpts;
	tb := tl bpts;
	if(b == hb){
		# remove from kids
		disablebpt(b);
		return tb;
	}
	return hb :: delbpt(b, tb);
}

disablebpt(b: ref Bpt)
{
	for(kl := kids; kl != nil; kl = tl kl){
		k := hd kl;
		k.prog.delbpt(b.m.dis, b.pc);
	}
}

delkid(k: ref Kid)
{
	kids = rdelkid(k, kids);
	if(kid == k){
		if(kids == nil){
			kid = nil;
			kidstate(k);
		}else{
			kid = hd kids;
		}
	}
}

rdelkid(k: ref Kid, kids: list of ref Kid): list of ref Kid
{
	if(kids == nil)
		return nil;
	hk := hd kids;
	t := tl kids;
	if(k == hk){
		# remove kid from display
#		k.stack.delete();
		return t;
	}
	return hk :: rdelkid(k, t);
}

killkids()
{
	for(kl := kids; kl != nil; kl = tl kl)
		killkid(hd kl);
}

killkid(k: ref Kid)
{
	if(k.watch >= 0){
		killpid(k.watch);
		k.watch = -1;
	}
	case k.state{
	Exited or Broken or Stopped =>
		k.cmd <-= KidKill;
		k.state = Killed;
	Running or Send or Recv or Alt or Killing =>
		k.prog.kill();
		k.state = Killing;
	* =>
		sys->print("unknown state %d in killkid\n", k.state);
	}
	k.w.wdel(1);
}

freekids(): int
{
	r := 0;
	for(kl := kids; kl != nil; kl = tl kl){
		k := hd kl;
		if(k.state == Exited || k.state == Killing || k.state == Killed){
			r ++;
			detachkid(k);
		}
	}
	return r;
}

detachkids()
{
	for(kl := kids; kl != nil; kl = tl kl)
		detachkid(hd kl);
}

detachkid(k: ref Kid)
{
	if(k == nil){
		alert("No current thread");
		return;
	}
	if(k.state == Exited){
		killkid(k);
		return;
	}

	# kill off the debugger progs
	killpid(k.watch);
	killpid(k.run);
	err := k.prog.start();
	if(err != "")
		alert("Detaching thread: "+err);

	delkid(k);
}

kidstate(k: ref Kid)
{
	if(k != nil){
		s := sys->sprint("/prog/%d/+%s", k.prog.id, status[k.state]);
		k.w.wname(s);
		k.w.wclean();
	}
}

verbose := 1;
refresh(k: ref Kid, domod: int)
{
	if(k.state == Killing || k.state == Killed){
		kidstate(k);
		return;
	}
	(s, err) := k.prog.stack();
	if(s == nil && err == "")
		err = "No stack";
	if(err != ""){
		k.w.wwritebody(err + "\n");
		kidstate(k);
		return;
	}
	for(i := 0; i < len s; i++){
		s[i].m.stdsym();
		err = s[i].findsym();
#		if(err != "")
#			alert(err);
		if(s[i].name != "unknown fn")
			k.w.wwritebody(sys->sprint("\nstackv -r 1 %d.%s.module\n", k.prog.id, s[i].name));
		k.w.wwritebody(s[i].name + "(");
		vs := s[i].expand();
		if(verbose && vs != nil){
			for(j := 0; j < len vs; j++){
				if(vs[j].name == "args"){
					d := vs[j].expand();
					ss := "";
					for(j = 0; j < len d; j++) {
						k.w.wwritebody(sys->sprint("%s%s=%s", ss, d[j].name, d[j].val().t0));
						ss = ", ";
					}
					break;
				}
			}
		}
		k.w.wwritebody(sys->sprint(") %s\n", s[i].srcstr()));
		if(verbose && vs != nil){
			for(j := 0; j < len vs; j++){
				if(vs[j].name == "locals" || (vs[j].name == "module" && domod)){
					d := vs[j].expand();
					for(j = 0; j < len d; j++)
						k.w.wwritebody("\t" + d[j].name + "=" + d[j].val().t0 + "\n");
					k.w.wwritebody("\n");
				}
			}
		}
		dis := s[i].m.dis();
		if(len dis > 0 && dis[0] == '$'){
			k.w.wwritebody(s[i].srcstr() + "\n");
		} else {
			sfile := dism->src(dis);
			src := s[i].src();
			# kid.w.wwritebody(sprint("%s:%d\n", sfile, src.start.line));
			if(src != nil && i == 0)
				highlight(sfile, string src.start.line);
		}
	}
	k.w.wwritebody("\n");
	kidstate(k);
}

pickup(pid: int): ref Kid
{
	for(kl := kids; kl != nil; kl = tl kl)
		if((hd kl).prog.id == pid)
			return hd kl;
	k := newkid(pid);
	if(k == nil)
		return nil;
	k.cmd <-= KidGrab;
	k.state = Running;
	k.pickup = 1;
	if(kid == nil){
		kid = k;
	}
	return k;
}


Enofd: con "no free file descriptors\n";

newkid(pid: int): ref Kid
{
	(p, err) := debug->prog(pid);
	if(err != ""){
		n := len err - len Enofd;
		if(n >= 0 && err[n: ] == Enofd && freekids()){
			(p, err) = debug->prog(pid);
			if(err == "")
				return mkkid(p);
		}
		alert("Can't pick up thread "+err);
		return nil;
	}
	return mkkid(p);
}

mkkid(p: ref Prog): ref Kid
{
	for(bl := bpts; bl != nil; bl = tl bl){
		b := hd bl;
		attachdis(b.m);
		p.setbpt(b.m.dis, b.pc);
	}
	k := ref Kid(Stopped, p, -1, -1, 0, chan of int, nil, chan of int);
	kids = k :: kids;
	c := chan of int;
	spawn kidslave(k, c);
	k.run = <- c;
	spawn kidwatch(k, c);
	k.watch = <-c;
	return k;
}

spawnkid(args: list of string)
{
	opts.args = args;
	opts.dis = dis(hd opts.args);
	(p, err) := debug->startprog(opts.dis, opts.dir, kidctxt, opts.args);
	if(err != nil){
		alert(opts.dis+" is not a debuggable Dis command module: "+err);
		return;
	}

	k :=  mkkid(p);
	newwin(k);
}

xlate := array[] of {
	KidStep => Debug->StepExp,
	KidStmt => Debug->StepStmt,
	KidOver => Debug->StepOver,
	KidOut => Debug->StepOut,
};

kidslave(k: ref Kid, me: chan of int)
{
	me <-= sys->pctl(0, nil);
	me = nil;
	for(;;){
		c := <-k.cmd;
		case c{
		KidGrab =>
			err := k.prog.grab();
			kidack <-= (k, err);
		KidStep or KidStmt or KidOver or KidOut =>
			err := k.prog.step(xlate[c]);
			kidack <-= (k, err);
		KidKill =>
			err := "kill "+k.prog.kill();
			k.prog.kill();			# kill again to slay blocked progs
			kidack <-= (k, err);
			exit;
		KidRun =>
			err := k.prog.cont();
			kidack <-= (k, err);
		* =>
			sys->print("kidslave: bad command %d\n", c);
			exit;
		}
	}
}

kidwatch(k: ref Kid, me: chan of int)
{
	me <-= sys->pctl(0, nil);
	me = nil;
	for(;;)
		kidevent <-= (k, k.prog.event());
}

killpid(pid: int)
{
	fd := sys->open("#p/"+string pid+"/ctl", sys->OWRITE);
	if(fd != nil)
		sys->fprint(fd, "kill");
}

alert(m: string)
{
	sys->fprint(sys->fildes(2), "%s\n", m);
}

findwin(f: string): int
{
	io := bufio->open("/mnt/acme/index", Sys->OREAD);
	if(io == nil){
		fprint(sys->fildes(2), "couldn't open acme/index\n");
		return 0;
	}
	while((s := io.gets('\n')) != nil){
		win := int s[0:11];
		(p, q) := str->splitl(s[60:], " ");
		if(len p >= len f && f == p[0:len f])
			return win;
		(p, q) = str->splitr(p, "/");
		if(len q >= len f && f == q[0:len f])
			return win;
	}
	return 0;
}

highlight(f: string, addr: string): int
{
	if(f == "")
		return 0;
	win := findwin(f);
	if(win == 0){
		if(plumbed){
			msg := ref Msg("Debug", "", 
			workdir->init(), "text", "click=1",
			array of byte sprint("%s:%s", f, addr));
			if(msg.send() < 0)
				fprint(sys->fildes(2), "deb: plumbing write error: %r\n");
		}
		return 0;
	}
	afd := open(sprint("/mnt/acme/%d/addr", win), Sys->OWRITE);
	cfd := open(sprint("/mnt/acme/%d/ctl", win), Sys->OWRITE);
	if(afd == nil || cfd == nil)
		return 0;
	fprint(afd, "%s", addr);
	fprint(cfd, "dot=addr");
	fprint(cfd, "show");
	return 1;
}

dis(s: string): string
{
	if (len s < 4 || s[len s - 4:] != ".dis")
		s += ".dis";
	if(stat(s).t0 == 0)
		return s;
	if(s[0] != '/' && s[0:2] != "./")
		s = "/dis/" + s;
	return s;
}

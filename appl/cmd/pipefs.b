implement pipefs;

include "sys.m";
	sys: Sys;
	FD: import sys;
include "draw.m";
include "styx.m";
	styx: Styx;
	Rmsg, Tmsg: import styx;
include "sh.m";
	sh: Sh;
include "arg.m";

pipefs: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

Aux: adt {
	fid, mode, isdir, busy: int;
	rin, rout, win, wout, tfd: ref FD;
	rc: chan of ref Rmsg.Read;
	wc: chan of ref Rmsg.Write;
	wend: chan of int;
};

msize: int;
lock: chan of int;
auxlst: list of ref Aux;
tags:= array[Styx->NOTAG+1] of (int, ref Aux);
twrc: chan of (ref Tmsg, ref Aux);
rwrc: chan of ref Rmsg;
rcmd, wcmd: string;
nullaux: Aux;

init(nil: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	if((styx = load Styx Styx->PATH) == nil)
		fatal("can't load " + Styx->PATH);
	if((sh = load Sh Sh->PATH) == nil)
		fatal("can't load " + Sh->PATH);
	if((arg := load Arg Arg->PATH) == nil)
		fatal("can't load " + Arg->PATH);

	arg->init(argv);
	arg->setusage("pipefs [-a|-b] [-c] [-r command] [-w command] dir mountpoint");
	mntopt := Sys->MREPL;
	copt := 0;
	while(( c:= arg->opt()) != 0)
		case c {
		'a' =>	mntopt = Sys->MAFTER;
		'b' =>	mntopt = Sys->MBEFORE;
		'c' =>	copt = 1;
		'r' =>		rcmd = arg->earg();
		'w' =>	wcmd = arg->earg();
		* => 		arg->usage();
		}
	argv = arg->argv();

	if(len argv != 2 || rcmd == nil && wcmd == nil)
		arg->usage();
	if(copt)
		mntopt |= Sys->MCREATE;
	if(rcmd == nil)
		rcmd = "/dis/cat.dis";
	if(wcmd == nil)
		wcmd = "/dis/cat.dis";
	dir := hd argv;
	mntpt := hd tl argv;
	twrc = chan of (ref Tmsg, ref Aux);
	rwrc = chan of ref Rmsg;
	lock = chan[1] of int;

	styx->init();
	sys->pipe(p := array[2] of ref FD);
	sys->pipe(q := array[2] of ref FD);
	if(sys->export(q[0], dir, Sys->EXPASYNC) < 0)
		fatal("can't export " + dir);
	spawn Treader(p[1]);
	spawn Twriter(q[1]);
	spawn Rreader(q[1]);
	spawn Rwriter(p[1]);
	if(sys->mount(p[0], nil, mntpt, mntopt, nil) < 0)
		fatal("can't mount on " + mntpt);
}

Treader(cfd: ref FD)
{
	while((t:=Tmsg.read(cfd, msize)) != nil){
		aux := ref nullaux;
		t.tag = newtag(t.tag);
		pick m := t {
		Clunk or
		Remove =>
			aux = getaux(m.fid);
			if(aux.win != nil){
				spawn clunkT(t, aux);
				continue;
			}
		Create =>
			aux = getaux(m.fid);
			aux.mode = m.mode;
		Open =>
			aux = getaux(m.fid);
			aux.mode = m.mode;
		Read =>
			aux = getaux(m.fid);
			if(!aux.isdir){
				spawn readT(m, aux);
				continue;
			}
		Write =>
			aux = getaux(m.fid);
			if(!aux.isdir){
				spawn writeT(m, aux);
				continue;
			}
		}
		twrc <-= (t, aux);
	}
	twrc <-= (nil, nil);
	rwrc <-= nil;
}

Twriter(sfd: ref FD)
{
	for(;;){
		(t, aux) :=<- twrc;
		if(t == nil){
			sys->write(sfd, array[1] of byte, 0);
			break;
		}
		tags[t.tag].t1 = aux;
		sys->write(sfd, t.pack(), t.packedsize());
	}
}

Rreader(sfd: ref FD)
{
	while((r := Rmsg.read(sfd, msize)) != nil){
		aux := tags[r.tag].t1;
		pick m := r {
		Clunk or
		Remove =>
			aux.tfd = nil;
			aux.busy = 0;
		Version =>
			msize = m.msize;
		Create or
		Open =>
			aux.isdir = m.qid.qtype & Styx->QTDIR;
			if(!aux.isdir){
				spawn openR(r, aux);
				continue;
			}
		Read =>
			if(!aux.isdir){
				aux.rc<-=m;
				continue;
			}
		Write =>
			if(!aux.isdir){
				aux.wc<-=m;
				continue;
			}
		}
		rwrc <-= r;
	}
}

Rwriter(cfd: ref FD)
{
	while((r:=<-rwrc) != nil){
		r.tag = freetag(r.tag);
		sys->write(cfd, r.pack(), r.packedsize());
	}
}

openR(m: ref Rmsg, aux: ref Aux)
{
	case aux.mode & 7 {
	Styx->OREAD =>
		pipercmd(aux);
	Styx->OWRITE =>
		pipewcmd(aux);
	Styx->ORDWR =>
		pipercmd(aux);
		pipewcmd(aux);
	}
	rwrc <-= m;
}

pipercmd(aux: ref Aux)
{
	sys->pipe(p := array[2] of ref FD);
	sys->pipe(q := array[2] of ref FD);
	aux.rin = p[0];
	aux.rout = q[0];
	aux.rc = chan of ref Rmsg.Read;
	sync := chan of int;
	spawn pipecmd(rcmd, p[1], q[1], sync);
	rpid := <- sync;
	p[1] = q[1] = nil;
	tname := "/tmp/pipefs." + string rpid;
	aux.tfd = sys->create(tname, Sys->ORDWR | Sys->ORCLOSE, 8r600);
	if(aux.tfd == nil)
		fatal("couldn't create " + tname);
	spawn rcmdin(aux);
	sys->stream(aux.rout, aux.tfd, 8192);
}

pipewcmd(aux: ref Aux)
{
	sys->pipe(p := array[2] of ref FD);
	sys->pipe(q := array[2] of ref FD);
	aux.win = p[0];
	aux.wout = q[0];
	aux.wc = chan of ref Rmsg.Write;
	aux.wend = chan of int;
	sync := chan of int;
	spawn pipecmd(wcmd, p[1], q[1], sync);
	<- sync;
	p[1] = q[1] = nil;
	spawn wcmdout(aux);
}

pipecmd(cmd: string, fd0, fd1: ref FD, sync: chan of int)
{
	pid := sys->pctl(Sys->FORKFD, nil);
	sys->dup(fd0.fd, 0);
	sys->dup(fd1.fd, 1);
	fd0 = fd1 = nil;
	sync <-= pid;
	sh->run(nil, "sh" :: "-c" :: cmd :: nil);
}

rcmdin(aux: ref Aux)
{
	tag := newtag(-1);
	offset := big 0;
	count := 0;
	do{
		t := ref Tmsg.Read(tag, aux.fid, offset, msize-Styx->IOHDRSZ);
		twrc <-= (t, aux);
		r := <-aux.rc;
		count = len r.data;
		offset += big count;
		sys->write(aux.rin, r.data, count);
	}while(count);
	freetag(tag);
}

wcmdout(aux: ref Aux)
{
	b := array[msize-Styx->IOHDRSZ] of byte;
	tag := newtag(-1);
	offset := big 0;
	while(count := sys->read(aux.wout, b, len b)){
		t := ref Tmsg.Write(tag, aux.fid, offset, b[:count]);
		twrc <-= (t, aux);
		r := <-aux.wc;
		offset += big r.count;
	}
	freetag(tag);
	aux.wend<-=1;
}

clunkT(t: ref Tmsg, aux: ref Aux)
{
	{
		sys->write(aux.win, array[1] of byte, 0);
	}exception e{
		"*" => e = nil;
	}
	<-aux.wend;
	twrc <-= (t, aux);
}

readT(m: ref Tmsg.Read, aux: ref Aux)
{
	data := array[m.count] of byte;
	sys->seek(aux.tfd, m.offset, Sys->SEEKSTART);
	count := sys->read(aux.tfd, data, len data);
	rwrc <-= ref Rmsg.Read(m.tag, data[:count]);
}

writeT(m: ref Tmsg.Write, aux: ref Aux)
{
	count := sys->write(aux.win, m.data, len m.data);
	rwrc <-= ref Rmsg.Write(m.tag, count);
}

getaux(fid: int): ref Aux
{
	aa: ref Aux;

	aa = nil;
	for(l:=auxlst; l!=nil; l=tl l){
		a := hd l;
		if(a.fid == fid){
			aa = a;
			break;
		}else if(aa == nil && !a.busy)
			aa = a;
	}
	if(aa == nil){
		aa = ref nullaux;
		auxlst = aa :: auxlst;
	}else if(!aa.busy)
		*aa = nullaux;
	aa.fid = fid;
	aa.busy = 1;
	return aa;
}

newtag(oldtag: int): int
{
	if(oldtag == styx->NOTAG)
		return tags[oldtag].t0 = oldtag;
	r := -1;
	lock <-= 1;
	for(i:=1; i<styx->NOTAG; i++)
		if(tags[i].t0 == 0){
			tags[r=i].t0 = oldtag;
			break;
		}
	<- lock;
	return r;
}

freetag(tag: int): int
{
	oldtag := tags[tag].t0;
	tags[tag].t0 = 0;
	return oldtag;
}

fatal(s: string)
{
	sys->fprint(sys->fildes(2), "pipefs: %s: %r\n", s);
	exit;
}

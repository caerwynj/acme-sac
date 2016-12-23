implement Wikifs;

include "sys.m";
	sys: Sys;
include "draw.m";
include "styx.m";
	styx: Styx;
	Rmsg, Tmsg: import styx;
include "styxservers.m";
	styxservers: Styxservers;
	Styxserver, Fid, Navigator, Navop, readbytes: import styxservers;
	Enotdir, Enotfound: import Styxservers;
	nametree: Nametree;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "wiki.m";
	wiki: Wiki;
	Map, Wpage, Wdoc, Whist, Tpage, Toldpage, Thistory, Tdiff, Tedit, Twerror: import wiki;
include "string.m";
	str: String;
include "arg.m";
	arg: Arg;
include "daytime.m";
	daytime: Daytime;

Wikifs: module {
	init: fn(nil: ref Draw->Context, argv: list of string);
};

badmodule(p: string)
{
	sys->fprint(sys->fildes(2), "wikifs: cannot load %s: %r\n", p);
	raise "fail:bad module";
}

user := "wikifs";
qidseq := 1;
pidregister: chan of (int, int);
flush: chan of (int, int, chan of int);
reqpool: list of chan of (ref Tmsg, ref Aux, ref Fid);
reqidle: int;
reqdone: chan of chan of (ref Tmsg, ref Aux, ref Fid);
srv: ref Styxserver;

filelist := array[] of {
	"index.html",
	"index.txt",
	"current",
	"history.html",
	"history.txt",
	"diff.html",
	"edit.html",
	"werror.html",
	"werror.txt",
};

Qindexhtml,
	Qindextxt,
	Qraw,
	Qhistoryhtml,
	Qhistorytxt,
	Qdiffhtml,
	Qedithtml,
	Qwerrorhtml,
	Qwerrortxt,
	Nfile: con iota;

# qids: <8-bit type><16-bit page number><16-bit page version><8-bit file index>.
Derror, Droot, D1st, D2nd, Fnew, Fmap, F1st, F2nd: con iota;

Maxreqidle: con 3;
Maxreplyidle: con 3;

Aux: adt {
	path:		big;
	name:	string;
	w:		ref Whist;
	t:		int;
	s:		string;
};

mkqid(typ, num, vers, file: int): big
{
	return  ((big typ)<< 40) |  ((big num)<<24) | big (vers<<8) | big file;
}

qidtype(path: big): int
{
	return int ((path>>40) & big 16rFF);
}

qidnum(path:big): int
{
	return int((path>>24) & big 16rFFFF);
}

qidvers(path:big): int
{
	return int((path>>8) & big 16rFFFF);
}

qidfile(path:big): int
{
	return int(path & big 16rFF);
}

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
	str = load String String->PATH;
	arg = load Arg Arg->PATH;
	daytime = load Daytime Daytime->PATH;
	wiki = load Wiki Wiki->PATH;
	wiki->init(bufio);
	styx = load Styx Styx->PATH;
	if (styx == nil)
		badmodule(Styx->PATH);
	styx->init();
	styxservers = load Styxservers Styxservers->PATH;
	if (styxservers == nil)
		badmodule(Styxservers->PATH);
	styxservers->init(styx);
	arg->init(args);
	while((c := arg->opt()) != 0)
		case c {
		'd' =>
			wiki->setwikidir(arg->earg());
		}
	args = arg->argv();

	sys->pctl(Sys->FORKNS, nil);		# fork pgrp?

	navops := chan of ref Navop;
	spawn navigator(navops);
	tchan: chan of ref Tmsg;
	(tchan, srv) = Styxserver.new(sys->fildes(0), Navigator.new(navops), mkqid(Droot, 0, 0, 0));
	spawn serve(tchan, navops);
}

serve(tchan: chan of ref Tmsg, navops: chan of ref Navop)
{
	pidregister = chan of (int, int);
	flush = chan of (int, int, chan of int);
	reqdone = chan of chan of (ref Tmsg, ref Aux, ref Fid);
	spawn flushproc(flush);

Serve:
	for(;;)alt{
	gm := <-tchan =>
		if(gm == nil)
			break Serve;
		pick m := gm {
		Readerror =>
			sys->fprint(sys->fildes(2), "wikifs: fatal read error: %s\n", m.error);
			break Serve;
		Read =>
			(fid, err) := srv.canread(m);
			if(err != nil)
				srv.reply(ref Rmsg.Error(m.tag, err));
			else if(fid.qtype & Sys->QTDIR)
				srv.read(m);
			else
				request(m, fid);
		Write =>
			(fid, err) := srv.canwrite(m);
			if(err != nil)
				srv.reply(ref Rmsg.Error(m.tag, err));
			else
				request(m, fid);
		Flush =>
			done := chan of int;
			flush <-= (m.tag, m.oldtag, done);
			<-done;
		Stat =>
			c := srv.getfid(m.fid);
			if(c == nil) {
				srv.reply(ref Rmsg.Error(m.tag, "bad fid"));
				return;
			} else
				request(m, c);
		* =>
			srv.default(gm);
		}
	reqpool = <-reqdone :: reqpool =>
		if(reqidle++ > Maxreqidle){
			hd reqpool <-= (nil, nil, nil);
			reqpool = tl reqpool;
			reqidle--;
		}
	}
	navops <-= nil;
}

request(m: ref Styx->Tmsg, fid: ref Fid)
{
	c: chan of (ref Tmsg, ref Aux, ref Fid);
	if(reqpool == nil){
		c = chan of (ref Tmsg, ref Aux, ref Fid);
		spawn requestproc(c);
	}else{
		(c, reqpool) = (hd reqpool, tl reqpool);
		reqidle--;
	}
	c <-= (m, nil, fid);
}

requestproc(req: chan of (ref Tmsg, ref Aux, ref Fid))
{
	pid := sys->pctl(0, nil);
	for(;;){
		(gm, nil, fid) := <-req;
		if(gm == nil)
			break;
		pidregister <-= (pid, gm.tag);
		path := fid.path;
		pick m := gm {
		Read =>
			case qidtype(path) {
			Fnew =>
				if(fid.data != nil)
					srv.reply(readbytes(m, fid.data));
				else
					srv.reply(ref Rmsg.Error(m.tag, "protocol botch"));
			Fmap =>
				srv.reply(readbytes(m, fid.data));
			F1st or F2nd =>
				if(fid.data != nil)
					srv.reply(readbytes(m, fid.data));
				else{
					fid.data = loadpath(path);
					srv.reply(readbytes(m, fid.data));
				}
			* =>
				srv.reply(ref Rmsg.Error(m.tag, "what was i thinking1?"));
			}
		Write =>
			case qidtype(path) {
			Fnew =>
				if(len m.data != 0){
					n := len fid.data;
					fid.data = (array[len fid.data + len m.data] of byte)[0:] = fid.data;
					p := fid.data[n:];
					p[0:] = m.data;
					srv.reply(ref Rmsg.Write(m.tag, len m.data));
				}else if(len fid.data != 0) {
					n := newfile(string fid.data);
					if(n < 0){
						fid.data = nil;
						srv.reply(ref Rmsg.Error(m.tag, "newfile failed"));
					}else{
						name := wiki->numtoname(n);
						for(i:=0;i<len name;i++)
							if(name[i] == ' ')
								name[i] = '_';
						fid.data = array of byte name;
						srv.reply(ref Rmsg.Write(m.tag, 0));
					}
				}else
					srv.reply(ref Rmsg.Error(m.tag, "protocol botch"));
			Fmap =>
				n := wiki->nametonum(string m.data);
				if(n < 0)
					srv.reply(ref Rmsg.Error(m.tag, "name not found"));
				else{
					fid.data = m.data;
					srv.reply(ref Rmsg.Write(m.tag, len m.data));
				}
			* =>
				srv.reply(ref Rmsg.Error(m.tag, "what was i thinking2?"));
			}
		Stat =>
			# the length is important because it is used by httpd for content-length
			# so we have to read and generate the content and calculate it's length
			# we can then stash it in the fid, or a cache of qid if we wanted.
			# httpd also uses mtime for last-modified
			(d, err) := dirgen(path);
			if(d == nil) {
				srv.reply(ref Rmsg.Error(m.tag, err));
				return;
			}
			if(fid.data == nil)
				case qidtype(path) {
				F1st or F2nd =>
					fid.data = loadpath(path);
					d.length = big len fid.data;
				}
			srv.reply(ref Rmsg.Stat(m.tag, *d));
		* =>
			srv.reply(ref Rmsg.Error(gm.tag, "oh dear"));	
		}
		pidregister <-= (pid, -1);
		reqdone <-= req;
	}
}

newfile(file: string): int
{
	w: ref Whist;
	t, n: int;
	title, author, comment: string;

	fd := bufio->sopen(file);
	if((title = fd.gets('\n')) == nil)
		return -1;
	w = ref Whist;
	w.title = title[0:len title-1];
	author = "me";
	t = 0;
	while((s := fd.gets('\n')) != nil && s != "\n"){
		case s[0] {
		'A' =>
			author = s[1:len s - 1];
		'D' =>
			t = int s[1:];
		'C' =>
			comment = s[1: len s - 1];
		}
	}
	w.doc = array[1] of ref Wdoc;
	w.doc[0] = ref Wdoc(author, comment, 0, daytime->now(), nil);
	
	w.doc[0].wtxt = wiki->Brdpage(fd, wiki->Srdwline);
	if(w.doc[0].wtxt == nil)
		return -1;
	w.ndoc = 1;
	n = wiki->allocnum(w.title, 0);
	if(n < 0)
		return -1;
	s = wiki->doctext(w.doc[0]);
	wiki->writepage(n, t, s, w.title);
	return n;
}

loadpath(path: big): array of byte
{
	s : string;
	wh : ref Whist;
	if(qidtype(path) == F2nd)
		wh = wiki->gethistory(qidnum(path));
	else {
		case qidfile(path) {
		Qhistoryhtml or Qhistorytxt or Qdiffhtml =>
			wh = wiki->gethistory(qidnum(path));
		* =>
			wh = wiki->getcurrent(qidnum(path));
		}
	}
	if(wh == nil)
		return nil;
	t := qidtype(path);
	if(t == F1st)
		t = Tpage;
	else
		t = Toldpage;
	n := qidvers(path);
	case qidfile(path) {
	Qindexhtml =>
		s = wiki->tohtml(wh, wh.doc[n], t);
	Qindextxt =>
		s = wiki->totext(wh, wh.doc[n], t);
	Qraw =>
		s = wh.title + "\n" + wiki->doctext(wh.doc[n]);
	Qhistoryhtml =>
		s = wiki->tohtml(wh, wh.doc[n], Thistory);
	Qhistorytxt =>
		s = wiki->totext(wh, wh.doc[n], Thistory);
	Qdiffhtml =>
		s = wiki->tohtml(wh, wh.doc[n], Tdiff);
	Qedithtml =>
		s = wiki->tohtml(wh, wh.doc[n], Tedit);
	Qwerrorhtml =>
		s = wiki->tohtml(wh, wh.doc[n], Twerror);
	* =>
		s = "internal error";
	}
	return array of byte s;
}

qid(path: big): Sys->Qid
{
	return dirgen(path).t0.qid;
}

navigator(navops: chan of ref Navop)
{
	while((m := <-navops) != nil){
		wiki->currentmap(0);
		path := big 0;
		pick n := m {
		Stat =>
			# stats from here return 0 length 
			# (used by styxservers' attach, canopen, cancreate, walk)
			# but for stat from client the above stat, not this one, is used.
			n.reply <-= dirgen(n.path);
		Walk =>
			name := n.name;
			case qidtype(m.path) {
			Droot =>
				case name {
				".." =>
					path = m.path;
				"new" =>
					path = mkqid(Fnew, 0, 0, 0);
				"map" =>
					path = mkqid(Fmap, 0, 0, 0);
				* =>
					(num, q) := str->toint(name, 10);
					if(q != nil)
						num = wiki->nametonum(name);
					if(num != -1)
						path = mkqid(D1st, num, 0, 0);
				}
			D1st =>
				case name{
				".." =>
					path = mkqid(Droot, 0, 0, 0);
				* =>
					(num, q) := str->toint(name, 10);
					if(q == nil){
						wh := wiki->gethistory(qidnum(m.path));
						if(wh == nil)
							break;
						for(i:=0;i<wh.ndoc;i++)
							if(wh.doc[i].time==num){
								path = mkqid(D2nd, qidnum(m.path), i, 0);
								break;
							}
					}else{
						for(i:=0;i<len filelist; i++)
							if(name == filelist[i]){
								path = mkqid(F1st, qidnum(m.path), 0, i);
								break;
							}
					}
				}
			D2nd =>
				case name {
				".." =>
					path = mkqid(D1st, qidnum(m.path), 0, 0);
				* =>
					for(i:=0;i<=Qraw;i++){
						if(name==filelist[i]){
							path = mkqid(F2nd, qidnum(m.path), qidvers(m.path), i);
							break;
						}
					}
				}
			}
			n.reply <-= dirgen(path);
		Readdir =>
			d: array of big;
			wh: ref Whist;
			case qidtype(m.path){
			Droot =>
				map := wiki->map;
				d = array[2+map.nel] of big;
				d[0] = mkqid(Fnew, 0, 0, 0);
				d[1] = mkqid(Fmap, 0, 0, 0);
				for(i:=0;i<map.nel;i++)
					d[i+2] = mkqid(D1st, map.el[i].n, 0, 0);
			D1st =>
				nfiles := Nfile;
				wh = wiki->gethistory(qidnum(m.path));
				if(wh != nil)
					nfiles += wh.ndoc;
				d = array[nfiles] of big;
				for(i:=0; i<Nfile; i++)
					d[i] = mkqid(F1st, qidnum(m.path), 0, i);
				for(; i<nfiles; i++)
					d[i] = mkqid(D2nd, qidnum(m.path), i - Nfile, 0);
			D2nd =>
				d = array[Qraw+1] of big;
				for(i:=0; i<=Qraw; i++)
					d[i] = mkqid(F2nd, qidnum(m.path), qidvers(m.path), i);
			}
			if(d == nil){
				n.reply <-= (nil, Enotdir);
				break;
			}
			for (i := n.offset; i < len d; i++)
				n.reply <-= dirgen(d[i]);
			n.reply <-= (nil, nil);
		}
	}
}

# dirgen has all the info needed to generate the correct info
# using gethistory or getcurrent.
dirgen(path: big): (ref Sys->Dir, string)
{
	d := ref sys->zerodir;
	d.qid.path = path;
	wh : ref Whist;

	vers := qidvers(path);
	case qidtype(path) {
	Droot =>
		d.name = ".";
		d.mode = 8r555|Sys->DMDIR;
	D1st =>
		d.name = wiki->numtoname(qidnum(path));
		for(i:=0;i<len d.name;i++)
			if(d.name[i] == ' ')
				d.name[i] = '_';
		d.mode = 8r555|Sys->DMDIR;
		wh = wiki->getcurrent(qidnum(path));
	D2nd =>
		wh = wiki->gethistory(qidnum(path));
		if(wh == nil)
			return (nil, Enotfound);
		d.name = sys->sprint("%ud", wh.doc[vers].time);
		d.mode = 8r555|Sys->DMDIR;
	Fmap =>
		d.name = "map";
		d.mode = 8r666;
	Fnew =>
		d.name = "new";
		d.mode = 8r666;
	F1st =>
		d.name = filelist[qidfile(path)];
		d.mode = 8r444;
		wh = wiki->getcurrent(qidnum(path));
	F2nd =>
		d.name = filelist[qidfile(path)];
		d.mode = 8r444;
		wh = wiki->gethistory(qidnum(path));
	* =>
		return (nil, Enotfound);
	}
	if(d.mode & Sys->DMDIR)
		d.qid.qtype = Sys->QTDIR;
	d.uid = user;
	d.gid = user;
	if(wh != nil)
		d.mtime = d.atime = wh.doc[vers].time;
	else
		d.mtime = d.atime = daytime->now();
	d.qid.vers = d.mtime;
	if(qidfile(path) == Qedithtml)
		d.mtime = daytime->now();
	return (d, nil);
}

flushproc(flush: chan of (int, int, chan of int))
{
	a: array of (int, int);
	n := 0;
	for(;;)alt{
	(pid, tag) := <-pidregister =>
		if(tag == -1){
			for(i := 0; i < n; i++)
				if(a[i].t0 == pid)
					break;
			n--;
			if(i < n)
				a[i] = a[n];
		}else{
			if(n >= len a){
				na := array[n + 5] of (int, int);
				na[0:] = a;
				a = na;
			}
			a[n++] = (pid, tag);
		}
	(tag, oldtag, done) := <-flush =>
		for(i := 0; i < n; i++)
			if(a[i].t1 == oldtag){
				spawn doflush(tag, a[i].t0, done);
				break;
			}
		if(i == n)
			spawn doflush(tag, -1, done);
	}
}

doflush(tag: int, pid: int, done: chan of int)
{
	if(pid != -1){
		kill(pid, "kill");
		pidregister <-= (pid, -1);
	}
	srv.reply(ref Rmsg.Flush(tag));
	done <-= 1;
}

kill(pid: int, note: string): int
{
	fd := sys->open("/prog/"+string pid+"/ctl", Sys->OWRITE);
	if(fd == nil || sys->fprint(fd, "%s", note) < 0)
		return -1;
	return 0;
}

implement mailpop3;

include "sys.m";
include "draw.m";
include "bufio.m";
include "daytime.m";
include "sh.m";
include "pop3.m";
include "acmewin.m";
include "arg.m";
	arg: Arg;
include "encoding.m";
	enc: Encoding;
include "factotum.m";

mailpop3 : module {
	init : fn(ctxt : ref Draw->Context, argl : list of string);
};

sys : Sys;
bufio : Bufio;
daytime : Daytime;
pop3 : Pop3;
acmewin: Acmewin;
Win, Event: import acmewin;

OREAD, OWRITE, ORDWR, FORKENV, NEWFD, FORKFD, NEWPGRP, UTFmax : import Sys;
FD, Dir : import sys;
fprint, sprint, sleep, create, open, read, write, remove, stat, fstat, fwstat, fildes, pctl, pipe, dup, byte2char : import sys;
Context : import Draw;
EOF : import Bufio;
Iobuf : import bufio;
Tm, time : import daytime;

DIRLEN : con 116;
PNPROC, PNGROUP : con iota;
False : con 0;
True : con 1;
EVENTSIZE : con 256;
Runeself : con 16r80;
OCEXEC : con 0;
CHEXCL : con 0; # 16r20000000;
CHAPPEND : con 0; # 16r40000000;


Mesg : adt {
	w : ref Win;
	id : int;
	hdr : string;
	realhdr : string;
	replyto : string;
	text : string;
	subj : string;
	next : cyclic ref Mesg;
 	lline1 : int;
	box : cyclic ref Box;
	isopen : int;
	posted : int;
	
	deleted : int;
	date: int;
	from: string;
	encoding: string;
	popno : int;

	read : fn(b : ref Box) : ref Mesg;
	open : fn(m : self ref Mesg);
	slave : fn(m : self ref Mesg);
	free : fn(m : self ref Mesg);
	save : fn(m : self ref Mesg, s : string);
	mkreply : fn(m : self ref Mesg);
	mkmail : fn(b : ref Box, s : string);
	putpost : fn(m : self ref Mesg, e : ref Event);

 	command : fn(m : self ref Mesg, s : string) : int;
 	send : fn(m : self ref Mesg);
};

Box : adt {
	w : ref Win;
	nm : int;
	readonly : int;
	m : cyclic ref Mesg;
#	io : ref Iobuf;
	clean : int;
 	leng : int;
 	cdel : chan of ref Mesg;
	cevent : chan of Event;
	cmore : chan of int;
	
	lst : list of int;
	s : string;
	
	line : string;
	popno : int;
	peekline : string;

	read : fn(n : int) : ref Box;
	readmore : fn(b : self ref Box, lck : int);
	readline : fn(b : self ref Box) : string;
	unreadline : fn(b : self ref Box);
	slave : fn(b : self ref Box);
	mopen : fn(b : self ref Box, n : int);
	rewrite : fn(b : self ref Box);
	mdel : fn(b : self ref Box, m : ref Mesg);
	event : fn(b : self ref Box, e : ref Event);

	command : fn(b : self ref Box, s : string) : int;
};

Lock : adt {
	cnt : int;
	chann : chan of int;

	init : fn() : ref Lock;
	lock : fn(l : self ref Lock);
	unlock : fn(l : self ref Lock);
};

Ref : adt {
	l : ref Lock;
	cnt : int;

	init : fn() : ref Ref;
	inc : fn(r : self ref Ref) : int;
};

mbox : ref Box;
user : string;
pwd : string;
date : string;
mailctxt : ref Context;
stdout, stderr : ref FD;

killing : int = 0;
usessl := 0;

server: string;

init(ctxt : ref Context, args : list of string)
{
	mailctxt = ctxt;
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
	daytime = load Daytime Daytime->PATH;
	pop3 = load Pop3 Pop3->PATH;
	acmewin = load Acmewin Acmewin->PATH;
	arg = load Arg Arg->PATH;
	acmewin->init();
	stdout = fildes(1);
	stderr = fildes(2);
	arg->init(args);
	while((c := arg->opt()) != 0)
	case c {
	'u'  => user = arg->earg();
	't' => usessl = 1;
	's' => server = arg->earg();
	}
	if(server != nil){
		factotum := load Factotum Factotum->PATH;
		factotum->init();
		(user, pwd) = factotum->getuserpasswd(sys->sprint("proto=pass service=pop3 dom=%s", server));
	}
	args = arg->argv();
	main();
}

dlock : ref Lock;
dfd : ref Sys->FD;

debug(s : string)
{
	if (dfd == nil) {
		dfd = sys->create("/usr/jrf/acme/debugmail", Sys->OWRITE, 8r600);
		dlock = Lock.init();
	}
	if (dfd == nil)
		return;
	dlock.lock();
	sys->fprint(dfd, "%s", s);	
	dlock.unlock();
}

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

exec(cmd : string, argl : list of string)
{
	file := cmd;
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
			fprint(stderr, "%s: %s\n", cmd, err);
			return;
		}
	}
	c->init(mailctxt, argl);
}

swrite(fd : ref FD, s : string) : int
{
	ab := array of byte s;
	m := len ab;
	p := write(fd, ab, m);
	if (p == m)
		return len s;
	if (p <= 0)
		return p;
	return 0;
}

strchr(s : string, c : int) : int
{
	for (i := 0; i < len s; i++)
		if (s[i] == c)
			return i;
	return -1;
} 

strrchr(s : string, c : int) : int
{
	for (i := len s - 1; i >= 0; i--)
		if (s[i] == c)
			return i;
	return -1;
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

access(s : string) : int
{
	fd := open(s, 0);
	if (fd == nil)
		return -1;
	fd = nil;
	return 0;
}

newevent() : ref Event
{
	e := ref Event;
	e.b = array[EVENTSIZE*UTFmax+1] of byte;
	e.r = array[EVENTSIZE+1] of int;
	return e;
}	

newmesg() : ref Mesg
{
	m := ref Mesg;
	m.id = m.lline1 = m.isopen = m.posted = m.deleted = 0;
	return m;
}

lc, uc : chan of ref Lock;

initlock()
{
	lc = chan of ref Lock;
	uc = chan of ref Lock;
	spawn lockmgr();
}

lockmgr()
{
	l : ref Lock;

	for (;;) {
		alt {
			l = <- lc =>
				if (l.cnt++ == 0)
					l.chann <-= 1;
			l = <- uc =>
				if (--l.cnt > 0)
					l.chann <-= 1;
		}
	}
}

Lock.init() : ref Lock
{
	return ref Lock(0, chan of int);
}

Lock.lock(l : self ref Lock)
{
	lc <-= l;
	<- l.chann;
}

Lock.unlock(l : self ref Lock)
{
	uc <-= l;
}

Ref.init() : ref Ref
{
	r := ref Ref;
	r.l = Lock.init();
	r.cnt = 0;
	return r;
}

Ref.inc(r : self ref Ref) : int
{
	r.l.lock();
	i := r.cnt;
	r.cnt++;
	r.l.unlock();
	return i;
}

error(s : string)
{
	if(s != nil)
		fprint(stderr, "mail: %s\n", s);
	postnote(PNGROUP, pctl(0, nil), "kill");
	killing = 1;
	exit;
}

tryopen(s : string, mode : int) : ref FD
{
	fd : ref FD;
	try : int;

	for(try=0; try<3; try++){
		fd = open(s, mode);
		if(fd != nil)
			return fd;
		sleep(1000);
	}
	return nil;
}

run(argv : list of string, c : chan of int, p0 : ref FD)
{
	# pctl(FORKFD|NEWPGRP, nil);	# had RFMEM
	pctl(FORKENV|NEWFD|NEWPGRP, 0::1::2::p0.fd::nil);
	c <-= pctl(0, nil);
	dup(p0.fd, 0);
	p0 = nil;
	exec(hd argv, argv);
	exit;
}

getuser() : string
{
  	fd := open("/dev/user", OREAD);
  	if(fd == nil)
    		return "";
  	buf := array[128] of byte;
  	n := read(fd, buf, len buf);
  	if(n < 0)
    		return "";
  	return string buf[0:n];	
}

pop3conn : int = 0;
pop3bad : int = 0;
pop3lock : ref Lock;

pop3open(lck : int)
{
	if (lck)
		pop3lock.lock();
	if (!pop3conn) {
		(ok, s) := pop3->open(user, pwd, server, usessl);
		if (ok < 0) {
			if (!pop3bad) {
				fprint(stderr, "mail: could not connect to POP3 mail server : %s\n", s);
				pop3bad = 1;
			}
			return;
		}
	}
	pop3conn = 1;
	pop3bad = 0;
}

pop3close(unlck : int)
{
	if (pop3conn) {
		(ok, s) := pop3->close();
		if (ok < 0) {
			fprint(stderr, "mail: could not close POP3 connection : %s\n", s);
			pop3lock.unlock();
			return;
		}
	}
	pop3conn = 0;
	if (unlck)
		pop3lock.unlock();
}

pop3stat(b : ref Box) : int
{
	(ok, s, nm, nil) := pop3->stat();
	if (ok < 0 && pop3conn) {
		fprint(stderr, "mail: could not stat POP3 server : %s\n", s);
		return b.leng;
	}
	return nm;
}

pop3list() : list of int
{
	(ok, s, l) := pop3->msgnolist();
	if (ok < 0 && pop3conn) {
		fprint(stderr, "mail: could not get list from POP3 server : %s\n", s);
		return nil;
	}
	return l;
}

pop3mesg(mno : int) : string
{
	(ok, s, msg) := pop3->get(mno);
	if (ok < 0 && pop3conn) {
		fprint(stderr, "mail: could not retrieve a message from server : %s\n", s);
		return "Acme Mail : FAILED TO RETRIEVE MESSAGE\n";
	}
	return msg;
}

pop3del(mno : int) : int
{
	(ok, s) := pop3->delete(mno);
	if (ok < 0) 
		fprint(stderr, "mail: could not delete message : %s\n", s);
	return ok;
}

pop3init(b : ref Box)
{
	b.leng = pop3stat(b);
	b.lst = pop3list();
	b.s = nil;
	b.popno = 0;
	if (len b.lst != b.leng)
		error("bad lengths in pop3init()");
}

pop3more(b : ref Box)
{
	nl : list of int;

	leng := b.leng;
	b.leng = pop3stat(b);
	b.lst = pop3list();
	b.s = nil;
	b.popno = 0;
	if (len b.lst != b.leng || b.leng < leng)
		error("bad lengths in pop3more()");
	# is this ok ?
	nl = nil;
	for (i := 0; i < leng; i++) {
		nl = hd b.lst :: nl;
		b.lst = tl b.lst;
	}
	# now update pop nos.
	for (m := b.m; m != nil; m = m.next) {
		# opopno := m.popno;
		if (nl == nil)
			error("message list too big");
		m.popno = hd nl;
		nl = tl nl;
		# debug(sys->sprint("%d : popno from %d to %d\n", m.id, opopno, m.popno));
	}
	if (nl != nil)
		error("message list too small");
}

pop3next(b : ref Box) : string
{
	mno : int = 0;
	r : string;

	if (b.s == nil) {
		if (b.lst == nil)
			return nil;	# end of box
		first := b.popno == 0;
		mno = hd b.lst;
		b.lst = tl b.lst;
		b.s = pop3mesg(mno);
		b.popno = mno;
		if (!first)
			return nil;	# end of message
	}
	t := strchr(b.s, '\n');
	if (t >= 0) {
		r = b.s[0:t+1];
		b.s = b.s[t+1:];
	}
	else {
		r = b.s;
		b.s = nil;
	}
	return r;
}

main()
{
	readonly : int;

	initlock();
	initreply();
	date = time();
	if(date==nil)
		error("can't get current time");
	if(user == nil)
		user = getuser();
	readonly = False;
	pop3lock = Lock.init();
	mbox = mbox.read(readonly);
	spawn timeslave(mbox, mbox.cmore);
	mbox.slave();
	error(nil);
}

timeslave(b : ref Box, c : chan of int)
{
	for(;;){
		sleep(60*3*1000);
		pop3open(1);
		leng := pop3stat(b);
		pop3close(1);
		if (leng > b.leng)
			c <-= 0;
	}
}

None,Unknown,Ignore,CC,From,ReplyTo,Sender,Subject,Re,To, Date, Received, TransferEncoding : con iota;
NHeaders : con 200;

Hdrs : adt {
	name : string;
	typex : int;
};


hdrs := array[NHeaders+1] of {
	Hdrs ( "CC:",				CC ),
	Hdrs ( "From:",				From ),
	Hdrs ( "Reply-To:",			ReplyTo ),
	Hdrs ( "Sender:",			Sender ),
	Hdrs ( "Subject:",			Subject ),
	Hdrs ( "Re:",				Re ),
	Hdrs ( "To:",				To ),
	Hdrs ( "Date:",				Date),
	Hdrs ("Content-Transfer-Encoding:", TransferEncoding),
 * => Hdrs ( "",					0 ),
};

StRnCmP(s : string, t : string, n : int) : int
{
	c, d, i, j : int;

	i = j = 0;
	if (len s < n || len t < n)
		return -1;
	while(n > 0){
		c = s[i++];
		d = t[j++];
		--n;
		if(c != d){
			if('a'<=c && c<='z')
				c -= 'a'-'A';
			if('a'<=d && d<='z')
				d -= 'a'-'A';
			if(c != d)
				return c-d;
		}
	}
	return 0;
}

readhdr(b : ref Box) : (string, int)
{
	i, j, n, m, typex : int;
	s, t : string;

{
	s = b.readline();
	n = len s;
	if(n <= 0) {
		b.unreadline();
		raise("e");
	}
	for(i=0; i<n; i++){
		j = s[i];
		if(i>0 && j == ':')
			break;
		if(j<'!' || '~'<j){
			b.unreadline();
			raise("e");
		}
	}
	typex = Unknown;
	for(i=0; hdrs[i].name != nil; i++){
		j = len hdrs[i].name;
		if(StRnCmP(hdrs[i].name, s, j) == 0){
			typex = hdrs[i].typex;
			break;
		}
	}
	# scan for multiple sublines 
	for(;;){
		t = b.readline();
		m = len t;
		if(m<=0 || (t[0]!=' ' && t[0]!='\t')){
			b.unreadline();
			break;
		}
		# absorb 
		s += t;
	}
	return(s, typex);
}
exception{
	"*" =>
		return (nil, None);
}
}

Mesg.read(b : ref Box) : ref Mesg
{
	m : ref Mesg;
	s : string;
	n, typex : int;

	s = b.readline();
	if(s == nil)
		return nil;
	b.unreadline();

{
	m = newmesg();
	m.popno = b.popno;
	if (m.popno == 0)
		error("bad pop3 id");
	m.text = nil;
	# read header 
loop:
	for(;;){
		(s, typex) = readhdr(b);
		case(typex){
		None =>
			break loop;
		ReplyTo =>
			m.replyto = s[9:];
			break;
		From =>
			if(m.replyto == nil)
				m.replyto = s[5:];
			m.from = s[5:];
			break;
		Subject =>
			m.subj = s[8:];
			break;
		Re =>
			m.subj = s[3:];
			break;
		Date =>
			m.date = mktime(s[5:]);
			break;
		TransferEncoding =>
			m.encoding = s[27:];
#			sys->print("%s", m.encoding);
			if(len m.encoding >= 6 && m.encoding[0:6] == "base64")
				enc = load Encoding Encoding->BASE64PATH;
		}
		m.realhdr += s;
		if(typex != Ignore && typex != Unknown)
			m.hdr += s;
	}
	# read body 
	for(;;){
		s = b.readline();
		n = len s;
		if(n <= 0)
			break;
		if(enc != nil){
			if(len s > 1 && s[len s - 1] == '\n')
				s = s[:len s - 1];
			if(len s > 1)
				s = string enc->dec(s);
		}
		m.text += s;
	}
#	sys->print("END");
	enc = nil;
	m.box = b;
	return m;
}
exception{
	"*" =>
		error("malformed header " + s);
		return nil;
}
}

Mesg.mkmail(b : ref Box, hdr : string)
{
	r : ref Mesg;

	r = newmesg();
	r.hdr = hdr + "\n";
	r.lline1 = len r.hdr;
	r.text = nil;
	r.box = b;
	r.open();
	r.w.wdormant();
}

replyaddr(r : string) : string
{
	p, q, rr : int;

	rr = 0;
	while(r[rr]==' ' || r[rr]=='\t')
		rr++;
	r = r[rr:];
	p = strchr(r, '<');
	if(p >= 0){
		q = strchr(r[p+1:], '>');
		if(q < 0)
			r = r[p+1:];
		else
			r = r[p+1:p+1+q] + "\n";
		return r;
	}
	p = strchr(r, '(');
	if(p >= 0){
		q = strchr(r[p:], ')');
		if(q < 0)
			r = r[0:p];
		else
			r = r[0:p] + r[p+q+1:];
	}
	return r;
}

Mesg.mkreply(m : self ref Mesg)
{
	r : ref Mesg;

	r = newmesg();
	r.hdr = replyaddr(m.replyto);
	r.lline1 = len r.hdr;
	if(m.subj != nil){
		if(StRnCmP(m.subj, "re:", 3)==0 || StRnCmP(m.subj, " re:", 4)==0)
			r.text = "Subject:" + m.subj + "\n";
		else
			r.text = "Subject: Re:" + m.subj + "\n";
	}
	else
		r.text = nil;
	r.box = m.box;
	r.open();
	r.w.wselect("$");
	r.w.wdormant();
}

Mesg.free(m : self ref Mesg)
{
	m.text = nil;
	m.hdr = nil;
	m.subj = nil;
	m.realhdr = nil;
	m.replyto = nil;
	m = nil;
}

replyid : ref Ref;

initreply()
{
	replyid = Ref.init();
}

Mesg.open(m : self ref Mesg)
{
	buf, s : string;

	if(m.isopen)
		return;
	m.w = Win.wnew();
	if(m.id != 0){
		from := replyaddr(m.from);
		if(from[len from - 1] == '\n')
			from = from[:len from -1];
		m.w.wwritebody("From " + fromdisp(m));
	}
	m.w.wwritebody(m.hdr);
	m.w.wwritebody(m.text);
	if(m.id){
		buf = sprint("Mail/box/%d", m.id);
		m.w.wtagwrite("Reply Delmesg Save");
	}else{
		buf = sprint("Mail/%s/Reply%d", s, replyid.inc());
		m.w.wtagwrite("Post");
	}
	m.w.wname(buf);
	m.w.wclean();
	m.w.wselect("0");
	m.isopen = True;
	m.posted = False;
	spawn m.slave();
}

Mesg.putpost(m : self ref Mesg, e : ref Event)
{
	if(m.posted || m.id==0)
		return;
	if(e.q0 >= len m.hdr+5)	# include "From " 
		return;
	m.w.wtagwrite(" Post");
	m.posted = True;
	return;
}

Mesg.slave(m : self ref Mesg)
{
	e, e2, ea, etoss, eq : ref Event;
	s : string;
	na : int;

	e = newevent();
	e2 = newevent();
	ea = newevent();
	etoss = newevent();
	for(;;){
		m.w.wevent(e);
		case(e.c1){
		'E' =>	# write to body; can't affect us 
			break;
		'F' =>	# generated by our actions; ignore 
			break;
		'K' or 'M' =>	# type away; we don't care 
			case(e.c2){
			'x' or 'X' =>	# mouse only 
				eq = e;
				if(e.flag & 2){
					m.w.wevent(e2);
					eq = e2;
				}
				if(e.flag & 8){
					m.w.wevent(ea);
					m.w.wevent(etoss);
					na = ea.nb;
				}else
					na = 0;
				if(eq.q1>eq.q0 && eq.nb==0)
					s = m.w.wread(eq.q0, eq.q1);
				else
					s = string eq.b[0:eq.nb];
				if(na)
					s = s + " " + string ea.b[0:ea.nb];
				if(!m.command(s))	# send it back 
					m.w.wwriteevent(e);
				s = nil;
				break;
			'l' or 'L' =>	# mouse only 
				if(e.flag & 2)
					m.w.wevent(e2);
				# just send it back 
				m.w.wwriteevent(e);
				break;
			'I' or 'D' =>	# modify away; we don't care 
				m.putpost(e);
				break;
			'd' or 'i' =>
				break;
			* =>
				fprint(stdout, "unknown message %c%c\n", e.c1, e.c2);
				break;
			}
		* =>
			fprint(stdout, "unknown message %c%c\n", e.c1, e.c2);
			break;
		}
	}
}

Mesg.command(m : self ref Mesg, s : string) : int
{
	while(s[0]==' ' || s[0]=='\t' || s[0]=='\n')
		s = s[1:];
	if(s == "Post"){
		m.send();
		return True;
	}
	if(len s >= 4 && s[0:4] == "Save"){
		s = s[4:];
		while(len s > 0 && (s[0]==' ' || s[0]=='\t' || s[0]=='\n'))
			s = s[1:];
		if(s == nil)
			m.save("/mail/box/" + user + "/stored");
		else{
			ss := 0;
			while(ss < len s && s[ss]!=' ' && s[ss]!='\t' && s[ss]!='\n')
				ss++;
			m.save(s[0:ss]);
		}
		return True;
	}
	if(s == "Reply"){
		m.mkreply();
		return True;
	}
	if(s == "Del"){
		if(m.w.wdel(False)){
			m.isopen = False;
			exit;
		}
		return True;
	}
	if(s == "Delmesg"){
		if(m.w.wdel(False)){
			m.isopen = False;
			m.box.cdel <-= m;
			exit;
		}
		return True;
	}
	return False;
}

Mesg.save(m : self ref Mesg, base : string)
{
	s, buf : string;
	fd : ref FD;
	b : ref Iobuf;

	if(m.id <= 0){
		fprint(stderr, "can't save reply message; mail it to yourself\n");
		return;
	}
	buf = nil;
	s = base;
{
	if(access(s) < 0)
		raise("e");
	fd = tryopen(s, OWRITE);
	if(fd == nil)
		raise("e");
	buf = nil;
	b = bufio->fopen(fd, OWRITE);
	# seek to end in case file isn't append-only 
	b.seek(big 0, 2);

	# TODO: create the plan9 header so Mail can read it. and quote From 
	# inside the body.
	# use edited headers: first line of real header followed by remainder of selected ones 
	from := replyaddr(m.from);
	if(from[len from - 1] == '\n')
		from = from[:len from -1];
	b.puts("From " + from + " " + daytime->text(daytime->local(m.date)) + "\n");
	b.puts(m.hdr);
	b.puts(m.text);
	b.puts("\n");
	b.close();
	b = nil;
	fd = nil;
}
exception{
	"*" =>
		buf = nil;
		fprint(stderr, "mail: can't open %s: %r\n", base);
		return;
}
}

fromdisp(m: ref Mesg): string
{
	from := replyaddr(m.from);
	if(from[len from - 1] == '\n')
		from = from[:len from -1];
	return from + "\t" + daytime->filet(daytime->now(), m.date) + "\n";
}

Mesg.send(m : self ref Mesg)
{
	s, buf : string;
	t, u : int;
	a : list of string;
	n : int;
	p : array of ref FD;
	c : chan of int;

	p = array[2] of ref FD;
	s = m.w.wreadall();
	if(len s >= 5 && (s[0:5] == "From " || s[0:5] == "From:"))
		s = s[5:];
	for(t=0; t < len s && s[t]!='\n' && s[t]!='\t';){
		while(t < len s && (s[t]==' ' || s[t]==','))
			t++;
		u = t;
		while(t < len s && s[t]!=' ' && s[t]!=',' && s[t]!='\t' && s[t]!='\n')
			t++;
		if(t == u)
			break;
		a = s[u:t] :: a;
	}
	if(usessl)
		a = "sendmail" :: "-a" :: a;
	else
		a = "sendmail" :: a;
	while(t < len s && s[t]!='\n')
		t++;
	if(s[t] == '\n')
		t++;
	if(pipe(p) < 0)
		error("can't pipe: %r");
	c = chan of int;
	spawn run(a, c, p[0]);
	<-c;
	c = nil;
	p[0] = nil;
	n = len s - t;
	if(swrite(p[1], s[t:]) != n)
		fprint(stderr, "write to pipe failed: %r\n");
	p[1] = nil;
	# run() frees the arg list 
	buf = sprint("Mail/box/%d-R", m.id);
	m.w.wname(buf);
	m.w.wclean();
}

Box.read(readonly : int) : ref Box
{
	b : ref Box;
	m : ref Mesg;
	buf : string;

	b = ref Box;
	b.nm = 0;
	b.leng = 0;
	b.readonly = readonly;
	b.w = Win.wnew();
	b.w.wname("Mail/box/");
	b.cevent = chan of Event;
	spawn b.w.wslave(b.cevent);
	if(pwd == nil){
		b.w.wwritebody("Password:");
		b.w.wclean();
		b.w.wselect("$");
		b.w.ctlwrite("noecho\n");
		e := ref Event;
		for (;;) {
			sleep(1000);
			s := b.w.wreadall();
			lens := len s;
			if (lens >= 10 && s[0:9] == "Password:" && s[lens-1] == '\n') {
				pwd = s[9:lens-1];
				for (i := 0; i < lens; i++)
					s[i] = '\b';
				b.w.wwritebody(s);
				break;
			}
			alt {
				*e = <-b.cevent =>
					b.event(e);
					break;
				* =>
					break;
			}
		}
		b.w.ctlwrite("echo\n");
	}
	pop3open(1);
	pop3init(b);
	while((m = m.read(b)) != nil){
		m.next = b.m;
		b.m = m;
		b.nm++;
		m.id = b.nm;
	}
	pop3close(1);
	if (b.leng != b.nm)
		error("bad message count in Box.read()");
	for(m=b.m; m != nil; m=m.next){
		if(m.subj != nil)
			buf = sprint("%d\t%s\t %s", m.id, fromdisp(m), m.subj);
		else
			buf = sprint("%d\t%s", m.id, fromdisp(m));
		b.w.wwritebody(buf);
	}
	if(b.readonly)
		b.w.wtagwrite("Mail");
	else
		b.w.wtagwrite("Put Mail");
	b.w.wsetdump("/acme/mail", "Mail box");
	b.w.wclean();
	b.w.wselect("0");
	b.w.wdormant();
	b.cdel= chan of ref Mesg;
	b.cmore = chan of int;
	b.clean = True;
	return b;
}

Box.readmore(b : self ref Box, lck : int)
{
	m : ref Mesg;
	new : int;
	buf : string;

	new = False;
	leng := b.leng;
	n := 0;
	pop3open(lck);
	pop3more(b);
	while((m = m.read(b)) != nil){
		m.next = b.m;
		b.m = m;
		b.nm++;
		n++;
		m.id = b.nm;
		if(m.subj != nil)
			buf  = sprint("%d\t%s\t  %s", m.id, fromdisp(m), m.subj);
		else
			buf = sprint("%d\t%s", m.id, fromdisp(m));
		b.w.wreplace("0", buf);
		new = True;
	}
	pop3close(1);
	if (b.leng != leng+n)
		error("bad message count in Box.readmore()");
	if(new){
		if(b.clean)
			b.w.wclean();
		b.w.wselect("0;/.*(\\n[ \t].*)*");
		b.w.wshow();
	}
	b.w.wdormant();
}

Box.readline(b : self ref Box) : string
{
    	for (;;) {
		if(b.peekline != nil){
			b.line = b.peekline;
			b.peekline = nil;
		}else
			b.line = pop3next(b);
		# nulls appear in mailboxes! 
		if(b.line != nil && strchr(b.line, 0) >= 0)
			;
		else
			break;
	}
	return b.line;
}

Box.unreadline(b : self ref Box)
{
	b.peekline = b.line;
}

Box.slave(b : self ref Box)
{
	e : ref Event;
	m : ref Mesg;

	e = newevent();
	for(;;){
		alt{
		*e = <-b.cevent =>
			b.event(e);
			break;
		<-b.cmore =>
			b.readmore(1);
			break;
		m = <-b.cdel =>
			b.mdel(m);
			break;
		}
	}
}

Box.event(b : self ref Box, e : ref Event)
{
	e2, ea, eq : ref Event;
	s : string;
	t : int;
	n, na, nopen : int;

	e2 = newevent();
	ea = newevent();
	case(e.c1){
	'E' =>	# write to body; can't affect us 
		break;
	'F' =>	# generated by our actions; ignore 
		break;
	'K' =>	# type away; we don't care 
		break;
	'M' =>
		case(e.c2){
		'x' or 'X' =>
			if(e.flag & 2)
				*e2 = <-b.cevent;
			if(e.flag & 8){
				*ea = <-b.cevent;
				na = ea.nb;
				<- b.cevent;
			}else
				na = 0;
			s = string e.b[0:e.nb];
			# if it's a known command, do it 
			if((e.flag&2) && e.nb==0)
				s = string e2.b[0:e2.nb];
			if(na)
				s = sprint("%s %s", s, string ea.b[0:ea.nb]);
			# if it's a long message, it can't be for us anyway 
			if(!b.command(s))	# send it back 
				b.w.wwriteevent(e);
			if(na)
				s = nil;
			break;
		'l' or 'L' =>
			eq = e;
			if(e.flag & 2){
				*e2 = <-b.cevent;
				eq = e2;
			}
			s = string eq.b[0:eq.nb];
			if(eq.q1>eq.q0 && eq.nb==0)
				s = b.w.wread(eq.q0, eq.q1);
			nopen = 0;
			do{
				t = 0;
				(n, t) = strtoi(s);
				if(n>0 && (t == len s || s[t]==' ' || s[t]=='\t' || s[t]=='\n')){
					b.mopen(n);
					nopen++;
					s = s[t:];
				}
				while(s != nil && s[0]!='\n')
					s = s[1:];
			}while(s != nil);
			if(nopen == 0)	# send it back 
				b.w.wwriteevent(e);
			break;
		'I' or 'D' or 'd' or 'i' =>	# modify away; we don't care 
			break;
		* =>
			fprint(stdout, "unknown message %c%c\n", e.c1, e.c2);
			break;
		}
	* =>
		fprint(stdout, "unknown message %c%c\n", e.c1, e.c2);
		break;
	}
}

Box.mopen(b : self ref Box, id : int)
{
	m : ref Mesg;

	for(m=b.m; m != nil; m=m.next)
		if(m.id == id){
			m.open();
			break;
		}
}

Box.mdel(b : self ref Box, dm : ref Mesg)
{
	m : ref Mesg;
	buf : string;

	if(dm.id){
		for(m=b.m; m!=nil && m!=dm; m=m.next)
			;
		if(m == nil)
			error(sprint("message %d not found", dm.id));
		m.deleted = 1;
		# remove from screen: use acme to help 
		buf = sprint("/^%d	.*\\n(^[ \t].*\\n)*/", m.id);
		b.w.wreplace(buf, "");
	}
	dm.free();
	b.clean = False;
}

Box.command(b : self ref Box, s : string) : int
{
	t : int;
	m : ref Mesg;

	while(s[0]==' ' || s[0]=='\t' || s[0]=='\n')
		s = s[1:];
	if(len s >= 4 && s[0:4] == "Mail"){
		s = s[4:];
		while(s != nil && (s[0]==' ' || s[0]=='\t' || s[0]=='\n'))
			s = s[1:];
		t = 0;
		while(t < len s && s[t] && s[t]!=' ' && s[t]!='\t' && s[t]!='\n')
			t++;
		m = b.m;		# avoid warning message on b.m.mkmail(...)
		m.mkmail(b, s[0:t]);
		return True;
	}
	if(s == "Del"){

		if(!b.clean){
			b.clean = True;
			fprint(stderr, "mail: mailbox not written\n");
			return True;
		}
		postnote(PNGROUP, pctl(0, nil), "kill");
		killing = 1;
		pctl(NEWPGRP, nil);
		b.w.wdel(True);
		for(m=b.m; m != nil; m=m.next)
			m.w.wdel(False);
		exit;
		return True;
	}
	if(s == "Put"){
		if(b.readonly)
			fprint(stderr, "Mail is read-only\n");
		else
			b.rewrite();
		return True;
	}
	return False;
}

Box.rewrite(b : self ref Box)
{
	prev, m : ref Mesg;

	if(b.clean){
		b.w.wclean();
		return;
	}
	prev = nil;
	pop3open(1);
	for(m=b.m; m!=nil; m=m.next) {
		if (m.deleted && pop3del(m.popno) >= 0) {
			b.leng--;
			if (prev == nil)
				b.m=m.next;
			else
				prev.next=m.next;
		}
		else
			prev = m;
	}
	# must update pop nos now so don't unlock pop3
	pop3close(0);
	b.w.wclean();
	b.clean = True;
	b.readmore(0);	# updates pop nos
}

wkday := array[] of {
	"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
};

month := array[] of {
	"Jan", "Feb", "Mar", "Apr", "May", "Jun",
	"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
};

blanktm: Tm;
mktime(s: string): int
{
	tm := ref blanktm;

#	tm = daytime->string2tm(s);
#	if(tm == nil)
#		return daytime->now();
#	else
#		daytime->tm2epoch(tm);

	(nil, fl) := sys->tokenize(s, " \t\n\r,():");

	
	day := hd fl;
	for(i := 0; i < len wkday; i++)
		if(wkday[i] == day)
			break;
	if(i < len wkday){
		tm.wday = i;
		fl = tl fl;
	}
	tm.mday = int hd fl;
	fl = tl fl;

	mon := hd fl;
	for(i = 0; i < len month; i++)
		if(month[i] == mon)
			break;
	tm.mon = i;
	fl = tl fl;

	tm.year = int hd fl - 1900;
	fl = tl fl;

	tm.hour = int hd fl;
	fl = tl fl;
	tm.min = int hd fl;
	fl = tl fl;
	tm.sec = int hd fl;
	fl = tl fl;

	zone := hd fl;
	if(zone[0] == '-' || zone[1] == '+'){
		tm.tzoff = (int zone[1:3] * 60 * 60) + (int zone[3:5] * 60);
		if(zone[0] == '-')
			tm.tzoff = - tm.tzoff;
	}else
		tm.zone = zone;
	return daytime->tm2epoch(tm);
}

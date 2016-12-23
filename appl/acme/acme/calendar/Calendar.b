implement Calendar;

#
# Copyright © 2000 Vita Nuova Limited. All rights reserved.
# Copyright © 2006 Caerwyn Jones.

include "sys.m";
	sys: Sys;
	pctl, open, fprint, print, OWRITE: import sys;
include "draw.m";
	draw: Draw;
	Font, Point, Rect: import draw;
include "daytime.m";
	daytime: Daytime;
	Tm: import Daytime;
include "readdir.m";
include "arg.m";
	arg: Arg;
include "sh.m";
include "bufio.m";
include "acmewin.m";
	acmewin: Acmewin;
	Win, Event: import acmewin;
include "string.m";
	str: String;

Calendar: module {
	init: fn(ctxt: ref Draw->Context, argv: list of string);
};

Cal: adt {
	onepos: int;
	top: ref Win;
	sched: ref Schedule;
	date: int;
	marked: array of int;
	make: fn(top: ref Win, sched: ref Schedule): ref Cal;
	show: fn(cal: self ref Cal, date: int);
	mark: fn(cal: self ref Cal, ent: Entry);
};

Entry: adt {
	date: int;		# YYYYMMDD
	mark: int;
};

Sentry: adt {
	ent: Entry;
	file: int;
};

Schedule: adt {
	dir: string;
	entries: array of Sentry;
	new: fn(dir: string): (ref Schedule, string);
	getentry: fn(sched: self ref Schedule, date: int): (int, Entry);
	readentry: fn(sched: self ref Schedule, date: int): (Entry, string);
	setentry: fn(sched: self ref Schedule, ent: Entry, data: string): (int, string);
};

DBFSPATH: con "/dis/rawdbfs.dis";
SCHEDDIR: con "/mnt/schedule";

stderr: ref Sys->FD;
days := array[] of {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri",  "Sat"};
months := array[] of {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
	dirty := 0;

usage()
{
	sys->fprint(stderr, "usage: calendar [/mnt/schedule | schedfile]\n");
	raise "fail:usage";
}

init(ctxt: ref Draw->Context, argv: list of string)
{
	loadmods();
	if (ctxt == nil) {
		sys->fprint(sys->fildes(2), "calendar: no window context\n");
		raise "fail:bad context";
	}
	arg->init(argv);
	while ((opt := arg->opt()) != 0) {
		case opt {
		* =>
			usage();
		}
	}
	argv = arg->argv();
	scheddir := SCHEDDIR;
	if (argv != nil)
		scheddir = hd argv;

	(sched, err) := Schedule.new(scheddir);
	if (sched == nil && scheddir != SCHEDDIR)
		sys->fprint(stderr, "cal: cannot load schedule: %s\n", err);
	currtime := daytime->local(daytime->now());
	if (currtime == nil) {
		sys->fprint(stderr, "cannot get local time: %r\n");
		raise "fail:failed to get local time";
	}
	sys->pctl(Sys->NEWPGRP|Sys->FORKNS, nil);

	top := Win.wnew();
	top.wname("Calendar");
	top.wtagwrite("Prev Next Get");
	top.wsetdump("/", "Calendar " + scheddir);

	cal:= Cal.make(top, sched);
	cal.date = tm2date(currtime);
	showdate(cal, cal.date);
	sync := chan of int;
	spawn clock(top, sync);
	<-sync;

	mainwin(cal);
}

doexec(cal: ref Cal, cmd: string): int
{
	cmd = skip(cmd, "");
	arg: string;
	(cmd, arg) = str->splitl(cmd, " ");
	if(arg != nil)
		arg = arg[1:];
	case cmd {
	"Get" =>
		showdate(cal, cal.date);
	"Put" =>
		if (save(cal) != -1)
			dirty = 0;
	"Next" =>
		ndate := incmonth(cal.date);
		showdate(cal, ndate);
		cal.date = ndate;
	"Prev" =>
		ndate := decmonth(cal.date);
		showdate(cal, ndate);
		cal.date = ndate;
	"DelEnt" =>
		cal.mark(Entry(cal.date, 0));
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

mainwin(cal: ref Cal)
{
	w := cal.top;
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
				n := doexec(cal, s);
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
					if(n>0){
						spawn newwin(cal, n);
						nopen++;
						s = s[t:];
					}
					while(s != nil && ! (s[0] >= '0' && s[0] <= '9')) 
						s = s[1:];
				}while(s != nil);
				if(nopen == 0)	# send it back 
					w.wwriteevent(ref e);
			}
		}
	}
	w.wdel(1);
	postnote(1, pctl(0, nil), "kill");
}

newwin(cal: ref Cal, day: int)
{
	sys->pctl(Sys->NEWPGRP, nil);
	w := Win.wnew();
	(y, m, nil) := date2ymd(cal.date);
	date := ymd2date(y, m, day);
	(nil, s) := cal.sched.readentry(date);
	w.wname(sys->sprint("%d", date));
	w.wtagwrite("Put");
	w.ctlwrite("mark\n");
	w.wwritebody(s);
	w.wclean();
	ncal := ref Cal;
	ncal.top = w;
	ncal.sched = cal.sched;
	ncal.date = date;
	ncal.marked = array[31] of {* => 0};
	spawn mainwin(ncal);
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

save(cal: ref Cal): int
{
	s := cal.top.wreadall();
	mark := 0;
	if(s != "")
		mark = 1;
	ent := Entry(cal.date, mark);
	cal.mark(ent);
	(ok, err) := cal.sched.setentry(ent, s);
	if (ok == -1) {
		sys->fprint(stderr, "Cannot save entry: %s\n", err);
		return -1;
	}
	cal.top.wclean();
	return 0;
}

showdate(cal: ref Cal, date: int)
{
 	cal.show(date);
#	(ent, s) := cal.sched.readentry(date);
}

nomod(s: string)
{
	sys->fprint(stderr, "cal: cannot load %s: %r\n", s);
	raise "fail:bad module";
}

loadmods()
{
	sys = load Sys Sys->PATH;
	stderr = sys->fildes(2);
	draw = load Draw Draw->PATH;
	daytime = load Daytime Daytime->PATH;
	if (daytime == nil)
		nomod(Daytime->PATH);
	acmewin = load Acmewin Acmewin->PATH;
	if (acmewin == nil)
		nomod(Acmewin->PATH);
	acmewin->init();
	arg = load Arg Arg->PATH;
	if (arg == nil)
		nomod(Arg->PATH);
	str = load String String->PATH;
	if (str == nil)
		nomod(String->PATH);
}


validtm(t: ref Daytime->Tm): int
{
	if (t.hour < 0 || t.hour > 23
			|| t.min < 0 || t.min > 59
			|| t.sec < 0 || t.sec > 59
			|| t.mday < 1 || t.mday > 31
			|| t.mon < 0 || t.mon > 11
			|| t.year < 70 || t.year > 137)
		return 0;
	if (t.mon == 1 && dysize(t.year+1900) > 365)
		return t.mday <= 29;
	return t.mday <= dmsize[t.mon];
}

clock(top: ref Win, sync: chan of int)
{
	fd := sys->open("/dev/time", Sys->OREAD);
	if (fd == nil) {
		sync <-= -1;
		return;
	}
	buf := array[128] of byte;
	for (;;) {
		sys->seek(fd, big 0, Sys->SEEKSTART);
		n := sys->read(fd, buf, len buf);
		if (n < 0) {
			sys->fprint(stderr, "cal: could not read time: %r\n");
			if (sync != nil)
				sync <-= -1;
			break;
		}
		ms := big string buf[0:n] / big 1000;
		ct := ms / big 1000;
		t := daytime->local(int ct);

		s := sys->sprint("%s_%s_%d_%.2d:%.2d",
			days[t.wday], months[t.mon], t.mday, t.hour, t.min);
		if (sync != nil) {
			sync <-= sys->pctl(0, nil);
			sync = nil;
		}
		top.wname(s);
		sys->sleep(int ((ct + big 60) * big 1000 - ms));
	}
}

# "the world is the lord's and all it contains,
# save the highlands and islands, which belong to macbraynes"
Cal.make(top: ref Win, sched: ref Schedule): ref Cal
{
	cal := ref Cal;
	cal.top = top;
	cal.sched = sched;
	cal.marked = array[31] of {* => 0};
	return cal;
}

dayw :=	" S\tM\tTu\tW\tTh\tF\tS";
smon := array[] of {
	"January", "February", "March", "April",
	"May", "June", "July", "August",
	"September", "October", "November", "December",
};

Cal.show(cal: self ref Cal, date: int)
{
	month := (date / 100) % 100;
	year := date / 10000;

	cal.top.wreplace(",", "");
	cal.top.wwritebody(sys->sprint("\t   %s %ud\n", smon[month-1], year));
	cal.top.wwritebody(sys->sprint("%s\n", dayw));
	lines := pcal(month, year, cal);
	for(i := 0; i < len lines; i++){
		cal.top.wwritebody(lines[i]);
		cal.top.wwritebody("\n");
	}
	cal.top.wclean();
	cal.date = date;
}

Cal.mark(nil: self ref Cal, ent: Entry)
{
	if (ent.date / 100 != ent.date / 100)
		return;
}

body2entry(body: string): (int, Entry, string)
{
	for (i := 0; i < len body; i++)
		if (body[i] == '\n')
			break;
	if (i == len body)
		return (-1, (-1, -1), "invalid schedule header (no newline)");
	(n, toks) := sys->tokenize(body[0:i], " \t\n");
	if (n < 2)
		return (-1, (-1, -1), "invalid schedule header (too few fields)");
	date := int hd toks;
	(y, m, d) := (date / 10000, (date / 100) % 100, date%100);
	if (y < 1970 || y > 2037 || m > 12 || m < 1 || d > 31 || d < 1)
		return (-1, (-1,-1), sys->sprint("invalid date (%.8d) in schedule header", date));
	e := Entry(ymd2date(y, m, d), int hd tl toks);
	return (0, e, body[i+1:]);
}

startdbfs(f: string): (string, string)
{
	dbfs := load Command DBFSPATH;
	if (dbfs == nil)
		return (nil, sys->sprint("cannot load %s: %r", DBFSPATH));
	sync := chan of string;
	spawn rundbfs(sync, dbfs, f, SCHEDDIR);
	e := <-sync;
	if (e != nil)
		return (nil, e);
	return (SCHEDDIR, nil);
}

rundbfs(sync: chan of string, dbfs: Command, f, d: string)
{
	sys->pctl(Sys->FORKFD, nil);
	{
		dbfs->init(nil, "dbfs" :: "-r" :: f :: d :: nil);
		sync <-= nil;
	}exception e{
	"fail:*" =>
		sync <-= "dbfs failed: " + e[5:];
		exit;
	}
}

Schedule.new(d: string): (ref Schedule, string)
{
	(rc, info) := sys->stat(d);
	if (rc == -1)
		return (nil, sys->sprint("cannot find %s: %r", d));
	if ((info.mode & Sys->DMDIR) == 0) {
		err: string;
		(d, err) = startdbfs(d);
		if (d == nil)
			return (nil, err);
	}
	(rc, nil) = sys->stat(d + "/new");
	if (rc == -1)
		return (nil, "no dbfs mounted on " + d);
		
	readdir := load Readdir Readdir->PATH;
	if (readdir == nil)
		return (nil, sys->sprint("cannot load %s: %r", Readdir->PATH));
	sched := ref Schedule;
	sched.dir = d;
	(de, nil) := readdir->init(d, Readdir->NONE);
	if (de == nil)
		return (nil, "could not read schedule directory");
	buf := array[Sys->ATOMICIO] of byte;
	sched.entries = array[len de] of Sentry;
	ne := 0;
	for (i := 0; i < len de; i++) {
		if (!isnum(de[i].name))
			continue;
		f := d + "/" + de[i].name;
		fd := sys->open(f, Sys->OREAD);
		if (fd == nil) {
			sys->fprint(stderr, "cal: cannot open %s: %r\n", f);
		} else {
			n := sys->read(fd, buf, len buf);
			if (n == -1) {
				sys->fprint(stderr, "cal: error reading %s: %r\n", f);
			} else {
				(ok, e, err) := body2entry(string buf[0:n]);
				if (ok == -1)
					sys->fprint(stderr, "cal: error on entry %s: %s\n", f, err);
				else
					sched.entries[ne++] = (e, int de[i].name);
				err = nil;
			}
		}
	}
	sched.entries = sched.entries[0:ne];
	sortentries(sched.entries);
	return (sched, nil);
}

Schedule.getentry(sched: self ref Schedule, date: int): (int, Entry)
{
	if (sched == nil)
		return (-1, (-1, -1));
	ent := search(sched, date);
	if (ent == -1)
		return (-1, (-1,-1));
	return (0, sched.entries[ent].ent);
}

Schedule.readentry(sched: self ref Schedule, date: int): (Entry, string)
{
	if (sched == nil)
		return ((-1, -1), nil);
	ent := search(sched, date);
	if (ent == -1)
		return ((-1, -1), nil);
	(nil, fno) := sched.entries[ent];

	f := sched.dir + "/" + string fno;
	fd := sys->open(f, Sys->OREAD);
	if (fd == nil) {
		sys->fprint(stderr, "cal: cannot open %s: %r", f);
		return ((-1, -1), nil);
	}
	buf := array[Sys->ATOMICIO] of byte;
	n := sys->read(fd, buf, len buf);
	if (n == -1) {
		sys->fprint(stderr, "cal: cannot read %s: %r", f);
		return ((-1, -1), nil);
	}
	(ok, e, body) := body2entry(string buf[0:n]);
	if (ok == -1) {
		sys->fprint(stderr, "cal: couldn't get body in file %s: %s\n", f, body);
		return ((-1, -1), nil);
	}
	return (e, body);
}	

writeentry(fd: ref Sys->FD, ent: Entry, data: string): (int, string)
{
	b := array of byte (sys->sprint("%d %d\n", ent.date, ent.mark) + data);
	if (len b > Sys->ATOMICIO)
		return (-1, "entry is too long");
	if (sys->write(fd, b, len b) != len b)
		return (-1, sys->sprint("cannot write entry: %r"));
	return (0, nil);
}
	
Schedule.setentry(sched: self ref Schedule, ent: Entry, data: string): (int, string)
{
	if (sched == nil)
		return (-1, "no schedule");
	idx := search(sched, ent.date);
	if (idx == -1) {
		if (data == nil)
			return (0, nil);
		fd := sys->open(sched.dir + "/new", Sys->OWRITE);
		if (fd == nil)
			return (-1, sys->sprint("cannot open new: %r"));
		(ok, info) := sys->fstat(fd);
		if (ok == -1)
			return (-1, sys->sprint("cannot stat new: %r"));
		if (!isnum(info.name))
			return (-1, "new dbfs entry is not numeric");
		err: string;
		(ok, err) = writeentry(fd, ent, data);
		if (ok == -1)
			return (ok, err);
		(fd, data) = (nil, nil);
		e := sched.entries;
		for (i := 0; i < len e; i++)
			if (ent.date < e[i].ent.date)
				break;
		ne := array[len e + 1] of Sentry;
		(ne[0:],  ne[i], ne[i+1:]) = (e[0:i], (ent, int info.name), e[i:]);
		sched.entries = ne;
		return (0, nil);
	} else {
		fno := sched.entries[idx].file;
		f := sched.dir + "/" + string fno;
		if (data == nil) {
			sys->remove(f);
			sched.entries[idx:] = sched.entries[idx+1:];
			sched.entries = sched.entries[0:len sched.entries - 1];
			return (0, nil);
		} else {
			sched.entries[idx] = (ent, fno);
			fd := sys->open(f, Sys->OWRITE);
			if (fd == nil)
				return (-1, sys->sprint("cannot open %s: %r", sched.dir + "/" + string fno));
			return writeentry(fd, ent, data);
		}
	}
}

search(sched: ref Schedule, date: int): int
{
	e := sched.entries;
	lo := 0;
	hi := len e - 1;
	while (lo <= hi) {
		mid := (lo + hi) / 2;
		if (date < e[mid].ent.date)
			hi = mid - 1;
		else if (date > e[mid].ent.date)
			lo = mid + 1;
		else
			return mid;
	}
	return -1;
}

sortentries(a: array of Sentry)
{
	m: int;
	n := len a;
	for(m = n; m > 1; ) {
		if(m < 5)
			m = 1;
		else
			m = (5*m-1)/11;
		for(i := n-m-1; i >= 0; i--) {
			tmp := a[i];
			for(j := i+m; j <= n-1 && tmp.ent.date > a[j].ent.date; j += m)
				a[j-m] = a[j];
			a[j-m] = tmp;
		}
	}
}

isnum(s: string): int
{
	for (i := 0; i < len s; i++)
		if (s[i] < '0' || s[i] > '9')
			return 0;
	return 1;
}

tm2date(t: ref Tm): int
{
	if (t == nil)
		return 19700001;
	return ymd2date(t.year+1900, t.mon+1, t.mday);
}

date2ymd(date: int): (int, int, int)
{
	return (date / 10000, (date / 100) % 100, date%100);
}

ymd2date(y, m, d: int): int
{
	return d + m* 100 + y * 10000;
}

adddays(date, delta: int): int
{
	t := ref blanktm;
	t.mday = date % 100;
	t.mon = (date / 100) % 100;
	t.year = (date / 10000) - 1900;
	t.hour = 12;
	e := daytime->tm2epoch(t);
	e += delta * 24 * 60 * 60;
	t = daytime->gmt(e);
	if (!validtm(t))
		return date;
	return tm2date(t);
}

incmonth(date: int): int
{
	(y,m,d) := date2ymd(date);
	if (m < 12)
		m++;
	else if (y < 2037)
		(y, m) = (y+1, 1);
	(n, nil) := monthinfo(m, y);
	if (d > n)
		d = n;
	return ymd2date(y,m,d);
}

decmonth(date: int): int
{
	(y,m,d) := date2ymd(date);
	if (m > 1)
		m--;
	else if (y > 1970)
		(y, m) = (y-1, 12);
	(n, nil) := monthinfo(m, y);
	if (d > n)
		d = n;
	return ymd2date(y,m,d);
}

dmsize := array[] of {
	31, 28, 31, 30, 31, 30,
	31, 31, 30, 31, 30, 31
};

dysize(y: int): int
{
	if( (y%4) == 0 && (y % 100 != 0 || y % 400 == 0) )
		return 366;
	return 365;
}

blanktm: Tm;

# return number of days in month and
# starting day of month/year.
monthinfo(mon, year: int): (int, int)
{
	t  := ref blanktm;
	t.mday = 1;
	t.mon = mon-1;
	t.year = year - 1900;
	t = daytime->gmt(daytime->tm2epoch(t));
	md := dmsize[t.mon];
	if (dysize(year) == 366 && t.mon == 1)
		md++;
	return (md, t.wday);
}


#following code takend from /appl/cmd/cal.b

mon := array[] of {
	0,
	31, 29, 31, 30,
	31, 30, 31, 31,
	30, 31, 30, 31,
};

pcal(m: int, y: int, cal: ref Cal): array of string
{
	d := jan1(y);
	mon[9] = 30;

	case (jan1(y+1)+7-d)%7 {

	#
	#	non-leap year
	#
	1 =>
		mon[2] = 28;

	#
	#	leap year
	#
	2 =>
		mon[2] = 29;

	#
	#	1752
	#
	* =>
		mon[2] = 29;
		mon[9] = 19;
	}
	for(i:=1; i<m; i++)
		d += mon[i];
	d %= 7;
	lines := array[6] of string;
	l := 0;
	s := "";
	base := y * 10000 + m * 100;
	for(i = 0; i < d; i++)
		s += "\t";
	for(i=1; i<=mon[m]; i++) {
		if(i==3 && mon[m]==19) {
			i += 11;
			mon[m] += 11;
		}
		(ok, ent) := cal.sched.getentry(base + i);
		if (ok != -1 && ent.mark){
		#	cal.mark(ent);
			s += sys->sprint("%2d⁺", i);
		}else
			s += sys->sprint("%2d", i);
		if(++d == 7) {
			d = 0;
			lines[l++] = s;
			s = "";
		}else
			s[len s] = '\t';
	}
	if(s != nil){
		while(s[len s-1] == ' ')
			s = s[:len s-1];
		lines[l] = s;
	}
	return lines;
}

#
#	return day of the week
#	of jan 1 of given year
#
jan1(y: int): int
{
#
#	normal gregorian calendar
#	one extra day per four years
#

	d := 4+y+(y+3)/4;

#
#	julian calendar
#	regular gregorian
#	less three days per 400
#

	if(y > 1800) {
		d -= (y-1701)/100;
		d += (y-1601)/400;
	}

#
#	great calendar changeover instant
#

	if(y > 1752)
		d += 3;

	return d%7;
}

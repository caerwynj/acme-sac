implement Rect;

include "sys.m";
include "draw.m";
include "env.m";
include "string.m";

sys: Sys;
open, pread, pwrite, print, fprint, sprint, fildes, FD, ORDWR, OREAD,OWRITE: import sys;
str: String;

Rect: module{
	init: fn(nil: ref Draw->Context, argv: list of string);
};

Win: adt{
	id: int;
	ctl, addr, data: ref FD;
	
	wopen: fn(id: int): ref Win;
	winctl: fn(w: self ref Win, m: string): int;
	wwriteaddr: fn(w: self ref Win, a: string): int;
	wreadaddr: fn(w: self ref Win): (int, int);
	wwritedata: fn(w: self ref Win, d: string): int;
	
	fopen: fn(w: self ref Win, f: string): ref FD;
};

init(nil: ref Draw->Context, argv: list of string)
{
	replace: string;
	
	sys = load Sys Sys->PATH;
	if((env := load Env Env->PATH) == nil)
		fatal("can't load " + Env->PATH);
	if((str = load String String->PATH) == nil)
		fatal("can't load " + String->PATH);

	case len argv {
	* =>	fprint(fildes(2), "usage: rect [replacement] (in an acme text window)\n");
		exit;
	1 =>	replace = "";
	2 => replace = hd tl argv;
	}

	s := env->getenv("acmewin");
	if(s == nil)
		fatal("$acmewin not set");
	id := int s;
	if(id == 0)
		fatal("bad $acmewin: " + s);
	w := Win.wopen(id);
	
	# get current selection
	w.winctl("addr=dot\n");
	(q0, q1) := w.wreadaddr();
	
	# compute left and right offsets
	n := w.wwriteaddr(".-/^");
	(q, nil) := w.wreadaddr();
	if(q > q0)	# acme bug
		q = 0;
	left := q0 - q;
	
	w.wwriteaddr(sprint("#%d,#%d", q1, q1));
	n = w.wwriteaddr(".-+");
	(q, nil) = w.wreadaddr();
	right := q1 - q;
	
	if(right < left)
		fatal(sprint("end column %d < start column %d", right, left));
	
	# there's at least one line.
	addr := array[80] of int;
	naddr := 0;
	addr[naddr++] = q0 - left;
	
	# find all the others
	for(;;){
		w.wwriteaddr(sprint("#%d/^", addr[naddr-1]+1));
		(q, nil) = w.wreadaddr();
		if(q<=addr[naddr-1] || q>=q1)
			break;
		if(naddr == len addr)
			addr = (array[naddr+80] of int)[0:] = addr;
		addr[naddr++] = q;
	}
	
	# now apply the change to each
	# in reverse to preserve addresses

	# no more undo marks for now
	w.winctl("mark");	# acme bug
	w.winctl("nomark");
	length := 0;
	for(i:=naddr-1; i>=0; i--){
		if(i == naddr-1)		# big enough
			length = right+1;
		else
			length = addr[i+1] - addr[i];
		if(length <= left)		# too short
			continue;
		
		q0 = addr[i] + left;
		if(length <= right)
			q1 = addr[i] + length - 1;
		else
			q1 = addr[i] + right;
		w.wwriteaddr(sprint("#%ud,#%ud", q0, q1));
		w.wwritedata(replace);
	}
}

Win.wopen(id: int): ref Win
{
	w := ref Win;
	w.id = id;
	w.ctl = w.fopen("ctl");
	w.addr = w.fopen("addr");
	w.data = w.fopen("data");
	return w;
}

Win.winctl(w: self ref Win, m: string): int
{
	return swrite(w.ctl, m);
}

Win.wwriteaddr(w: self ref Win, a: string): int
{
	return swrite(w.addr, a);
}

Win.wreadaddr(w: self ref Win): (int, int)
{
	buf := array[40] of byte;
	n := pread(w.addr, buf, len buf, big 0);
	if(n <= 0)
		return (-1, -1);
	(q0, s) := str->toint(string buf[:n], 10);
	(q1, nil) := str->toint(s, 10);
	return (q0, q1);
}

Win.wwritedata(w: self ref Win, d: string): int
{
	return swrite(w.data, d);
}

Win.fopen(w: self ref Win, f: string): ref FD
{
	fd := open(sprint("/chan/%d/%s", w.id, f), ORDWR);
	if(fd == nil)
		fatal(sprint("can't open window %s file: %r", f));
	return fd;
}

swrite(fd: ref FD, s: string): int
{
	a := array of byte s;
	n := pwrite(fd, a, len a, big 0);
	if(n == len a)
		return len s;
	return n;
}

fatal(s: string)
{
	fprint(fildes(2), "rect: %s\n", s);
	raise "fail:"+s;
}

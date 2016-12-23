implement acmeevent;

include "sys.m";
	sys: Sys;
include "draw.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "string.m";
	str: String;
 
acmeevent: module
{
	init: fn(nil: ref Draw->Context, nil: list of string);
};

init(nil: ref Draw->Context, nil: list of string)
{
	b: ref Iobuf;
	c1, c2, q0, q1, eq0, eq1, flag, nr: int;
	buf, buf2, buf3: string;

	sys = load Sys Sys->PATH;
	if((bufio = load Bufio Bufio->PATH) == nil)
		fatal("can't load " + Bufio->PATH);
	if((str = load String String->PATH) == nil)
		fatal("can't load " + String->PATH);

	b = bufio->fopen(sys->fildes(0), Bufio->OREAD);
	if(b == nil)
		fatal("nil b");
	for(;;){
		(c1, c2, q0, q1, flag, nr, buf) = getevent(b);
		eq0 = q0;
		eq1 = q1;
		buf2 = "";
		buf3 = "";
		if(flag & 2)	# null string with non-null expansion
			(nil, nil, eq0, eq1, nil, nr, buf) = getevent(b);
		if(flag & 8){	# chorded argument
			(nil, nil, nil, nil, nil, nil, buf2) = getevent(b);
			(nil, nil, nil, nil, nil, nil, buf3) = getevent(b);
		}
		sys->print("event %c %c %d %d %d %d %d %d %q %q %q\n",
				c1, c2, q0, q1, eq0, eq1, flag, nr, buf, buf2, buf3);
	}
}

getn(b: ref Iobuf): int
{
	n: int;
	s: string;
	
	(n, s) = str->toint(b.gets(' '), 10);
	if(s[0] != ' ')
		fatal("bad number syntax");
	return n;
}

getevent(b: ref Iobuf): (int, int, int, int, int, int, string)
{
	c1, c2, q0, q1, flag, nr, i: int;
	buf: string;

	c1 = b.getc();
	if(c1 == -1)
		exit;
	c2 = b.getc();
	q0 = getn(b);
	q1 = getn(b);
	flag = getn(b);
	nr = getn(b);
	for(i=0; i<nr; i++)
		buf[i] = b.getc();
	if(b.getc() != '\n')
		fatal("expected newline");
	
	return (c1, c2, q0, q1, flag, nr, buf);
}

fatal(s: string)
{
	sys->fprint(sys->fildes(2), "acmeevent: %s: %r\n", s);
	exit;
}

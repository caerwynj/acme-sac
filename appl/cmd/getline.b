implement Getline;
include "sys.m"; 
	sys: Sys;
	read, write, fildes, open, print, fprint, FD, OREAD: import sys;
include "draw.m";
include "arg.m";
	arg: Arg;
include "string.m";
	str: String;

Getline: module {
	init: fn(nil: ref Draw->Context, argv: list of string);
};

usage()
{
	sys->fprint(sys->fildes(2), "usage: getline  [-m] [-n nlines] [files...]\n");
	raise "fail:usage";
}

multi: int;
nlines: int;
stderr, stdout: ref FD;

init(nil: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	arg = load Arg Arg->PATH;
	str = load String String->PATH;
	stderr = fildes(2);
	stdout = fildes(1);
	arg->init(argv);
	while((c := arg->opt()) != 0)
		case c {
		'm' => 
			multi = 1;
		'n' => 
			s := arg->arg();
			(nlines, nil) = str->toint(s, 10);
		* =>
			usage();
		}
	argv = arg->argv();
	if(len argv == 0)
		usage();
	for(; argv != nil; argv = tl argv){
		fd := open(hd argv, OREAD);
		if(fd == nil){
			fprint(stderr, "getline: can't open %s: %r\n", hd argv);
			exit;
		}
		lines(fd, hd argv);
	}
}

line(fd: ref FD, file: string): int
{
	n, m: int;
	buf:= array[1024] of byte;

	for(m=0; ; ){
		c:= array[1] of byte;
		n = read(fd, c, 1);
		if(n < 0){
			fprint(stderr, "getline: error reading %s: %r\n", file);
			exit;
		}
		if(n == 0){
			break;
		}
		buf[m++] = c[0];
		if(int c[0] == '\n')
			break;
	}
	if(m > 0)
		write(stdout, buf, m);
	return m;
}

lines(fd: ref FD, file: string)
{
	do{
		if(line(fd, file) == 0)
			break;
	}while(multi || --nlines>0);
}

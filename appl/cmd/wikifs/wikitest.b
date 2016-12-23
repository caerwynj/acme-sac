implement Wikipost;

include "sys.m";
	sys: Sys;
include "draw.m";

Wikipost: module { init: fn(ctxt: ref Draw->Context, args: list of string); };

error(s: string)
{
	sys->fprint(sys->fildes(2), "%s", s);
	exit;
}

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	fd := sys->open("/mnt/wiki/new", Sys->ORDWR);
	if(fd == nil)
		error("open new");
	args = tl args;
	in := sys->open(hd args, Sys->OREAD);
	if(in == nil)
		error("open input");
	buf := array[8192] of byte;
	n := sys->read(in, buf, len buf);
	sys->write(fd, buf[0:n], n);

	sys->write(fd, buf, 0);
	sys->seek(fd, big 0, Sys->SEEKSTART);
	n = sys->read(fd, buf, len buf);
	sys->print("%s\n", string buf[0:n]);
}

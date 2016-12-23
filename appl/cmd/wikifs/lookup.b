implement Lookup;

include "sys.m";
include "wiki.m";
include "draw.m";

Lookup: module {
	init: fn(ctxt: ref Draw->Context, args: list of string);
};

init(nil: ref Draw->Context, args:list of string)
{
	sys := load Sys Sys->PATH;
	wiki := load Wiki Wiki->PATH;
	wiki->init();
	args = tl args;
	sys->print("%d\n", wiki->nametonum(hd args));
}

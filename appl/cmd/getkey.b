implement Getkey;

include "sys.m";
include "draw.m";
include "factotum.m";

Getkey: module {
	init:fn(nil: ref Draw->Context, args: list of string);
};

init(nil: ref Draw->Context, args: list of string)
{
	sys := load Sys Sys->PATH;
	factotum := load Factotum Factotum->PATH;
	
	factotum->init();
	args = tl args;
	keyspec := "";
	if(args != nil)
		keyspec = hd args;
	(user, password) := factotum->getuserpasswd(sys->sprint("%s", keyspec));
	sys->print("%s %s\n", user, password);
}

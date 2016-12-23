implement Web;
include "sys.m";
sys:	Sys;
print, sprint: import sys;
include "draw.m";
include "string.m";
stringmod: String;

include "url.m";
urlmod: Url;
ParsedUrl: import urlmod;

include "web.m";
include "webget.m";

webio:	ref Sys->FD;
DEBUG: con 0;

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	stringmod = load String String->PATH;
	urlmod = load Url Url->PATH;
	urlmod->init();
	webstart();
	url := "http://google.com";
	
	args = tl args;
	if(len args >= 1)
		url = hd args;
	(doctype, nil, clen) := webget(url, url, "text/html,text/plain,image/x-compressed,*/*");
	if(doctype==nil)
		error("no page '"+doctype+"'", url);
	b := webcontents(clen);
	sys->print("%s", string b);
}

init0()
{
	sys = load Sys Sys->PATH;
	stringmod = load String String->PATH;
	urlmod = load Url Url->PATH;
	urlmod->init();
	webstart();
}

readurl(url: string): array of byte
{
	(doctype, nil, clen) := webget(url, url, "text/html,text/plain,image/x-compressed,*/*");
	if(doctype==nil){
		error("no page '"+doctype+"'", url);
		return nil;
	}
	return  webcontents(clen);
}

posturl(url, msg: string): array of byte
{
	(doctype, nil, clen) := webpost(url, url, "text/html,text/plain,image/x-compressed,*/*", msg);
	if(doctype==nil){
		error("no page '"+doctype+"'", url);
		return nil;
	}
	return  webcontents(clen);
}

error(msg, url: string)
{
	if(DEBUG)
		sys->print("ERROR: %s: %s\n", url, msg);
}

webstart(): string
{
	webio = sys->open("/chan/webget", sys->ORDWR);
	if(webio == nil) {
		webget := load Webget Webget->PATH;
		if(webget == nil)
			return ("can't load webget from " + Webget->PATH);
		spawn webget->init(nil, nil);
		ntries := 0;
		while(webio == nil && ntries++ < 10)
			webio = sys->open("/chan/webget", sys->ORDWR);
		if(webio == nil)
			return "error connecting to web";
	}
	return "";
}

getstatus(loc: string): (string, string, int)
{
	clen := 0;
	dtype := "";
	nbase := "";
	bstatus := array[1000] of byte;
	n := sys->read(webio, bstatus, len bstatus);
	if(n < 0)
		error(sys->sprint("error reading webget response header: %r"), loc);
	else {
		status := string bstatus[0:n];
		if(DEBUG)
			sys->print("webget response: %s\n", status);
		(nl, l) := sys->tokenize(status, " \n");
		if(nl < 3)
			error("unexpected webget response: " + status, loc);
		else {
			s := hd l;
			l = tl l;
			if(s == "ERROR") {
				(nil, msg) := stringmod->splitl(status[6:], " ");
				error(msg, loc);
			}
			else if(s == "OK") {
				clen = int (hd l);
				l = tl(tl l);
				dtype = hd l;
				l = tl l;
				nbase = hd l;
			}
			else
				error("webget protocol error", loc);
		}
	}
	return (dtype, nbase, clen);
}

webpost(base, url, types, msg: string) : (string, string, int)
{
	u := urlmod->makeurl(url);
	b := urlmod->makeurl(base);
	u.makeabsolute(b);
	savefrag := u.frag;
	u.frag = "";
	loc := u.tostring();
	u.frag = savefrag;
	clen := 0;
	dtype := "";
	nbase := "";
	s := sys->sprint("POST∎%d∎id1∎%s∎%s∎max-stale=3600\n", len msg, loc, types);
	if(DEBUG)
		sys->print("webget request: %s", s);
	bs := array of byte s;
	n := sys->write(webio, bs, len bs);
	if(n < 0)
		error(sys->sprint("error writing webget request: %r"), loc);
	n = sys->write(webio, array of byte msg, len array of byte msg);
	if(n < 0)
		error(sys->sprint("error writing webget post data: %r"), loc);
	else {
		(dtype, nbase, clen) = getstatus(loc);
	}
	return (dtype, nbase, clen);
}

webget(base, url, types: string) : (string, string, int)
{
	n : int;
	s : string;
	u := urlmod->makeurl(url);
	b := urlmod->makeurl(base);
	u.makeabsolute(b);
	savefrag := u.frag;
	u.frag = "";
	loc := u.tostring();
	u.frag = savefrag;
	clen := 0;
	dtype := "";
	nbase := "";
	s = "GET∎0∎id1∎" + loc + "∎" + types + "∎max-stale=3600\n";
	if(DEBUG)
		sys->print("webget request: %s", s);
	bs := array of byte s;
	n = sys->write(webio, bs, len bs);
	if(n < 0)
		error(sys->sprint("error writing webget request: %r"), loc);
	else {
		(dtype, nbase, clen) =  getstatus(loc);
	}
	return (dtype, nbase, clen);
}

webcontents(clen: int) : array of byte
{
	contents := array[clen] of byte;
	i := 0;
	n := 0;
	while(i < clen) {
		n = sys->read(webio, contents[i:], clen-i);
		if(n < 0)
			break;
		i += n;
	}
	return contents;
}

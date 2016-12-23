implement Wiki2text;
include "sys.m";
	sys: Sys;
include "draw.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "wiki.m";
	wiki: Wiki;
	Whist, Wdoc, Wpage: import wiki;

Wiki2text: module {
	init: fn(ctxt: ref Draw->Context, args: list of string);
};

init(nil: ref Draw->Context, args:list of string)
{
	sys = load Sys Sys->PATH;
	wiki = load Wiki Wiki->PATH;
	bufio = load Bufio Bufio->PATH;
	wiki->init(bufio);
	args = tl args;

	b := bufio->open(hd args, Sys->ORDWR);
	doc := wiki->Brdwhist(b);
	h := "";
	for(i := 0; i < doc.ndoc; i++){
		sys->print("__________________ %d ______________\n", i);
		if((h = wiki->pagetext("", doc.doc[i].wtxt, 1)) == nil)
			sys->print("error %r\n");
		sys->print("%s", h);
	}
}

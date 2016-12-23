implement Wiki2html;

include "sys.m";
	sys: Sys;
include "draw.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "wiki.m";
	wiki: Wiki;
	Whist, Wdoc, Wpage: import wiki;
include "arg.m";
	arg: Arg;

Wiki2html: module {
	init: fn(ctxt: ref Draw->Context, args: list of string);
};

init(nil: ref Draw->Context, args:list of string)
{
	sys = load Sys Sys->PATH;
	wiki = load Wiki Wiki->PATH;
	bufio = load Bufio Bufio->PATH;
	arg = load Arg Arg->PATH;
	wiki->init(bufio);

	t := wiki->Tpage;
	h: string;
	doc: ref Whist;
	arg->init(args);
	while((c := arg->opt()) != 0)
		case c {
		'd' =>
			wiki->setwikidir(arg->earg());
		'h' =>
			t = wiki->Thistory;
		'o' =>
			t = wiki->Toldpage;
		'D' =>
			t = wiki->Tdiff;
		}
	args = arg->argv();
	if(len args != 1)
		usage();

	if(t == wiki->Thistory || t==wiki->Tdiff)
		doc = wiki->gethistory(int hd args);
	else
		doc = wiki->getcurrent(int hd args);

	if(doc == nil){
		sys->print("doc: %r");
		exit;
	}

	if((h = wiki->tohtml(doc, doc.doc[doc.ndoc-1], t)) == nil){
		sys->print("wiki2html: %r");
		exit;
	}

	sys->print("%s", h);
}

usage()
{
	sys->fprint(sys->fildes(2), "usage: wiki2html [-d dir] wikifile\n");
	exit;
}

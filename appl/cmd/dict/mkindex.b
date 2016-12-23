implement Mkindex;

include "draw.m";

include "sys.m";
	sys: Sys;
	print, sprint: import sys;
include "libc.m";
	libc: Libc;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "arg.m";
	arg: Arg;
include "dictm.m";
	dict: Dictm; # current dictionary
	Entry: import dict;
include "utils.m";
	utils: Utils;
	err, fold, linelen, debug: import utils;
	
Mkindex: module
{
	init: fn(nil: ref Draw->Context, argl: list of string);
};

Dictinfo: adt{
	name: string;
	desc: string;
	path: string;
	indexpath: string;
	modpath: string;
};

dicts := array[] of {
	Dictinfo ("pgw",	"Project Gutenberg Webster Dictionary",	"/lib/dict/pgw",	"/lib/dict/pgwindex",	"/dis/dict/pgw.dis"),
	Dictinfo("simple", "Simple test dictionary", "/lib/dict/simple", "/lib/dict/simpleindex", "/dis/dict/simple.dis"),
	Dictinfo ("roget",	"Roget's Thesaurus from Project Gutenberg",	"/lib/dict/roget",	"/lib/dict/rogetindex", "/dis/dict/roget.dis"),
	Dictinfo ("wp",	"Wikipedia",	"/lib/dict/wikipedia",	"/lib/dict/wpindex", "/dis/dict/wikipedia.dis"),
	Dictinfo("oeisn", "Online Encyclopedia of Integer Sequences (Names)",  "/lib/dict/oeis-names", "/lib/dict/oeisindex", "/dis/dict/simple.dis"),
	Dictinfo("oeis", "Online Encyclopedia of Integer Sequences",  "/lib/dict/oeis", "/lib/dict/oeisidx", "/dis/dict/oeis.dis"),
	Dictinfo("pga", "Project Gutenberg Archive", "/lib/dict/pga", "/lib/dict/pgaindex", "/dis/dict/pg.dis"),
	Dictinfo("latin", "Latin-English Word List", "/lib/dict/latin", "/lib/dict/latinindex", "/dis/dict/simple.dis"),
};

bout, bdict: ref Iobuf;	#  output 

init(nil: ref Draw->Context, argl: list of string)
{
	sys = load Sys Sys->PATH;
	libc = load Libc Libc->PATH;
	bufio = load Bufio Bufio->PATH;
	arg = load Arg Arg->PATH;
	utils = load Utils Utils->PATH;
	
	dictinfo := dicts[0];
	startoff := big 0;
	bout = bufio->fopen(sys->fildes(1), Bufio->OWRITE);
	utils->init(bufio, bout);
	arg->init(argl);
	while((c := arg->opt()) != 0)
		case c {
			'd' =>
				p := arg->arg();
				if(p != nil)
					for(i := 0; i < len dicts; i++)
						if(p == dicts[i].name){
							dictinfo = dicts[i];
							break;
						}
				if(i == len dicts){
					err(sprint("unknown dictionary: %s", p));
					exit;
				}
			'o' =>
				startoff = big arg->earg();
			}
	dict = load Dictm dictinfo.modpath;
	if(dict == nil){
		err(sprint("can't load module %s: %r", dictinfo.modpath));
		exit;
	}
	bdict = bufio->open(dictinfo.path, Sys->OREAD);
	if(bdict == nil){
		err("can't open dictionary " + dictinfo.path);
		exit;
	}

	dict->init(bufio, utils, bdict, bout);
	dict->mkindex();
#	utils->breaklen = 1024;
#	ae := bdict.seek(big 0, 2);
#	print("%bd\n", ae);
#	for(a := startoff; a < ae; a = dict->nextoff(a+ big 1)) {
#		linelen = 0;
#		e := getentry(a);
#		bout.puts(sprint("%bd\t", a));
#		linelen = 4;
#		dict->printentry(e, 'h');
#	}
	bout.flush();
	exit;
}

getentry(b: big): Entry
{
	dtop: big;
	ans : Entry;
	e := dict->nextoff(b+ big 1);
	ans.doff = big b;
	if(e < big 0) {
		dtop = bdict.seek(big 0, 2);
		if(b < dtop){
			e = dtop;
		}else{
			err("couldn't seek to entry");
			ans.start = nil;
		}
	}
	n := int (e-b);
	if(n != 0){
		ans.start = array[n] of byte;
		bdict.seek(big b, 0);
		n = bdict.read(ans.start, n);
		ans.start = ans.start[:n];
	}
	return ans;
}

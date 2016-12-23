implement Dict;

include "draw.m";

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "libc.m";
	libc: Libc;
include "math.m";
	math: Math;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "arg.m";
	arg: Arg;
include "regex.m";
	regex : Regex;
	Re: import regex;
include "string.m";
	str: String;
include "dictm.m";
	dict: Dictm; # current dictionary
	Entry: import dict;
include "utils.m";
	utils: Utils;
	err, fold, linelen, debug: import utils;
	
Dict: module
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
	Dictinfo ("wd",	"Wiktionary",	"/lib/dict/wiktionary",	"/lib/dict/wdindex", "/dis/dict/wikipedia.dis"),
	Dictinfo("oeis", "Online Encyclopedia of Integer Sequences",  "/lib/dict/oeis", "/lib/dict/oeisidx", "/dis/dict/oeis.dis"),
	Dictinfo("pga", "Project Gutenberg Author Index", "/lib/dict/pga", "/lib/dict/pgaindex", "/dis/dict/pg.dis"),
	Dictinfo("latin", "Latin-English Word List", "/lib/dict/latin", "/lib/dict/latinindex", "/dis/dict/simple.dis"),
};

argv0:= "dict";

# 
#  Assumed index file structure: lines of form
#  	[^\t]+\t[0-9]+
#  First field is key, second is byte offset into dictionary.
#  Should be sorted with args -u -t'	' +0f -1 +0 -1 +1n -2
#  
Addr: adt{
	n: int;	#  number of offsets 
	cur: int;	#  current position within doff array 
	maxn: int;	#  actual current size of doff array 
	doff: array of big;	#  doff[maxn], with 0..n-1 significant 
};


bin: ref Iobuf;	#  user cmd input 
bout: ref Iobuf;	#  output 
bdict	#  dictionary 
, bindex: ref Iobuf;	#  index file 
indextop: int;	#  index offset at end of file 
lastcmd: int;	#  last executed command 
dot: ref Addr;	#  "current" address 

Plen: con 300;	#  max length of a search pattern 
Fieldlen: con 200;	#  max length of an index field 
Aslots: con 10;	#  initial number of slots in an address 

init(nil: ref Draw->Context, argl: list of string)
{
	sys = load Sys Sys->PATH;
	libc = load Libc Libc->PATH;
	math = load Math Math->PATH;
	bufio = load Bufio Bufio->PATH;
	arg = load Arg Arg->PATH;
	regex = load Regex Regex->PATH;
	str = load String String->PATH;
	utils = load Utils Utils->PATH;
	
	i, cmd, kflag: int;
	line, p: string;

	kflag = 0;
	line = nil;
	dictinfo := dicts[0];
	
	bout = bufio->fopen(sys->fildes(1), Bufio->OWRITE);
	bin = bufio->fopen(sys->fildes(0), Bufio->OREAD);
	utils->init(bufio, bout);
	arg->init(argl);
	while((c := arg->opt()) != 0)
		case c {
			'd' =>
				p = arg->arg();
				if(p != nil)
					for(i = 0; i < len dicts; i++)
						if(p == dicts[i].name){
							dictinfo = dicts[i];
							break;
						}
				if(i == len dicts)
					usage();
			'c' =>
				line = arg->arg();
				if(line == nil)
					usage();
			'k' =>
				kflag++;
			'D' =>
				debug++;
			* =>
				usage();
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
	bindex = bufio->open(dictinfo.indexpath, Sys->OREAD);
	if(bindex == nil){
		err("can't open index " + dictinfo.indexpath);
		exit;
	}
	
	dict->init(bufio, utils, bdict, bout);
	
	argl = arg->argv();
	if(kflag){
		dict->printkey();
		exit;
	}
	if(len argl  > 1)
		usage();
	else if(len argl == 1){
		if(line != nil)
			usage();
		p = hd argl;
		line = sprint("/%s/P\n", p);
	}
	indextop = int bindex.seek(big 0, 2);
	dot = ref Addr;
	dot.doff = array[Aslots] of big;
	dot.n = 0;
	dot.cur = 0;
	dot.maxn = Aslots;
	lastcmd = 0;
	if(line != nil){
		cmd = parsecmd(line);
		if(cmd)
			execcmd(cmd);
	}else
		for(;;){
			bout.puts("*");
			bout.flush();
			line = bin.gets('\n');
			linelen = 0;
			if(line == nil)
				break;
			cmd = parsecmd(line);
			if(cmd){
				execcmd(cmd);
				lastcmd = cmd;
			}
		}
	bout.flush();
	exit;
}

usage()
{
	i: int;

	bout.puts(sprint("Usage: %s [-d dict] [-k] [-c cmd] [word]\n", argv0));
	bout.puts("available dictionaries:\n");
	for(i = 0; i < len dicts; i++)
		bout.puts(sprint("   %s\t%s\n", dicts[i].name, dicts[i].desc));
	bout.flush();
	exit;
}

parsecmd(line: string): int
{
	cmd, ans: int;
	n: int;

	(n, line) = parseaddr(line);
	if(n < 0)
		return 0;
	cmd = line[0];
	ans = cmd;
	if(libc->isupper(cmd))
		cmd = libc->tolower(cmd);
	if(!(cmd == 'a' || cmd == 'h' || cmd == 'p' || cmd == 'r' || cmd == '\n')){
		err(sprint("unknown command %c", cmd));
		return 0;
	}
	if(cmd == '\n')
		case(lastcmd){
		0 =>
			ans = 'H';
		'H' =>
			ans = 'p';
		* =>
			ans = lastcmd;
		}
	else if(len line > 1 && line[1] !=  '\n')
		err(sprint("extra stuff after command %c ignored", cmd));
	return ans;
}

execcmd(cmd: int)
{
	e: Entry;
	cur, doall: int;

	if(libc->isupper(cmd)){
		doall = 1;
		cmd = libc->tolower(cmd);
		cur = 0;
	}
	else{
		doall = 0;
		cur = dot.cur;
	}
	if(debug && doall && cmd == 'a')
		bout.puts(sprint("%d entries, cur=%d\n", dot.n, cur+1));
	for(;;){
		if(cur >= dot.n)
			break;
		if(doall){
			bout.puts(sprint("%d\t", cur+1));
			linelen += 4+(cur >= 10);
		}
		case(cmd){
		'a' =>
			bout.puts(sprint("#%bd\n", dot.doff[cur]));
		'h' or 'p' or 'r' =>
			e = getentry(cur);
			dict->printentry(e, cmd);
		}
		cur++;
		if(doall){
			if(cmd == 'p' || cmd == 'r'){
				bout.putc('\n');
				linelen = 0;
			}
		}else
			break;
	}
	if(cur >= dot.n)
		cur = 0;
	dot.cur = cur;
}

# Address syntax: ('.' | '/' re '/' | '!' re '!' | number | '#' number) ('+' | '-')*
# Answer goes in dot.
# Return -1 if address starts, but get error.
# Return 0 if no address.

parseaddr(line: string): (int, string)
{
	delim, plen: int;
	e: string;
	pat := "";

	if(line[0] == '/' || line[0] == '!'){
		#  anchored regular expression match; '!' means no folding 
		if(line[0] ==  '/'){
			delim = '/';
			(e, line) = str->splitl(line[1:], "/\n");
		}
		else{
			delim = '!';
			(e, line) = str->splitl(line[1:], "!\n");
		}
		plen = len e;
		if(plen >= Plen-3){
			err("pattern too big");
			return (-1, nil);
		}
		pat = "^" + e + "$";
		line = line[1:];
		if(!search(pat, delim == '/')){
			err("pattern not found");
			return (-1, nil);
		}
	}else if(line[0] ==  '#'){
		v: big;
		(v, line) = str->tobig(line[1:], 10);
		#  absolute byte offset into dictionary 
		dot.doff[0] = v;
		dot.n = 1;
		dot.cur = 0;
	}else if(line[0] >= '0' && line[0] <= '9'){
		v: int;
		(v, line) = str->toint(line, 10);
		if(v < 1 || v > dot.n)
			err(sprint(".%d not in range [1,%d], ignored", v, dot.n));
		else
			dot.cur = v-1;
	}else if(line[0] ==  '.')
		line = line[1:];
	else{
		return (0, line);
	}
	while(len line > 0 && (line[0] == '+' || line[0] == '-')){
		if(line[0] == '+')
			setdotnext();
		else
			setdotprev();
		line = line[1:];
	}
	return (1, line);
}

#  acomp(s, t) returns:
#  	-2 if s strictly precedes t
#  	-1 if s is a prefix of t
#  	0 if s is the same as t
#  	1 if t is a prefix of s
#  	2 if t strictly precedes s

acomp(s, t: string): int
{
	cs, ct, l: int;

	if(len s > len t)
		l = len t;
	else
		l = len s;
	if(s == t)
		return 0;
	for(i := 0; i < l; i++) {
		cs = int s[i];
		ct = int  t[i];
		if(cs != ct)
			break;
	}
	if(i == len s)
		return -1;
	if(i == len t)
		return 1;
	if(cs < ct)
		return -2;
	return 2;
}

# Index file is sorted by folded field1.
# Method: find pre, a folded prefix of r.e. pat,
# and then low = offset to beginning of
# line in index file where first match of prefix occurs.
# Then go through index until prefix no longer matches,
# adding each line that matches real pattern to dot.
# Finally, sort dot offsets (uniquing).
# We know pat len < Plen, and that it is surrounded by ^..$

search(pat: string, dofold: int): int
{
	needre, n: int;
	match : array of (int, int);
	re: Re;
	ioff: int;
	v: big;
	pre : string;
	lit : string;
	entry : string;
	fpat : string;

	(pre, nil) = getpref(pat[1:]);
	if(len pat == len pre || pat[len pre+1] ==  '$'){
		lit = pre;
		if(dofold)
			lit = fold(lit);
		needre = 0;
		re = nil;
	}else{
		needre = 1;
		if(dofold){
			fpat = fold(pat);
			(re, nil) = regex->compile(fpat, 0);
		}
		else
			(re, nil) = regex->compile(pat, 0);
	}
	pre = fold(pre);
	ioff = locate(pre);
	if(ioff < 0)
		return 0;
	dot.n = 0;
	bindex.seek(big ioff, 0);
	for(;;){
		if((entry = getfield()) == nil)
			break;
		if(dofold)
			entry = fold(entry);
		if(needre)
			match = regex->execute(re, entry);
		else if(acomp(lit, entry) == 0)
			match = array[1] of (int, int);
		else
			match = nil;
		if(match != nil){
			if((entry = getfield()) == nil)
				break;
			(v, nil) = str->tobig(entry, 10);
			if(dot.n >= dot.maxn){
				n = 2*dot.maxn;
				dot.doff = (array[n] of big)[0:] = dot.doff;
				if(dot.doff == nil){
					err("out of memory");
					exit;
				}
				dot.maxn = n;
			}
			dot.doff[dot.n++] = v;
		}else{
			if(!dofold)
				entry = fold(entry);
			if(len pre > 0){
				n = acomp(pre, entry);
				if(n < -1 || !needre && n < 0)
					break;
			}
			#  get to next index entry 
			if((entry = getfield()) == nil)
				break;
		}
	}
	sortaddr(dot);
	dot.cur = 0;
	return dot.n;
}

# Return offset in index file of first line whose folded
# first field has pre as a prefix.  -1 if none found.

locate(pre: string): int
{
	top, bot, mid: int;
	entry :string;

	if(pre == nil)
		return 0;
	bot = 0;
	top = indextop;
	if(debug > 1)
		sys->fprint(sys->fildes(2), "locate looking for prefix %s\n", pre);

	# Loop invariant: foldkey(bot) < pre <= foldkey(top)
	# and bot < top, and bot,top point at beginning of lines

	for(;;){
		mid = (top+bot)/2;
		mid = seeknextline(bindex, mid);
		if(debug > 1)
			sys->fprint(sys->fildes(2), "bot=%d, mid=%d->%d, top=%d\n", bot, (top+bot)/2, mid, top);
		if(mid == top || (entry = getfield()) == nil)
			break;
		if(debug > 1)
			sys->fprint(sys->fildes(2), "key=%s\n", entry);

		# here mid is strictly between bot and top

		entry = fold(entry);
		if(acomp(pre, entry) <= 0)
			top = mid;
		else
			bot = mid;
	}

	# bot < top, but they don't necessarily point at successive lines
	# Use linear search from bot to find first line that pre is a
	# prefix of

	while((bot = seeknextline(bindex, bot)) <= top){  # we'll be missing the first line
		if((entry = getfield()) == nil)
			return -1;
		if(debug > 1)
			sys->fprint(sys->fildes(2), "s key=%s\n", entry);
		entry = fold(entry);
		case(acomp(pre, entry)){
		-2 =>
			return -1;
		-1 or 0 =>
			if(debug > 1)
			sys->fprint(sys->fildes(2), "ret bot %d\n", bot);
			return bot;
		1 or 2 =>
			continue;
		}
	}
	return -1;
}

# Get prefix of non re-metacharacters, runified, into pre,
# and return length

getpref(pat: string): (string, string)
{
	n := 0;
	while(n < len pat){
		case(pat[n]){
		'.' or '*' or '+' or '?' or
		'[' or ']' or '(' or  ')' or
		'|' or '^' or '$'  =>
			return (pat[:n], pat[n:]);
		'\\' =>
			n += 2;
		* =>
			n++;
		}
	}
	return (pat[:n], pat[n:]);
}

seeknextline(b: ref Iobuf, off: int): int
{
	c: int;

	b.seek(big off, 0);
	do
		c = b.getc();
	while(c >= 0 && c != '\n');
	return int b.offset();
}

# Get next field out of index file (either tab- or nl- terminated)
# Answer in *rp, assumed to be Fieldlen long.
# Return 0 if read error first.

getfield(): string
{
	s := bindex.gett("\t\n");
	if(len s > Fieldlen){
		err("word too long");
		return nil;
	}
	if(len s > 0 && (s[len s - 1] == '\t' || s[len s - 1] == '\n'))
		s = s[:len s - 1];
	return s;
}


sortaddr(a: ref Addr)
{
	i, j: int;
	v: big;

	if(a.n <= 1)
		return;
	qsort(a.doff, a.n);
	#  remove duplicates 
	for((i, j) = (0, 0); j < a.n; j++){
		v = a.doff[j];
		if(i > 0 && v == a.doff[i-1])
			continue;
		a.doff[i++] = v;
	}
	a.n = i;
}

qsort(a: array of big, n: int)
{
	i, j: int;
	t: big;

	while(n > 1){
		i = n>>1;
		t = a[0]; a[0] = a[i]; a[i] = t;
		i = 0;
		j = n;
		for(;;){
			do
				i++;
			while(i < n && a[i] < a[0]);
			do
				j--;
			while(j > 0 && a[j] > a[0]);
			if(j < i)
				break;
			t = a[i]; a[i] = a[j]; a[j] = t;
		}
		t = a[0]; a[0] = a[j]; a[j] = t;
		n = n-j-1;
		if(j >= n){
			qsort(a, j);
			a = a[j+1:];
		}else{
			qsort(a[j+1:], n);
			n = j;
		}
	}
}

ans: Entry;
anslen: int = 0;

getentry(i: int): Entry
{
	b, e: big;
	n: int;

	b = dot.doff[i];
	e = dict->nextoff(b+ big 1);
	ans.doff =  b;
	if(e < big 0){
		err("couldn't seek to entry");
		ans.start = nil;
		ans.end = nil;
	}else{
		n = int (e-b);
		ans.start = array[n+1] of byte;
#		anslen = n+1;
		bdict.seek(b, 0);
		n = bdict.read(ans.start, n);
		if(n < 0){
			err(sprint("read entry %bd %bd, %d: %r\n", b, e, n));
			return ans;
		};
		ans.start = ans.start[:n];
		ans.end = ans.start[n:];
	#	ans.end[0] = byte 0;   huh!
	}
	return ans;
}

setdotnext()
{
	b: big;

	b = dict->nextoff(dot.doff[dot.cur] + big 1);
	if(b < big 0){
		err("couldn't find a next entry");
		return;
	}
	dot.doff[0] = b;
	dot.n = 1;
	dot.cur = 0;
}

setdotprev()
{
	tryback: big;
	here, last, p: big;

	if(dot.cur < 0 || dot.cur >= dot.n)
		return;
	tryback = big 2000;
	here = dot.doff[dot.cur];
	last = big 0;
	while(last == big 0){
		p = here-tryback;
		if(p < big 0)
			p = big 0;
		for(;;){
			p = dict->nextoff(p+ big 1);
			if(p < big 0)
				return;	#  shouldn't happen 
			if(p >= here)
				break;
			last = p;
		}
		if(last == big 0){
			if(here-tryback < big 0){
				err("can't find a previous entry");
				return;
			}
			tryback = big 2*tryback;
		}
	}
	dot.doff[0] = last;
	dot.n = 1;
	dot.cur = 0;
}


implement Dictm;

include "draw.m";
include "sys.m";
	sys: Sys;
	print, sprint: import sys;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "utils.m";
	utils: Utils;
	err, outrune, outrunes, outnl, linelen, outinhibit,
	lookassoc, Assoc, debug: import utils;
include "dictm.m";

bdict, bout : ref Iobuf;

init(b: Bufio, u: Utils, bd, bo: ref Iobuf )
{
	sys = load Sys Sys->PATH;
	bufio = b;
	bdict = bd;
	bout = bo;
	utils = u;
}

NONE : con 16r800;

tagstarts: int;
tag : string;
head: string;
curentry: Entry;

#  Possible tags 
Br, Font, Anchor, Ntag: con  iota;

#  Assoc tables must be sorted on first field 
tagtab := array[] of {
	Assoc("br",	Br),
	Assoc("font",	Font),
	Assoc("a",	Anchor),
};

# Possible headers
Etextno, Title, Author, Language, Link, Nhead: con iota;

headtab := array[] of {
	Assoc("EText-No.", Etextno),
	Assoc("Title:", Title),
	Assoc("Author:", Author),
	Assoc("Language:", Language),
	Assoc("Link:", Link),
};

printentry(e: Entry, cmd: int)
{
	t: int;
	r, rprev: int;

	p := string e.start;
	rprev = NONE;
	curentry = e;
	outinhibit = 1;
	while(len p > 0){
		if(cmd == 'r'){
			outinhibit = 0;
			outrune(p[0]);
			p = p[1:];
			continue;
		}
		r = p[0];
		p = p[1:];
		if(r == '<'){
			#  Start of tag name 
			if(rprev != NONE){
				outrune(rprev);
				rprev = NONE;
			}
			p = gettag(p);
			t = lookassoc(tagtab, len tagtab, tag);
			if(t == -1){
				if(debug)
					err(sprint("tag %bd %d %s", e.doff, len curentry.start, tag));
				continue;
			}
			case(t){
			Font =>
				if(!tagstarts)
					continue;
				p = gethead(p);
#				err(sprint("head %s", head));
				h := lookassoc(headtab, len headtab, head);
				if(t == -1){
					if(debug)
						err(sprint("tag %bd %d %s", e.doff, len curentry.start, head));
					continue;
				}
				case(h){
				Author =>
					if(cmd == 'h')
						outinhibit = 0;
					else if(cmd == 't')
						outinhibit = 1;
					else {
						outinhibit = 0;
						outnl(0);
						outrunes(head);
					}
				Title =>
					if(cmd == 'h')
						outinhibit = 1;
					else if(cmd == 't')
						outinhibit = 0;
					else {
						outinhibit = 0;
						outnl(0);
						outrunes(head);
					}
				* =>
					if(cmd == 'h' || cmd == 't')
						outinhibit = 1;
					else{
						outinhibit = 0;
						outnl(0);
						outrunes(head);
					}
				}
			}
		}else{
			#  Emit the rune, but buffer in case of ligature 
			if(rprev != NONE){
				if(rprev == '*' || rprev == '#'){
					outnl(4);
					outrune('•');
				}else if(rprev == '\'' && r == '\''){
					r = NONE;
				}else if(rprev == '[' && r == '[')
					r = NONE;
				else if(rprev == ']' && r == ']')
					r  = NONE;
				else if(rprev == '=' && r == '='){
					outnl(2);
					r = NONE;
				}else if(rprev == '\n' && r == '\n'){
					outnl(2);
					r = NONE;
				}else if(rprev == '\n'){
					outrune(' ');
				}else
					outrune(rprev);
			}
			rprev = r;
		}
	}
	if(cmd == 'h' || cmd == 't'){
		outinhibit = 0;
		outnl(0);
	}
}

nextoff(fromoff: big): big
{
	c: int;
	if(bdict.seek(big fromoff, 0) < big 0)
		return big -1;
	for(;;){
		c = bdict.getc();
		if(c < 0){
			sys->fprint(sys->fildes(2), "nextoff getc: %r\n");
			return big -1;
		}
		if(c == 'E' && bdict.getc() == 'T' && bdict.getc()=='e' 
		&& bdict.getc()=='x' && bdict.getc()=='t')
			break;
	}
#	sys->fprint(sys->fildes(2), "nextoff found %bd\n", bdict.offset() - big 2);
	return (bdict.offset() - big 5);
}

printkey()
{
	bout.puts("No pronunciation key.\n");
}


mkindex()
{
	utils->breaklen = 1024;
	ae := bdict.seek(big 0, 2);
	print("End byte %bd\n", ae);
	for(a := big 0; a < ae && a !=  big -1; a = nextoff(a+ big 1)) {
		linelen = 0;
		e := getentry(a);
		bout.puts(sprint("%bd\t", a));
		linelen = 4;
		printentry(e, 'h');
		linelen = 0;
		e = getentry(a);
		bout.puts(sprint("%bd\t", a));
		linelen = 4;
		printentry(e, 't');
	}
}

getentry(b: big): Entry
{
	dtop: big;
	ans : Entry;
	e := nextoff(b+ big 1);
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

#  * f points just after '<'; fe points at end of entry.
#  * Expect next characters from bin to match:
#  *  [/][^ >]+( [^>=]+=[^ >]+)*>
#  *      tag   auxname auxval
#  * Accumulate the tag and its auxilliary information in
#  * tag[], auxname[][] and auxval[][].
#  * Set tagstarts=1 if the tag is 'starting' (has no '/'), else 0.
#  * Set naux to the number of aux pairs found.
#  * Return pointer to after final '>'.

gettag(f: string): string
{
	tag = "";
	k := 0;
	if(f[0] == '/'){
		tagstarts = 0;
		f = f[1:];
	}else {
		tagstarts = 1;
	}
	loop: for(i := 0; i < len f; i++){
		if(f[i] == '>'){
			if(f[i-1] == '/')
				tagstarts = 0;
			break;
		}else if (f[i] == ' '){
			for (; i < len f; i++)
				if(f[i] == '>')
					break loop;
		}
		tag[k++] = f[i];
	}
	return f[i+1:];
}

gethead(f: string): string
{
	head = "";
	k := 0;
	for(i := 0; i < len f; i++){
		if(f[i] == '<'){
			break;
		}
		head[k++] = f[i];
	}
	return f[i:];
}

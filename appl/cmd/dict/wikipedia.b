implement Dictm;

include "draw.m";
include "sys.m";
	sys: Sys;
	sprint: import sys;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "libc.m";
	libc: Libc;
include "utils.m";
	utils: Utils;
	outrune, outrunes, outnl, Assoc, outinhibit,
	lookassoc,debug,err: import utils;
include "dictm.m";
include "string.m";
	str: String;
	
bdict, bout : ref Iobuf;

init(b: Bufio, u: Utils, bd, bo: ref Iobuf )
{
	sys = load Sys Sys->PATH;
	bufio = b;
	bdict = bd;
	bout = bo;
	utils = u;
	libc = load Libc Libc->PATH;
	str = load String String->PATH;
}

Buflen: con 1000;
Maxaux: con 5;

#  Possible tags 
Title, Text, Ntag: con  iota;

NONE : con 16r800;


#  Assoc tables must be sorted on first field 
tagtab := array[] of {
	Assoc("text",	Text),
	Assoc("title",	Title),
};

spectab := array[] of {
	Assoc("amp",		'&'),
	Assoc("gt", '>'),
	Assoc("lt",	'<'),
	Assoc("mdash", '-'),
	Assoc("nbsp", '\u00a0'),
	Assoc("ndash", '-'),
	Assoc("quot", '\''),
};

tagstarts: int;
tag : string;
spec : string;
curentry: Entry;

# 
#  * cmd is one of:
#  *    'p': normal print
#  *    'h': just print headwords
#  *    'P': print raw
#  
printentry(e: Entry, cmd: int)
{
	t: int;
	r, rprev: int;

	p := string e.start;
	p = substituteentities(p);
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
#		if(r == '&'){
#			#  Start of special character name 
#			(spec, p) = getspec(p);
#			r = lookassoc(spectab, len spectab, spec);	
#			if(r == -1){
#				if(debug)
#					err(sprint("spec %bd %d %s", e.doff, len curentry.start, spec));
#				r = '�';
#			}
#			if(rprev != NONE)
#				outrune(rprev);
#			rprev = r;
#		}else 
		
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
			Title =>
				outinhibit = !tagstarts;
				outrune(' ');
			Text =>
				if(cmd != 'h')
					outinhibit = !tagstarts;
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
	if(cmd == 'h'){
		outinhibit = 0;
		outnl(0);
	}
}

# 
#  Return offset into bdict where next Wikipedia entry after fromoff starts.
#  Wikipedia entries start with <title>
#  
nextoff(fromoff: big): big
{
	a: big;
	n: int;
	c: int;
	a = bdict.seek(fromoff, 0);
	if(a != fromoff)
		return big -1;
	n = 0;
	for(;;){
		c = bdict.getc();
		if(c < 0){
			sys->fprint(sys->fildes(2), "getc: %r\n");
			break;
		}
		if(c == '<' && bdict.getc() == 't' && bdict.getc() == 'i'){
			if(bdict.getc() == 't' && bdict.getc() == 'l'
			&& bdict.getc() == 'e' && bdict.getc() == '>')
				n = 7;
			if(n)
				break;
		}
	}
	return (bdict.offset()- big n);
}


printkey()
{
	bout.puts("No pronunciation key\n");
}

#  f points just after a '&'
#  Accumulate the special name, starting after the &
#  and continuing until the next ';'.

getspec(f: string): (string, string)
{
	for(i := 0; i < len f; i++){
		if(f[i] == ';')
			break;
	}
	if(i == len f)
		return (f, nil);
	else
		return (f[:i], f[i+1:]);
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

substituteentities(buff: string): string
{
	i := 0;
	while (i < len buff) {
		if (buff[i] == '&') {
			(t, j) := translateentity(buff, i);
			# XXX could be quicker
			buff = buff[0:i] + t + buff[j:];
			i += len t;
		} else
			i++;
	}
	return buff;
}

translateentity(s: string, i: int): (string, int)
{
	i++;
	for (j := i; j < len s; j++)
		if (s[j] == ';')
			break;
	ent := s[i:j];
	if (j == len s) {
		if (len ent > 10)
			ent = ent[0:11] + "...";
		err(sys->sprint("missing ; at end of entity (&%s)", ent));
		return (nil, i);
	}
	j++;
	if (ent == nil) {
		err("empty entity");
		return ("", j);
	}
	if (ent[0] == '#') {
		n: int;
		rem := ent;
		if (len ent >= 3 && ent[1] == 'x')
			(n, rem) = str->toint(ent[2:], 16);
		else if (len ent >= 2)
			(n, rem) = str->toint(ent[1:], 10);
		if (rem != nil) {
			err(sys->sprint("unrecognized entity (&%s)", ent));
			return (nil, j);
		}
		ch: string = nil;
		ch[0] = n;
		return (ch, j);
	}
	hv := lookassoc(spectab, len spectab, ent);
	if (hv == -1) {
		err(sys->sprint("unrecognized entity (&%s)", ent));
		return (nil, j);
	}
	hvs : string = nil;
	hvs[0] = hv;
	return (hvs, j);
}

mkindex()
{
	offset: big;
	title: string;
	for(;;){
		c := bdict.getc();
		if(c < 0)
			break;
		if(c == '<' && bdict.getc() == 't' && bdict.getc() == 'i'){
			if(bdict.getc() == 't' && bdict.getc() == 'l'
			&& bdict.getc() == 'e' && bdict.getc() == '>'){
				offset = bdict.offset() - big 7;
				title = "";
				i := 0;
				while((c = bdict.getc()) != '<')
					title[i++] = c;
				title = substituteentities(title);
				bout.puts(sprint("%bd\t%s\n", offset, title));
			}
		}
	}
	bout.flush();
}

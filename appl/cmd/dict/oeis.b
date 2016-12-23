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
	err, outrune, outnl, linelen: import utils;
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

# Routines for handling dictionaries in UTF, headword
# separated from entry by tab, entries separated by newline.

printentry(e: Entry, cmd: int)
{
	inhead := 0;
	s := string e.start;
	for(i := 0; i < len s; i++){
		if(cmd == 'r'){
			outrune(s[i]);
		}else if(cmd == 'h'){
			if(s[i] == '%' && s[i+1] == 'I')
				inhead = 1;
			if(inhead && s[i] == '\n'){
				inhead = 0;
			}
			if(inhead){
				if(s[i] != '%' && s[i] != 'I' && s[i] != ' ')
					outrune(s[i]);
			}
		}else{
			outrune(s[i]);
			if(s[i] == '\n')
				linelen = 0;
		}
	}
	outnl(0);
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
		if(c == '%' && bdict.getc() == 'I')
			break;
	}
#	sys->fprint(sys->fildes(2), "nextoff found %bd\n", bdict.offset() - big 2);
	return (bdict.offset() - big 2);
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

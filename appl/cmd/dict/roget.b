implement Dictm;

include "draw.m";
include "sys.m";
	sys: Sys;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "libc.m";
	libc: Libc;
include "utils.m";
	utils: Utils;
	outrune, outrunes, outnl: import utils;
include "dictm.m";

bdict, bout : ref Iobuf;

init(b: Bufio, u: Utils, bd, bo: ref Iobuf )
{
	sys = load Sys Sys->PATH;
	bufio = b;
	bdict = bd;
	bout = bo;
	utils = u;
	libc = load Libc Libc->PATH;
}

# Roget's Thesaurus from project Gutenberg

printentry(e: Entry, cmd: int)
{
	spc: int = 0;
	c: int;
	
	p := string e.start;
	if(cmd == 'h'){
		while(len p > 0 && !libc->isspace(p[0]))
			p = p[1:];
		while(len p >=4 && p[:4] == " -- "){
			while(len p > 0 && libc->isspace(p[0]))
				p = p[1:];
			if(p[0] == '[' || p[0] == '{'){
				if(p[0] == '[')
					c = ']';
				else
					c = '}';
				while(len p > 0 && p[0] != c)
					p = p[1:];
				continue;
			}
			if(libc->isdigit(p[0]) || libc->ispunct(p[0])){
				while(len p > 0 && !libc->isspace(p[0]))
					p = p[1:];
				continue;
			}
			
			if(libc->isspace(p[0]))
				spc = 1;
			else if(spc){
				outrune(' ');
				spc = 0;
			}
			
			while(len p > 0 && !libc->isspace(p[0])) {
				outrune(p[0]);
				p = p[1:];
			}
		}
		return;
	}
	while(len p > 0 && !libc->isspace(p[0]))
		p = p[1:];
	
	while(len p > 0 && libc->isspace(p[0]))
		p = p[1:];
	
	while(len p > 0) {
		if(len p > 4 && p[:4] == " -- "){
			outnl(2);
			p = p[4:];
			spc = 0;
		}
		
		if(len p > 2 && p[:2] == "[ "){
			outrunes(" [");
			continue;
		}
		
		if(len p > 4 && p[:4] == "&c ("){
			if(spc)
				outrune(' ');
			outrune('/');
			while(len p > 0 && p[0] != '(')
				p = p[1:];
			p = p[1:];
			while(len p > 0 && p[0] != ')'){
				outrune(p[0]);
				p = p[1:];
			}
			p = p[1:];
			while(len p > 0 && libc->isspace(p[0]))
				p = p[1:];
			while(len p > 0 && libc->isdigit(p[0]))
				p = p[1:];
			outrune('/');
			continue;
		}
		
		if(len p > 3 && p[:3] == "&c "){
			while(len p > 0 && !libc->isdigit(p[0]))
				p = p[1:];
			while(len p > 0 && libc->isdigit(p[0]))
				p = p[1:];
			continue;
		}
		
		if(len p > 0 && p[0] == '\n'){
			spc = 0;
			p = p[1:];
			if(len p > 0 && libc->isspace(p[0])){
				while(len p > 0 && libc->isspace(p[0]))
					p = p[1:];
				# TBA was p--;
			}else {
				outnl(2);
			}
		}
		if(len p > 0 && spc && p[0] != ';' && p[0] != '.' &&
			p[0] != ',' && !libc->isspace(p[0])){
				spc = 0;
				outrune(' ');
		}
		if(len p > 0 && libc->isspace(p[0]))
			spc = 1;
		else if (len p > 0)
			outrune(p[0]);
		if(len p > 0)
			p = p[1:];
	}
	outnl(0);
}

nextoff(fromoff: big): big
{
	bdict.seek(big fromoff, 0);
	bdict.gets('\n');
	while((p := bdict.gets('\n')) != nil){
		if(!libc->isdigit(p[0]))
			continue;
		for(i := 0; i < len p - 4; i++)
			if(p[i:i+4] == " -- ")
				return bdict.offset() - big len p;
	}
	return bdict.offset();
}

printkey()
{
	bout.puts("No pronunciation key.\n");
}

mkindex()
{
}

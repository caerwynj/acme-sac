implement Dcr;

include "sys.m";
include "draw.m";
include "sh.m";

Dcr: module {
	init: fn(nil:ref Draw->Context, nil: list of string);
};

init(nil: ref Draw->Context, nil: list of string)
{
	sys := load Sys Sys->PATH;
	buf := array[256] of byte;
	
	stdin := sys->fildes(0);
	stdout := sys->fildes(1);
	rd: while((n := sys->read(stdin, buf, len buf)) != 0){
		p := buf[:n];
		loop: while (len p > 0){
			for(i:=0; i < len p; i++){
				if(int(p[i]) == ''){
					sys->write(stdout, p[0:i], len p[:i]);
					if((i+1) == len p)
						continue rd;
					p = p[i+1:];
					continue loop;
				}
			}
			sys->write(stdout, p, len p);
			continue rd;
		}
	}
}

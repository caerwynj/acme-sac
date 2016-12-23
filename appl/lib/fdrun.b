implement FDrun;
include "sys.m";
	sys: Sys;
include "draw.m";
include "sh.m";
	sh: Sh;
include "fdrun.m";

init()
{
	sys = load Sys Sys->PATH;
	sh = load Sh Sh->PATH;
}

# run command args; spec specifies how to arrange the file descriptors
# for the command; spec[i] specifies how to arrange fd i; a decimal digit n,
# means use sfds[n]; 'x' means use /dev/null; '-' means leave untouched.
# status of command is sent down result.
run(ctxt: ref Draw->Context, args: list of string, spec: string, sfds: array of ref Sys->FD, result: chan of string): int
{
	fds := array[len spec] of ref Sys->FD;
	for(i := 0; i < len spec; i++){
		case spec[i] {
		'x' =>
			fds[i] = sys->open("/dev/null", Sys->ORDWR);
		'-' =>
			;
		'0' to '9' =>
			p := spec[i] - '0';
			if(p >= len sfds){
				sys->werrstr("fd array too short");
				return -1;
			}
			fds[i] = sfds[p];
		* =>
			sys->werrstr("invalid character in spec");
			return -1;
		}
	}
	sfds = nil;
	spawn runpipe(ctxt, args, fds, sync := chan of int, result);
	<-sync;
	return 0;
}

runpipe(ctxt: ref Draw->Context,
		args: list of string,
		fds: array of ref Sys->FD,
		sync: chan of int,
		result: chan of string)
{
	sys->pctl(Sys->FORKFD, nil);
	fl: list of int;
	for(i := 0; i < len fds; i++){
		if(fds[i] != nil && fds[i].fd != i)
			sys->dup(fds[i].fd, i);
		fl = i :: fl;
	}
	fds = nil;
	sys->pctl(Sys->NEWFD, fl);
	sync <-= 0;
	result <-= sh->run(ctxt, args);
}
